import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_routes.dart';
import '../../../shared/providers/core_providers.dart';
import 'requisition_workflow_settings.dart';

// Primary Brand Color
const Color _primaryColor = Color(0xFF1E3A8A);

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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          '${fallback['requisition_no'] ?? 'Requisition Details'}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _primaryColor),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: details.when(
        data: (row) => Center(
          // Responsive Constraint: Prevents the UI from stretching too much on web/tablets
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                _StatusHeader(row: row),
                const SizedBox(height: 20),
                settings.when(
                  data: (value) => _WorkflowStepper(
                    settings: RequisitionWorkflowSettings.fromSettings(value),
                    currentStatus: '${row['status'] ?? 'pending'}',
                    requesterDepartmentId: _userDepartmentId(row['user'] is Map ? Map<String, dynamic>.from(row['user'] as Map) : null),
                  ),
                  loading: () => const LinearProgressIndicator(color: _primaryColor),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 20),
                _ItemDetailsCard(row: row),
                const SizedBox(height: 20),
                _ApprovalHistoryCard(row: row),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: _primaryColor)),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _ErrorCard(message: '$error'),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// UI COMPONENTS
// -----------------------------------------------------------------------------

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final status = '${row['status'] ?? 'pending'}';
    final statusColor = _statusColor(status);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryColor.withOpacity(0.8), _primaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${row['requisition_no'] ?? 'REQ-${row['id'] ?? '-'}'}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 6),
                        Text(
                          _date(row['created_at']),
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Current Status: ', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  status.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
        ],
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route_rounded, color: _primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text('Routing & Approval Flow', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 24),
          for (var i = 0; i < steps.length; i++)
            _TimelineItem(
              title: steps[i].label,
              subtitle: steps[i].hint,
              isFirst: i == 0,
              isLast: i == steps.length - 1,
              isPast: i < activeIndex,
              isActive: i == activeIndex,
            ),
        ],
      ),
    );
  }
}

class _ItemDetailsCard extends StatelessWidget {
  const _ItemDetailsCard({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final items = _rows(row['items'] ?? row['requisition_items']);
    final displayItems = items.isEmpty ? [row] : items;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: _primaryColor, size: 20),
                const SizedBox(width: 8),
                const Text('Requested Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                  child: Text('${displayItems.length} items', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                )
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayItems.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
            itemBuilder: (context, index) {
              final item = displayItems[index];
              final requested = '${item['demanded_qty'] ?? item['qty'] ?? '-'}';
              final approved = '${item['supplied_qty'] ?? item['approved_qty'] ?? 0}';

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(color: _primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                      child: Center(child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: _primaryColor))),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_productName(item), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text('Purpose: ${item['purpose'] ?? 'N/A'}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Req: $requested', style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text('Apprv: $approved', style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    )
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ApprovalHistoryCard extends StatelessWidget {
  const _ApprovalHistoryCard({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final history = _history(row);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, color: _primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text('Approval History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 24),
          if (history.isEmpty)
            const Text('No history found.', style: TextStyle(color: Colors.grey))
          else
            for (var i = 0; i < history.length; i++)
              _TimelineItem(
                title: '${history[i]['name'] ?? history[i]['role'] ?? 'Approver'}',
                subtitle: '${history[i]['comment'] ?? history[i]['remarks'] ?? 'No remarks'}\nDate: ${_date(history[i]['created_at'] ?? history[i]['date'])}',
                trailing: '${history[i]['status'] ?? 'Approved'}',
                isFirst: i == 0,
                isLast: i == history.length - 1,
                isPast: true,
                isActive: false,
              ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// CUSTOM TIMELINE WIDGET
// -----------------------------------------------------------------------------

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.isFirst,
    required this.isLast,
    required this.isPast,
    required this.isActive,
  });

  final String title;
  final String subtitle;
  final String? trailing;
  final bool isFirst;
  final bool isLast;
  final bool isPast;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isPast || isActive ? _primaryColor : Colors.grey.shade300;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Indicator Column
          SizedBox(
            width: 30,
            child: Column(
              children: [
                // Top line
                Expanded(child: Container(width: 2, color: isFirst ? Colors.transparent : (isPast || isActive ? _primaryColor : Colors.grey.shade300))),
                // Circle Node
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white : color,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: isActive ? 4 : 0),
                    boxShadow: isActive ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6)] : null,
                  ),
                ),
                // Bottom line
                Expanded(child: Container(width: 2, color: isLast ? Colors.transparent : (isPast ? _primaryColor : Colors.grey.shade300))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0, top: 2), // Spacing between steps
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: isActive || isPast ? FontWeight.bold : FontWeight.w500,
                            color: isActive || isPast ? Colors.black87 : Colors.grey.shade500,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        trailing!,
                        style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.red.shade200),
    ),
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Icon(Icons.error_outline_rounded, color: Colors.red.shade400),
        const SizedBox(width: 12),
        Expanded(child: Text(message, style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w500))),
      ],
    ),
  );
}

// -----------------------------------------------------------------------------
// HELPER FUNCTIONS
// -----------------------------------------------------------------------------

class _WorkflowStep {
  const _WorkflowStep(this.statuses, this.label, this.hint);
  final Set<String> statuses;
  final String label;
  final String hint;
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
      steps.add(const _WorkflowStep({'initiator_checked'}, 'Assistant Director Approval', 'Initiator যাচাইয়ের পর AD approval step.'));
    } else if (role == 'Deputy Director') {
      steps.add(const _WorkflowStep({'ad_approved'}, 'Deputy Director Approval', 'Configured approval flow অনুযায়ী DD review.'));
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

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'distributed':
    case 'completed':
    case 'director_approved':
      return Colors.green;
    case 'returned':
    case 'rejected':
      return Colors.red;
    case 'pending':
      return Colors.orange;
    default:
      return Colors.blue;
  }
}