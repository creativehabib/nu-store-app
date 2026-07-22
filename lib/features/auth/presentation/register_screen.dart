import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_routes.dart';
import '../../../shared/providers/core_providers.dart';
import 'auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pfNo = TextEditingController();
  final _mobile = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  int? _departmentId;
  int? _designationId;
  bool _submitting = false;

  // Password visibility states
  bool _isPasswordVisible = false;
  bool _isConfirmVisible = false;

  // Primary brand color matching the previous screens
  final Color _primaryColor = const Color(0xFF1E3A8A);

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pfNo.dispose();
    _mobile.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final departments = ref.watch(departmentsProvider);
    final designations = ref.watch(designationsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Create Account',
          style: TextStyle(
            color: _primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            children: [
              // Notice / Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Registration successful হলে admin approval এর পর login করা যাবে।',
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Form Fields
              _buildTextField(
                controller: _name,
                label: 'Full Name',
                hint: 'e.g. John Doe',
                icon: Icons.person_outline_rounded,
              ),
              _buildTextField(
                controller: _email,
                label: 'Email Address',
                hint: 'example@nu.ac.bd',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              _buildTextField(
                controller: _pfNo,
                label: 'PF Number',
                hint: 'e.g. PF12345',
                icon: Icons.badge_outlined,
              ),
              _buildTextField(
                controller: _mobile,
                label: 'Mobile Number',
                hint: '01XXXXXXXXX',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),

              // Dropdowns
              _buildDropdown(
                label: 'Department',
                value: _departmentId,
                rows: departments,
                icon: Icons.domain_rounded,
                onChanged: (v) => setState(() => _departmentId = v),
              ),
              _buildDropdown(
                label: 'Designation',
                value: _designationId,
                rows: designations,
                icon: Icons.work_outline_rounded,
                onChanged: (v) => setState(() => _designationId = v),
              ),

              // Passwords
              _buildTextField(
                controller: _password,
                label: 'Password',
                hint: 'Enter a strong password',
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                isVisible: _isPasswordVisible,
                onVisibilityToggle: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
              _buildTextField(
                controller: _confirm,
                label: 'Confirm Password',
                hint: 'Re-enter your password',
                icon: Icons.lock_reset_rounded,
                isPassword: true,
                isVisible: _isConfirmVisible,
                onVisibilityToggle: () => setState(() => _isConfirmVisible = !_isConfirmVisible),
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    disabledBackgroundColor: _primaryColor.withOpacity(0.6),
                  ),
                  child: _submitting
                      ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                      : const Text(
                    'Register',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // Modern Text Field Builder
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onVisibilityToggle,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && !isVisible,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400),
          labelStyle: TextStyle(color: Colors.grey.shade600),
          prefixIcon: Icon(icon, color: _primaryColor.withOpacity(0.7)),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              color: Colors.grey.shade500,
            ),
            onPressed: onVisibilityToggle,
          )
              : null,
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
            borderSide: BorderSide(color: _primaryColor, width: 2),
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

  // Modern Dropdown Builder - Fixed Overflow Issue
  Widget _buildDropdown({
    required String label,
    required int? value,
    required AsyncValue<List<Map<String, dynamic>>> rows,
    required IconData icon,
    required ValueChanged<int?> onChanged,
  }) {
    final options = rows.when(
      data: (items) => items,
      loading: () => const <Map<String, dynamic>>[],
      error: (_, _) => const <Map<String, dynamic>>[],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: DropdownButtonFormField<int>(
        isExpanded: true, // Prevents horizontal overflow
        value: options.any((row) => _asInt(row['id']) == value) ? value : null,
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade600),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600),
          prefixIcon: Icon(icon, color: _primaryColor.withOpacity(0.7)),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
            borderSide: BorderSide(color: _primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
        ),
        items: [
          for (final row in options)
            DropdownMenuItem(
              value: _asInt(row['id']),
              child: Text(
                _label(row),
                overflow: TextOverflow.ellipsis, // Truncates text with ... if too long
              ),
            )
        ],
        onChanged: onChanged,
        validator: (val) => val == null ? 'Please select a $label' : null,
      ),
    );
  }

  Future<void> _submit() async {
    // Hide keyboard
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_password.text != _confirm.text) {
      _showSnackBar('Password confirmation does not match.', Colors.redAccent);
      return;
    }

    setState(() => _submitting = true);

    try {
      final response = await ref.read(authRepositoryProvider).register({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'pf_no': _pfNo.text.trim(),
        'mobile_no': _mobile.text.trim(),
        'department_id': _departmentId,
        'designation_id': _designationId,
        'role': 'requisitioner',
        'password': _password.text,
        'password_confirmation': _confirm.text,
      });

      if (!mounted) return;
      _showSnackBar(
        response['message'] ?? 'Registration successful. Please wait for admin approval.',
        Colors.green.shade600,
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('$error', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

// ----------------- Providers & Helpers -----------------

final departmentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await ref.watch(apiClientProvider).dio.get(ApiRoutes.departments);
  return _rows(response.data);
});

final designationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await ref.watch(apiClientProvider).dio.get(ApiRoutes.designations);
  return _rows(response.data);
});

List<Map<String, dynamic>> _rows(dynamic data) {
  final payload = data is Map ? data['data'] : data;
  if (payload is List) {
    return payload.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }
  if (payload is Map) {
    final nested = payload['data'] ?? payload['items'] ?? payload['results'];
    if (nested is List) {
      return nested.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    }
  }
  return const [];
}

int _asInt(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

String _label(Map<String, dynamic> row) {
  return '${row['name'] ?? row['title'] ?? row['name_en'] ?? row['name_bn'] ?? 'Item'}';
}