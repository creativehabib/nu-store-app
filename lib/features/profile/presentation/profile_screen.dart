import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/register_screen.dart';
import '../domain/user_profile.dart';
import 'profile_controller.dart';
import 'widgets/profile_avatar.dart';

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

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final profile = profileState.valueOrNull;
    if (!_seeded && profile != null) _seed(profile);

    return Scaffold(
      appBar: AppBar(title: const Text('Update Profile')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(profileControllerProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(child: ProfileAvatar(name: profile?.name ?? _name.text, imageUrl: profile?.imageUrl, radius: 48)),
            const SizedBox(height: 12),
            Center(child: Text(profile?.role ?? '', style: TextStyle(color: Colors.grey.shade600))),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _field(_name, 'Full Name', Icons.person_outline),
                  _field(_email, 'Email Address', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                  _field(_pfNo, 'PF Number', Icons.badge_outlined),
                  _field(_mobile, 'Mobile Number', Icons.phone_outlined, keyboardType: TextInputType.phone),
                  _dropdown('Department', ref.watch(departmentsProvider), _departmentId, (value) => setState(() => _departmentId = value)),
                  _dropdown('Designation', ref.watch(designationsProvider), _designationId, (value) => setState(() => _designationId = value)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (profileState.hasError)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('${profileState.error}', style: const TextStyle(color: Colors.redAccent)),
              ),
            FilledButton.icon(
              onPressed: profileState.isLoading ? null : _submit,
              icon: profileState.isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: const Text('Save Profile'),
            ),
            const SizedBox(height: 12),
            Text(
              'Profile image is shown from the API user payload when fields like profile_photo_url, avatar_url, photo_url, or image_url are available.',
              style: TextStyle(color: Colors.grey.shade600, height: 1.4),
            ),
          ],
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

  Widget _field(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder()),
        validator: (value) => value == null || value.trim().isEmpty ? '$label is required' : null,
      ),
    );
  }

  Widget _dropdown(String label, AsyncValue<List<Map<String, dynamic>>> rows, int? value, ValueChanged<int?> onChanged) {
    final options = rows.valueOrNull ?? const <Map<String, dynamic>>[];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<int>(
        isExpanded: true,
        value: options.any((row) => _id(row['id']) == value) ? value : null,
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.apartment_outlined), border: const OutlineInputBorder()),
        items: [for (final row in options) DropdownMenuItem(value: _id(row['id']), child: Text('${row['name'] ?? row['title'] ?? 'Item'}'))],
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final payload = UserProfile.fromMap(const {}).toUpdatePayload(
      name: _name.text,
      email: _email.text,
      pfNo: _pfNo.text,
      mobileNo: _mobile.text,
      departmentId: _departmentId,
      designationId: _designationId,
    );
    await ref.read(profileControllerProvider.notifier).update(payload);
    if (!mounted) return;
    final failed = ref.read(profileControllerProvider).hasError;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failed ? 'Profile update failed.' : 'Profile updated successfully.')));
  }

  int? _id(Object? value) => value is num ? value.toInt() : int.tryParse('$value');
}
