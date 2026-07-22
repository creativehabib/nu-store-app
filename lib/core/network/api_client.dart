import 'package:dio/dio.dart';

import '../storage/local_storage_service.dart';

class ApiClient {
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://store.creativehabib.com',
  );

  ApiClient(this._storage)
    : dio = Dio(
        BaseOptions(
          baseUrl: defaultBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.headers['X-App-Token'] = _bootstrapApiToken;
          final token = await _storage.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  static const String _bootstrapApiToken = String.fromEnvironment(
    'API_TOKEN',
    defaultValue:
        'GRP5ZdDuR65FVhWkOnNM2aMQU8ESiodM8AiuhyrWB6a4eKTspI39bUlX2FvQKc3O',
  );

  final LocalStorageService _storage;
  final Dio dio;
}
