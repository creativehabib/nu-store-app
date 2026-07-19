import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_routes.dart';
import '../../../shared/providers/core_providers.dart';
import 'requisitioner_screens.dart';
import 'requisition_details_screen.dart';
import 'requisition_workflow_settings.dart';

final requisitionQueueProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, queue) async {
  final response = await ref.watch(apiClientProvider).dio.get(
    ApiRoutes.requisitions,
    queryParameters: {'queue': queue, 'status': _queueStatus(queue), 'per_page': 25},
  );
  return _queueRows(response.data);
});

class RequisitionApprovalQueueScreen extends ConsumerWidget {
  const RequisitionApprovalQueueScreen({super.key, required this.title, required this.queue});

  final String title;
  final String queue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(requisitionQueueProvider(queue));
    final settings = ref.watch(appSettingsProvider);
    final workflowSettings = settings.when(
      data: (value) => value,
      loading: () => const <String, dynamic>{},
      error: (_, _) => const <String, dynamic>{},
    );
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.refresh(requisitionQueueProvider(queue).future);
        },
        child: items.when(
          data: (rows) {
            if (rows.isEmpty) {
              return ListView(padding: const EdgeInsets.all(24), children: const [Center(child: Text('No pending requisitions found.'))]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _ApprovalQueueCard(
                row: rows[index],
                queue: queue,
                settings: workflowSettings,
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(padding: const EdgeInsets.all(24), children: [_QueueErrorCard(message: '$error')]),
        ),
      ),
    );
  }
}

class _ApprovalQueueCard extends ConsumerStatefulWidget {
  const _ApprovalQueueCard({required this.row, required this.queue, required this.settings});

  final Map<String, dynamic> row;
  final String queue;
  final Map<String, dynamic>? settings;

  @override
  ConsumerState<_ApprovalQueueCard> createState() => _ApprovalQueueCardState();
}

class _ApprovalQueueCardState extends ConsumerState<_ApprovalQueueCard> {
  final _remarksController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = RequisitionWorkflowSettings.fromSettings(widget.settings ?? const {});
    final action = _queueAction(widget.queue, settings);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${widget.row['requisition_no'] ?? 'REQ-${widget.row['id'] ?? '-'}'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            Chip(label: Text('${widget.row['status'] ?? _queueStatus(widget.queue)}')),
          ]),
          const SizedBox(height: 8),
          Text(_queueItemSummary(widget.row)),
          const SizedBox(height: 8),
          Text('Next: ${action.nextLabel}', style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          TextField(
            controller: _remarksController,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Remarks / note', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Row(children: [
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RequisitionDetailsScreen(id: _queueInt(widget.row['id']), fallback: widget.row))),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('View'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _submitting ? null : () => _submit(action),
              icon: const Icon(Icons.send_outlined),
              label: Text(_submitting ? 'Forwarding...' : action.buttonLabel),
            ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _submit(_QueueAction action) async {
    final id = _queueInt(widget.row['id']);
    if (id == 0) return;
    setState(() => _submitting = true);
    try {
      await _sendRequisitionAction(
        ref,
        id: id,
        action: action.action,
        nextRole: action.nextRole,
        nextStatus: action.nextStatus,
        remarks: _remarksController.text.trim(),
      );
      ref.invalidate(requisitionQueueProvider(widget.queue));
      ref.invalidate(myRequisitionsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${action.buttonLabel} successful'), backgroundColor: Colors.green));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_actionErrorMessage(error)), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _QueueAction {
  const _QueueAction({required this.action, required this.buttonLabel, required this.nextLabel, required this.nextStatus, this.nextRole});

  final String action;
  final String buttonLabel;
  final String nextLabel;
  final String nextStatus;
  final String? nextRole;
}

class _HttpAttempt {
  const _HttpAttempt(this.method, this.path);

  final String method;
  final String path;
}

class _QueueErrorCard extends StatelessWidget {
  const _QueueErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(message, style: const TextStyle(color: Colors.red))));
  }
}

String _queueStatus(String queue) {
  if (queue == 'assistant_director') return 'initiator_checked';
  if (queue == 'deputy_director') return 'ad_approved';
  if (queue == 'director') return 'dd_approved';
  return 'pending';
}

