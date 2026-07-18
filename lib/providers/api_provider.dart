import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_service.dart';

// এই প্রোভাইডারের মাধ্যমে আমরা যেকোনো স্ক্রিন থেকে ApiService ব্যবহার করতে পারব
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService();
});