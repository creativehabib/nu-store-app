enum AppRole {
  admin,
  requisitioner,
  initiator,
  assistantDirector,
  deputyDirector,
  director,
  unknown;

  String get label {
    switch (this) {
      case AppRole.admin:
        return 'Admin';
      case AppRole.requisitioner:
        return 'Requisitioner';
      case AppRole.initiator:
        return 'Initiator';
      case AppRole.assistantDirector:
        return 'Assistant Director';
      case AppRole.deputyDirector:
        return 'Deputy Director';
      case AppRole.director:
        return 'Director';
      case AppRole.unknown:
        return 'Unknown Role';
    }
  }

  static AppRole fromUser(Map<String, dynamic>? user) {
    final rawRole = user?['role'] ?? user?['role_name'] ?? user?['user_role'];
    final roles = user?['roles'];
    final normalized = _normalize(
      rawRole ?? (roles is List && roles.isNotEmpty ? roles.first : null),
    );

    switch (normalized) {
      case 'admin':
      case 'administrator':
      case 'superadmin':
        return AppRole.admin;
      case 'requisitioner':
      case 'requester':
        return AppRole.requisitioner;
      case 'initiator':
        return AppRole.initiator;
      case 'assistantdirector':
      case 'assistant_director':
      case 'ad':
        return AppRole.assistantDirector;
      case 'deputydirector':
      case 'deputy_director':
      case 'dd':
        return AppRole.deputyDirector;
      case 'director':
        return AppRole.director;
      default:
        return AppRole.unknown;
    }
  }

  static String _normalize(dynamic value) {
    if (value is Map) {
      return _normalize(value['name'] ?? value['slug'] ?? value['title']);
    }
    return '$value'.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }
}

enum AppPermission {
  manageEverything,
  createRequisition,
  viewOwnRequisitions,
  viewRequisitionLocation,
  forwardRequisition,
  printFinalRequisition,
  assistantDirectorVerify,
  deputyDirectorVerify,
  finalApprove,
  manageInventory,
  manageOrganization,
  manageSettings,
}

class RolePermissions {
  const RolePermissions._();

  static bool can(AppRole role, AppPermission permission) {
    if (role == AppRole.admin) return true;
    return _permissions[role]?.contains(permission) ?? false;
  }

  static const Map<AppRole, Set<AppPermission>> _permissions = {
    AppRole.requisitioner: {
      AppPermission.createRequisition,
      AppPermission.viewOwnRequisitions,
      AppPermission.viewRequisitionLocation,
    },
    AppRole.initiator: {
      AppPermission.createRequisition,
      AppPermission.viewOwnRequisitions,
      AppPermission.forwardRequisition,
      AppPermission.printFinalRequisition,
      AppPermission.viewRequisitionLocation,
    },
    AppRole.assistantDirector: {
      AppPermission.forwardRequisition,
      AppPermission.assistantDirectorVerify,
      AppPermission.viewRequisitionLocation,
    },
    AppRole.deputyDirector: {
      AppPermission.forwardRequisition,
      AppPermission.deputyDirectorVerify,
      AppPermission.viewRequisitionLocation,
    },
    AppRole.director: {
      AppPermission.finalApprove,
      AppPermission.viewRequisitionLocation,
    },
  };
}
