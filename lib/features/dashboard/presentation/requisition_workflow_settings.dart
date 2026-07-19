import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_routes.dart';
import '../../../shared/providers/core_providers.dart';

final appSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final response = await ref.watch(apiClientProvider).dio.get(ApiRoutes.settings);
  final data = response.data is Map ? Map<String, dynamic>.from(response.data as Map) : <String, dynamic>{};
  final payload = data['data'];
  return payload is Map ? Map<String, dynamic>.from(payload) : data;
});

class RequisitionWorkflowSettings {
  const RequisitionWorkflowSettings({
    required this.storeMode,
    required this.centralStoreDepartmentId,
    required this.approvalFlowRoles,
    required this.showPrintFooter,
  });

  final String storeMode;
  final int centralStoreDepartmentId;
  final List<String> approvalFlowRoles;
  final bool showPrintFooter;

  bool get isCentralized => storeMode == 'centralized';

  static RequisitionWorkflowSettings fromSettings(Map<String, dynamic> settings) {
    final requisition = settings['requisition'] is Map ? Map<String, dynamic>.from(settings['requisition'] as Map) : <String, dynamic>{};
    final roles = requisition['approval_flow_roles'];
    return RequisitionWorkflowSettings(
      storeMode: '${requisition['store_mode'] ?? 'departmental'}'.toLowerCase(),
      centralStoreDepartmentId: _intFrom(requisition['central_store_dept_id']),
      approvalFlowRoles: roles is List ? roles.map((role) => '$role').toList() : const ['assistant_director', 'deputy_director', 'director'],
      showPrintFooter: _boolFrom(requisition['show_print_footer'], fallback: true),
    );
  }
}

int _intFrom(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

bool _boolFrom(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (['1', 'true', 'yes', 'on', 'enabled'].contains(normalized)) return true;
    if (['0', 'false', 'no', 'off', 'disabled'].contains(normalized)) return false;
  }
  return fallback;
}
