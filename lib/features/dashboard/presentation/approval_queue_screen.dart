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
  final statuses = _queueStatuses(queue);
  final attempts = <_HttpAttempt>[
    if (queue == 'initiator')
      const _HttpAttempt('GET', ApiRoutes.workflowInitiatorQueue)
    else
      const _HttpAttempt('GET', ApiRoutes.workflowApprovalQueue),
    _HttpAttempt('GET', '${ApiRoutes.requisitionWorkflow}/queue/$queue'),
    _HttpAttempt('GET', '${ApiRoutes.workflowRequisitions}/queue/$queue'),
    _HttpAttempt('GET', '${ApiRoutes.requisitions}/workflow/queue/$queue'),
    _HttpAttempt('GET', ApiRoutes.requisitions),
  ];

  for (final attempt in attempts) {
    try {
      final rowsById = <String, Map<String, dynamic>>{};
      for (final status in statuses) {
        try {
          final response = await dio.get(
            attempt.path,
            queryParameters: _queueQueryParameters(attempt.path, queue, status),
          );
          for (final row in _queueRows(response.data)) {
            rowsById[_queueRowKey(row)] = row;
          }
        } on DioException catch (error) {
          if (_shouldTryNextStatus(error)) continue;
          rethrow;
        }
      }
      return rowsById.values.toList();
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

    final queueColors = _QueueColors.of(context);

    return Scaffold(
      backgroundColor: queueColors.background,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: queueColors.primary,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(requisitionQueueProvider(widget.queue).future),
        child: items.when(
          data: (rows) {
            final filteredRows = _filterRows(rows);
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                    child: _QueueHeader(title: widget.title, rows: rows),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _QueueFilters(
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
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                if (filteredRows.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No pending requisitions found.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    sliver: SliverToBoxAdapter(
                      child: _QueueTable(
                        rows: filteredRows,
                        queue: widget.queue,
                        settings: workflowSettings,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _QueueErrorCard(message: '$error'),
            ),
          ),
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

class _QueueColors {
  const _QueueColors({
    required this.primary,
    required this.primaryDark,
    required this.primarySoft,
    required this.background,
    required this.card,
    required this.border,
    required this.fieldFill,
  });

  final Color primary;
  final Color primaryDark;
  final Color primarySoft;
  final Color background;
  final Color card;
  final Color border;
  final Color fieldFill;

  static _QueueColors of(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    return _QueueColors(
      primary: primary,
      primaryDark: const Color(0xFF1E3A8A),
      primarySoft: primary.withOpacity(.10),
      background: const Color(0xFFF1F5F9),
      card: Colors.white,
      border: const Color(0xFFD8E2F0),
      fieldFill: const Color(0xFFF8FAFC),
    );
  }
}

class _QueueHeader extends StatelessWidget {
  const _QueueHeader({required this.title, required this.rows});

  final String title;
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final colors = _QueueColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.primaryDark],
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withOpacity(.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(.22)),
                ),
                child: const Icon(Icons.forward_to_inbox, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Review, match stock demand, and forward requisitions smoothly.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(.82)),
                    ),
                  ],
                ),
              ),
              _HeaderTotalBadge(count: rows.length),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatusPill(label: 'Pending', count: _countStatus(rows, 'pending'), color: const Color(0xFFF59E0B)),
              _StatusPill(label: 'Returned', count: _countStatus(rows, 'returned'), color: const Color(0xFFEF4444)),
              _StatusPill(label: 'Ready', count: _readyCount(rows), color: const Color(0xFF22C55E)),
              _StatusPill(label: 'Distributed', count: _countStatus(rows, 'distributed'), color: const Color(0xFF818CF8)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderTotalBadge extends StatelessWidget {
  const _HeaderTotalBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(.24)),
      ),
      child: Column(
        children: [
          Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22)),
          Text('Total', style: TextStyle(color: Colors.white.withOpacity(.78), fontSize: 12)),
        ],
      ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 4, backgroundColor: color),
          const SizedBox(width: 8),
          Text(
            '$label: $count',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
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
    final colors = _QueueColors.of(context);

    return Card(
      color: colors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 600;

            final searchField = TextField(
              controller: controller,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search requisition, applicant, item...',
                filled: true,
                fillColor: colors.fieldFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            );

            final statusField = DropdownButtonFormField<String>(
              value: statusFilter,
              isExpanded: true,
              icon: const Icon(Icons.filter_list),
              items: statuses.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: onStatusChanged,
              decoration: InputDecoration(
                labelText: 'Filter by Status',
                filled: true,
                fillColor: colors.fieldFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            );

            final clearBtn = FilledButton.tonalIcon(
              onPressed: onClear,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                foregroundColor: colors.primaryDark,
                backgroundColor: colors.primarySoft,
              ),
            );

            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  searchField,
                  const SizedBox(height: 12),
                  statusField,
                  const SizedBox(height: 12),
                  clearBtn,
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 3, child: searchField),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: statusField),
                const SizedBox(width: 12),
                clearBtn,
              ],
            );
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
    final action = _queueAction(queue, RequisitionWorkflowSettings.fromSettings(settings ?? const {}));
    final isDesktop = MediaQuery.sizeOf(context).width > 800;

    // Mobile View (Cards)
    if (!isDesktop) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _RequisitionMobileCard(
          row: rows[index],
          queue: queue,
          settings: settings,
          action: action,
        ),
      );
    }

    final colors = _QueueColors.of(context);

    // Desktop View (Data Table)
    return Card(
      color: colors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(colors.primarySoft),
          dataRowMaxHeight: 70,
          columns: const [
            DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('REQUISITION', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('APPLICANT', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('ITEMS', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('DEMAND', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('ACTION', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: List.generate(rows.length, (index) {
            final row = rows[index];
            return DataRow(cells: [
              DataCell(Text('${index + 1}')),
              DataCell(_RequisitionCell(row: row)),
              DataCell(_ApplicantCell(row: row)),
              DataCell(_ItemsCell(row: row)),
              DataCell(_DemandCell(row: row)),
              DataCell(Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusBadge(status: '${row['status'] ?? _queueStatus(queue)}'),
                  const SizedBox(height: 4),
                  Text(_queueAge(row).replaceAll('\n', ' '), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              )),
              DataCell(_ActionCell(row: row, queue: queue, settings: settings, action: action)),
            ]);
          }),
        ),
      ),
    );
  }
}

class _RequisitionMobileCard extends StatelessWidget {
  const _RequisitionMobileCard({required this.row, required this.queue, required this.settings, required this.action});

  final Map<String, dynamic> row;
  final String queue;
  final Map<String, dynamic>? settings;
  final _QueueAction action;

  @override
  Widget build(BuildContext context) {
    final colors = _QueueColors.of(context);

    return Card(
      color: colors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _RequisitionCell(row: row)),
                _StatusBadge(status: '${row['status'] ?? _queueStatus(queue)}'),
              ],
            ),
            Divider(height: 24, color: colors.border),
            Row(
              children: [
                Expanded(child: _ApplicantCell(row: row)),
                Container(width: 1, height: 40, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 12)),
                Expanded(child: _DemandCell(row: row, compact: true)),
              ],
            ),
            const SizedBox(height: 12),
            _ItemsCell(row: row),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: _ActionCell(row: row, queue: queue, settings: settings, action: action),
            ),
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
      Text('${row['requisition_no'] ?? 'REQ-${row['id'] ?? '-'}'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 4),
      Row(
        children: [
          const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
          const SizedBox(width: 4),
          Text(_queueDate(row), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700)),
        ],
      )
    ]);
  }
}

