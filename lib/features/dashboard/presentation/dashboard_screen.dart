import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import 'dashboard_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedNavIndexProvider);
    final auth = ref.watch(authControllerProvider);

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
      drawer: _AppDrawer(userName: auth.user?['name'] as String? ?? 'Approved User'),
      body: SafeArea(child: _DashboardBody(selectedIndex: selectedIndex)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => ref.read(selectedNavIndexProvider.notifier).state = index,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Inventory'),
          NavigationDestination(icon: Icon(Icons.assignment_outlined), label: 'Requisitions'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selectedIndex != 0) {
      const labels = ['Dashboard', 'Inventory', 'Requisitions', 'Settings'];
      return Center(child: Text('${labels[selectedIndex]} module coming next'));
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
  const _AppDrawer({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(userName),
            accountEmail: const Text('NU Store Management'),
            currentAccountPicture: const CircleAvatar(child: Icon(Icons.person)),
          ),
          const ListTile(leading: Icon(Icons.category_outlined), title: Text('Categories & Products')),
          const ListTile(leading: Icon(Icons.add_box_outlined), title: Text('Stock In / Entries')),
          const ListTile(leading: Icon(Icons.playlist_add), title: Text('Create Requisition')),
          const ListTile(leading: Icon(Icons.approval_outlined), title: Text('Approval Workflow')),
          const ListTile(leading: Icon(Icons.apartment_outlined), title: Text('Departments & Designations')),
          const ListTile(leading: Icon(Icons.language), title: Text('Language Switcher')),
        ],
      ),
    );
  }
}
