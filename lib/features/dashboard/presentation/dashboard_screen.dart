import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/app_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../../screens/home_screen.dart';
import '../../../shared/widgets/api_collection_screen.dart';
import '../domain/dashboard_stats.dart';
import 'dashboard_controller.dart';
import 'requisitioner_screens.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestedIndex = ref.watch(selectedNavIndexProvider);
    final auth = ref.watch(authControllerProvider);

    if (!auth.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
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
        body: Center(child: Text('Please login to continue.')),
      );
    }

    final navItems = _navItemsFor(auth.role);
    final selectedIndex = requestedIndex >= navItems.length ? 0 : requestedIndex;

    return Scaffold(
      appBar: AppBar(
        title: const Text('NU Store Management'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Badge(child: Icon(Icons.notifications_outlined)),
            onPressed: () {},
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      drawer: _AppDrawer(
        userName: auth.user?['name'] as String? ?? 'Approved User',
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
        onDestinationSelected: (index) => ref.read(selectedNavIndexProvider.notifier).state = index,
        destinations: [
          for (final item in navItems)
            NavigationDestination(icon: Icon(item.icon), label: item.label),
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
  final List<_NavItem> navItems;
  final AppRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selectedIndex != 0) {
      return Center(child: Text('${navItems[selectedIndex].label} module coming next'));
    }

    if (role == AppRole.requisitioner) {
      return const RequisitionerDashboard();
    }

    if (!RolePermissions.can(role, AppPermission.manageInventory)) {
      return _RoleDashboard(role: role);
    }

    final stats = ref.watch(dashboardStatsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        await ref.refresh(dashboardStatsProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Dashboard overview', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          stats.when(
            data: (value) => GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _StatCard(title: 'Current Stock', value: value.currentStock, icon: Icons.warehouse, color: Colors.blue),
                _StatCard(title: 'Pending Requisitions', value: value.pendingRequisitions, icon: Icons.pending_actions, color: Colors.orange),
                _StatCard(title: 'Approval Queue', value: value.approvalQueue, icon: Icons.fact_check, color: Colors.green),
                _StatCard(title: 'Low Stock Alerts', value: value.lowStockItems, icon: Icons.warning_amber, color: Colors.red),
              ],
            ),
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
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
    final items = _drawerItemsFor(role);
    final stats = ref.watch(dashboardStatsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(dashboardStatsProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _RoleHero(role: role),
          const SizedBox(height: 16),
          stats.when(
            data: (value) => _InitiatorInsights(stats: value, enabled: role == AppRole.initiator),
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            error: (error, _) => _OfflineStatsHint(message: 'Live dashboard data load failed: $error'),
          ),
          const SizedBox(height: 16),
          Text('Quick actions', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final item in items)
            Card(
              child: ListTile(
                leading: Icon(item.icon, color: const Color(0xFF2563EB)),
                title: Text(item.label),
                subtitle: Text(_actionHint(item.label)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => screenForDrawerLabel(item.label)),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1D4ED8), Color(0xFF7C3AED)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const CircleAvatar(radius: 28, backgroundColor: Colors.white24, child: Icon(Icons.storefront, color: Colors.white, size: 30)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${role.label} Dashboard', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Pending checks, stock-out alerts, print-ready requisitions, and distribution work in one place.', style: TextStyle(color: Colors.white70)),
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
                color: const Color(0xFF16A34A),
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
                color: const Color(0xFF2563EB),
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
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: columns == 2 ? 2.15 : 1.65,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: tiles,
            );
          },
        ),
        if (stats.recentRequisitions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Recent requisitions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final row in stats.recentRequisitions.take(4))
            Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text('${row['requisition_no'] ?? 'REQ-${row['id'] ?? '-'}'}'),
                subtitle: Text('Status: ${row['status'] ?? 'pending'}'),
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
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: color.withOpacity(.20)),
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(.12), color.withOpacity(.04)],
          ),
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
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text('$value', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, height: 1)),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color.withOpacity(.85), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color.withOpacity(.70), size: 28),
            ),
          ],
        ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(.12), child: Icon(icon, color: color)),
            Text('$value', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class _OfflineStatsHint extends StatelessWidget {
  const _OfflineStatsHint({this.message = 'Dashboard API is not reachable yet. Connect Laravel API to load live stock, requisition, and approval queue stats.'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message),
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({required this.userName, required this.role});

  final String userName;
  final AppRole role;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(userName),
            accountEmail: Text(role.label),
            currentAccountPicture: const CircleAvatar(child: Icon(Icons.person)),
          ),
          for (final item in _drawerItemsFor(role))
            ListTile(
              leading: Icon(item.icon),
              title: Text(item.label),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => screenForDrawerLabel(item.label)),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

List<_NavItem> _navItemsFor(AppRole role) {
  final items = <_NavItem>[
    const _NavItem(icon: Icons.dashboard_outlined, label: 'Dashboard'),
  ];

  if (RolePermissions.can(role, AppPermission.manageInventory)) {
    items.add(const _NavItem(icon: Icons.inventory_2_outlined, label: 'Inventory'));
  }

  if (RolePermissions.can(role, AppPermission.createRequisition) ||
      RolePermissions.can(role, AppPermission.viewRequisitionLocation) ||
      RolePermissions.can(role, AppPermission.forwardRequisition) ||
      RolePermissions.can(role, AppPermission.finalApprove)) {
    items.add(const _NavItem(icon: Icons.assignment_outlined, label: 'Requisitions'));
  }

  if (RolePermissions.can(role, AppPermission.manageSettings)) {
    items.add(const _NavItem(icon: Icons.settings_outlined, label: 'Settings'));
  }

  return items;
}

List<_NavItem> _drawerItemsFor(AppRole role) {
  final items = <_NavItem>[];

  if (RolePermissions.can(role, AppPermission.manageInventory)) {
    items.addAll(const [
      _NavItem(icon: Icons.category_outlined, label: 'Categories & Products'),
      _NavItem(icon: Icons.add_box_outlined, label: 'Stock In / Entries'),
    ]);
  }

  if (RolePermissions.can(role, AppPermission.createRequisition)) {
    items.add(const _NavItem(icon: Icons.playlist_add, label: 'Submit Demand'));
  }

  if (RolePermissions.can(role, AppPermission.viewOwnRequisitions) ||
      RolePermissions.can(role, AppPermission.viewRequisitionLocation)) {
    items.add(const _NavItem(icon: Icons.timeline, label: 'My Requisitions'));
  }

  if (RolePermissions.can(role, AppPermission.forwardRequisition)) {
    items.add(const _NavItem(icon: Icons.forward_to_inbox, label: 'Initiator Queue'));
  }

  if (RolePermissions.can(role, AppPermission.assistantDirectorVerify)) {
    items.add(const _NavItem(icon: Icons.fact_check_outlined, label: 'Assistant Director Review'));
  }

  if (RolePermissions.can(role, AppPermission.deputyDirectorVerify)) {
    items.add(const _NavItem(icon: Icons.verified_outlined, label: 'Deputy Director Review'));
  }

  if (RolePermissions.can(role, AppPermission.finalApprove)) {
    items.add(const _NavItem(icon: Icons.approval_outlined, label: 'Director Final Approval'));
  }

  if (role != AppRole.initiator && RolePermissions.can(role, AppPermission.printFinalRequisition)) {
    items.add(const _NavItem(icon: Icons.print_outlined, label: 'Final Print'));
  }

  if (RolePermissions.can(role, AppPermission.manageOrganization)) {
    items.add(const _NavItem(icon: Icons.apartment_outlined, label: 'Departments & Designations'));
  }

  if (RolePermissions.can(role, AppPermission.manageSettings)) {
    items.add(const _NavItem(icon: Icons.language, label: 'Language & Settings'));
  }

  return items;
}

String _actionHint(String label) {
  return switch (label) {
    'Initiator Queue' => 'Check new requisitions and forward them to approval.',
    'Final Print' => 'Print completed requisition letters after final approval.',
    'My Requisitions' => 'Track requisition status and location.',
    _ => 'Open this module.',
  };
}
