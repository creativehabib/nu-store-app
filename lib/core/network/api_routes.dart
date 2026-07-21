class ApiRoutes {
  const ApiRoutes._();

  static const String register = '/api/v1/auth/register';
  static const String login = '/api/v1/auth/login';
  static const String me = '/api/v1/auth/me';
  static const String logout = '/api/v1/auth/logout';
  static const String inventory = '/api/v1/inventory';
  static const String dashboard = '/api/v1/dashboard';
  static const String products = '/api/v1/products';
  static const String categories = '/api/v1/categories';
  static const String departments = '/api/v1/departments';
  static const String designations = '/api/v1/designations';
  static const String purposes = '/api/v1/purposes';
  static const String requisitions = '/api/v1/requisitions';
  static const String requisitionWorkflow = '/api/v1/requisition-workflow';
  static const String workflowRequisitions = '/api/v1/workflow/requisitions';
  static const String workflowCounts = '/api/v1/workflow/counts';
  static const String workflowInitiatorQueue = '/api/v1/workflow/initiator-queue';
  static const String workflowApprovalQueue = '/api/v1/workflow/approval-queue';
  static const String settings = '/api/v1/settings';
  static const String stockEntries = '/api/v1/stock-entries';
}
