import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_routes.dart';
import '../../../shared/providers/core_providers.dart';
import 'requisitioner_screens.dart';
import 'requisition_details_screen.dart';
import 'requisition_workflow_settings.dart';

final requisitionQueueProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, queue) async {
  final dio = ref.watch(apiClientProvider).dio;
  final status = _queueStatus(queue);
  final attempts = <_HttpAttempt>[
    _HttpAttempt('GET', '${ApiRoutes.requisitionWorkflow}/queue/$queue'),
    _HttpAttempt('GET', '${ApiRoutes.workflowRequisitions}/queue/$queue'),
    _HttpAttempt('GET', '${ApiRoutes.requisitions}/workflow/queue/$queue'),
    _HttpAttempt('GET', ApiRoutes.requisitions),
  ];

  for (final attempt in attempts) {
    try {
      final response = await dio.get(
        attempt.path,
        queryParameters: {'queue': queue, 'status': status, 'per_page': 25},
      );
      return _queueRows(response.data);
    } on DioException catch (error) {
      if (_shouldTryNextRoute(error)) continue;
      rethrow;
    }
  }

  return const [];
});

class RequisitionApprovalQueueScreen extends ConsumerStatefulWidget {
  const RequisitionApprovalQueueScreen({super.key, required this.title, required this.queue});

  final String title;
  final String queue;

  @override
  ConsumerState<RequisitionApprovalQueueScreen> createState() => _RequisitionApprovalQueueScreenState();
}

class _RequisitionApprovalQueueScreenState extends ConsumerState<RequisitionApprovalQueueScreen> {
  final _searchController = TextEditingController();
  String _statusFilter = 'All Statuses';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(requisitionQueueProvider(widget.queue));
    final settings = ref.watch(appSettingsProvider);
    final workflowSettings = settings.when(
      data: (value) => value,
      loading: () => const <String, dynamic>{},
      error: (_, _) => const <String, dynamic>{},
    );

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(requisitionQueueProvider(widget.queue).future),
        child: items.when(
          data: (rows) {
            final filteredRows = _filterRows(rows);
            if (rows.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: const [Center(child: Text('No pending requisitions found.'))],
              );
            }

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _QueueHeader(title: widget.title, rows: rows),
                const SizedBox(height: 20),
                _QueueFilters(
                  controller: _searchController,
                  statusFilter: _statusFilter,
                  statuses: _statusOptions(rows),
                  onSearchChanged: (_) => setState(() {}),
                  onStatusChanged: (value) => setState(() => _statusFilter = value ?? 'All Statuses'),
                  onClear: () => setState(() {
                    _searchController.clear();
                    _statusFilter = 'All Statuses';
                  }),
                ),
                const SizedBox(height: 16),
                _QueueTable(
                  rows: filteredRows,
                  queue: widget.queue,
                  settings: workflowSettings,
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(padding: const EdgeInsets.all(24), children: [_QueueErrorCard(message: '$error')]),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filterRows(List<Map<String, dynamic>> rows) {
    final query = _searchController.text.trim().toLowerCase();
    return rows.where((row) {
      final status = '${row['status'] ?? _queueStatus(widget.queue)}';
      final matchesStatus = _statusFilter == 'All Statuses' || status == _statusFilter;
      final haystack = [
        row['requisition_no'],
        row['applicant_name'],
        row['user_name'],
        row['pf_no'],
        row['department_name'],
        _queueItemSummary(row),
      ].whereType<Object>().join(' ').toLowerCase();
      return matchesStatus && (query.isEmpty || haystack.contains(query));
    }).toList();
  }
}

class _QueueHeader extends StatelessWidget {
  const _QueueHeader({required this.title, required this.rows});

  final String title;
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Review requisitions, stock demand, and distribution-ready items from one table.'),
          ],
        ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _StatusPill(label: 'Pending', count: _countStatus(rows, 'pending'), color: const Color(0xFFF59E0B)),
          _StatusPill(label: 'Returned', count: _countStatus(rows, 'returned'), color: const Color(0xFFEF4444)),
          _StatusPill(label: 'Ready', count: _readyCount(rows), color: const Color(0xFF16A34A)),
          _StatusPill(label: 'Distributed', count: _countStatus(rows, 'distributed'), color: const Color(0xFF4F46E5)),
        ]),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.count, required this.color});

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: color.withOpacity(.12),
      label: Text('$label: $count', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _QueueFilters extends StatelessWidget {
  const _QueueFilters({
    required this.controller,
    required this.statusFilter,
    required this.statuses,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String statusFilter;
  final List<String> statuses;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 720;
            final search = TextField(
              controller: controller,
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Requisition no, applicant, PF, department, or product...',
                border: OutlineInputBorder(),
              ),
            );
            final status = DropdownButtonFormField<String>(
              value: statusFilter,
              items: statuses.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: onStatusChanged,
              decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
            );
            final clear = OutlinedButton.icon(onPressed: onClear, icon: const Icon(Icons.close), label: const Text('Clear'));

            if (narrow) {
              return Column(children: [search, const SizedBox(height: 12), status, const SizedBox(height: 12), Align(alignment: Alignment.centerRight, child: clear)]);
            }
            return Row(children: [Expanded(flex: 4, child: search), const SizedBox(width: 12), Expanded(child: status), const SizedBox(width: 12), clear]);
          },
        ),
      ),
    );
  }
}

