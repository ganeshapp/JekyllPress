import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jekyllpress/core/services/secure_storage_service.dart';

/// In-memory stand-in for the flutter_secure_storage plugin, so the real
/// [SecureStorageService] (its JSON item, migration, cache) can be tested.
/// [locked] throws on every call, like a Linux keyring that is absent or
/// whose unlock the user cancelled, or a denied macOS keychain prompt.
class MemoryStorage extends FlutterSecureStorage {
  final Map<String, String> items;
  final bool locked;
  int writes = 0;

  MemoryStorage([Map<String, String>? items, this.locked = false])
      : items = items ?? {};

  void _check() {
    if (locked) throw PlatformException(code: 'Libsecret error');
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _check();
    return items[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _check();
    writes++;
    items[key] = value!;
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _check();
    items.remove(key);
  }

  /// On macOS the shared default service holds other apps' items too
  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    fail('deleteAll must never be called');
  }
}

/// In-memory SecureStorageService that never touches platform channels
class FakeSecureStorage extends SecureStorageService {
  String? token;
  String? authMethod;
  String? clientId;
  String? refreshToken;
  DateTime? accessTokenExpiry;

  /// Field names in the order they were written (rotation-order checks)
  final List<String> writeLog = [];

  FakeSecureStorage([this.token]);

  @override
  Future<String?> getToken() async => token;

  @override
  Future<void> saveToken(String value) async {
    token = value;
    writeLog.add('token');
  }

  @override
  Future<void> deleteToken() async {
    token = null;
    authMethod = null;
    refreshToken = null;
    accessTokenExpiry = null;
  }

  @override
  Future<bool> hasToken() async => token != null && token!.isNotEmpty;

  @override
  Future<String?> getAuthMethod() async => authMethod;

  @override
  Future<void> saveAuthMethod(String method) async {
    authMethod = method;
    writeLog.add('authMethod');
  }

  @override
  Future<String?> getClientId() async => clientId;

  @override
  Future<void> saveClientId(String value) async {
    clientId = value;
    writeLog.add('clientId');
  }

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<void> saveRefreshToken(String? value) async {
    refreshToken = value;
    writeLog.add('refreshToken');
  }

  @override
  Future<DateTime?> getAccessTokenExpiry() async => accessTokenExpiry;

  @override
  Future<void> saveAccessTokenExpiry(DateTime? expiry) async {
    accessTokenExpiry = expiry;
    writeLog.add('accessTokenExpiry');
  }

  /// One write in the real service, so one log entry here
  @override
  Future<void> saveDeviceFlowTokens({
    required String accessToken,
    String? refreshToken,
    DateTime? accessTokenExpiry,
  }) async {
    this.refreshToken = refreshToken;
    this.accessTokenExpiry = accessTokenExpiry;
    token = accessToken;
    authMethod = AuthMethods.device;
    writeLog.add('deviceFlowTokens');
  }
}

/// Dio adapter that returns a canned response per request
class FakeHttpAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) handler;

  FakeHttpAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

/// Dio adapter that throws a canned error per request
class ThrowingHttpAdapter implements HttpClientAdapter {
  final Object Function(RequestOptions options) errorFactory;

  ThrowingHttpAdapter(this.errorFactory);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // ignore: only_throw_errors
    throw errorFactory(options);
  }

  @override
  void close({bool force = false}) {}
}

/// Build a Dio whose responses are fully controlled by [handler]
Dio dioWithResponse(ResponseBody Function(RequestOptions) handler) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.github.com'));
  dio.httpClientAdapter = FakeHttpAdapter(handler);
  return dio;
}

/// Build a Dio that throws [errorFactory]'s error on every request
Dio dioWithError(Object Function(RequestOptions) errorFactory) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.github.com'));
  dio.httpClientAdapter = ThrowingHttpAdapter(errorFactory);
  return dio;
}

/// JSON response body helper
ResponseBody jsonResponse(String body, int status) {
  return ResponseBody.fromString(
    body,
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

/// Adapter that fails loudly instead of letting a test reach the internet.
///
/// Several fakes extend real services and pass a [Dio] in, overriding only the
/// methods they exercise. Any method left un-overridden would otherwise issue a
/// real request to api.github.com, which fails unpredictably in CI (rate
/// limits, 403s, no network). This turns that silent flake into a clear error.
class _OfflineAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw StateError(
      'A test tried to make a real network request to ${options.uri}. '
      'Override the method under test, or stub the adapter.',
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A [Dio] that can never reach the network. Use in place of `Dio()` when
/// constructing fakes of real services.
Dio offlineDio() => Dio()..httpClientAdapter = _OfflineAdapter();
