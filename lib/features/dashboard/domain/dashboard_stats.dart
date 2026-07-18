class DashboardStats {
  const DashboardStats({
    required this.currentStock,
    required this.pendingRequisitions,
    required this.approvalQueue,
    required this.lowStockItems,
  });

  final int currentStock;
  final int pendingRequisitions;
  final int approvalQueue;
  final int lowStockItems;

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      currentStock: (json['current_stock'] as num?)?.toInt() ?? 0,
      pendingRequisitions: (json['pending_requisitions'] as num?)?.toInt() ?? 0,
      approvalQueue: (json['approval_queue'] as num?)?.toInt() ?? 0,
      lowStockItems: (json['low_stock_items'] as num?)?.toInt() ?? 0,
    );
  }
}
