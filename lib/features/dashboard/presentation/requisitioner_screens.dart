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
  final user = ref.watch(authControllerProvider).user;
  final response = await ref.watch(apiClientProvider).dio.get(
    ApiRoutes.requisitions,
    queryParameters: {
      'mine': 1,
      'my_requisitions': 1,
      'user_id': _currentUserId(user),
      'per_page': 50,
    },
  );
  final rows = _rows(response.data);
  final userId = _currentUserId(user);
  if (userId == null) return rows;

  if (!rows.any(_hasOwnerMetadata)) return rows;
  return rows.where((row) => _isOwnedBy(row, userId)).toList();
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

// -----------------------------------------------------------------------------
// SCREENS
// -----------------------------------------------------------------------------

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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          Text(
            'Requisitioner Dashboard',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          settings.when(
            data: (value) => _WorkflowInfoCard(
                settings: RequisitionWorkflowSettings.fromSettings(value)),
            loading: () => const LinearProgressIndicator(borderRadius: BorderRadius.all(Radius.circular(8))),
            error: (_, _) => const _ErrorCard(
                message: 'Settings load failed. Default departmental workflow will be used.'),
          ),
          const SizedBox(height: 24),
          stats.when(
            data: (value) => _StatsGrid(stats: value),
            loading: () => const Center(
                child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator())),
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
      appBar: AppBar(
        title: const Text('Submit Demand', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          settings.when(
            data: (value) => _WorkflowInfoCard(
                settings: RequisitionWorkflowSettings.fromSettings(value),
                requesterDepartmentId: _userDepartmentId(user)),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const _ErrorCard(
                message: 'Could not load workflow settings. You can still submit.'),
          ),
          const SizedBox(height: 20),

          for (var i = 0; i < _lines.length; i++)
            _DemandLineForm(
              index: i,
              line: _lines[i],
              categories: _asyncRows(categories),
              products: _asyncRows(products),
              purposes: _asyncRows(purposes),
              onRemove: _lines.length == 1 ? null : () => setState(() => _lines.removeAt(i)),
            ),

          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () => setState(() => _lines.add(_DemandLine())),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Add Another Item', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
            ],
          ),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send),
            label: Text(
                _submitting ? 'Submitting...' : 'Submit Demand',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final items = _lines.where((line) => line.productId != null).map((line) => {
      'product_id': line.productId,
      'demanded_qty': line.qty,
      'purpose': line.purpose,
    }).toList();

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one item to submit.'))
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(apiClientProvider).dio.post(ApiRoutes.requisitions, data: {'items': items});
      ref.invalidate(myRequisitionsProvider);
      ref.invalidate(requisitionerDashboardProvider);
      if (mounted) Navigator.pop(context);
    } catch(e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submission failed: $e')));
      }
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
      appBar: AppBar(
        title: const Text('My Requisitions', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        elevation: 0,
      ),
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
      return (_query.isEmpty || haystack.contains(_query.toLowerCase())) &&
          (_status == 'all' || status == _status);
    }).toList();

    final stats = _statsFromRows(items);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _MyRequisitionsHeader(total: items.length),
              const SizedBox(height: 20),
              _StatsGrid(stats: stats),
              const SizedBox(height: 24),
              _ModernFilterSection(
                currentStatus: _status,
                onQueryChanged: (value) => setState(() => _query = value),
                onStatusChanged: (value) => setState(() => _status = value),
              ),
              const SizedBox(height: 16),
            ]),
          ),
        ),
        if (filtered.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyRequisitionCard(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) => _RequisitionTile(row: filtered[index]),
                childCount: filtered.length,
              ),
            ),
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// UI COMPONENTS
// -----------------------------------------------------------------------------

class _ModernFilterSection extends StatelessWidget {
  const _ModernFilterSection({
    required this.currentStatus,
    required this.onQueryChanged,
    required this.onStatusChanged,
  });

  final String currentStatus;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final statuses = [
      {'val': 'all', 'label': 'All'},
      {'val': 'pending', 'label': 'Pending'},
      {'val': 'distributed', 'label': 'Distributed'},
      {'val': 'returned', 'label': 'Returned'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Search by req no or item...',
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: onQueryChanged,
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: statuses.map((s) {
              final isSelected = currentStatus == s['val'];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(s['label']!),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) onStatusChanged(s['val']!);
                  },
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  showCheckmark: false,
                  selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _RequisitionTile extends StatelessWidget {
  const _RequisitionTile({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final status = '${row['status'] ?? 'pending'}';
    final color = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: color.withOpacity(0.15), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openDetails(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.receipt_long_rounded, color: color, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${row['requisition_no'] ?? 'REQ-${row['id'] ?? '-'}'}',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _itemSummary(row),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey[700], height: 1.3),
                            ),
                          ]
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                          status.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          )
                      ),
                    ),
                  ]),
              const SizedBox(height: 16),
              const Divider(height: 1, thickness: 1),
              const SizedBox(height: 12),
              Row(children: [
                Icon(Icons.access_time_rounded, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(
                        _date(row['created_at']),
                        style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)
                    )
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[400]),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  void _openDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RequisitionDetailsScreen(
          id: _intFrom(row['id']),
          fallback: row,
        ),
      ),
    );
  }
}

