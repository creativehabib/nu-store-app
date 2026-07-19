import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_routes.dart';
import '../../../shared/providers/core_providers.dart';
import 'requisition_workflow_settings.dart';

final requisitionDetailProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, id) async {
  final response = await ref.watch(apiClientProvider).dio.get('${ApiRoutes.requisitions}/$id');
  final data = response.data is Map ? Map<String, dynamic>.from(response.data as Map) : <String, dynamic>{};
  final payload = data['data'];
  return payload is Map ? Map<String, dynamic>.from(payload) : data;
});

class RequisitionDetailsScreen extends ConsumerWidget {
  const RequisitionDetailsScreen({super.key, required this.id, required this.fallback});

  final int id;
  final Map<String, dynamic> fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = id == 0 ? AsyncData<Map<String, dynamic>>(fallback) : ref.watch(requisitionDetailProvider(id));
    final settings = ref.watch(appSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text('${fallback['requisition_no'] ?? 'Requisition Details'}')),
      body: details.when(
        data: (row) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _StatusHeader(row: row),
            const SizedBox(height: 16),
            settings.when(
              data: (value) => _WorkflowStepper(settings: RequisitionWorkflowSettings.fromSettings(value), currentStatus: '${row['status'] ?? 'pending'}', requesterDepartmentId: _userDepartmentId(row['user'] is Map ? Map<String, dynamic>.from(row['user'] as Map) : null)),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            _HistoryCard(row: row),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(padding: const EdgeInsets.all(24), children: [_ErrorCard(message: '$error')]),
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${row['requisition_no'] ?? 'REQ-${row['id'] ?? '-'}'}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            Chip(label: Text('Status: ${row['status'] ?? 'pending'}')),
            Chip(label: Text('Submitted: ${_date(row['created_at'])}')),
          ]),
        ]),
      ),
    );
  }
}

class _WorkflowStepper extends StatelessWidget {
  const _WorkflowStepper({required this.settings, required this.currentStatus, this.requesterDepartmentId});

  final RequisitionWorkflowSettings settings;
  final String currentStatus;
  final int? requesterDepartmentId;

  @override
  Widget build(BuildContext context) {
    final steps = _workflowSteps(settings, requesterDepartmentId);
    final activeIndex = _activeStepIndex(steps, currentStatus.toLowerCase());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Routing & Approval Flow', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          for (var i = 0; i < steps.length; i++)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 13,
                backgroundColor: i <= activeIndex ? Colors.green : Colors.grey.shade300,
                child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Colors.white)),
              ),
              title: Text(steps[i].label),
              subtitle: Text(steps[i].hint),
            ),
        ]),
      ),
    );
  }
}

class _WorkflowStep {
  const _WorkflowStep(this.statuses, this.label, this.hint);
  final Set<String> statuses;
  final String label;
  final String hint;
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final history = _history(row);
    final items = _rows(row['items'] ?? row['requisition_items']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tracking Details: ${row['requisition_no'] ?? 'REQ-${row['id'] ?? '-'}'}', style: const TextStyle(fontWeight: FontWeight.bold)),
          const Divider(height: 28),
          const Text('Item Details & Approval:', style: TextStyle(fontWeight: FontWeight.bold)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(columns: const [DataColumn(label: Text('Item Name')), DataColumn(label: Text('Requested')), DataColumn(label: Text('Approved'))], rows: [for (final item in items.isEmpty ? [row] : items) DataRow(cells: [DataCell(Text(_productName(item))), DataCell(Text('${item['demanded_qty'] ?? item['qty'] ?? '-'}')), DataCell(Text('${item['supplied_qty'] ?? item['approved_qty'] ?? 0}'))])]),
          ),
          const SizedBox(height: 16),
          const Text('Approval History (Timeline):', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final h in history) ListTile(leading: const Icon(Icons.circle, color: Colors.green, size: 14), title: Text('${h['name'] ?? h['role'] ?? 'Approver'}'), subtitle: Text('${h['comment'] ?? h['remarks'] ?? ''}\n${_date(h['created_at'] ?? h['date'])}'), trailing: Chip(label: Text('${h['status'] ?? 'Approved / Forwarded'}'))),
        ]),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(message, style: const TextStyle(color: Colors.red))));
}

