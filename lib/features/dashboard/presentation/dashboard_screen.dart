import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/app_role.dart';
import '../../profile/domain/user_profile.dart';
import '../../profile/presentation/widgets/profile_avatar.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../../screens/home_screen.dart';
import '../../../shared/widgets/api_collection_screen.dart';
import '../domain/dashboard_stats.dart';
import 'dashboard_controller.dart';
import 'dashboard_navigation.dart';
import 'requisitioner_screens.dart';

// Primary brand color to keep consistency with Login/Register screens
const Color _primaryColor = Color(0xFF1E3A8A);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestedIndex = ref.watch(selectedNavIndexProvider);
    final auth = ref.watch(authControllerProvider);

    if (!auth.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: _primaryColor),
        ),
      );
    }

    if (!auth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
              (route) => false,
        );
      });

      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text('Please login to continue.', style: TextStyle(fontWeight: FontWeight.w500))),
      );
    }

    final navItems = navItemsFor(auth.role);
    final selectedIndex = requestedIndex >= navItems.length ? 0 : requestedIndex;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'NU Store Management',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _primaryColor,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: Badge(
              backgroundColor: Colors.redAccent,
              child: Icon(Icons.notifications_outlined, color: Colors.grey.shade700),
            ),
            onPressed: () {},
          ),
          IconButton(
            tooltip: 'Logout',
            icon: Icon(Icons.logout_rounded, color: Colors.grey.shade700),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _AppDrawer(
        profile: UserProfile.fromMap(auth.user),
        role: auth.role,
      ),
      body: SafeArea(
        child: _DashboardBody(
          selectedIndex: selectedIndex,
          navItems: navItems,
          role: auth.role,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        backgroundColor: Colors.white,
        indicatorColor: _primaryColor.withOpacity(0.15),
        surfaceTintColor: Colors.white,
        onDestinationSelected: (index) => ref.read(selectedNavIndexProvider.notifier).state = index,
        destinations: [
          for (final item in navItems)
            NavigationDestination(
              icon: Icon(item.icon, color: Colors.grey.shade600),
              selectedIcon: Icon(item.icon, color: _primaryColor),
              label: item.label,
            ),
        ],
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({
    required this.selectedIndex,
    required this.navItems,
    required this.role,
  });

  final int selectedIndex;
  final List<DashboardNavItem> navItems;
  final AppRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selectedIndex != 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(navItems[selectedIndex].icon, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              '${navItems[selectedIndex].label} module coming next',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    if (role == AppRole.requisitioner) {
      return const RequisitionerDashboard();
    }

    if (!RolePermissions.can(role, AppPermission.manageInventory)) {
      return _RoleDashboard(role: role);
    }

    final stats = ref.watch(dashboardStatsProvider);
    return RefreshIndicator(
      color: _primaryColor,
      backgroundColor: Colors.white,
      onRefresh: () async {
        await ref.refresh(dashboardStatsProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Dashboard Overview', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryColor)),
          const SizedBox(height: 20),
          stats.when(
            data: (value) => GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _StatCard(title: 'Current Stock', value: value.currentStock, icon: Icons.warehouse_rounded, color: Colors.blue),
                _StatCard(title: 'Pending Req.', value: value.pendingRequisitions, icon: Icons.pending_actions_rounded, color: Colors.orange),
                _StatCard(title: 'Approval Queue', value: value.approvalQueue, icon: Icons.fact_check_rounded, color: Colors.green),
                _StatCard(title: 'Low Stock Alerts', value: value.lowStockItems, icon: Icons.warning_amber_rounded, color: Colors.redAccent),
              ],
            ),
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: _primaryColor))),
            error: (_, _) => const _OfflineStatsHint(),
          ),
        ],
      ),
    );
  }
}

class _RoleDashboard extends ConsumerWidget {
  const _RoleDashboard({required this.role});

  final AppRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = drawerItemsFor(role);
    final stats = ref.watch(dashboardStatsProvider);

