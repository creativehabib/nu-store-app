import 'package:hive_flutter/hive_flutter.dart';

class LocalStorageService {
  static const String authBoxName = 'authBox';
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  Future<Box<dynamic>> get _authBox => Hive.openBox(authBoxName);

  Future<String?> readToken() async {
    final box = await _authBox;
    return box.get(_tokenKey) as String?;
  }

  Future<void> saveToken(String token) async {
    final box = await _authBox;
    await box.put(_tokenKey, token);
  }

  Future<Map<String, dynamic>?> readUser() async {
    final box = await _authBox;
    final value = box.get(_userKey);
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  Future<void> saveUser(Map<String, dynamic> user) async {
    final box = await _authBox;
    await box.put(_userKey, user);
  }

  Future<void> clearAuth() async {
    final box = await _authBox;
    await box.delete(_tokenKey);
    await box.delete(_userKey);
  }
}
