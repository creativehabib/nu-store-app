class UserProfile {
  const UserProfile({
    required this.raw,
    required this.name,
    required this.email,
    required this.pfNo,
    required this.mobileNo,
    required this.role,
    required this.departmentName,
    required this.designationTitle,
    required this.imageUrl,
  });

  final Map<String, dynamic> raw;
  final String name;
  final String email;
  final String pfNo;
  final String mobileNo;
  final String role;
  final String departmentName;
  final String designationTitle;
  final String? imageUrl;

  factory UserProfile.fromMap(Map<String, dynamic>? map) {
    final source = Map<String, dynamic>.from(map ?? const {});
    return UserProfile(
      raw: source,
      name: _text(source['name'], fallback: 'User'),
      email: _text(source['email']),
      pfNo: _text(source['pf_no'] ?? source['pfNo']),
      mobileNo: _text(source['mobile_no'] ?? source['mobile']),
      role: _text(source['role']),
      departmentName: _nestedText(source['department'], ['name', 'title', 'code']),
      designationTitle: _nestedText(source['designation'], ['title', 'name']),
      imageUrl: _nullableText(
        source['picture_url'] ??
            source['picture'] ??
            source['profile_picture_url'] ??
            source['profile_picture'] ??
            source['profile_photo_url'] ??
            source['profile_image_url'] ??
            source['avatar_url'] ??
            source['photo_url'] ??
            source['image_url'] ??
            source['profile_photo'] ??
            source['profile_image'] ??
            source['avatar'] ??
            source['photo'] ??
            source['image'],
      ),
    );
  }

  Map<String, dynamic> toUpdatePayload({
    required String name,
    required String email,
    required String pfNo,
    required String mobileNo,
    required int? departmentId,
    required int? designationId,
  }) {
    return {
      'name': name.trim(),
      'email': email.trim(),
      'pf_no': pfNo.trim(),
      'mobile_no': mobileNo.trim(),
      if (departmentId != null) 'department_id': departmentId,
      if (designationId != null) 'designation_id': designationId,
    };
  }

  static String _nestedText(Object? value, List<String> keys) {
    if (value is Map) {
      for (final key in keys) {
        final text = _nullableText(value[key]);
        if (text != null) return text;
      }
    }
    return '';
  }

  static String _text(Object? value, {String fallback = ''}) =>
      _nullableText(value) ?? fallback;

  static String? _nullableText(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
