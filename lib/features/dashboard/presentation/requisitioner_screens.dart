import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_routes.dart';
import '../../../shared/providers/core_providers.dart';

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
  final response = await ref.watch(apiClientProvider).dio.get(ApiRoutes.requisitions);
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
    return RefreshIndicator(
      onRefresh: () => ref.refresh(requisitionerDashboardProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Requisitioner Dashboard', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Demand')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Submit New Demand', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const Divider(height: 28),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                for (var i = 0; i < _lines.length; i++)
                  _DemandLineForm(
                    line: _lines[i],
                    categories: categories.valueOrNull ?? const [],
                    products: products.valueOrNull ?? const [],
                    purposes: purposes.valueOrNull ?? const [],
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
        onRefresh: () => ref.refresh(myRequisitionsProvider.future),
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
    trailing: FilledButton.tonalIcon(icon: const Icon(Icons.history), label: const Text('View History'), onPressed: () => showDialog(context: context, builder: (_) => _HistoryDialog(row: row))),
  );
}

class _HistoryDialog extends StatelessWidget {
  const _HistoryDialog({required this.row});
  final Map<String, dynamic> row;
  @override
  Widget build(BuildContext context) {
    final history = _history(row);
    final items = _rows(row['items'] ?? row['requisition_items']);
    return AlertDialog(
      title: Text('Tracking Details: ${row['requisition_no'] ?? 'REQ-${row['id'] ?? '-'}'}'),
      content: SizedBox(width: 560, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Submitted on ${_date(row['created_at'])}'),
        const Divider(height: 28),
        const Text('Item Details & Approval:', style: TextStyle(fontWeight: FontWeight.bold)),
        DataTable(columns: const [DataColumn(label: Text('Item Name')), DataColumn(label: Text('You Requested')), DataColumn(label: Text('Approved Quantity'))], rows: [for (final item in items.isEmpty ? [row] : items) DataRow(cells: [DataCell(Text(_productName(item))), DataCell(Text('${item['demanded_qty'] ?? item['qty'] ?? '-'}')), DataCell(Text('${item['supplied_qty'] ?? item['approved_qty'] ?? 0}'))])]),
        const SizedBox(height: 16),
        const Text('Approval History (Timeline):', style: TextStyle(fontWeight: FontWeight.bold)),
        for (final h in history) ListTile(leading: const Icon(Icons.circle, color: Colors.green, size: 14), title: Text('${h['name'] ?? h['role'] ?? 'Approver'}'), subtitle: Text('${h['comment'] ?? h['remarks'] ?? ''}\n${_date(h['created_at'] ?? h['date'])}'), trailing: Chip(label: Text('${h['status'] ?? 'Approved / Forwarded'}'))),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }
}

class _StatsGrid extends StatelessWidget { const _StatsGrid({required this.stats}); final Map<String,int> stats; @override Widget build(BuildContext context) => GridView.count(crossAxisCount: MediaQuery.sizeOf(context).width > 900 ? 4 : 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 2.2, children: [_Card('Total Submitted Requests', stats['total'] ?? 0, Colors.blue, Icons.description_outlined), _Card('Processing (Pending)', stats['processing'] ?? 0, Colors.orange, Icons.schedule), _Card('Completed (Distributed)', stats['completed'] ?? 0, Colors.green, Icons.check_circle_outline), _Card('Returned', stats['returned'] ?? 0, Colors.red, Icons.reply)]); }
class _Card extends StatelessWidget { const _Card(this.title,this.value,this.color,this.icon); final String title; final int value; final Color color; final IconData icon; @override Widget build(BuildContext context)=>Card(color: color.withValues(alpha:.08), child: Padding(padding: const EdgeInsets.all(20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)), const Spacer(), Text('$value', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold))]), Icon(icon, color: color.withValues(alpha:.45), size: 34)]))); }
class _ErrorCard extends StatelessWidget { const _ErrorCard({required this.message}); final String message; @override Widget build(BuildContext context)=>Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(message, style: const TextStyle(color: Colors.red)))); }
class _DemandLine { int? categoryId; int? productId; int qty=1; String? purpose; }
class _DemandLineForm extends StatefulWidget { const _DemandLineForm({required this.line,required this.categories,required this.products,required this.purposes,this.onRemove}); final _DemandLine line; final List<Map<String,dynamic>> categories,products,purposes; final VoidCallback? onRemove; @override State<_DemandLineForm> createState()=>_DemandLineFormState(); }
class _DemandLineFormState extends State<_DemandLineForm>{ @override Widget build(BuildContext context)=>Padding(padding: const EdgeInsets.only(bottom:12), child: Row(children:[Expanded(child: _drop('Category', widget.line.categoryId, widget.categories, (v)=>setState(()=>widget.line.categoryId=v))), const SizedBox(width:12), Expanded(flex:2, child: _drop('Item Name', widget.line.productId, widget.products, (v)=>setState(()=>widget.line.productId=v))), const SizedBox(width:12), SizedBox(width:90, child: TextFormField(initialValue:'1', decoration: const InputDecoration(labelText:'Qty'), keyboardType: TextInputType.number, onChanged:(v)=>widget.line.qty=int.tryParse(v)??1)), const SizedBox(width:12), Expanded(child: _purpose()), if(widget.onRemove!=null) IconButton(onPressed: widget.onRemove, icon: const Icon(Icons.delete_outline))])); Widget _drop(String label,int? value,List<Map<String,dynamic>> rows,ValueChanged<int?> onChanged)=>DropdownButtonFormField<int>(value:value, decoration: InputDecoration(labelText:label), items:[for(final r in rows) DropdownMenuItem(value:_intFrom(r['id']), child: Text('${r['name'] ?? r['name_en'] ?? r['title'] ?? r['product_name']}', overflow: TextOverflow.ellipsis))], onChanged:onChanged); Widget _purpose()=>DropdownButtonFormField<String>(value:widget.line.purpose, decoration: const InputDecoration(labelText:'Purpose'), items:[for(final r in widget.purposes) DropdownMenuItem(value:'${r['purpose'] ?? r['name'] ?? r['title']}', child: Text('${r['purpose'] ?? r['name'] ?? r['title']}', overflow: TextOverflow.ellipsis))], onChanged:(v)=>setState(()=>widget.line.purpose=v)); }

