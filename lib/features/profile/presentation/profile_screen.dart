import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/register_screen.dart';
import '../domain/user_profile.dart';
import 'profile_controller.dart';
import 'widgets/change_password_dialog.dart';
import 'widgets/profile_avatar.dart';

// Primary brand color to maintain consistency
const Color _primaryColor = Color(0xFF1E3A8A);

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pfNo = TextEditingController();
  final _mobile = TextEditingController();

  int? _departmentId;
  int? _designationId;
  bool _seeded = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pfNo.dispose();
    _mobile.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final profile = profileState.when(
      data: (value) => value,
      loading: () => null,
      error: (_, _) => null,
    );
    final isBusy = profileState.when(
      data: (_) => false,
      loading: () => true,
      error: (_, _) => false,
    );
    final errorText = profileState.when(
      data: (_) => null,
      loading: () => null,
      error: (error, _) => '$error',
    );

    if (!_seeded && profile != null) _seed(profile);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Update Profile',
          style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 20),
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: RefreshIndicator(
              color: _primaryColor,
              backgroundColor: Colors.white,
              onRefresh: () => ref.read(profileControllerProvider.notifier).refresh(),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                children: [
                  // Hero Profile Section
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: _primaryColor.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8)),
                            ],
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: ProfileAvatar(
                            name: profile?.name ?? _name.text,
                            imageUrl: profile?.imageUrl,
                            radius: 56,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Role Badge
                  if (profile?.role != null && profile!.role.isNotEmpty)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          profile.role.toUpperCase(),
                          style: const TextStyle(
                            color: _primaryColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),

                  // Form Section inside a modern Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5)),
                      ],
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Personal Information',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _name,
                            label: 'Full Name',
                            icon: Icons.person_outline_rounded,
                          ),
                          _buildTextField(
                            controller: _email,
                            label: 'Email Address',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          _buildTextField(
                            controller: _mobile,
                            label: 'Mobile Number',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Divider(),
                          ),

                          const Text(
                            'Professional Details',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _pfNo,
                            label: 'PF Number',
                            icon: Icons.badge_outlined,
                          ),
                          _buildDropdown(
                            label: 'Department',
                            rows: ref.watch(departmentsProvider),
                            value: _departmentId,
                            icon: Icons.domain_rounded,
                            onChanged: (value) => setState(() => _departmentId = value),
                          ),
                          _buildDropdown(
                            label: 'Designation',
                            rows: ref.watch(designationsProvider),
                            value: _designationId,
                            icon: Icons.work_outline_rounded,
                            onChanged: (value) => setState(() => _designationId = value),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Error Message
                  if (errorText != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: Colors.red.shade600),
                          const SizedBox(width: 12),
                          Expanded(child: Text(errorText, style: TextStyle(color: Colors.red.shade800))),
                        ],
                      ),
                    ),

                  // Action Buttons
                  SizedBox(
                    height: 56,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isBusy ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        disabledBackgroundColor: _primaryColor.withOpacity(0.6),
                      ),
                      icon: isBusy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        isBusy ? 'Saving...' : 'Save Profile',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 56,
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isBusy ? null : _openChangePasswordDialog,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primaryColor,
                        side: BorderSide(color: _primaryColor.withOpacity(0.5), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.lock_reset_rounded),
                      label: const Text(
                        'Change Password',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _seed(UserProfile profile) {
    _name.text = profile.name;
    _email.text = profile.email;
    _pfNo.text = profile.pfNo;
    _mobile.text = profile.mobileNo;
    _departmentId = _id(profile.raw['department_id'] ?? (profile.raw['department'] as Map?)?['id']);
    _designationId = _id(profile.raw['designation_id'] ?? (profile.raw['designation'] as Map?)?['id']);
    _seeded = true;
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600),
          prefixIcon: Icon(icon, color: _primaryColor.withOpacity(0.7)),
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
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
        ),
        validator: (value) => value == null || value.trim().isEmpty ? '$label is required' : null,
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required AsyncValue<List<Map<String, dynamic>>> rows,
    required int? value,
    required IconData icon,
    required ValueChanged<int?> onChanged,
  }) {
    final options = rows.when(
      data: (items) => items,
      loading: () => const <Map<String, dynamic>>[],
      error: (_, _) => const <Map<String, dynamic>>[],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<int>(
        isExpanded: true,
        value: options.any((row) => _id(row['id']) == value) ? value : null,
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade600),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600),
          prefixIcon: Icon(icon, color: _primaryColor.withOpacity(0.7)),
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
        ),
        items: [
          for (final row in options)
            DropdownMenuItem(
              value: _id(row['id']),
              child: Text(
                '${row['name'] ?? row['title'] ?? 'Item'}',
                overflow: TextOverflow.ellipsis,
              ),
            )
        ],
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _openChangePasswordDialog() async {
    await showDialog<bool>(
      context: context,
      builder: (_) => const ChangePasswordDialog(),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final payload = UserProfile.fromMap(const {}).toUpdatePayload(
      name: _name.text.trim(),
      email: _email.text.trim(),
      pfNo: _pfNo.text.trim(),
      mobileNo: _mobile.text.trim(),
      departmentId: _departmentId,
      designationId: _designationId,
    );

    await ref.read(profileControllerProvider.notifier).update(payload);
    if (!mounted) return;

    final failed = ref.read(profileControllerProvider).when(
      data: (_) => false,
      loading: () => false,
      error: (_, _) => true,
    );

    if (failed) {
      _showSnackBar('Profile update failed. Please check your data.', Colors.redAccent);
    } else {
      _showSnackBar('Profile updated successfully!', Colors.green.shade600);
    }
  }

  int? _id(Object? value) => value is num ? value.toInt() : int.tryParse('$value');
}