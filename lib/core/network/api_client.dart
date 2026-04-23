import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

final dioProvider = Provider<Dio>((ref) {
  // Use 10.0.2.2 for Android emulator to access localhost, or a remote URL
  final fallbackUrl = kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';
  final baseUrl = (dotenv.env['API_URL'] ?? fallbackUrl).trim();
  
  if (kDebugMode) {
    print('DEBUG: Connecting to Backend at: $baseUrl');
  }
  
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 120),
      receiveTimeout: const Duration(seconds: 120),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        // Add auth token if available (to be implemented with AuthProvider)
        // final token = ref.read(authProvider).token;
        // if (token != null) options.headers['Authorization'] = 'Bearer $token';
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        // Handle global errors (e.g., refresh token, logout on 401)
        return handler.next(e);
      },
    ),
  );

  return dio;
});
