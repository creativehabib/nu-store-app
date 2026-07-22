import 'package:flutter/material.dart';

import '../../auth/domain/app_role.dart';
import '../../profile/presentation/profile_screen.dart';
import 'requisitioner_screens.dart';

class DashboardNavItem {
  const DashboardNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

List<DashboardNavItem> navItemsFor(AppRole role) {
  final items = <DashboardNavItem>[
    const DashboardNavItem(icon: Icons.dashboard_outlined, label: 'Dashboard'),
  ];

  if (RolePermissions.can(role, AppPermission.manageInventory)) {
    items.add(const DashboardNavItem(icon: Icons.inventory_2_outlined, label: 'Inventory'));
  }

  if (RolePermissions.can(role, AppPermission.createRequisition) ||
      RolePermissions.can(role, AppPermission.viewRequisitionLocation) ||
      RolePermissions.can(role, AppPermission.forwardRequisition) ||
      RolePermissions.can(role, AppPermission.finalApprove)) {
    items.add(const DashboardNavItem(icon: Icons.assignment_outlined, label: 'Requisitions'));
  }

  if (RolePermissions.can(role, AppPermission.manageSettings)) {
    items.add(const DashboardNavItem(icon: Icons.settings_outlined, label: 'Settings'));
  }

  return items;
}

List<DashboardNavItem> drawerItemsFor(AppRole role) {
  final items = <DashboardNavItem>[
    const DashboardNavItem(icon: Icons.account_circle_outlined, label: 'Update Profile'),
  ];

  if (RolePermissions.can(role, AppPermission.manageInventory)) {
    items.addAll(const [
      DashboardNavItem(icon: Icons.category_outlined, label: 'Categories & Products'),
      DashboardNavItem(icon: Icons.add_box_outlined, label: 'Stock In / Entries'),
    ]);
  }

  if (RolePermissions.can(role, AppPermission.createRequisition)) {
    items.add(const DashboardNavItem(icon: Icons.playlist_add_rounded, label: 'Submit Demand'));
  }

  if (RolePermissions.can(role, AppPermission.viewOwnRequisitions) ||
      RolePermissions.can(role, AppPermission.viewRequisitionLocation)) {
    items.add(const DashboardNavItem(icon: Icons.timeline_rounded, label: 'My Requisitions'));
  }

  if (RolePermissions.can(role, AppPermission.forwardRequisition)) {
    items.add(const DashboardNavItem(icon: Icons.forward_to_inbox_rounded, label: 'Initiator Queue'));
  }

  if (RolePermissions.can(role, AppPermission.assistantDirectorVerify)) {
    items.add(const DashboardNavItem(icon: Icons.fact_check_outlined, label: 'Assistant Director Review'));
  }

  if (RolePermissions.can(role, AppPermission.deputyDirectorVerify)) {
    items.add(const DashboardNavItem(icon: Icons.verified_outlined, label: 'Deputy Director Review'));
  }

  if (RolePermissions.can(role, AppPermission.finalApprove)) {
    items.add(const DashboardNavItem(icon: Icons.approval_outlined, label: 'Director Final Approval'));
  }

  if (role != AppRole.initiator && RolePermissions.can(role, AppPermission.printFinalRequisition)) {
    items.add(const DashboardNavItem(icon: Icons.print_outlined, label: 'Final Print'));
  }

  if (RolePermissions.can(role, AppPermission.manageOrganization)) {
    items.add(const DashboardNavItem(icon: Icons.apartment_outlined, label: 'Departments & Designations'));
  }

  if (RolePermissions.can(role, AppPermission.manageSettings)) {
    items.add(const DashboardNavItem(icon: Icons.language_rounded, label: 'Language & Settings'));
  }

  return items;
}

Widget screenForDashboardLabel(String label) {
  if (label == 'Update Profile') return const ProfileScreen();
  return screenForDrawerLabel(label);
}

String actionHint(String label) {
  return switch (label) {
    'Update Profile' => 'Edit profile details and view your profile photo.',
    'Initiator Queue' => 'Check new requisitions and forward them to approval.',
    'Final Print' => 'Print completed requisition letters after final approval.',
    'My Requisitions' => 'Track requisition status and location.',
    _ => 'Open this module.',
  };
}
