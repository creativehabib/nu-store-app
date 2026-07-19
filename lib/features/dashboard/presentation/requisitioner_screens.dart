import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_routes.dart';
import '../../../shared/providers/core_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import 'requisition_details_screen.dart';
import 'requisition_workflow_settings.dart';

const _processingStatuses = {
  'pending',
  'initiator_checked',
  'ad_approved',
  'dd_approved',
  'director_approved',
  'department_director_review',
  'pending_dept_director',
  'forwarded_to_central_store',
};

final requisitionerDashboardProvider = FutureProvider<Map<String, int>>((ref) async {
  final response = await ref.watch(apiClientProvider).dio.get('/api/v1/dashboard');
  final data = response.data is Map ? Map<String, dynamic>.from(response.data as Map) : <String, dynamic>{};
  final payload = data['data'] is Map ? Map<String, dynamic>.from(data['data'] as Map) : data;
  return {
    'total': _intFrom(payload['total_submitted_requests'] ?? payload['total_submitted'] ?? payload['total'] ?? payload['submitted']),
    'processing': _intFrom(payload['processing'] ?? payload['pending'] ?? payload['in_progress']),
    'completed': _intFrom(payload['completed'] ?? payload['distributed']),
    'returned': _intFrom(payload['returned']),
  };
});

final myRequisitionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await ref.watch(apiClientProvider).dio.get(ApiRoutes.requisitions, queryParameters: {'mine': 1, 'per_page': 25});
  return _rows(response.data);
});

final categoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await ref.watch(apiClientProvider).dio.get(ApiRoutes.categories);
  return _rows(response.data);
});

final productsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await ref.watch(apiClientProvider).dio.get(ApiRoutes.products);
  return _rows(response.data);
});

final purposesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await ref.watch(apiClientProvider).dio.get(ApiRoutes.purposes);
  return _rows(response.data);
});


class RequisitionerDashboard extends ConsumerWidget {
  const RequisitionerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(requisitionerDashboardProvider);
    final settings = ref.watch(appSettingsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        await ref.refresh(requisitionerDashboardProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Requisitioner Dashboard', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          settings.when(
            data: (value) => _WorkflowInfoCard(settings: RequisitionWorkflowSettings.fromSettings(value)),
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const _ErrorCard(message: 'Settings load failed. Default departmental workflow will be used for UI hints.'),
          ),
          const SizedBox(height: 16),
          stats.when(
            data: (value) => _StatsGrid(stats: value),
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
            error: (error, _) => _ErrorCard(message: 'Dashboard data load failed: $error'),
          ),
        ],
      ),
    );
  }
}

class SubmitDemandScreen extends ConsumerStatefulWidget {
  const SubmitDemandScreen({super.key});

  @override
  ConsumerState<SubmitDemandScreen> createState() => _SubmitDemandScreenState();
}

