import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_routes.dart';
import '../../../shared/providers/core_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import 'requisition_details_screen.dart';
import 'requisition_workflow_settings.dart';

// Primary brand color to keep consistency
const Color _primaryColor = Color(0xFF1E3A8A);

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

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        color: _primaryColor,
        backgroundColor: Colors.white,
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
                color: _primaryColor,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),
            settings.when(
              data: (value) => _WorkflowInfoCard(settings: RequisitionWorkflowSettings.fromSettings(value)),
              loading: () => const LinearProgressIndicator(
                  borderRadius: BorderRadius.all(Radius.circular(8)), color: _primaryColor),
              error: (_, _) => const _ErrorCard(message: 'Settings load failed. Default departmental workflow will be used.'),
            ),
            const SizedBox(height: 24),
            stats.when(
              data: (value) => _StatsGrid(stats: value),
              loading: () => const Center(
                  child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: _primaryColor))),
              error: (error, _) => _ErrorCard(message: 'Dashboard data load failed: $error'),
            ),
          ],
        ),
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Submit Demand',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: _primaryColor),
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
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  settings.when(
                    data: (value) => _WorkflowInfoCard(
                        settings: RequisitionWorkflowSettings.fromSettings(value),
                        requesterDepartmentId: _userDepartmentId(user)),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const _ErrorCard(message: 'Could not load workflow settings. You can still submit.'),
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
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primaryColor,
                        side: BorderSide(color: _primaryColor.withOpacity(0.5), width: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => setState(() => _lines.add(_DemandLine())),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('Add Another Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            // Bottom Action Area
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    disabledBackgroundColor: _primaryColor.withOpacity(0.6),
                  ),
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _submitting ? 'Submitting...' : 'Submit Demand',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final items = _lines.where((line) => line.productId != null).map((line) => {
      'product_id': line.productId,
      'demanded_qty': line.qty,
      'purpose': line.purpose,
    }).toList();

    if (items.isEmpty) {
      _showSnackBar('Please select at least one item to submit.', Colors.redAccent);
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(apiClientProvider).dio.post(ApiRoutes.requisitions, data: {'items': items});
      ref.invalidate(myRequisitionsProvider);
      ref.invalidate(requisitionerDashboardProvider);
      if (mounted) {
        _showSnackBar('Requisition submitted successfully!', Colors.green.shade600);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Submission failed: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'My Requisitions',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: _primaryColor),
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
      body: RefreshIndicator(
        color: _primaryColor,
        backgroundColor: Colors.white,
        onRefresh: () async {
          await ref.refresh(myRequisitionsProvider.future);
        },
        child: reqs.when(
          data: (items) => _buildList(context, items),
          loading: () => const Center(child: CircularProgressIndicator(color: _primaryColor)),
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
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _MyRequisitionsHeader(total: items.length),
              const SizedBox(height: 24),
              _StatsGrid(stats: stats),
              const SizedBox(height: 28),
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: Icon(Icons.search_rounded, color: _primaryColor.withOpacity(0.7)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _primaryColor, width: 2),
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
                padding: const EdgeInsets.only(right: 12.0),
                child: ChoiceChip(
                  label: Text(s['label']!),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) onStatusChanged(s['val']!);
                  },
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: isSelected ? _primaryColor : Colors.grey.shade300),
                  ),
                  showCheckmark: false,
                  selectedColor: _primaryColor,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: Colors.grey.shade200, width: 1),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _itemSummary(row),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade600, height: 1.3, fontSize: 13),
                        ),
                      ],
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
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _date(row['created_at']),
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
                ],
              ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Item #${widget.index + 1}',
                    style: const TextStyle(
                      color: _primaryColor,
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
                      child: Icon(Icons.cancel_rounded, color: Colors.red.shade400, size: 24),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    decoration: _modernInputDecoration(label: 'Qty', icon: Icons.format_list_numbered_rounded),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => widget.line.qty = int.tryParse(value) ?? 1,
                  ),
                );

                final purposeField = purposeOptions.isEmpty
                    ? TextFormField(
                  initialValue: widget.line.purpose,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  decoration: _modernInputDecoration(label: 'Purpose', icon: Icons.help_outline_rounded),
                  onChanged: (value) => widget.line.purpose = value,
                )
                    : DropdownButtonFormField<String>(
                  value: purposeOptions.contains(widget.line.purpose) ? widget.line.purpose : null,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
                  decoration: _modernInputDecoration(label: 'Purpose', icon: Icons.help_outline_rounded),
                  isExpanded: true,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade600),
                  items: purposeOptions
                      .map((p) => DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (value) => setState(() => widget.line.purpose = value),
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      categoryField,
                      const SizedBox(height: 16),
                      productField,
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: qtyField),
                          const SizedBox(width: 16),
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
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: productField),
                    const SizedBox(width: 16),
                    qtyField,
                    const SizedBox(width: 16),
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
      isExpanded: true,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade600),
      decoration: _modernInputDecoration(label: label, icon: icon),
      items: rows
          .map((row) => DropdownMenuItem(
        value: _intFrom(row['id']),
        child: Text(_rowLabel(row), overflow: TextOverflow.ellipsis),
      ))
          .toList(),
      onChanged: rows.isEmpty ? null : onChanged,
    );
  }

  InputDecoration _modernInputDecoration({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade600),
      prefixIcon: Icon(icon, color: _primaryColor.withOpacity(0.7), size: 22),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _primaryColor, width: 2),
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
              gradient: const LinearGradient(colors: [_primaryColor, Color(0xFF3B82F6)]),
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
    required this.icon,
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
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
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
                    fontSize: 14,
                    height: 1.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
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
              fontSize: 32,
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
      padding: EdgeInsets.all(isNarrow ? 20 : 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [_primaryColor, Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(children: [
        if (!isNarrow) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.timeline_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Requisitions',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Only requisitions submitted by you are shown here.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$total Total',
            style: const TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
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

    return Container(
      decoration: BoxDecoration(
        color: (settings.isCentralized ? Colors.deepPurple : Colors.teal).withOpacity(.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (settings.isCentralized ? Colors.deepPurple : Colors.teal).withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                settings.isCentralized ? Icons.hub_outlined : Icons.account_tree_outlined,
                color: settings.isCentralized ? Colors.deepPurple : Colors.teal,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: settings.isCentralized ? Colors.deepPurple.shade700 : Colors.teal.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Approval flow: ${_approvalRoleLabels(settings.approvalFlowRoles).join(' → ')}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRequisitionCard extends StatelessWidget {
  const _EmptyRequisitionCard();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(40),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text(
          'No requisitions found',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        Text(
          'Try adjusting your filters or search query.',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      ],
    ),
  );
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
        Expanded(
          child: Text(message, style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w500)),
        ),
      ],
    ),
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
  if (payload is List) return payload.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  if (payload is Map) {
    final nested = payload['data'] ?? payload['items'] ?? payload['results'] ?? payload['categories'] ?? payload['products'] ?? payload['purposes'] ?? payload['requisitions'];
    if (nested is List) return nested.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    return payload.entries.where((entry) => entry.value is List).expand((entry) => (entry.value as List).whereType<Map>()).map((e) => Map<String, dynamic>.from(e)).toList();
  }
  return const [];
}

int _intFrom(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

Map<String, int> _statsFromRows(List<Map<String, dynamic>> rows) => {
  'total': rows.length,
  'processing': rows.where((r) => _processingStatuses.contains('${r['status']}'.toLowerCase())).length,
  'completed': rows.where((r) => '${r['status']}'.toLowerCase() == 'distributed').length,
  'returned': rows.where((r) => '${r['status']}'.toLowerCase() == 'returned').length
};

String _date(dynamic value) {
  final d = DateTime.tryParse('$value');
  return d == null ? '-' : DateFormat('dd MMM, yyyy hh:mm a').format(d.toLocal());
}

String _itemSummary(Map<String, dynamic> r) {
  final items = _rows(r['items'] ?? r['requisition_items']);
  if (items.isEmpty) return _productName(r);
  return items.map(_productName).take(2).join(', ');
}

String _productName(Map<String, dynamic> r) {
  final p = r['product'];
  if (p is Map) return '${p['name'] ?? p['name_en'] ?? p['title'] ?? 'Item'}';
  return '${r['product_name'] ?? r['item_name'] ?? r['name'] ?? 'Item'}';
}