int? _userDepartmentId(Map<String, dynamic>? user) {
  if (user == null) return null;
  final department = user['department'];
  if (department is Map) return _intFrom(department['id']);
  final value = user['department_id'] ?? user['dept_id'];
  final parsed = _intFrom(value);
  return parsed == 0 ? null : parsed;
}

String _roleLabel(String role) {
  if (role == 'assistant_director') return 'Assistant Director';
  if (role == 'deputy_director') return 'Deputy Director';
  if (role == 'director') return 'Director';
  return role.replaceAll('_', ' ');
}

List<String> _approvalRoleLabels(List<String> roles) {
  final labels = <String>[];
  for (final role in roles) {
    final label = _roleLabel(role);
    if (!labels.contains(label)) labels.add(label);
  }
  if (!labels.contains('Director')) labels.add('Director');
  return labels;
}

List<_WorkflowStep> _workflowSteps(RequisitionWorkflowSettings settings, int? requesterDepartmentId) {
  final isCentralRequester = settings.isCentralized && requesterDepartmentId == settings.centralStoreDepartmentId;
  final steps = <_WorkflowStep>[
    if (settings.isCentralized && !isCentralRequester)
      const _WorkflowStep({'department_director_review', 'pending_dept_director'}, 'Department Director Review', 'নিজ department director requisition review করবেন.'),
    const _WorkflowStep({'pending'}, 'Initiator / Store Queue', 'Departmental হলে নিজ department initiator; centralized হলে central store initiator queue.'),
  ];
  for (final role in _approvalRoleLabels(settings.approvalFlowRoles)) {
    if (role == 'Assistant Director') {
      steps.add(const _WorkflowStep({'initiator_checked'}, 'Assistant Director Approval', 'Initiator যাচাইয়ের পর AD approval step.'));
    } else if (role == 'Deputy Director') {
      steps.add(const _WorkflowStep({'ad_approved'}, 'Deputy Director Approval', 'Configured approval flow অনুযায়ী DD review.'));
    } else if (role == 'Director') {
      steps.add(const _WorkflowStep({'dd_approved', 'director_approved'}, 'Director Final Approval', 'Director final approver হিসেবে requisition approve করবেন.'));
    }
  }
  steps.add(const _WorkflowStep({'distributed'}, 'Distributed', 'Store requisition issue/distribute সম্পন্ন করবে.'));
  return steps;
}

int _activeStepIndex(List<_WorkflowStep> steps, String status) {
  if (status == 'returned') return 0;
  final index = steps.indexWhere((step) => step.statuses.contains(status));
  return index < 0 ? 0 : index;
}

List<Map<String, dynamic>> _rows(dynamic data) {
  final payload = data is Map ? (data['data'] ?? data['items'] ?? data['results'] ?? data) : data;
  if (payload is List) return payload.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  if (payload is Map) {
    final nested = payload['data'] ?? payload['items'] ?? payload['results'] ?? payload['requisitions'];
    if (nested is List) return nested.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  return const [];
}

int _intFrom(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

String _date(dynamic value) {
  final date = DateTime.tryParse('$value');
  return date == null ? '-' : DateFormat('dd MMM, yyyy hh:mm a').format(date.toLocal());
}

String _productName(Map<String, dynamic> row) {
  final product = row['product'];
  if (product is Map) return '${product['name'] ?? product['name_en'] ?? product['title'] ?? 'Item'}';
  return '${row['product_name'] ?? row['item_name'] ?? row['name'] ?? 'Item'}';
}

List<Map<String, dynamic>> _history(Map<String, dynamic> row) {
  final history = row['approval_history'];
  if (history is List) return history.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  return [{'role': 'Submitted', 'status': row['status'] ?? 'Pending', 'created_at': row['created_at']}];
}
