import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../shared/providers/core_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/profile_repository.dart';
import '../domain/user_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider), ref.watch(localStorageProvider));
});

final profileControllerProvider = StateNotifierProvider<ProfileController, AsyncValue<UserProfile?>>((ref) {
  final initialUser = ref.watch(authControllerProvider).user;
  return ProfileController(ref.watch(profileRepositoryProvider), ref)
    ..setLocalProfile(initialUser);
});

class ProfileController extends StateNotifier<AsyncValue<UserProfile?>> {
  ProfileController(this._repository, this._ref) : super(const AsyncData(null));

  final ProfileRepository _repository;
  final Ref _ref;

  void setLocalProfile(Map<String, dynamic>? user) {
    if (user == null) return;
    state = AsyncData(UserProfile.fromMap(user));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await _repository.fetchProfile();
      await _repository.saveProfile(user);
      _ref.read(authControllerProvider.notifier).replaceUser(user);
      return UserProfile.fromMap(user);
    });
  }

  Future<void> update(Map<String, dynamic> payload) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await _repository.updateProfile(payload);
      _ref.read(authControllerProvider.notifier).replaceUser(user);
      return UserProfile.fromMap(user);
    });
  }
}