class _SubmitDemandScreenState extends ConsumerState<SubmitDemandScreen> {
  final List<_DemandLine> _lines = [_DemandLine()];
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final products = ref.watch(productsProvider);
    final purposes = ref.watch(purposesProvider);
    final settings = ref.watch(appSettingsProvider);
    final user = ref.watch(authControllerProvider).user;
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Demand')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Submit New Demand', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          settings.when(
            data: (value) => _WorkflowInfoCard(settings: RequisitionWorkflowSettings.fromSettings(value), requesterDepartmentId: _userDepartmentId(user)),
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const _ErrorCard(message: 'Could not load workflow settings. You can still submit; backend will route it.'),
          ),
          const Divider(height: 28),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                for (var i = 0; i < _lines.length; i++)
                  _DemandLineForm(
                    line: _lines[i],
                    categories: _asyncRows(categories),
                    products: _asyncRows(products),
                    purposes: _asyncRows(purposes),
                    onRemove: _lines.length == 1 ? null : () => setState(() => _lines.removeAt(i)),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _lines.add(_DemandLine())),
                    icon: const Icon(Icons.add),
                    label: const Text('Add New Item'),
                  ),
                ),
                const Divider(height: 32),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: const Icon(Icons.send),
                    label: Text(_submitting ? 'Submitting...' : 'Submit Demand'),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final items = _lines.where((line) => line.productId != null).map((line) => {
      'product_id': line.productId,
      'demanded_qty': line.qty,
      'purpose': line.purpose,
    }).toList();
    if (items.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ref.read(apiClientProvider).dio.post(ApiRoutes.requisitions, data: {'items': items});
      ref.invalidate(myRequisitionsProvider);
      ref.invalidate(requisitionerDashboardProvider);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class MyRequisitionsScreen extends ConsumerStatefulWidget {
  const MyRequisitionsScreen({super.key});

  @override
  ConsumerState<MyRequisitionsScreen> createState() => _MyRequisitionsScreenState();
}

class _MyRequisitionsScreenState extends ConsumerState<MyRequisitionsScreen> {
  String _query = '';
  String _status = 'all';

  @override
  Widget build(BuildContext context) {
    final reqs = ref.watch(myRequisitionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Requisitions')),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.refresh(myRequisitionsProvider.future);
        },
        child: reqs.when(
          data: (items) => _buildList(context, items),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(padding: const EdgeInsets.all(24), children: [_ErrorCard(message: '$error')]),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Map<String, dynamic>> items) {
    final filtered = items.where((item) {
      final haystack = '${item['requisition_no']} ${_itemSummary(item)}'.toLowerCase();
      final status = '${item['status'] ?? ''}'.toLowerCase();
      return (_query.isEmpty || haystack.contains(_query.toLowerCase())) && (_status == 'all' || status == _status);
    }).toList();
    final stats = _statsFromRows(items);
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text('My Requisitions (Tracking & History)', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const Text('Track every submitted demand, item summary, and approval timeline from one place.'),
      const Divider(height: 28),
      _StatsGrid(stats: stats),
      const SizedBox(height: 20),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        Row(children: [
          Expanded(child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search requisition no or product name...'), onChanged: (v) => setState(() => _query = v))),
          const SizedBox(width: 12),
          DropdownButton<String>(value: _status, items: const [DropdownMenuItem(value: 'all', child: Text('All Status')), DropdownMenuItem(value: 'pending', child: Text('Pending')), DropdownMenuItem(value: 'returned', child: Text('Returned')), DropdownMenuItem(value: 'distributed', child: Text('Distributed'))], onChanged: (v) => setState(() => _status = v ?? 'all')),
        ]),
        const SizedBox(height: 16),
        for (final item in filtered) _RequisitionTile(row: item),
      ]))),
    ]);
  }
}

class _RequisitionTile extends StatelessWidget {
  const _RequisitionTile({required this.row});
  final Map<String, dynamic> row;
  @override
  Widget build(BuildContext context) => ListTile(
    title: Text('${row['requisition_no'] ?? 'REQ-${row['id'] ?? '-'}'}', style: const TextStyle(fontWeight: FontWeight.bold)),
    subtitle: Text('${_date(row['created_at'])}\n${_itemSummary(row)}'),
    trailing: FilledButton.tonalIcon(icon: const Icon(Icons.history), label: const Text('Details'), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RequisitionDetailsScreen(id: _intFrom(row['id']), fallback: row)))),
  );
  return _rows(response.data);
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
        onRefresh: () => ref.refresh(requisitionQueueProvider(queue).future),
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
          error: (error, _) => ListView(padding: const EdgeInsets.all(24), children: [_ErrorCard(message: '$error')]),
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
          Text(_itemSummary(widget.row)),
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
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RequisitionDetailsScreen(id: _intFrom(widget.row['id']), fallback: widget.row))),
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
    final id = _intFrom(widget.row['id']);
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error'), backgroundColor: Colors.red));
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

class RequisitionDetailsScreen extends ConsumerWidget {
  const RequisitionDetailsScreen({super.key, required this.id, required this.fallback});

  final int id;
  final Map<String, dynamic> fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = id == 0 ? AsyncData(fallback) : ref.watch(requisitionDetailProvider(id));
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
            _HistoryDialog(row: row),
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


class _WorkflowInfoCard extends StatelessWidget {
  const _WorkflowInfoCard({required this.settings, this.requesterDepartmentId});

  final RequisitionWorkflowSettings settings;
  final int? requesterDepartmentId;