class _ApplicantCell extends StatelessWidget {
  const _ApplicantCell({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(_queueApplicant(row), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      const SizedBox(height: 2),
      Text('PF: ${row['pf_no'] ?? row['pf'] ?? '-'} • ${_queueDepartment(row)}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ]);
  }
}

class _ItemsCell extends StatelessWidget {
  const _ItemsCell({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final items = _queueRows(row['items'] ?? row['requisition_items']);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(
            _queueItemSummary(row),
            style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text('${items.isEmpty ? 1 : items.length} item(s)', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _DemandCell extends StatelessWidget {
  const _DemandCell({required this.row, this.compact = false});
  final Map<String, dynamic> row;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final demandedQuantity = _queueDemand(row);
    final actionQuantity = _queueSupplyQuantity(row);
    final hasEditedQuantity = actionQuantity > 0 && actionQuantity != demandedQuantity;

    return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Text(
              '$actionQuantity',
              style: TextStyle(fontSize: compact ? 16 : 18, fontWeight: FontWeight.bold, color: Colors.green.shade700)
          ),
          Text(hasEditedQuantity ? 'Demanded: $demandedQuantity ${_queueUnit(row)}' : _queueUnit(row), style: Theme.of(context).textTheme.bodySmall),
        ]
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
          _titleCase(status),
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)
      ),
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
      icon: const Icon(Icons.print_outlined, size: 18),
      label: const Text('Print'),
      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
    )
        : FilledButton.icon(
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => _DetermineQuantityDialog(row: row, queue: queue, settings: settings, action: action),
      ),
      icon: const Icon(Icons.visibility_outlined, size: 18),
      label: const Text('Action'),
      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
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
    final parsed = _queueRows(
      widget.row['items'] ?? widget.row['requisition_items'] ?? widget.row['details'] ?? widget.row['products'],
    );
    _items = parsed.isEmpty ? [widget.row] : parsed;
    _quantityControllers = _items.map((item) => TextEditingController(text: '${_queueSupplyQuantity(item)}')).toList();
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
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: isMobile ? double.infinity : 700,
        constraints: const BoxConstraints(maxHeight: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Action: ${widget.row['requisition_no'] ?? 'REQ-${widget.row['id'] ?? '-'}'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('${_queueApplicant(widget.row)} • ${_queueDepartment(widget.row)}', style: TextStyle(color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(backgroundColor: Colors.grey.shade200),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Body
            Flexible(
              child: ListView(
                padding: const EdgeInsets.all(24),
                shrinkWrap: true,
                children: [
                  Text('Items Requested (${_items.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),

                  // Responsive Items List instead of DataTable for better Mobile UX
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          crossAxisAlignment: WrapCrossAlignment.end,
                          children: [
                            SizedBox(
                                width: isMobile ? double.infinity : 200,
                                child: _ItemNameWithUnit(item: item)
                            ),
                            SizedBox(
                              width: 100,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Stock', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text('${_queueCurrentStock(item)}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 100,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Demanded', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text('${_queueDemand(item)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 120,
                              child: TextField(
                                controller: _quantityControllers[index],
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Action Qty',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _remarksController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Note / Comment (Optional)',
                      hintText: 'e.g., Sufficient in stock...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Footer Action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.queue != 'initiator') ...[
                    FilledButton.icon(
                      onPressed: _submitting ? null : _sendBack,
                      icon: _submitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.keyboard_return_rounded),
                      label: const Text('Send Back'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const Spacer(),
                  ],
                  TextButton(
                      onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel')
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_circle_outline),
                    label: Text(_submitting ? 'Processing...' : widget.action.buttonLabel),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendBack() async {
    await _submitAction('return', buttonLabel: 'Send Back');
  }

  Future<void> _submit() async {
    await _submitAction(widget.action.action, buttonLabel: widget.action.buttonLabel);
  }

  Future<void> _submitAction(String action, {required String buttonLabel, bool includeQuantities = true}) async {
    final id = _queueInt(widget.row['id']);
    if (id == 0) return;
    setState(() => _submitting = true);
    final quantities = <Map<String, dynamic>>[];
    for (var index = 0; index < _items.length; index++) {
      final item = _items[index];
      final supplyQuantity = _queueInt(_quantityControllers[index].text);
      if (supplyQuantity <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quantity must be greater than 0'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
          );
        }
        setState(() => _submitting = false);
        return;
      }
      final itemId = _queueItemId(item);
      quantities.add({
        if (itemId != null) 'id': itemId,
        if (item['requisition_item_id'] != null) 'requisition_item_id': item['requisition_item_id'],
        if (item['pivot_id'] != null) 'pivot_id': item['pivot_id'],
        if (item['requisition_detail_id'] != null) 'requisition_detail_id': item['requisition_detail_id'],
        if (item['detail_id'] != null) 'detail_id': item['detail_id'],
        'product_id': _queueProductId(item),
        'original_demanded_qty': _queueDemand(item),
        'requested_quantity': supplyQuantity,
        'request_quantity': supplyQuantity,
        'requested_qty': supplyQuantity,
        'request_qty': supplyQuantity,
        'demanded_quantity': supplyQuantity,
        'demand_quantity': supplyQuantity,
        'demanded_qty': supplyQuantity,
        'demand_qty': supplyQuantity,
        'required_quantity': supplyQuantity,
        'required_qty': supplyQuantity,
        'requisition_quantity': supplyQuantity,
        'quantity_requested': supplyQuantity,
        'quantity': supplyQuantity,
        'qty': supplyQuantity,
        'supplied_qty': supplyQuantity,
        'approved_qty': supplyQuantity,
        'approved_quantity': supplyQuantity,
        'determined_qty': supplyQuantity,
        'determined_quantity': supplyQuantity,
        'supply_qty': supplyQuantity,
        'supply_quantity': supplyQuantity,
      });
    }

    try {
      if (includeQuantities && quantities.isNotEmpty) {
        await _persistRequisitionQuantities(ref, id: id, quantities: quantities);
      }
      await _sendRequisitionAction(
        ref,
        id: id,
        action: action,
        nextRole: widget.action.nextRole,
        currentRole: widget.action.currentRole ?? widget.queue,
        nextStatus: widget.action.nextStatus,
        remarks: _remarksController.text.trim(),
        quantities: includeQuantities ? quantities : const <Map<String, dynamic>>[],
      );
      ref.invalidate(requisitionQueueProvider(widget.queue));
      ref.invalidate(myRequisitionsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$buttonLabel successful'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
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
      Text(_queueProductName(item), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 2),
      Text('Unit: ${_queueUnit(item)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
    ]);
  }
}

class _QueueAction {
  const _QueueAction({
    required this.action,
    required this.buttonLabel,
    required this.nextLabel,
    required this.nextStatus,
    this.nextRole,
    this.currentRole,
  });

  final String action;
  final String buttonLabel;
  final String nextLabel;
  final String nextStatus;
  final String? nextRole;
  final String? currentRole;
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
    return Card(
        color: Colors.red.shade50,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.red.shade200)),
        child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade400, size: 48),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700)),
              ],
            )
        )
    );
  }
}

String _queueStatus(String queue) {
  if (queue == 'assistant_director') return 'initiator_checked';
  if (queue == 'deputy_director') return 'ad_approved';
  if (queue == 'director') return 'dd_approved';
  return 'pending';
}

List<String> _queueStatuses(String queue) {
  if (queue == 'initiator') {
    return const [
      'pending',
      'returned',
      'director_approved',
      'ready',
      'ready_for_print',
      'ready_for_distribute',
      'distributed',
    ];
  }
  return [_queueStatus(queue)];
}

String _queueRowKey(Map<String, dynamic> row) {
  final id = row['id'] ?? row['requisition_id'];
  if (id != null) return 'id:$id';
  return 'req:${row['requisition_no'] ?? row.hashCode}';
}

_QueueAction _queueAction(String queue, RequisitionWorkflowSettings settings) {
  final approvalFlowRoles = settings.approvalFlowRoles;
  if (queue == 'initiator') {
    final nextRole = approvalFlowRoles.isEmpty ? 'director' : approvalFlowRoles.first;
    return _QueueAction(
      action: 'forward',
      buttonLabel: 'Forward',
      nextLabel: _queueRoleLabel(nextRole),
      nextRole: nextRole,
      nextStatus: _waitingStatusForRole(nextRole),
      currentRole: 'initiator',
    );
  }

  final nextRole = _nextApprovalRole(queue, approvalFlowRoles);
  final nextStatus = _approvalStatusForRole(queue);
  if (nextRole == null || queue == 'director') {
    return const _QueueAction(
      action: 'approve',
      buttonLabel: 'Final Approve',
      nextLabel: 'Distribution',
      nextStatus: 'director_approved',
    );
  }

  return _QueueAction(
    action: 'approve',
    buttonLabel: 'Approve & Forward',
    nextLabel: _queueRoleLabel(nextRole),
    nextRole: nextRole,
    nextStatus: nextStatus,
    currentRole: queue,
  );
}

String? _nextApprovalRole(String currentRole, List<String> approvalFlowRoles) {
  final currentIndex = approvalFlowRoles.indexOf(currentRole);
  if (currentIndex == -1 || currentIndex + 1 >= approvalFlowRoles.length) return null;
  return approvalFlowRoles[currentIndex + 1];
}

String _waitingStatusForRole(String role) {
  if (role == 'assistant_director') return 'initiator_checked';
  if (role == 'deputy_director') return 'ad_approved';
  if (role == 'director') return 'dd_approved';
  return 'pending';
}

String _approvalStatusForRole(String role) {
  if (role == 'assistant_director') return 'ad_approved';
  if (role == 'deputy_director') return 'dd_approved';
  if (role == 'director') return 'director_approved';
  return '${role}_approved';
}

String _queueRoleLabel(String role) {
  if (role == 'assistant_director') return 'Assistant Director';
  if (role == 'deputy_director') return 'Deputy Director';
  if (role == 'director') return 'Director';
  return role.replaceAll('_', ' ');
}


Future<void> _persistRequisitionQuantities(
  WidgetRef ref, {
  required int id,
  required List<Map<String, dynamic>> quantities,
}) async {
  final dio = ref.read(apiClientProvider).dio;
  final payload = _quantityUpdatePayload(quantities);
  final attempts = <_HttpAttempt>[
    _HttpAttempt('PATCH', '${ApiRoutes.requisitions}/$id/items'),
    _HttpAttempt('PUT', '${ApiRoutes.requisitions}/$id/items'),
    _HttpAttempt('PATCH', '${ApiRoutes.requisitions}/$id/quantities'),
    _HttpAttempt('PUT', '${ApiRoutes.requisitions}/$id/quantities'),
    _HttpAttempt('PATCH', '${ApiRoutes.requisitionWorkflow}/$id/quantities'),
    _HttpAttempt('PUT', '${ApiRoutes.requisitionWorkflow}/$id/quantities'),
    _HttpAttempt('PATCH', '${ApiRoutes.workflowRequisitions}/$id/quantities'),
    _HttpAttempt('PUT', '${ApiRoutes.workflowRequisitions}/$id/quantities'),
    _HttpAttempt('PATCH', '${ApiRoutes.requisitions}/$id'),
    _HttpAttempt('PUT', '${ApiRoutes.requisitions}/$id'),
  ];

  for (final attempt in attempts) {
    try {
      if (attempt.method == 'PUT') {
        await dio.put(attempt.path, data: payload);
      } else {
        await dio.patch(attempt.path, data: payload);
      }
      return;
    } on DioException catch (error) {
      if (_shouldTryNextRoute(error) || _shouldTryNextStatus(error)) continue;
      rethrow;
    }
  }
}

Map<String, dynamic> _quantityUpdatePayload(List<Map<String, dynamic>> quantities) {
  final byItemId = _suppliedQuantitiesByItemId(quantities);
  return {
    'items': quantities,
    'quantities': quantities,
    'requisition_items': quantities,
    'details': quantities,
    'products': quantities,
    'supplied_quantities': byItemId,
    'approved_quantities': byItemId,
    'determined_quantities': byItemId,
    'supply_quantities': byItemId,
    'requested_quantities': byItemId,
    'demanded_quantities': byItemId,
    if (quantities.length == 1) ...{
      'quantity': _quantityFromPayloadItem(quantities.first),
      'qty': _quantityFromPayloadItem(quantities.first),
      'supplied_quantity': _quantityFromPayloadItem(quantities.first),
      'approved_quantity': _quantityFromPayloadItem(quantities.first),
      'determined_quantity': _quantityFromPayloadItem(quantities.first),
      'supply_quantity': _quantityFromPayloadItem(quantities.first),
      'requested_quantity': _quantityFromPayloadItem(quantities.first),
      'demanded_quantity': _quantityFromPayloadItem(quantities.first),
    },
  };
}

Future<void> _sendRequisitionAction(
    WidgetRef ref, {
      required int id,
      required String action,
      required String nextStatus,
      String? nextRole,
      String? currentRole,
      String? remarks,
      List<Map<String, dynamic>> quantities = const <Map<String, dynamic>>[],
    }) async {
  final dio = ref.read(apiClientProvider).dio;
  final payload = {
    'action': action,
    'decision': action,
    'status': nextStatus,
    'next_status': nextStatus,
    if (currentRole != null) ...{
      'role': currentRole,
      'current_role': currentRole,
      'approver_role': currentRole,
    },
    if (nextRole != null) ...{
      'next_role': nextRole,
      'next_approver_role': nextRole,
    },
    if (remarks != null && remarks.isNotEmpty) ...{
      'remarks': remarks,
      'comment': remarks,
      'note': remarks,
    },
    if (quantities.isNotEmpty) ...{
      'supplied_quantities': _suppliedQuantitiesByItemId(quantities),
      'approved_quantities': _suppliedQuantitiesByItemId(quantities),
      'determined_quantities': _suppliedQuantitiesByItemId(quantities),
      'supply_quantities': _suppliedQuantitiesByItemId(quantities),
      if (quantities.length == 1) ...{
        'supplied_quantity': _quantityFromPayloadItem(quantities.first),
        'approved_quantity': _quantityFromPayloadItem(quantities.first),
        'determined_quantity': _quantityFromPayloadItem(quantities.first),
        'supply_quantity': _quantityFromPayloadItem(quantities.first),
      },
      'items': quantities,
      'quantities': quantities,
      'requisition_items': quantities,
      'approved_items': quantities,
      'supply_items': quantities,
    },
  };

  final attempts = <_HttpAttempt>[
    _HttpAttempt('POST', '${ApiRoutes.workflowRequisitions}/$id/$action'),
    _HttpAttempt('POST', '${ApiRoutes.requisitionWorkflow}/$id/$action'),
    _HttpAttempt('POST', '${ApiRoutes.requisitionWorkflow}/requisitions/$id/$action'),
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

  throw UnsupportedError('Workflow action API পাওয়া যায়নি। অনুগ্রহ করে অ্যাপ আপডেট/রিফ্রেশ করে আবার চেষ্টা করুন।');
}

Map<String, int> _suppliedQuantitiesByItemId(List<Map<String, dynamic>> quantities) {
  final suppliedQuantities = <String, int>{};
  for (final item in quantities) {
    final quantity = _quantityFromPayloadItem(item);
    final ids = <Object?>{
      item['id'],
      item['requisition_item_id'],
      item['requisition_detail_id'],
      item['detail_id'],
      item['pivot_id'],
      item['product_id'],
      _queueItemId(item),
      _queueProductId(item),
    };
    for (final id in ids) {
      if (id != null && '$id'.trim().isNotEmpty && '$id' != '0') {
        suppliedQuantities['$id'] = quantity;
      }
    }
  }
  return suppliedQuantities;
}

int _quantityFromPayloadItem(Map<String, dynamic> item) {
  return _queueInt(
    item['supplied_qty'] ?? item['supply_qty'] ?? item['supply_quantity'] ?? item['quantity'] ?? item['approved_qty'],
  );
}

dynamic _queueItemId(Map<String, dynamic> item) {
  final requisitionItem = item['requisition_item'];
  final detail = item['detail'];
  final pivot = item['pivot'];
  return item['requisition_item_id'] ??
      item['requisition_detail_id'] ??
      item['detail_id'] ??
      item['pivot_id'] ??
      (requisitionItem is Map ? requisitionItem['id'] : null) ??
      (detail is Map ? detail['id'] : null) ??
      (pivot is Map ? pivot['id'] : null) ??
      item['id'];
}

bool _shouldTryNextRoute(DioException error) {
  final statusCode = error.response?.statusCode;
  return statusCode == 404 || statusCode == 405;
}

bool _shouldTryNextStatus(DioException error) {
  final statusCode = error.response?.statusCode;
  return statusCode == 400 || statusCode == 422;
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
    if (error.response?.statusCode == 422) return 'Forward করার তথ্য সঠিক নয়। Remarks/approval data যাচাই করুন।';
    if (error.response?.statusCode == 404) return 'Workflow action API পাওয়া যায়নি। অ্যাপটি রিফ্রেশ করে আবার চেষ্টা করুন।';
  }
  return 'Requisition action সম্পন্ন করা যায়নি। আবার চেষ্টা করুন।';
}

Map<String, dynamic> _queueQueryParameters(String path, String queue, String status) {
  if (path == ApiRoutes.workflowInitiatorQueue) {
    return {'status': status, 'per_page': 100};
  }
  if (path == ApiRoutes.workflowApprovalQueue) {
    return {'per_page': 100};
  }
  return {'queue': queue, 'status': status, 'per_page': 100};
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
  if (diff.inMinutes < 60) return '${diff.inMinutes} mins\nago';
  if (diff.inHours < 24) return '${diff.inHours} hrs\nago';
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
  return _queueFirstPositiveInt([
    row['demanded_quantity'],
    row['demand_quantity'],
    row['requested_quantity'],
    row['request_quantity'],
    row['requisition_quantity'],
    row['required_quantity'],
    row['quantity_requested'],
    row['requested_qty'],
    row['request_qty'],
    row['demanded_qty'],
    row['demand_qty'],
    row['required_qty'],
    row['quantity'],
    row['qty'],
  ]);
}

int _queueSupplyQuantity(Map<String, dynamic> row) {
  final savedSupply = _queueFirstPositiveInt([
    row['supplied_quantity'],
    row['supplied_qty'],
    row['supply_quantity'],
    row['supply_qty'],
    row['approved_quantity'],
    row['approved_qty'],
    row['determined_quantity'],
    row['determined_qty'],
  ]);
  return savedSupply > 0 ? savedSupply : _queueDemand(row);
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

int _queueFirstPositiveInt(List<dynamic> values) {
  for (final value in values) {
    final parsed = _queueInt(value);
    if (parsed > 0) return parsed;
  }
  return 0;
}

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