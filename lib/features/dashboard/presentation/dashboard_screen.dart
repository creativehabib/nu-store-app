import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/app_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../../screens/home_screen.dart';
import '../../../shared/widgets/api_collection_screen.dart';
import 'dashboard_controller.dart';

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

class _RoleDashboard extends StatelessWidget {
  const _RoleDashboard({required this.role});

  final AppRole role;

  @override
  Widget build(BuildContext context) {
    final items = _drawerItemsFor(role);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${role.label} Dashboard',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('Only your permitted requisition workflow actions are shown.'),
        const SizedBox(height: 16),
        for (final item in items)
          Card(
            child: ListTile(
              leading: Icon(item.icon, color: const Color(0xFF2563EB)),
              title: Text(item.label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => screenForDrawerLabel(item.label)),
              ),
            ),
          ),
      ],
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
            CircleAvatar(backgroundColor: color.withValues(alpha: .12), child: Icon(icon, color: color)),
            Text('$value', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class _OfflineStatsHint extends StatelessWidget {
  const _OfflineStatsHint();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('Dashboard API is not reachable yet. Connect Laravel API to load live stock, requisition, and approval queue stats.'),
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
    items.add(const _NavItem(icon: Icons.playlist_add, label: 'Create Requisition'));
  }

  if (RolePermissions.can(role, AppPermission.viewOwnRequisitions) ||
      RolePermissions.can(role, AppPermission.viewRequisitionLocation)) {
    items.add(const _NavItem(icon: Icons.timeline, label: 'My Requisitions & Status'));
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

  if (RolePermissions.can(role, AppPermission.printFinalRequisition)) {
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