class _DemandLine {
  int? categoryId;
  int? productId;
  int qty = 1;
  String? purpose;
}

class _DemandLineForm extends StatefulWidget {
  const _DemandLineForm({
    required this.index,
    required this.line,
    required this.categories,
    required this.products,
    required this.purposes,
    this.onRemove,
  });

  final int index;
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Item #${widget.index + 1}',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.onRemove != null)
                  InkWell(
                    onTap: widget.onRemove,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(Icons.close_rounded, color: Colors.red[400], size: 22),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 720;

                final categoryField = _idDropdown(
                  label: 'Category',
                  value: _containsId(categoryOptions, widget.line.categoryId) ? widget.line.categoryId : null,
                  rows: categoryOptions,
                  icon: Icons.category_outlined,
                  onChanged: (value) => setState(() {
                    widget.line.categoryId = value;
                    widget.line.productId = null;
                  }),
                );

                final productField = _idDropdown(
                  label: 'Select Product',
                  value: _containsId(productOptions, widget.line.productId) ? widget.line.productId : null,
                  rows: productOptions,
                  icon: Icons.inventory_2_outlined,
                  onChanged: (value) => setState(() => widget.line.productId = value),
                );

                final qtyField = SizedBox(
                  width: isNarrow ? double.infinity : 110,
                  child: TextFormField(
                    initialValue: '${widget.line.qty}',
                    decoration: InputDecoration(
                      labelText: 'Qty',
                      prefixIcon: const Icon(Icons.format_list_numbered, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => widget.line.qty = int.tryParse(value) ?? 1,
                  ),
                );

                final purposeField = purposeOptions.isEmpty
                    ? TextFormField(
                  initialValue: widget.line.purpose,
                  decoration: InputDecoration(
                    labelText: 'Purpose',
                    prefixIcon: const Icon(Icons.help_outline, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (value) => widget.line.purpose = value,
                )
                    : DropdownButtonFormField<String>(
                  value: purposeOptions.contains(widget.line.purpose) ? widget.line.purpose : null,
                  decoration: InputDecoration(
                    labelText: 'Purpose',
                    prefixIcon: const Icon(Icons.help_outline, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  isExpanded: true,
                  items: purposeOptions.map((p) =>
                      DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis))
                  ).toList(),
                  onChanged: (value) => setState(() => widget.line.purpose = value),
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      categoryField,
                      const SizedBox(height: 12),
                      productField,
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(flex: 3, child: qtyField),
                          const SizedBox(width: 12),
                          Expanded(flex: 7, child: purposeField),
                        ],
                      )
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: categoryField),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: productField),
                    const SizedBox(width: 12),
                    qtyField,
                    const SizedBox(width: 12),
                    Expanded(child: purposeField),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _idDropdown({
    required String label,
    required int? value,
    required List<Map<String, dynamic>> rows,
    required IconData icon,
    required ValueChanged<int?> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      isExpanded: true,
      items: rows.map((row) => DropdownMenuItem(
          value: _intFrom(row['id']),
          child: Text(_rowLabel(row), overflow: TextOverflow.ellipsis)
      )).toList(),
      onChanged: rows.isEmpty ? null : onChanged,
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
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final Map<String, int> stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width > 900 ? 4 : 2;
        final isCompact = width < 420;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isCompact ? 1.3 : 1.5,
          children: [
            _StatCard(
              title: 'Total Requests',
              value: stats['total'] ?? 0,
              gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
              icon: Icons.description_rounded,
            ),
            _StatCard(
              title: 'Processing',
              value: stats['processing'] ?? 0,
              gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
              icon: Icons.pending_actions_rounded,
            ),
            _StatCard(
              title: 'Completed',
              value: stats['completed'] ?? 0,
              gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
              icon: Icons.check_circle_rounded,
            ),
            _StatCard(
              title: 'Returned',
              value: stats['returned'] ?? 0,
              gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
              icon: Icons.keyboard_return_rounded,
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.gradient,
    required this.icon
  });

  final String title;
  final int value;
  final LinearGradient gradient;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.last.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ]
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ],
          ),
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _MyRequisitionsHeader extends StatelessWidget {
  const _MyRequisitionsHeader({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 380;
    return Container(
      padding: EdgeInsets.all(isNarrow ? 16 : 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(colors: [Color(0xFF1D4ED8), Color(0xFF14B8A6)]),
      ),
      child: Row(children: [
        if (!isNarrow) ...[
          const CircleAvatar(
            backgroundColor: Colors.white24,
            child: Icon(Icons.timeline, color: Colors.white),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'My Requisitions',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Only requisitions submitted by you are shown here.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white70),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        Chip(label: Text('$total Total')),
      ]),
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
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(
              settings.isCentralized ? Icons.hub_outlined : Icons.account_tree_outlined,
              color: settings.isCentralized ? Colors.deepPurple : Colors.teal,
            ),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          Text(message),
          const SizedBox(height: 8),
          Text('Approval flow: ${_approvalRoleLabels(settings.approvalFlowRoles).join(' → ')}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

class _EmptyRequisitionCard extends StatelessWidget {
  const _EmptyRequisitionCard();

  @override
  Widget build(BuildContext context) => const Card(
    elevation: 0,
    child: Padding(
      padding: EdgeInsets.all(28),
      child: Column(children: [
        Icon(Icons.inbox_outlined, size: 48, color: Colors.black38),
        SizedBox(height: 12),
        Text('No requisitions found for this filter.'),
      ]),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
      elevation: 0,
      color: Colors.red.withOpacity(0.1),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(message, style: const TextStyle(color: Colors.red))
      )
  );
}

// -----------------------------------------------------------------------------
// HELPER FUNCTIONS
// -----------------------------------------------------------------------------

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

int? _currentUserId(Map<String, dynamic>? user) {
  if (user == null) return null;
  final parsed = _intFrom(user['id'] ?? user['user_id']);
  return parsed == 0 ? null : parsed;
}

bool _isOwnedBy(Map<String, dynamic> row, int userId) {
  final ownerIds = _ownerIds(row);
  return ownerIds.isEmpty || ownerIds.contains(userId);
}

bool _hasOwnerMetadata(Map<String, dynamic> row) => _ownerIds(row).isNotEmpty;

List<int> _ownerIds(Map<String, dynamic> row) {
  final requester = row['user'] ?? row['requester'] ?? row['created_by_user'];
  return <int>[
    _intFrom(row['user_id']),
    _intFrom(row['requester_id']),
    _intFrom(row['created_by']),
    if (requester is Map) _intFrom(requester['id'] ?? requester['user_id']),
  ]..removeWhere((id) => id == 0);
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'distributed':
    case 'completed':
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

List<String> _approvalRoleLabels(List<String> roles) {
  final labels = <String>[];
  for (final role in roles) {
    final label = _roleLabel(role);
    if (!labels.contains(label)) labels.add(label);
  }
  if (!labels.contains('Director')) labels.add('Director');
  return labels;
}

List<Map<String, dynamic>> _rows(dynamic data) {
  final payload = data is Map ? (data['data'] ?? data['items'] ?? data['results'] ?? data) : data;
  if (payload is List) return payload.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
  if (payload is Map) {
    final nested = payload['data'] ?? payload['items'] ?? payload['results'] ?? payload['categories'] ?? payload['products'] ?? payload['purposes'] ?? payload['requisitions'];
    if (nested is List) return nested.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
    return payload.entries.where((entry) => entry.value is List).expand((entry) => (entry.value as List).whereType<Map>()).map((e)=>Map<String,dynamic>.from(e)).toList();
  }
  return const [];
}

int _intFrom(dynamic v)=> v is num ? v.toInt() : int.tryParse('$v') ?? 0;

Map<String,int> _statsFromRows(List<Map<String,dynamic>> rows)=> {
  'total': rows.length,
  'processing': rows.where((r)=>_processingStatuses.contains('${r['status']}'.toLowerCase())).length,
  'completed': rows.where((r)=>'${r['status']}'.toLowerCase()=='distributed').length,
  'returned': rows.where((r)=>'${r['status']}'.toLowerCase()=='returned').length
};

String _date(dynamic value){
  final d=DateTime.tryParse('$value');
  return d==null ? '-' : DateFormat('dd MMM, yyyy hh:mm a').format(d.toLocal());
}

String _itemSummary(Map<String,dynamic> r){
  final items=_rows(r['items'] ?? r['requisition_items']);
  if(items.isEmpty) return _productName(r);
  return items.map(_productName).take(2).join(', ');
}

String _productName(Map<String,dynamic> r){
  final p=r['product'];
  if(p is Map) return '${p['name'] ?? p['name_en'] ?? p['title'] ?? 'Item'}';
  return '${r['product_name'] ?? r['item_name'] ?? r['name'] ?? 'Item'}';
}