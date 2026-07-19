import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_routes.dart';
import '../../../shared/providers/core_providers.dart';
import '../presentation/auth_controller.dart';

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

  @override
  Widget build(BuildContext context) {
    final departments = ref.watch(departmentsProvider);
    final designations = ref.watch(designationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('NU Store Registration', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Registration successful হলে admin approval এর পর login করা যাবে।'),
            const SizedBox(height: 24),
            _text(_name, 'Full name', Icons.person_outline),
            _text(_email, 'Email', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
            _text(_pfNo, 'PF number', Icons.badge_outlined),
            _text(_mobile, 'Mobile number', Icons.phone_outlined, keyboardType: TextInputType.phone),
            _dropdown('Department', _departmentId, departments, (v) => setState(() => _departmentId = v)),
            _dropdown('Designation', _designationId, designations, (v) => setState(() => _designationId = v)),
            _text(_password, 'Password', Icons.lock_outline, obscureText: true),
            _text(_confirm, 'Confirm password', Icons.lock_reset, obscureText: true),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: const Icon(Icons.person_add_alt),
              label: Text(_submitting ? 'Submitting...' : 'Register'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _text(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType, bool obscureText = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder()),
        validator: (value) => value == null || value.trim().isEmpty ? '$label is required' : null,
      ),
    );
  }

  Widget _dropdown(String label, int? value, AsyncValue<List<Map<String, dynamic>>> rows, ValueChanged<int?> onChanged) {
    final options = rows.valueOrNull ?? const <Map<String, dynamic>>[];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<int>(
        value: options.any((row) => _asInt(row['id']) == value) ? value : null,
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.apartment_outlined), border: const OutlineInputBorder()),
        items: [for (final row in options) DropdownMenuItem(value: _asInt(row['id']), child: Text(_label(row)))],
        onChanged: onChanged,
        validator: (value) => value == null ? '$label is required' : null,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_password.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password confirmation does not match.'), backgroundColor: Colors.red));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${response['message'] ?? 'Registration successful. Please wait for admin approval.'}'), backgroundColor: Colors.green));
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

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