_QueueAction _queueAction(String queue, RequisitionWorkflowSettings settings) {
  if (queue == 'initiator') {
    final nextRole = settings.approvalFlowRoles.isEmpty ? 'assistant_director' : settings.approvalFlowRoles.first;
    return _QueueAction(
      action: 'forward',
      buttonLabel: 'Forward',
      nextLabel: _queueRoleLabel(nextRole),
      nextRole: nextRole,
      nextStatus: 'initiator_checked',
    );
  }
  if (queue == 'assistant_director') {
    return const _QueueAction(action: 'approve', buttonLabel: 'Verify', nextLabel: 'Deputy Director', nextRole: 'deputy_director', nextStatus: 'ad_approved');
  }
  if (queue == 'deputy_director') {
    return const _QueueAction(action: 'approve', buttonLabel: 'Verify', nextLabel: 'Director', nextRole: 'director', nextStatus: 'dd_approved');
  }
  return const _QueueAction(action: 'approve', buttonLabel: 'Final Approve', nextLabel: 'Distribution', nextStatus: 'director_approved');
}

String _queueRoleLabel(String role) {
  if (role == 'assistant_director') return 'Assistant Director';
  if (role == 'deputy_director') return 'Deputy Director';
  if (role == 'director') return 'Director';
  return role.replaceAll('_', ' ');
}

Future<void> _sendRequisitionAction(
  WidgetRef ref, {
  required int id,
  required String action,
  required String nextStatus,
  String? nextRole,
  String? remarks,
}) async {
  final dio = ref.read(apiClientProvider).dio;
  final payload = {
    'action': action,
    'status': nextStatus,
    'next_status': nextStatus,
    if (nextRole != null) 'next_role': nextRole,
    if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
  };

  final attempts = <_HttpAttempt>[
    _HttpAttempt('POST', '${ApiRoutes.requisitions}/$id/$action'),
    _HttpAttempt('PATCH', '${ApiRoutes.requisitions}/$id'),
    _HttpAttempt('PUT', '${ApiRoutes.requisitions}/$id'),
    _HttpAttempt('PATCH', '${ApiRoutes.requisitions}/$id/status'),
  ];

  for (final attempt in attempts) {
    try {
      if (attempt.method == 'PUT') {
        await dio.put(attempt.path, data: payload);
      } else if (attempt.method == 'PATCH') {
        await dio.patch(attempt.path, data: payload);
      } else {
        await dio.post(attempt.path, data: payload);
      }
      return;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 404 || statusCode == 405) continue;
      rethrow;
    }
  }

  throw UnsupportedError(
    'Forward/approval endpoint পাওয়া যায়নি। Backend-এ requisition action route expose করতে হবে: POST ${ApiRoutes.requisitions}/:id/$action অথবা PATCH/PUT ${ApiRoutes.requisitions}/:id।',
  );
}

String _actionErrorMessage(Object error) {
  if (error is UnsupportedError) return error.toString().replaceFirst('Unsupported operation: ', '');
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message'] ?? data['error'];
      if (message != null && '$message'.trim().isNotEmpty) return '$message';
    }
    if (error.response?.statusCode == 403) return 'আপনার এই requisition action করার permission নেই।';
    if (error.response?.statusCode == 422) return 'Forward করার তথ্য সঠিক নয়। Remarks/approval data যাচাই করুন।';
    if (error.response?.statusCode == 404) return 'এই requisition action endpoint পাওয়া যায়নি। Backend API route enable করা প্রয়োজন।';
  }
  return 'Requisition action সম্পন্ন করা যায়নি। আবার চেষ্টা করুন।';
}

List<Map<String, dynamic>> _queueRows(dynamic data) {
  final payload = data is Map ? (data['data'] ?? data['items'] ?? data['results'] ?? data) : data;
  if (payload is List) return payload.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  if (payload is Map) {
    final nested = payload['data'] ?? payload['items'] ?? payload['results'] ?? payload['requisitions'];
    if (nested is List) return nested.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  return const [];
}

int _queueInt(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

String _queueItemSummary(Map<String, dynamic> row) {
  final items = _queueRows(row['items'] ?? row['requisition_items']);
  if (items.isEmpty) return _queueProductName(row);
  return items.map(_queueProductName).take(2).join(', ');
}

String _queueProductName(Map<String, dynamic> row) {
  final product = row['product'];
  if (product is Map) return '${product['name'] ?? product['name_en'] ?? product['title'] ?? 'Item'}';
  return '${row['product_name'] ?? row['item_name'] ?? row['name'] ?? 'Item'}';
}
