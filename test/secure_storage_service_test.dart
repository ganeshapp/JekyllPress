import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jekyllpress/core/config/github_app_config.dart';
import 'package:jekyllpress/core/services/secure_storage_service.dart';

import 'fakes.dart';

const _session = SecureStorageService.sessionKey;

/// The five items 2.2.1-and-earlier wrote, one per field
const _legacyItems = {
  'github_pat': 'ghu_old',
  'auth_method': 'device',
  'oauth_client_id': 'Iv1.old',
  'refresh_token': 'ghr_old',
  'access_token_expiry': '2026-10-03T10:00:00.000',
};

void main() {
  group('keychain options (regression: the shared default service)', () {
    test('the macOS service name is app-specific', () {
      final params = SecureStorageService.macOsOptions.params;
      expect(params['accountName'], 'com.jekyllpress.jekyllpress');
      expect(params['accountName'], isNot(AppleOptions.defaultAccountName));
      expect(params['useDataProtectionKeyChain'], 'false');
    });

    test('the legacy cleanup targets the plugin default service', () {
      final params = SecureStorageService.sharedMacOsOptions.params;
      expect(params['accountName'], AppleOptions.defaultAccountName);
      expect(params['useDataProtectionKeyChain'], 'false');
    });
  });

  group('one-item session', () {
    late MemoryStorage storage;
    late SecureStorageService service;

    setUp(() {
      storage = MemoryStorage();
      service = SecureStorageService(storage: storage);
    });

    test('round trip: every field lands in one item and reads back', () async {
      final expiry = DateTime(2026, 10, 3, 10);
      await service.saveClientId('Iv1.abc');
      await service.saveDeviceFlowTokens(
        accessToken: 'ghu_access',
        refreshToken: 'ghr_refresh',
        accessTokenExpiry: expiry,
      );

      expect(storage.items.keys, [_session]);
      expect(await service.getToken(), 'ghu_access');
      expect(await service.getAuthMethod(), AuthMethods.device);
      expect(await service.getClientId(), 'Iv1.abc');
      expect(await service.getRefreshToken(), 'ghr_refresh');
      expect(await service.getAccessTokenExpiry(), expiry);

      // A fresh instance (next launch) reads the same from the store
      final again = SecureStorageService(storage: storage);
      expect(await again.getToken(), 'ghu_access');
      expect(await again.getClientId(), 'Iv1.abc');
    });

    test('a device-flow token set is a single write', () async {
      await service.saveDeviceFlowTokens(
        accessToken: 'ghu_access',
        refreshToken: 'ghr_refresh',
        accessTokenExpiry: DateTime(2026),
      );
      expect(storage.writes, 1);
    });

    test('reads are served from memory after the first one', () async {
      storage.items[_session] = jsonEncode({'token': 'ghp_x'});
      expect(await service.getToken(), 'ghp_x');
      storage.items.clear();
      expect(await service.getToken(), 'ghp_x');
    });

    test('a PAT session has no refresh token or expiry', () async {
      await service.saveToken('ghp_pat');
      await service.saveAuthMethod(AuthMethods.pat);
      expect(await service.getRefreshToken(), isNull);
      expect(await service.getAccessTokenExpiry(), isNull);
      expect(jsonDecode(storage.items[_session]!), {
        'token': 'ghp_pat',
        'authMethod': 'pat',
      });
    });

    test('logout clears everything but the client id', () async {
      await service.saveClientId('Iv1.abc');
      await service.saveDeviceFlowTokens(
        accessToken: 'ghu_access',
        refreshToken: 'ghr_refresh',
        accessTokenExpiry: DateTime(2026),
      );

      await service.deleteToken();

      expect(await service.hasToken(), isFalse);
      expect(await service.getAuthMethod(), isNull);
      expect(await service.getRefreshToken(), isNull);
      expect(await service.getAccessTokenExpiry(), isNull);
      expect(await service.getClientId(), 'Iv1.abc');
      expect(jsonDecode(storage.items[_session]!), {'clientId': 'Iv1.abc'});
    });

    test('logout with no client id removes the item entirely', () async {
      await service.saveToken('ghp_pat');
      await service.deleteToken();
      expect(storage.items, isEmpty);
    });

    test('a locked store surfaces the error instead of a stale value',
        () async {
      final locked = SecureStorageService(storage: MemoryStorage({}, true));
      expect(locked.getToken(), throwsA(isA<Object>()));
    });
  });

  group('migration from one item per field (2.2.1 and earlier)', () {
    test('builds the session on first read and deletes the five items',
        () async {
      final storage = MemoryStorage({..._legacyItems});
      final service = SecureStorageService(storage: storage);

      expect(await service.getToken(), 'ghu_old');
      expect(await service.getAuthMethod(), 'device');
      expect(await service.getClientId(), 'Iv1.old');
      expect(await service.getRefreshToken(), 'ghr_old');
      expect(await service.getAccessTokenExpiry(),
          DateTime(2026, 10, 3, 10));
      expect(storage.items.keys, [_session]);
    });

    test('a partial legacy session (PAT: token + method) migrates too',
        () async {
      final storage = MemoryStorage({
        'github_pat': 'ghp_old',
        'auth_method': 'pat',
      });
      final service = SecureStorageService(storage: storage);

      expect(await service.getToken(), 'ghp_old');
      expect(await service.getRefreshToken(), isNull);
      expect(jsonDecode(storage.items[_session]!), {
        'token': 'ghp_old',
        'authMethod': 'pat',
      });
    });

    test('nothing stored stays nothing stored', () async {
      final storage = MemoryStorage();
      final service = SecureStorageService(storage: storage);
      expect(await service.getToken(), isNull);
      expect(storage.items, isEmpty);
    });
  });

  group('adoptSharedServiceItems (macOS, 2.2.0 shared keychain service)', () {
    const pat = {'github_pat': 'ghp_old', 'auth_method': 'pat'};

    test('an upgrade adopts a PAT session and deletes the items', () async {
      final own = MemoryStorage();
      final shared = MemoryStorage({...pat, 'other_app': 'keep'});
      final service = SecureStorageService(storage: own, shared: shared);

      await service.adoptSharedServiceItems(upgrade: true);

      expect(await service.getToken(), 'ghp_old');
      expect(await service.getAuthMethod(), AuthMethods.pat);
      expect(own.items.keys, [_session]);
      // Per-key deletes only: another app's item in the shared service
      // survives
      expect(shared.items, {'other_app': 'keep'});
    });

    test('an upgrade adopts a device-flow session issued to this app',
        () async {
      final own = MemoryStorage();
      final shared = MemoryStorage({
        ..._legacyItems,
        'oauth_client_id': GitHubAppConfig.bundledClientId,
      });
      final service = SecureStorageService(storage: own, shared: shared);

      await service.adoptSharedServiceItems(upgrade: true);

      expect(await service.getToken(), 'ghu_old');
      expect(await service.getRefreshToken(), 'ghr_old');
      expect(await service.getClientId(), GitHubAppConfig.bundledClientId);
      expect(shared.items, isEmpty);
    });

    test("another app's device-flow session is deleted, not adopted",
        () async {
      final own = MemoryStorage();
      final shared = MemoryStorage({..._legacyItems}); // client id Iv1.old
      final service = SecureStorageService(storage: own, shared: shared);

      await service.adoptSharedServiceItems(upgrade: true);

      expect(await service.getToken(), isNull);
      expect(own.items, isEmpty);
      expect(shared.items, isEmpty);
    });

    test('a fresh install never reads the shared service, only deletes',
        () async {
      final own = MemoryStorage();
      final shared = MemoryStorage({...pat, 'other_app': 'keep'});
      final service = SecureStorageService(storage: own, shared: shared);

      await service.adoptSharedServiceItems(upgrade: false);

      expect(shared.reads, 0);
      expect(own.items, isEmpty);
      expect(shared.items, {'other_app': 'keep'});
    });

    test('never overwrites an existing session, still deletes', () async {
      final own = MemoryStorage({
        _session: jsonEncode({'token': 'ghp_mine', 'authMethod': 'pat'}),
      });
      final shared = MemoryStorage({...pat});
      final service = SecureStorageService(storage: own, shared: shared);

      await service.adoptSharedServiceItems(upgrade: true);

      expect(await service.getToken(), 'ghp_mine');
      expect(shared.items, isEmpty);
    });

    test('a denied keychain prompt leaves the app signed out, no throw',
        () async {
      final own = MemoryStorage();
      final service = SecureStorageService(
        storage: own,
        shared: MemoryStorage({...pat}, true),
      );

      await service.adoptSharedServiceItems(upgrade: true);

      expect(await service.getToken(), isNull);
      expect(own.items, isEmpty);
    });

    test('nothing in the shared service is a no-op', () async {
      final own = MemoryStorage();
      final service =
          SecureStorageService(storage: own, shared: MemoryStorage());
      await service.adoptSharedServiceItems(upgrade: true);
      expect(own.items, isEmpty);
    });
  });
}