    return RefreshIndicator(
      color: _primaryColor,
      backgroundColor: Colors.white,
      onRefresh: () async => ref.refresh(dashboardStatsProvider.future),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          _RoleHero(role: role),
          const SizedBox(height: 24),
          stats.when(
            data: (value) => _InitiatorInsights(stats: value, enabled: role == AppRole.initiator),
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: _primaryColor))),
            error: (error, _) => _OfflineStatsHint(message: 'Live dashboard data load failed: $error'),
          ),
          const SizedBox(height: 28),
          const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor)),
          const SizedBox(height: 12),
          for (final item in items)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4)),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: _primaryColor),
                ),
                title: Text(item.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(actionHint(item.label), style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ),
                trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => screenForDashboardLabel(item.label)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoleHero extends StatelessWidget {
  const _RoleHero({required this.role});

  final AppRole role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primaryColor, Color(0xFF3B82F6)], // Updated gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${role.label} Dashboard',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pending checks, stock-out alerts, print-ready requisitions, and distribution work in one place.',
                  style: TextStyle(color: Colors.white.withOpacity(0.85), height: 1.4, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InitiatorInsights extends StatelessWidget {
  const _InitiatorInsights({required this.stats, required this.enabled});

  final DashboardStats stats;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final pendingAction = stats.roleStats['pending_action'] ?? stats.pendingRequisitions;
    final printReady = stats.roleStats['print_ready'] ?? stats.roleStats['ready_for_print'] ?? 0;
    final distributeReady = stats.roleStats['ready_for_distribute'] ?? stats.roleStats['director_approved'] ?? stats.approvalQueue;
    final stockOut = stats.roleStats['stock_out_products'] ?? stats.lowStockItems;
    final total = stats.roleStats['total_requisitions'] ?? stats.roleStats['total_system_requisitions'] ?? stats.recentRequisitions.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final tiles = [
              _MetricTile(
                title: 'New Requisitions',
                subtitle: 'In your queue',
                value: pendingAction,
                icon: Icons.assignment_late_outlined,
                color: const Color(0xFFF59E0B),
              ),
              _MetricTile(
                title: 'Print & Distribute',
                subtitle: 'Ready to process',
                value: printReady + distributeReady,
                icon: Icons.print_outlined,
                color: const Color(0xFF10B981),
              ),
              _MetricTile(
                title: 'Stock Out Products',
                subtitle: 'Needs attention',
                value: stockOut,
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFEF4444),
              ),
              _MetricTile(
                title: 'Total Requisitions',
                subtitle: enabled ? 'System activity' : 'Visible activity',
                value: total,
                icon: Icons.file_copy_outlined,
                color: _primaryColor,
              ),
            ];
            final columns = constraints.maxWidth > 760 ? 4 : constraints.maxWidth > 520 ? 2 : 1;

            if (columns == 1) {
              return Column(
                children: [
                  for (var index = 0; index < tiles.length; index++) ...[
                    tiles[index],
                    if (index != tiles.length - 1) const SizedBox(height: 12),
                  ],
                ],
              );
            }

            return GridView.count(
              crossAxisCount: columns,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: columns == 2 ? 2.15 : 1.65,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: tiles,
            );
          },
        ),
        if (stats.recentRequisitions.isNotEmpty) ...[
          const SizedBox(height: 28),
          const Text('Recent Requisitions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor)),
          const SizedBox(height: 12),
          for (final row in stats.recentRequisitions.take(4))
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                  child: const Icon(Icons.receipt_long_outlined, color: Colors.grey),
                ),
                title: Text('${row['requisition_no'] ?? 'REQ-${row['id'] ?? '-'}'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Status: ${row['status'] ?? 'pending'}', style: TextStyle(color: Colors.grey.shade600)),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ),
            ),
        ],
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.title, required this.subtitle, required this.value, required this.icon, required this.color});

  final String title;
  final String subtitle;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text('$value', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, height: 1, color: color)),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  final String title;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
            ],
          ),
          const Spacer(),
          Text('$value', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _OfflineStatsHint extends StatelessWidget {
  const _OfflineStatsHint({this.message = 'Dashboard API is not reachable yet. Connect Laravel API to load live stock, requisition, and approval queue stats.'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: TextStyle(color: Colors.orange.shade900, height: 1.4))),
        ],
      ),
    );
  }
}



class _ProfileInfoChip extends StatelessWidget {
  const _ProfileInfoChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({required this.profile, required this.role});

  final UserProfile profile;
  final AppRole role;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 44, 18, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ProfileAvatar(
                  name: profile.name,
                  imageUrl: profile.imageUrl,
                  radius: 28,
                  backgroundColor: _primaryColor.withOpacity(0.12),
                  foregroundColor: _primaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF333333),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (profile.email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          profile.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _ProfileInfoChip(
                            label: 'Role: ${role.label}',
                            backgroundColor: const Color(0xFFEAF1FF),
                            foregroundColor: _primaryColor,
                          ),
                          _ProfileInfoChip(
                            label: 'PF No: ${profile.pfNo.isEmpty ? 'N/A' : profile.pfNo}',
                            backgroundColor: const Color(0xFFF2F2F2),
                            foregroundColor: const Color(0xFF333333),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                for (final item in drawerItemsFor(role))
                  ListTile(
                    leading: Icon(item.icon, color: Colors.grey.shade700),
                    title: Text(item.label, style: const TextStyle(fontWeight: FontWeight.w500)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screenForDashboardLabel(item.label)));
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
