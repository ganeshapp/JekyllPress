import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'secure_storage_service.dart';

part 'dio_client.g.dart';

/// Provides a configured Dio instance with GitHub API interceptors
@riverpod
Dio dioClient(Ref ref) {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://api.github.com',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    },
  ));

  // Add logging interceptor in debug mode
  dio.interceptors.add(LogInterceptor(
    requestHeader: true,
    requestBody: true,
    responseHeader: false,
    responseBody: true,
    error: true,
  ));

  return dio;
}

/// Creates a Dio instance with the auth token already set
Future<Dio> createAuthenticatedDio(SecureStorageService storageService) async {
  final token = await storageService.getToken();
  
  final dio = Dio(BaseOptions(
    baseUrl: 'https://api.github.com',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      if (token != null) 'Authorization': 'Bearer $token',
    },
  ));

  dio.interceptors.add(LogInterceptor(
    requestHeader: false,
    requestBody: false,
    responseHeader: false,
    responseBody: true,
    error: true,
  ));

  return dio;
}