  @override
  Widget build(BuildContext context) {
    final isCentralRequester = settings.isCentralized && requesterDepartmentId == settings.centralStoreDepartmentId;
    final title = settings.isCentralized ? 'Centralized Store Workflow' : 'Departmental Store Workflow';
    final message = settings.isCentralized
        ? (isCentralRequester
            ? 'আপনি central store department-এর user; requisition সরাসরি Central Store Initiator queue-তে pending হিসেবে যাবে।'
            : 'আপনার requisition আগে নিজের department director review-তে যাবে, তারপর Central Store Initiator queue-তে যাবে।')
        : 'আপনার requisition নিজের department-এর Initiator queue-তে pending হিসেবে যাবে।';
    return Card(
      color: (settings.isCentralized ? Colors.deepPurple : Colors.teal).withValues(alpha: .08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(settings.isCentralized ? Icons.hub_outlined : Icons.account_tree_outlined, color: settings.isCentralized ? Colors.deepPurple : Colors.teal),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          Text(message),
          const SizedBox(height: 8),
          Text('Approval flow: ${_approvalRoleLabels(settings.approvalFlowRoles).join(' → ')}'),
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
    final details = id == 0 ? AsyncData(fallback) : ref.watch(requisitionDetailProvider(id));
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
            _HistoryDialog(row: row),
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


class _WorkflowInfoCard extends StatelessWidget {
  const _WorkflowInfoCard({required this.settings, this.requesterDepartmentId});

  final RequisitionWorkflowSettings settings;
  final int? requesterDepartmentId;

  @override
  Widget build(BuildContext context) {
    final isCentralRequester = settings.isCentralized && requesterDepartmentId == settings.centralStoreDepartmentId;
    final title = settings.isCentralized ? 'Centralized Store Workflow' : 'Departmental Store Workflow';
    final message = settings.isCentralized
        ? (isCentralRequester
            ? 'আপনি central store department-এর user; requisition সরাসরি Central Store Initiator queue-তে pending হিসেবে যাবে।'
            : 'আপনার requisition আগে নিজের department director review-তে যাবে, তারপর Central Store Initiator queue-তে যাবে।')
        : 'আপনার requisition নিজের department-এর Initiator queue-তে pending হিসেবে যাবে।';
    return Card(
      color: (settings.isCentralized ? Colors.deepPurple : Colors.teal).withValues(alpha: .08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(settings.isCentralized ? Icons.hub_outlined : Icons.account_tree_outlined, color: settings.isCentralized ? Colors.deepPurple : Colors.teal),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          Text(message),
          const SizedBox(height: 8),
          Text('Approval flow: ${_approvalRoleLabels(settings.approvalFlowRoles).join(' → ')}'),
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
            _HistoryDialog(row: row),
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


class _WorkflowInfoCard extends StatelessWidget {
  const _WorkflowInfoCard({required this.settings, this.requesterDepartmentId});

  final RequisitionWorkflowSettings settings;
  final int? requesterDepartmentId;

  @override
  Widget build(BuildContext context) {
    final isCentralRequester = settings.isCentralized && requesterDepartmentId == settings.centralStoreDepartmentId;
    final title = settings.isCentralized ? 'Centralized Store Workflow' : 'Departmental Store Workflow';
    final message = settings.isCentralized
        ? (isCentralRequester
            ? 'আপনি central store department-এর user; requisition সরাসরি Central Store Initiator queue-তে pending হিসেবে যাবে।'
            : 'আপনার requisition আগে নিজের department director review-তে যাবে, তারপর Central Store Initiator queue-তে যাবে।')
        : 'আপনার requisition নিজের department-এর Initiator queue-তে pending হিসেবে যাবে।';
    return Card(
      color: (settings.isCentralized ? Colors.deepPurple : Colors.teal).withOpacity(.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(settings.isCentralized ? Icons.hub_outlined : Icons.account_tree_outlined, color: settings.isCentralized ? Colors.deepPurple : Colors.teal),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          Text(message),
          const SizedBox(height: 8),
          Text('Approval flow: ${_approvalRoleLabels(settings.approvalFlowRoles).join(' → ')}'),
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


class _StatsGrid extends StatelessWidget { const _StatsGrid({required this.stats}); final Map<String,int> stats; @override Widget build(BuildContext context) => GridView.count(crossAxisCount: MediaQuery.sizeOf(context).width > 900 ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 2.2, children: [_Card('Total Submitted Requests', stats['total'] ?? 0, Colors.blue, Icons.description_outlined), _Card('Processing (Pending)', stats['processing'] ?? 0, Colors.orange, Icons.schedule), _Card('Completed (Distributed)', stats['completed'] ?? 0, Colors.green, Icons.check_circle_outline), _Card('Returned', stats['returned'] ?? 0, Colors.red, Icons.reply)]); }
class _Card extends StatelessWidget { const _Card(this.title,this.value,this.color,this.icon); final String title; final int value; final Color color; final IconData icon; @override Widget build(BuildContext context)=>Card(color: color.withOpacity(.08), child: Padding(padding: const EdgeInsets.all(20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)), const Spacer(), Text('$value', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold))]), Icon(icon, color: color.withOpacity(.45), size: 34)]))); }
class _ErrorCard extends StatelessWidget { const _ErrorCard({required this.message}); final String message; @override Widget build(BuildContext context)=>Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(message, style: const TextStyle(color: Colors.red)))); }
class _DemandLine {
  int? categoryId;
  int? productId;
  int qty = 1;
  String? purpose;
}

class _DemandLineForm extends StatefulWidget {
  const _DemandLineForm({
    required this.line,
    required this.categories,
    required this.products,
    required this.purposes,
    this.onRemove,
  });

  final _DemandLine line;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> purposes;
  final VoidCallback? onRemove;

  @override
  State<_DemandLineForm> createState() => _DemandLineFormState();
}

class _DemandLineFormState extends State<_DemandLineForm> {
  @override
  Widget build(BuildContext context) {
    final productOptions = _filteredProductOptions();
    final categoryOptions = _categoryOptions(widget.categories, widget.products);
    final purposeOptions = _purposeOptions(widget.purposes);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 720;
          final fields = <Widget>[
            _fieldBox(
              isNarrow,
              _idDropdown(
                label: 'Category',
                value: _containsId(categoryOptions, widget.line.categoryId) ? widget.line.categoryId : null,
                rows: categoryOptions,
                onChanged: (value) => setState(() {
                  widget.line.categoryId = value;
                  widget.line.productId = null;
                }),
              ),
            ),
            _fieldBox(
              isNarrow,
              _idDropdown(
                label: 'Item Name',
                value: _containsId(productOptions, widget.line.productId) ? widget.line.productId : null,
                rows: productOptions,
                onChanged: (value) => setState(() => widget.line.productId = value),
              ),
              flex: 2,
            ),
            SizedBox(
              width: isNarrow ? double.infinity : 96,
              child: TextFormField(
                initialValue: '${widget.line.qty}',
                decoration: const InputDecoration(labelText: 'Qty'),
                keyboardType: TextInputType.number,
                onChanged: (value) => widget.line.qty = int.tryParse(value) ?? 1,
              ),
            ),
            _fieldBox(
              isNarrow,
              purposeOptions.isEmpty
                  ? TextFormField(
                      initialValue: widget.line.purpose,
                      decoration: const InputDecoration(labelText: 'Purpose'),
                      onChanged: (value) => widget.line.purpose = value,
                    )
                  : DropdownButtonFormField<String>(
                      value: purposeOptions.contains(widget.line.purpose) ? widget.line.purpose : null,
                      decoration: const InputDecoration(labelText: 'Purpose'),
                      isExpanded: true,
                      items: [
                        for (final purpose in purposeOptions)
                          DropdownMenuItem(value: purpose, child: Text(purpose, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (value) => setState(() => widget.line.purpose = value),
                    ),
            ),
            if (widget.onRemove != null) IconButton(onPressed: widget.onRemove, icon: const Icon(Icons.delete_outline)),
          ];

          if (isNarrow) {
            return Column(
              children: [
                for (var i = 0; i < fields.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  fields[i],
                ],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < fields.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                fields[i],
              ],
            ],
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _filteredProductOptions() {
    final products = _optionRows(widget.products);
    final categoryId = widget.line.categoryId;
    if (categoryId == null) return products;
    return products.where((product) {
      final productCategory = product['category_id'] ??
          (product['category'] is Map ? (product['category'] as Map)['id'] : null);
      final parsedCategoryId = _intFrom(productCategory);
      return parsedCategoryId == 0 || parsedCategoryId == categoryId;
    }).toList();
  }

  Widget _fieldBox(bool isNarrow, Widget child, {int flex = 1}) {
    if (isNarrow) return SizedBox(width: double.infinity, child: child);
    return Expanded(flex: flex, child: child);
  }

  Widget _idDropdown({
    required String label,
    required int? value,
    required List<Map<String, dynamic>> rows,
    required ValueChanged<int?> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(labelText: label),
      isExpanded: true,
      items: [
        for (final row in rows)
          DropdownMenuItem(value: _intFrom(row['id']), child: Text(_rowLabel(row), overflow: TextOverflow.ellipsis)),
      ],
      onChanged: rows.isEmpty ? null : onChanged,
    );
  }
}

List<Map<String, dynamic>> _optionRows(List<Map<String, dynamic>> rows) {
  final seen = <int>{};
  final options = <Map<String, dynamic>>[];
  for (final row in rows) {
    final id = _intFrom(row['id']);
    if (id == 0 || seen.contains(id)) continue;
    seen.add(id);
    options.add(row);
  }
  return options;
}

bool _containsId(List<Map<String, dynamic>> rows, int? id) {
  if (id == null) return false;
  return rows.any((row) => _intFrom(row['id']) == id);
}

List<Map<String, dynamic>> _categoryOptions(
  List<Map<String, dynamic>> categories,
  List<Map<String, dynamic>> products,
) {
  final options = _optionRows(categories);
  if (options.isNotEmpty) return options;

  final fromProducts = <Map<String, dynamic>>[];
  final seen = <int>{};
  for (final product in products) {
    final nestedCategory = product['category'];
    if (nestedCategory is Map) {
      final category = Map<String, dynamic>.from(nestedCategory);
      final id = _intFrom(category['id']);
      if (id != 0 && !seen.contains(id)) {
        seen.add(id);
        fromProducts.add(category);
      }
      continue;
    }

    final categoryId = _intFrom(product['category_id']);
    if (categoryId != 0 && !seen.contains(categoryId)) {
      seen.add(categoryId);
      fromProducts.add({
        'id': categoryId,
        'name': product['category_name'] ?? product['category_title'] ?? 'Category $categoryId',
      });
    }
  }
  return fromProducts;
}

List<String> _purposeOptions(List<Map<String, dynamic>> rows) {
  final options = <String>[];
  for (final row in rows) {
    final purpose = '${row['purpose'] ?? row['name'] ?? row['name_en'] ?? row['title'] ?? ''}'.trim();
    if (purpose.isNotEmpty && !options.contains(purpose)) options.add(purpose);
  }
  return options.isEmpty ? const ['For official use'] : options;
}

String _rowLabel(Map<String, dynamic> row) {
  return '${row['name'] ?? row['name_en'] ?? row['name_bn'] ?? row['title'] ?? row['product_name'] ?? row['category_name'] ?? 'Item'}';
}

List<Map<String, dynamic>> _asyncRows(AsyncValue<List<Map<String, dynamic>>> value) {
  return value.when(
    data: (rows) => rows,
    loading: () => const [],
    error: (_, _) => const [],
  );
}



String _roleLabel(String role) {
  if (role == 'assistant_director') return 'Assistant Director';
  if (role == 'deputy_director') return 'Deputy Director';
  if (role == 'director') return 'Director';
  return role.replaceAll('_', ' ');
}

int? _userDepartmentId(Map<String, dynamic>? user) {
  if (user == null) return null;
  final department = user['department'];
  if (department is Map) return _intFrom(department['id']);
  final value = user['department_id'] ?? user['dept_id'];
  final parsed = _intFrom(value);
  return parsed == 0 ? null : parsed;
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

List<Map<String, dynamic>> _rows(dynamic data) { final payload = data is Map ? (data['data'] ?? data['items'] ?? data['results'] ?? data) : data; if (payload is List) return payload.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList(); if (payload is Map) { final nested = payload['data'] ?? payload['items'] ?? payload['results'] ?? payload['categories'] ?? payload['products'] ?? payload['purposes'] ?? payload['requisitions']; if (nested is List) return nested.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList(); return payload.entries.where((entry) => entry.value is List).expand((entry) => (entry.value as List).whereType<Map>()).map((e)=>Map<String,dynamic>.from(e)).toList(); } return const []; }
int _intFrom(dynamic v)=> v is num ? v.toInt() : int.tryParse('$v') ?? 0;
Map<String,int> _statsFromRows(List<Map<String,dynamic>> rows)=> {'total': rows.length, 'processing': rows.where((r)=>_processingStatuses.contains('${r['status']}'.toLowerCase())).length, 'completed': rows.where((r)=>'${r['status']}'.toLowerCase()=='distributed').length, 'returned': rows.where((r)=>'${r['status']}'.toLowerCase()=='returned').length};
String _date(dynamic value){ final d=DateTime.tryParse('$value'); return d==null ? '-' : DateFormat('dd MMM, yyyy hh:mm a').format(d.toLocal()); }
String _itemSummary(Map<String,dynamic> r){ final items=_rows(r['items'] ?? r['requisition_items']); if(items.isEmpty) return _productName(r); return items.map(_productName).take(2).join(', '); }
String _productName(Map<String,dynamic> r){ final p=r['product']; if(p is Map) return '${p['name'] ?? p['name_en'] ?? p['title'] ?? 'Item'}'; return '${r['product_name'] ?? r['item_name'] ?? r['name'] ?? 'Item'}'; }
