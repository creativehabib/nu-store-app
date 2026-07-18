import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_service.dart';
import '../shared/providers/core_providers.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(ref.watch(apiClientProvider));
});
