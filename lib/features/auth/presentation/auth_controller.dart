import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/core_providers.dart';
import '../data/auth_repository.dart';
import '../domain/auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(localStorageProvider),
  );
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
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

  Future<void> login(String email, String password, {String? twoFactorCode}) async {
    state = state.copyWith(
      isLoading: true,
      isInitialized: true,
      requiresTwoFactor: false,
      isApproved: false,
      clearError: true,
      clearSession: true,
    );
    try {
      final payload = await _repository.login(
        email: email,
        password: password,
        twoFactorCode: twoFactorCode,
      );
      final requiresTwoFactor = payload['two_factor_required'] == true;
      final token = payload['token'] as String?;
      final user = Map<String, dynamic>.from((payload['user'] as Map?) ?? {});
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
        errorMessage: 'Login failed. Please verify credentials, 2FA, or approval status.',
      );
    }
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
    if (user == null || user.isEmpty) return false;
    return user['approved'] == true || user['is_approved'] == true || user['approved_at'] != null;
  }
}
