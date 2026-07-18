import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/core_providers.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_stats.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(apiClientProvider));
});

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  return ref.watch(dashboardRepositoryProvider).fetchStats();
});

final selectedNavIndexProvider = StateProvider<int>((ref) => 0);