class _QueueTable extends ConsumerWidget {
  const _QueueTable({required this.rows, required this.queue, required this.settings});

  final List<Map<String, dynamic>> rows;
  final String queue;
  final Map<String, dynamic>? settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rows.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No requisitions match this filter.'))));
    }

    final action = _queueAction(queue, RequisitionWorkflowSettings.fromSettings(settings ?? const {}));
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
          columns: const [
            DataColumn(label: Text('#')),
            DataColumn(label: Text('REQUISITION')),
            DataColumn(label: Text('APPLICANT & DEPARTMENT')),
            DataColumn(label: Text('ITEMS SUMMARY')),
            DataColumn(label: Text('DEMAND')),
            DataColumn(label: Text('AGE')),
            DataColumn(label: Text('STATUS')),
            DataColumn(label: Text('ACTION')),
          ],
          rows: [
            for (var index = 0; index < rows.length; index++)
              DataRow(cells: [
                DataCell(Text('${index + 1}')),
                DataCell(_RequisitionCell(row: rows[index])),
                DataCell(_ApplicantCell(row: rows[index])),
                DataCell(_ItemsCell(row: rows[index])),
                DataCell(_DemandCell(row: rows[index])),
                DataCell(Text(_queueAge(rows[index]))),
                DataCell(_StatusBadge(status: '${rows[index]['status'] ?? _queueStatus(queue)}')),
                DataCell(_ActionCell(row: rows[index], queue: queue, settings: settings, action: action)),
              ]),
          ],
        ),
      ),
    );
  }
}

