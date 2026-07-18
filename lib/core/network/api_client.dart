import 'package:dio/dio.dart';

import '../storage/local_storage_service.dart';

class ApiClient {
  ApiClient(this._storage)
    : dio = Dio(
        BaseOptions(
          baseUrl: const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'https://store.creativehabib.com',
          ),
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
          final token = await _storage.readToken() ?? _bootstrapApiToken;
          if (token.isNotEmpty) {
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
        'H5G0Kg3Ge7tBvdzIwYtihKGsh9HkMnmEMRD4MA4DqQyXS5u7yJpXer0EQ9GcTNEF',
  );

  final LocalStorageService _storage;
  final Dio dio;
}
