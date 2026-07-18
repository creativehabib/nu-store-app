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
    final isEmail = login.contains('@');
    final response = await _apiClient.dio.post(
      ApiRoutes.login,
      data: {
        'login': login,
        if (isEmail) 'email': login else 'pf_no': login,
        'password': password,
        'device_name': 'NU Store Mobile',
        if (twoFactorCode != null) 'two_factor_code': twoFactorCode,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
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
