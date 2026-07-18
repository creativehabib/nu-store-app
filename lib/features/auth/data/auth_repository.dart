import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_routes.dart';
import '../../../core/storage/local_storage_service.dart';

class AuthRepository {
  AuthRepository(this._apiClient, this._storage);

  final ApiClient _apiClient;
  final LocalStorageService _storage;

  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    final response = await _apiClient.dio.post(ApiRoutes.register, data: data);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> login({
    required String login,
    required String password,
    String? twoFactorCode,
  }) async {
    final payloads = _loginPayloads(
      login: login,
      password: password,
      twoFactorCode: twoFactorCode,
    );
    DioException? lastAuthError;

    for (final payload in payloads) {
      try {
        final response = await _apiClient.dio.post(
          ApiRoutes.login,
          data: payload,
        );
        return Map<String, dynamic>.from(response.data as Map);
      } on DioException catch (error) {
        if (!_canRetryWithNextPayload(error)) rethrow;
        lastAuthError = error;
      }
    }

    throw lastAuthError ?? StateError('No login payloads were available.');
  }

  List<Map<String, dynamic>> _loginPayloads({
    required String login,
    required String password,
    String? twoFactorCode,
  }) {
    final base = <String, dynamic>{
      'password': password,
      'device_name': 'NU Store Mobile',
      if (twoFactorCode != null) 'two_factor_code': twoFactorCode,
    };
    final isEmail = login.contains('@');

    if (isEmail) {
      return [
        {...base, 'login': login, 'email': login},
        {...base, 'email': login},
      ];
    }

    return [
      {...base, 'login': login, 'pf_no': login},
      {...base, 'pf_no': login},
      {...base, 'login': login},
      {...base, 'email': login},
    ];
  }

  bool _canRetryWithNextPayload(DioException error) {
    final statusCode = error.response?.statusCode;
    return statusCode == 400 || statusCode == 401 || statusCode == 422;
  }

  Future<Map<String, dynamic>> me() async {
    final response = await _apiClient.dio.get(ApiRoutes.me);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> logout() async {
    await _apiClient.dio.post(ApiRoutes.logout);
    await _storage.clearAuth();
  }

  Future<void> persistSession(String token, Map<String, dynamic> user) async {
    await _storage.saveToken(token);
    await _storage.saveUser(user);
  }

  Future<({String? token, Map<String, dynamic>? user})> readSession() async {
    return (token: await _storage.readToken(), user: await _storage.readUser());
  }

  Future<void> clearSession() => _storage.clearAuth();
}
