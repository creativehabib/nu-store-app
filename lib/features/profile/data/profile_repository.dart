import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_routes.dart';
import '../../../core/storage/local_storage_service.dart';

class ProfileRepository {
  ProfileRepository(this._apiClient, this._storage);

  final ApiClient _apiClient;
  final LocalStorageService _storage;

  Future<Map<String, dynamic>> fetchProfile() async {
    final response = await _apiClient.dio.get(ApiRoutes.me);
    return _extractUser(response.data);
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    DioException? lastError;
    for (final route in ApiRoutes.profileUpdateCandidates) {
      try {
        final response = await _sendUpdate(route, data);
        final user = _extractUser(response.data);
        await _storage.saveUser(user);
        return user;
      } on DioException catch (error) {
        if (!_shouldTryNextRoute(error)) rethrow;
        lastError = error;
      }
    }
    throw lastError ?? StateError('Profile update route is unavailable.');
  }

  Future<Response<dynamic>> _sendUpdate(String route, Map<String, dynamic> data) async {
    try {
      return await _apiClient.dio.patch(route, data: data);
    } on DioException catch (error) {
      if (error.response?.statusCode != 405) rethrow;
      return _apiClient.dio.put(route, data: data);
    }
  }

  Future<void> saveProfile(Map<String, dynamic> user) => _storage.saveUser(user);

  Map<String, dynamic> _extractUser(Object? data) {
    if (data is Map) {
      final payload = data['data'];
      if (payload is Map) {
        final user = payload['user'];
        if (user is Map) return Map<String, dynamic>.from(user);
        return Map<String, dynamic>.from(payload);
      }
      final user = data['user'];
      if (user is Map) return Map<String, dynamic>.from(user);
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }

  bool _shouldTryNextRoute(DioException error) {
    final code = error.response?.statusCode;
    return code == 404 || code == 405;
  }
}
