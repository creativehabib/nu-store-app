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

  Future<String> changePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    final payload = {
      'current_password': currentPassword,
      'password': password,
      'password_confirmation': passwordConfirmation,
    };

    DioException? lastError;
    for (final route in ApiRoutes.changePasswordCandidates) {
      try {
        final response = await _sendPasswordChange(route, payload);
        return _message(response.data) ?? 'Password changed successfully.';
      } on DioException catch (error) {
        if (!_shouldTryNextRoute(error)) rethrow;
        lastError = error;
      }
    }
    throw lastError ?? StateError('Password change route is unavailable.');
  }

  Future<Response<dynamic>> _sendPasswordChange(String route, Map<String, dynamic> data) async {
    try {
      return await _apiClient.dio.post(route, data: data);
    } on DioException catch (error) {
      if (error.response?.statusCode != 405) rethrow;
      try {
        return await _apiClient.dio.put(route, data: data);
      } on DioException catch (putError) {
        if (putError.response?.statusCode != 405) rethrow;
        return _apiClient.dio.patch(route, data: data);
      }
    }
  }

  Future<void> saveProfile(Map<String, dynamic> user) => _storage.saveUser(user);

  String? _message(Object? data) {
    if (data is Map) {
      final direct = data['message'] ?? data['status_message'];
      if (direct != null && direct.toString().trim().isNotEmpty) {
        return direct.toString();
      }
      final payload = data['data'];
      if (payload is Map) return _message(payload);
    }
    return null;
  }

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
