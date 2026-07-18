import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_routes.dart';
import '../providers/core_providers.dart';

final apiCollectionProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, route) async {
  final response = await ref.watch(apiClientProvider).dio.get(route);
  return _extractRows(response.data);
});

class ApiCollectionScreen extends ConsumerWidget {
  const ApiCollectionScreen({
    super.key,
    required this.title,
    required this.route,
    this.emptyMessage = 'No data found.',
  });

  final String title;
  final String route;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(apiCollectionProvider(route));
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.refresh(apiCollectionProvider(route).future);
        },
        child: rows.when(
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text(emptyMessage)),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _ApiRowCard(row: items[index]),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Failed to load $title'),
              const SizedBox(height: 8),
              Text('$error', style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApiRowCard extends StatelessWidget {
  const _ApiRowCard({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(_primaryText(row)),
        subtitle: Text(_secondaryText(row)),
        trailing: Text('#${row['id'] ?? '-'}'),
      ),
    );
  }

  String _primaryText(Map<String, dynamic> row) {
    return '${row['name'] ?? row['name_en'] ?? row['title'] ?? row['purpose'] ?? row['status'] ?? 'Item'}';
  }

  String _secondaryText(Map<String, dynamic> row) {
    final values = <String>[];
    for (final key in ['name_bn', 'pf_no', 'email', 'quantity', 'stock', 'status', 'created_at']) {
      final value = row[key];
      if (value != null && '$value'.isNotEmpty) values.add('$key: $value');
    }
    return values.isEmpty ? 'Open this module from the app workflow.' : values.take(3).join(' • ');
  }
}

List<Map<String, dynamic>> _extractRows(dynamic data) {
  final payload = data is Map ? data['data'] : data;
  if (payload is List) {
    return payload.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }
  if (payload is Map) {
    final rows = payload['data'] ?? payload['items'] ?? payload['results'];
    if (rows is List) {
      return rows.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    }
    return payload.entries
        .where((entry) => entry.value is List)
        .expand((entry) => (entry.value as List).whereType<Map>())
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
  return const [];
}

ApiCollectionScreen screenForDrawerLabel(String label) {
  switch (label) {
    case 'Categories & Products':
      return const ApiCollectionScreen(title: 'Products', route: ApiRoutes.products);
    case 'Stock In / Entries':
      return const ApiCollectionScreen(title: 'Stock Entries', route: ApiRoutes.stockEntries);
    case 'Create Requisition':
      return const ApiCollectionScreen(title: 'Purposes', route: ApiRoutes.purposes);
    case 'My Requisitions & Status':
    case 'Initiator Queue':
    case 'Assistant Director Review':
    case 'Deputy Director Review':
    case 'Director Final Approval':
    case 'Final Print':
      return ApiCollectionScreen(title: label, route: ApiRoutes.requisitions);
    case 'Departments & Designations':
      return const ApiCollectionScreen(title: 'Departments', route: ApiRoutes.departments);
    case 'Language & Settings':
      return const ApiCollectionScreen(title: 'Settings', route: ApiRoutes.settings);
    default:
      return ApiCollectionScreen(title: label, route: ApiRoutes.inventory);
  }
}