class _RequisitionCell extends StatelessWidget {
  const _RequisitionCell({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('${row['requisition_no'] ?? 'REQ-${row['id'] ?? '-'}'}', style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(_queueDate(row), style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

class _ApplicantCell extends StatelessWidget {
  const _ApplicantCell({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(_queueApplicant(row), style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text('PF: ${row['pf_no'] ?? row['pf'] ?? '-'}', style: Theme.of(context).textTheme.bodySmall),
      Text(_queueDepartment(row), style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

class _ItemsCell extends StatelessWidget {
  const _ItemsCell({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final items = _queueRows(row['items'] ?? row['requisition_items']);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Chip(label: Text(_queueItemSummary(row)), visualDensity: VisualDensity.compact),
      Text('${items.isEmpty ? 1 : items.length} item(s)', style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

class _DemandCell extends StatelessWidget {
  const _DemandCell({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('${_queueDemand(row)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      Text(_queueUnit(row), style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Chip(
      label: Text(_titleCase(status), style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      backgroundColor: color.withOpacity(.12),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ActionCell extends StatelessWidget {
  const _ActionCell({required this.row, required this.queue, required this.settings, required this.action});

  final Map<String, dynamic> row;
  final String queue;
  final Map<String, dynamic>? settings;
  final _QueueAction action;

  @override
  Widget build(BuildContext context) {
    final status = '${row['status'] ?? ''}'.toLowerCase();
    final printReady = status.contains('distributed') || status.contains('director_approved');
    return printReady
        ? OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RequisitionDetailsScreen(id: _queueInt(row['id']), fallback: row))),
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Print & Distribute'),
          )
        : FilledButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _DetermineQuantityDialog(row: row, queue: queue, settings: settings, action: action),
            ),
            icon: const Icon(Icons.visibility, size: 16),
            label: const Text('View & Action'),
          );
  }
}

class _DetermineQuantityDialog extends ConsumerStatefulWidget {
  const _DetermineQuantityDialog({required this.row, required this.queue, required this.settings, required this.action});

  final Map<String, dynamic> row;
  final String queue;
  final Map<String, dynamic>? settings;
  final _QueueAction action;

  @override
  ConsumerState<_DetermineQuantityDialog> createState() => _DetermineQuantityDialogState();
}

class _DetermineQuantityDialogState extends ConsumerState<_DetermineQuantityDialog> {
  late final List<Map<String, dynamic>> _items;
  late final List<TextEditingController> _quantityControllers;
  final _remarksController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final parsed = _queueRows(widget.row['items'] ?? widget.row['requisition_items']);
    _items = parsed.isEmpty ? [widget.row] : parsed;
    _quantityControllers = _items.map((item) => TextEditingController(text: '${_queueDemand(item)}')).toList();
  }

  @override
  void dispose() {
    for (final controller in _quantityControllers) {
      controller.dispose();
    }
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Row(children: [
        Expanded(child: Text('Requisition Details: ${widget.row['requisition_no'] ?? 'REQ-${widget.row['id'] ?? '-'}'}')),
        IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
      ]),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Applicant: ${_queueApplicant(widget.row)} (${_queueDepartment(widget.row)})'),
            const Divider(height: 28),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Item Name')),
                  DataColumn(label: Text('Current Stock')),
                  DataColumn(label: Text('Demanded Quantity')),
                  DataColumn(label: Text('Determine Supply Quantity')),
                ],
                rows: [
                  for (var index = 0; index < _items.length; index++)
                    DataRow(cells: [
                      DataCell(_ItemNameWithUnit(item: _items[index])),
                      DataCell(Text('${_queueCurrentStock(_items[index])}', style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold))),
                      DataCell(Text('${_queueDemand(_items[index])}')),
                      DataCell(SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _quantityControllers[index],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                        ),
                      )),
                    ]),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _remarksController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Note / Comment (Optional)', hintText: 'e.g., Sufficient in stock...', border: OutlineInputBorder()),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _submitting ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: const Icon(Icons.check_circle),
          label: Text(_submitting ? 'Forwarding...' : '${widget.action.buttonLabel} for Approval'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final id = _queueInt(widget.row['id']);
    if (id == 0) return;
    setState(() => _submitting = true);
    final quantities = <Map<String, dynamic>>[];
    for (var index = 0; index < _items.length; index++) {
      quantities.add({
        'id': _items[index]['id'],
        'product_id': _queueProductId(_items[index]),
        'approved_quantity': _queueInt(_quantityControllers[index].text),
        'determined_quantity': _queueInt(_quantityControllers[index].text),
        'supply_quantity': _queueInt(_quantityControllers[index].text),
      });
    }

    try {
      await _sendRequisitionAction(
        ref,
        id: id,
        action: widget.action.action,
        nextRole: widget.action.nextRole,
        nextStatus: widget.action.nextStatus,
        remarks: _remarksController.text.trim(),
        quantities: quantities,
      );
      ref.invalidate(requisitionQueueProvider(widget.queue));
      ref.invalidate(myRequisitionsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.action.buttonLabel} successful'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_actionErrorMessage(error), maxLines: 3, overflow: TextOverflow.ellipsis), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _ItemNameWithUnit extends StatelessWidget {
  const _ItemNameWithUnit({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(_queueProductName(item), style: const TextStyle(fontWeight: FontWeight.bold)),
      Text(_queueUnit(item), style: Theme.of(context).textTheme.bodySmall),
    ]);
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
  List<Map<String, dynamic>> quantities = const <Map<String, dynamic>>[],
}) async {
  final dio = ref.read(apiClientProvider).dio;
  final payload = {
    'action': action,
    'decision': action,
    'status': nextStatus,
    'next_status': nextStatus,
    if (nextRole != null) ...{
      'next_role': nextRole,
      'next_approver_role': nextRole,
      'role': nextRole,
    },
    if (remarks != null && remarks.isNotEmpty) ...{
      'remarks': remarks,
      'comment': remarks,
      'note': remarks,
    },
    if (quantities.isNotEmpty) ...{
      'items': quantities,
      'requisition_items': quantities,
      'approved_items': quantities,
    },
  };

  final attempts = <_HttpAttempt>[
    _HttpAttempt('POST', '${ApiRoutes.requisitionWorkflow}/$id/$action'),
    _HttpAttempt('POST', '${ApiRoutes.requisitionWorkflow}/requisitions/$id/$action'),
    _HttpAttempt('POST', '${ApiRoutes.workflowRequisitions}/$id/$action'),
    _HttpAttempt('POST', '${ApiRoutes.requisitions}/$id/workflow/$action'),
    _HttpAttempt('POST', '${ApiRoutes.requisitions}/$id/actions/$action'),
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
      if (_shouldTryNextRoute(error)) continue;
      rethrow;
    }
  }

  throw UnsupportedError('Workflow action API পাওয়া যায়নি। অনুগ্রহ করে অ্যাপ আপডেট/রিফ্রেশ করে আবার চেষ্টা করুন।');
}


bool _shouldTryNextRoute(DioException error) {
  final statusCode = error.response?.statusCode;
  return statusCode == 404 || statusCode == 405;
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
    if (error.response?.statusCode == 404) return 'Workflow action API পাওয়া যায়নি। অ্যাপটি রিফ্রেশ করে আবার চেষ্টা করুন।';
  }
  return 'Requisition action সম্পন্ন করা যায়নি। আবার চেষ্টা করুন।';
}


List<String> _statusOptions(List<Map<String, dynamic>> rows) {
  final statuses = rows.map((row) => '${row['status'] ?? ''}').where((status) => status.trim().isNotEmpty).toSet().toList()..sort();
  return ['All Statuses', ...statuses];
}

int _countStatus(List<Map<String, dynamic>> rows, String status) {
  return rows.where((row) => '${row['status'] ?? ''}'.toLowerCase().contains(status)).length;
}

int _readyCount(List<Map<String, dynamic>> rows) {
  return rows.where((row) {
    final status = '${row['status'] ?? ''}'.toLowerCase();
    return status.contains('ready') || status.contains('approved');
  }).length;
}

Color _statusColor(String status) {
  final normalized = status.toLowerCase();
  if (normalized.contains('distributed')) return const Color(0xFF4F46E5);
  if (normalized.contains('return') || normalized.contains('reject')) return const Color(0xFFEF4444);
  if (normalized.contains('ready') || normalized.contains('approved')) return const Color(0xFF16A34A);
  return const Color(0xFFF59E0B);
}

String _titleCase(String value) {
  final clean = value.replaceAll('_', ' ').trim();
  if (clean.isEmpty) return 'Pending';
  return clean.split(' ').map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}').join(' ');
}

String _queueDate(Map<String, dynamic> row) {
  final value = row['created_at'] ?? row['date'] ?? row['submitted_at'];
  if (value == null) return '-';
  final parsed = DateTime.tryParse('$value');
  if (parsed == null) return '$value';
  return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
}

String _queueAge(Map<String, dynamic> row) {
  final value = row['created_at'] ?? row['submitted_at'];
  final parsed = value == null ? null : DateTime.tryParse('$value');
  if (parsed == null) return '-';
  final diff = DateTime.now().difference(parsed);
  if (diff.inMinutes < 60) return '${diff.inMinutes} minutes\nago';
  if (diff.inHours < 24) return '${diff.inHours} hours\nago';
  if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'}\nago';
  final weeks = (diff.inDays / 7).floor();
  return '$weeks week${weeks == 1 ? '' : 's'}\nago';
}


String _queueDepartment(Map<String, dynamic> row) {
  final department = row['department'];
  if (department is Map) return '${department['name'] ?? department['name_en'] ?? '-'}';
  return '${row['department_name'] ?? row['office_name'] ?? '-'}';
}

Object? _queueProductId(Map<String, dynamic> row) {
  final product = row['product'];
  if (product is Map) return product['id'];
  return row['product_id'];
}
String _queueApplicant(Map<String, dynamic> row) {
  final user = row['user'] ?? row['applicant'] ?? row['employee'];
  if (user is Map) return '${user['name'] ?? user['full_name'] ?? 'Applicant'}';
  return '${row['applicant_name'] ?? row['user_name'] ?? row['employee_name'] ?? row['name'] ?? 'Applicant'}';
}

int _queueDemand(Map<String, dynamic> row) {
  return _queueInt(row['demanded_quantity'] ?? row['quantity'] ?? row['qty'] ?? row['requested_quantity'] ?? 1);
}

String _queueUnit(Map<String, dynamic> row) {
  final product = row['product'];
  if (product is Map) return '${product['unit'] ?? product['unit_name'] ?? 'pcs'}';
  return '${row['unit'] ?? row['unit_name'] ?? 'pcs'}';
}

int _queueCurrentStock(Map<String, dynamic> row) {
  final product = row['product'];
  if (product is Map) return _queueInt(product['current_stock'] ?? product['stock'] ?? product['quantity']);
  return _queueInt(row['current_stock'] ?? row['stock'] ?? row['available_stock']);
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
