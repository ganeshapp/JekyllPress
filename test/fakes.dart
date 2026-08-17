import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:jekyllpress/core/services/secure_storage_service.dart';

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
