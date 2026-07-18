import 'package:dio/dio.dart';

class ApiService {
  late final Dio _dio;
  
  // আপনার সার্ভারের বেস ইউআরএল এখানে দিন (যেমন: আপনার লোকাল আইপি বা লাইভ ডোমেইন)
  static const String baseUrl = 'http://nu-store.test'; 
  
  // আপনার দেওয়া টেস্টিং এপিআই টোকেন
  static const String staticToken = '793NsqOfZ2mHVb600Jw5zD2cA2xT3xKMyuD1RI1VKap1qEc0zoOcV2x4iTCZgeBz';

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Accept': 'application/json',
      },
    ));

    // Interceptor: এটি প্রতিটি রিকোয়েস্টের সাথে স্বয়ংক্রিয়ভাবে টোকেন যুক্ত করে দেবে
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // প্রোডাকশনে আমরা Hive থেকে ডায়নামিক টোকেন নেব, আপাতত আপনার দেওয়া টোকেনটি ব্যবহার করছি
        options.headers['Authorization'] = 'Bearer $staticToken';
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        // API থেকে কোনো এরর আসলে এখানে লগ করা বা হ্যান্ডেল করা যায়
        print('API Error: ${e.response?.statusCode} - ${e.message}');
        return handler.next(e);
      },
    ));
  }

  // ==========================================
  // ১. Auth Endpoints
  // ==========================================
  
  Future<Response> login(String email, String password) async {
    return await _dio.post('/api/v1/auth/login', data: {
      'email': email,
      'password': password,
    });
  }

  Future<Response> getUserProfile() async {
    return await _dio.get('/api/v1/auth/me');
  }

  // ==========================================
  // ২. Store & Inventory Endpoints
  // ==========================================

  Future<Response> getRequisitions() async {
    return await _dio.get('/api/v1/requisitions');
  }

  Future<Response> getInventory() async {
    return await _dio.get('/api/v1/inventory');
  }

  Future<Response> getStockEntries() async {
    return await _dio.get('/api/v1/stock-entries');
  }
}