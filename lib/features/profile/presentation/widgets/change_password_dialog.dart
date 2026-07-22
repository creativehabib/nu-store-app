import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../profile_controller.dart';

class ChangePasswordDialog extends ConsumerStatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  ConsumerState<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _submitting = false;
  bool _showCurrent = false;
  bool _showPassword = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentPassword.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Password'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _passwordField(
                controller: _currentPassword,
                label: 'Current Password',
                visible: _showCurrent,
                onToggle: () => setState(() => _showCurrent = !_showCurrent),
              ),
              const SizedBox(height: 14),
              _passwordField(
                controller: _password,
                label: 'New Password',
                visible: _showPassword,
                onToggle: () => setState(() => _showPassword = !_showPassword),
                validator: _newPasswordValidator,
              ),
              const SizedBox(height: 14),
              _passwordField(
                controller: _confirmPassword,
                label: 'Confirm New Password',
                visible: _showConfirm,
                onToggle: () => setState(() => _showConfirm = !_showConfirm),
                validator: _confirmPasswordValidator,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lock_reset_rounded),
          label: const Text('Update'),
        ),
      ],
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool visible,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !visible,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(visible ? Icons.visibility_off_rounded : Icons.visibility_rounded),
        ),
      ),
      validator: validator ?? _requiredPasswordValidator,
    );
  }

  String? _requiredPasswordValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Password is required';
    return null;
  }

  String? _newPasswordValidator(String? value) {
    final requiredMessage = _requiredPasswordValidator(value);
    if (requiredMessage != null) return requiredMessage;
    if (value!.length < 8) return 'Password must be at least 8 characters';
    if (value == _currentPassword.text) return 'New password must be different';
    return null;
  }

  String? _confirmPasswordValidator(String? value) {
    final requiredMessage = _requiredPasswordValidator(value);
    if (requiredMessage != null) return requiredMessage;
    if (value != _password.text) return 'Password confirmation does not match';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final message = await ref.read(profileControllerProvider.notifier).changePassword(
            currentPassword: _currentPassword.text,
            password: _password.text,
            passwordConfirmation: _confirmPassword.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(error)), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final message = data['message'] ?? data['error'];
        if (message != null && message.toString().trim().isNotEmpty) return message.toString();
      }
    }
    return 'Password change failed. Please verify your current password.';
  }
}