List<Map<String, dynamic>> _rows(dynamic data) { final payload = data is Map ? (data['data'] ?? data['items'] ?? data['results'] ?? data) : data; if (payload is List) return payload.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList(); if (payload is Map) { final nested = payload['data'] ?? payload['items'] ?? payload['results']; if (nested is List) return nested.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList(); } return const []; }
int _intFrom(dynamic v)=> v is num ? v.toInt() : int.tryParse('$v') ?? 0;
Map<String,int> _statsFromRows(List<Map<String,dynamic>> rows)=> {'total': rows.length, 'processing': rows.where((r)=>_processingStatuses.contains('${r['status']}'.toLowerCase())).length, 'completed': rows.where((r)=>'${r['status']}'.toLowerCase()=='distributed').length, 'returned': rows.where((r)=>'${r['status']}'.toLowerCase()=='returned').length};
String _date(dynamic value){ final d=DateTime.tryParse('$value'); return d==null ? '-' : DateFormat('dd MMM, yyyy hh:mm a').format(d.toLocal()); }
String _itemSummary(Map<String,dynamic> r){ final items=_rows(r['items'] ?? r['requisition_items']); if(items.isEmpty) return _productName(r); return items.map(_productName).take(2).join(', '); }
String _productName(Map<String,dynamic> r){ final p=r['product']; if(p is Map) return '${p['name'] ?? p['name_en'] ?? p['title'] ?? 'Item'}'; return '${r['product_name'] ?? r['item_name'] ?? r['name'] ?? 'Item'}'; }
List<Map<String,dynamic>> _history(Map<String,dynamic> r){ final h=r['approval_history']; if(h is List) return h.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList(); return [{'role':'Submitted','status':r['status'] ?? 'Pending','created_at':r['created_at']}]; }
