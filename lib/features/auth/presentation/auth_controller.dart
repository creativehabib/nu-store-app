import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../shared/providers/core_providers.dart';
import '../data/auth_repository.dart';
import '../domain/auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(localStorageProvider),
  );
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((
  ref,
) {
  return AuthController(ref.watch(authRepositoryProvider))..restoreSession();
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthState());

  final AuthRepository _repository;

  Future<void> restoreSession() async {
    final session = await _repository.readSession();
    if (session.token != null) {
      state = state.copyWith(
        token: session.token,
        user: session.user,
        isApproved: _isApproved(session.user),
        isInitialized: true,
        clearError: true,
      );
      return;
    }

    state = state.copyWith(isInitialized: true, clearError: true);
  }

  Future<void> login(
    String login,
    String password, {
    String? twoFactorCode,
  }) async {
    state = state.copyWith(
      isLoading: true,
      isInitialized: true,
      requiresTwoFactor: false,
      isApproved: false,
      clearError: true,
      clearSession: true,
    );
    await _repository.clearSession();
    try {
      final payload = await _repository.login(
        login: login,
        password: password,
        twoFactorCode: twoFactorCode,
      );
      if (payload['success'] == false || payload['status'] == false) {
        throw Exception(payload['message'] ?? 'Invalid login credentials.');
      }
      final data = Map<String, dynamic>.from(
        (payload['data'] as Map?) ?? payload,
      );
      if (data['success'] == false || data['status'] == false) {
        throw Exception(data['message'] ?? 'Invalid login credentials.');
      }
      final requiresTwoFactor = _boolValue(
        data['two_factor_required'] ??
            data['requires_two_factor'] ??
            data['2fa_required'],
      );
      final token = _stringValue(
        data['token'] ??
            data['access_token'] ??
            data['plainTextToken'] ??
            payload['token'] ??
            payload['access_token'],
      );
      if ((token == null || token.isEmpty) && !requiresTwoFactor) {
        throw Exception('Login response did not include an access token.');
      }
      final user = Map<String, dynamic>.from(
        (data['user'] as Map?) ?? (payload['user'] as Map?) ?? {},
      );
      final isApproved = _isApproved(user);

      if (token != null && !requiresTwoFactor && isApproved) {
        await _repository.persistSession(token, user);
      }

      state = state.copyWith(
        token: token,
        user: user,
        isLoading: false,
        isInitialized: true,
        requiresTwoFactor: requiresTwoFactor,
        isApproved: isApproved,
      );
    } catch (error) {
      await _repository.clearSession();
      state = state.copyWith(
        isLoading: false,
        isInitialized: true,
        isApproved: false,
        clearSession: true,
        errorMessage: _errorMessage(error),
      );
    }
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final message = _stringValue(data['message'] ?? data['error']);
        if (message != null && message.isNotEmpty) return message;
      }
      if (error.response?.statusCode == 401 ||
          error.response?.statusCode == 422) {
        return 'Invalid email/PF No or password.';
      }
      if (error.response?.statusCode == 403) {
        return 'Your user approval is pending or access is forbidden.';
      }
    }
    return 'Login failed. Please verify credentials, 2FA, or approval status.';
  }

  String? _stringValue(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  bool _boolValue(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      return {'1', 'true', 'yes', 'approved', 'active', 'enabled'}
          .contains(value.trim().toLowerCase());
    }
    return value != null;
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.logout();
    } catch (_) {
      await _repository.clearSession();
    }
    state = const AuthState(isInitialized: true);
  }

  bool _isApproved(Map<String, dynamic>? user) {
    if (user == null || user.isEmpty) return true;
    final approvalValue =
        user['approved'] ?? user['is_approved'] ?? user['status'];
    final approvalDate = _stringValue(user['approved_at']);
    return _boolValue(approvalValue) ||
        (approvalDate != null && approvalDate.isNotEmpty);
  }
}
