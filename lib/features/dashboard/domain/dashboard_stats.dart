class DashboardStats {
  const DashboardStats({
    required this.currentStock,
    required this.pendingRequisitions,
    required this.approvalQueue,
    required this.lowStockItems,
    this.roleStats = const <String, int>{},
    this.recentRequisitions = const <Map<String, dynamic>>[],
  });

  final int currentStock;
  final int pendingRequisitions;
  final int approvalQueue;
  final int lowStockItems;
  final Map<String, int> roleStats;
  final List<Map<String, dynamic>> recentRequisitions;

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      currentStock: (json['current_stock'] as num?)?.toInt() ?? 0,
      pendingRequisitions: (json['pending_requisitions'] as num?)?.toInt() ?? 0,
      approvalQueue: (json['approval_queue'] as num?)?.toInt() ?? 0,
      lowStockItems: (json['low_stock_items'] as num?)?.toInt() ?? 0,
      roleStats: _intMapFrom(json['stats']),
      recentRequisitions: _listFrom(json['recent_requisitions']),
    );
  }

  static Map<String, int> _intMapFrom(dynamic value) {
    if (value is! Map) return const <String, int>{};
    return value.map((key, item) => MapEntry('$key', _intFrom(item)));
  }

  static int _intFrom(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static List<Map<String, dynamic>> _listFrom(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }
}
