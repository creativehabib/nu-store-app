import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_routes.dart';
import '../domain/dashboard_stats.dart';

class DashboardRepository {
  DashboardRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<DashboardStats> fetchStats() async {
    Response<dynamic>? dashboardResponse;
    try {
      dashboardResponse = await _apiClient.dio.get(ApiRoutes.dashboard, queryParameters: {'trend_filter': '30'});
    } on DioException {
      dashboardResponse = null;
    }

    final responses = await Future.wait<Response<dynamic>>([
      _apiClient.dio.get(ApiRoutes.inventory),
      _apiClient.dio.get(ApiRoutes.requisitions),
      _apiClient.dio.get(ApiRoutes.stockEntries),
    ]);

    final inventory = _listFromResponse(responses[0].data);
    final requisitions = _listFromResponse(responses[1].data);
    final stockEntries = _listFromResponse(responses[2].data);

    final pendingRequisitions = requisitions.where(_isPending).length;
    final approvalQueue = requisitions.where(_isWaitingForApproval).length;
    final lowStockItems = inventory.where(_isLowStock).length;

    final dashboardData = _mapFromResponse(dashboardResponse?.data);
    final roleStats = DashboardStats.fromJson(dashboardData).roleStats;
    final recentRequisitions = DashboardStats.fromJson(dashboardData).recentRequisitions;

    return DashboardStats(
      currentStock: stockEntries.isNotEmpty ? stockEntries.length : inventory.length,
      pendingRequisitions: roleStats['pending_action'] ?? pendingRequisitions,
      approvalQueue: approvalQueue,
      lowStockItems: roleStats['stock_out_products'] ?? lowStockItems,
      roleStats: roleStats,
      recentRequisitions: recentRequisitions.isNotEmpty ? recentRequisitions : requisitions.take(5).toList(),
    );
  }

  Map<String, dynamic> _mapFromResponse(dynamic data) {
    if (data is Map) {
      final payload = data['data'];
      if (payload is Map) return Map<String, dynamic>.from(payload);
      return Map<String, dynamic>.from(data);
    }
    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _listFromResponse(dynamic data) {
    if (data is List) {
      return data.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    }
    if (data is Map) {
      final payload = data['data'] ?? data['items'] ?? data['results'];
      if (payload is List) {
        return payload.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
      }
    }
    return const [];
  }

  bool _isPending(Map<String, dynamic> requisition) {
    final status = '${requisition['status'] ?? ''}'.toLowerCase();
    return status == 'pending' || status == 'initiated' || status == 'submitted';
  }

  bool _isWaitingForApproval(Map<String, dynamic> requisition) {
    final status = '${requisition['status'] ?? ''}'.toLowerCase();
    return status.contains('approval') ||
        status.contains('director') ||
        status == 'pending';
  }

  bool _isLowStock(Map<String, dynamic> item) {
    final quantity = _numberFrom(item['quantity'] ?? item['stock'] ?? item['current_stock']);
    final reorderLevel = _numberFrom(
      item['reorder_level'] ?? item['minimum_stock'] ?? item['low_stock_threshold'],
    );
    if (quantity == null || reorderLevel == null) return false;
    return quantity <= reorderLevel;
  }

  num? _numberFrom(dynamic value) {
    if (value is num) return value;
    return num.tryParse('$value');
  }
}
