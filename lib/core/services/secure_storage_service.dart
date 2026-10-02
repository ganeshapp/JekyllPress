import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// How the stored access token was obtained
abstract final class AuthMethods {
  /// Personal Access Token pasted by the user
  static const pat = 'pat';

  /// GitHub Device Flow (GitHub App or OAuth App)
  static const device = 'device';
}

/// The GitHub session: access token (PAT or device-flow token), how it was
/// obtained, the device-flow client id, refresh token and expiry.
///
/// The whole session is ONE item, a JSON object under [sessionKey], in the
/// platform's credential store. On macOS an ad-hoc-signed build gets a new
/// code identity with every update, and the login keychain asks "Always
/// Allow" once per item it then reads: one item is one prompt, not five.
/// Reads are cached for the life of the process for the same reason.
class SecureStorageService {
  static const sessionKey = 'session';

  // Fields of the session JSON
  static const _token = 'token';
  static const _authMethod = 'authMethod';
  static const _clientId = 'clientId';
  static const _refreshToken = 'refreshToken';
  static const _expiry = 'expiry';
  static const _fields = [_token, _authMethod, _clientId, _refreshToken, _expiry];

  /// 2.2.1-and-earlier layout: one item per field, in [_fields] order
  static const legacyKeys = [
    'github_pat',
    'auth_method',
    'oauth_client_id',
    'refresh_token',
    'access_token_expiry',
  ];

  /// Keychain service name (macOS). The plugin's default is shared by every
  /// app built with it, so two such apps on one Mac would read each other's
  /// items and macOS would demand the login keychain password.
  static const keychainService = 'com.jekyllpress.jekyllpress';

  /// The data-protection keychain needs a provisioning profile, which an
  /// ad-hoc signed build cannot have (-34018); use the login keychain.
  static const macOsOptions = MacOsOptions(
    useDataProtectionKeyChain: false,
    accountName: keychainService,
  );

  /// Where 2.2.0 wrote: the plugin's shared default service
  static const sharedMacOsOptions = MacOsOptions(
    useDataProtectionKeyChain: false,
  );

  final FlutterSecureStorage _storage;
  final FlutterSecureStorage _shared;
  Map<String, String>? _cache;

  /// [storage] and [shared] are injection points for tests
  SecureStorageService({FlutterSecureStorage? storage, FlutterSecureStorage? shared})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              mOptions: macOsOptions,
            ),
        _shared = shared ?? const FlutterSecureStorage(mOptions: sharedMacOsOptions);

  /// Save the GitHub access token (PAT or device-flow access token)
  Future<void> saveToken(String token) => _update({_token: token});

  /// Retrieve the stored GitHub access token
  Future<String?> getToken() async => (await _session())[_token];

  /// Delete all session data (logout). The OAuth client id survives so
  /// signing back in stays one tap.
  Future<void> deleteToken() => _update({
        _token: null,
        _authMethod: null,
        _refreshToken: null,
        _expiry: null,
      });

  /// Check if a token exists
  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// How the current token was obtained: [AuthMethods.pat],
  /// [AuthMethods.device], or null when logged out
  Future<String?> getAuthMethod() async => (await _session())[_authMethod];

  Future<void> saveAuthMethod(String method) => _update({_authMethod: method});

  /// The GitHub App / OAuth App client id used for device-flow sign-in.
  /// Kept across logouts.
  Future<String?> getClientId() async => (await _session())[_clientId];

  Future<void> saveClientId(String clientId) => _update({_clientId: clientId});

  /// Single-use device-flow refresh token; null for PAT/OAuth-App sessions
  Future<String?> getRefreshToken() async => (await _session())[_refreshToken];

  Future<void> saveRefreshToken(String? refreshToken) =>
      _update({_refreshToken: refreshToken});

  /// When the device-flow access token expires; null = never (PAT or
  /// OAuth-App token)
  Future<DateTime?> getAccessTokenExpiry() async {
    final iso = (await _session())[_expiry];
    return iso == null ? null : DateTime.tryParse(iso);
  }

  Future<void> saveAccessTokenExpiry(DateTime? expiry) =>
      _update({_expiry: expiry?.toIso8601String()});

  /// Persist a device-flow token set as ONE write. Refresh tokens are
  /// single-use, so with separate items a crash between writes could leave
  /// a fresh access token whose only refresh token was already burned; a
  /// single item cannot be half-updated.
  Future<void> saveDeviceFlowTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? accessTokenExpiry,
  }) =>
      _update({
        _refreshToken: refreshToken,
        _expiry: accessTokenExpiry?.toIso8601String(),
        _token: accessToken,
        _authMethod: AuthMethods.device,
      });

  /// macOS, once per install: 2.2.0 wrote the five legacy items under the
  /// plugin's shared default service. Adopt them as this app's session when
  /// it has none (so the update does not sign the user out), then delete
  /// them so they stop triggering other apps' keychain prompts. Every step
  /// is best effort: the reads may prompt and be denied. Never deleteAll -
  /// the shared service holds other apps' items too.
  Future<void> adoptSharedServiceItems() async {
    try {
      final legacy = await _readLegacy(_shared);
      if (legacy[_token] != null && (await _session())[_token] == null) {
        await _write({...await _session(), ...legacy});
      }
    } catch (_) {
      // Denied, or this app's own item unreadable: still clean up below
    }
    for (final key in legacyKeys) {
      try {
        await _shared.delete(key: key);
      } catch (_) {}
    }
  }

  /// The session, migrating the one-item-per-field layout of 2.2.1 and
  /// earlier on first read
  Future<Map<String, String>> _session() async {
    if (_cache case final cached?) return cached;
    final json = await _storage.read(key: sessionKey);
    if (json != null) {
      return _cache = Map<String, String>.from(jsonDecode(json) as Map);
    }
    final legacy = await _readLegacy(_storage);
    if (legacy.isNotEmpty) {
      await _write(legacy);
      for (final key in legacyKeys) {
        await _storage.delete(key: key);
      }
    }
    return _cache = legacy;
  }

  /// Apply [changes] (null removes a field) and persist the result
  Future<void> _update(Map<String, String?> changes) async {
    final session = {...await _session()};
    changes.forEach((field, value) {
      value == null ? session.remove(field) : session[field] = value;
    });
    await _write(session);
  }

  Future<void> _write(Map<String, String> session) async {
    if (session.isEmpty) {
      await _storage.delete(key: sessionKey);
    } else {
      await _storage.write(key: sessionKey, value: jsonEncode(session));
    }
    _cache = session;
  }

  static Future<Map<String, String>> _readLegacy(
      FlutterSecureStorage storage) async {
    final session = <String, String>{};
    for (var i = 0; i < legacyKeys.length; i++) {
      final value = await storage.read(key: legacyKeys[i]);
      if (value != null) session[_fields[i]] = value;
    }
    return session;
  }
}
