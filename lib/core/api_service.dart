import 'package:dio/dio.dart';

import 'network/api_client.dart';
import 'network/api_routes.dart';

class ApiService {
  ApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<Response<dynamic>> register(Map<String, dynamic> data) {
    return _apiClient.dio.post(ApiRoutes.register, data: data);
  }

  Future<Response<dynamic>> login(String email, String password) {
    return _apiClient.dio.post(ApiRoutes.login, data: {
      'email': email,
      'password': password,
    });
  }

  Future<Response<dynamic>> getUserProfile() => _apiClient.dio.get(ApiRoutes.me);

  Future<Response<dynamic>> logout() => _apiClient.dio.post(ApiRoutes.logout);

  Future<Response<dynamic>> getInventory() => _apiClient.dio.get(ApiRoutes.inventory);

  Future<Response<dynamic>> getProducts() => _apiClient.dio.get(ApiRoutes.products);

  Future<Response<dynamic>> getCategories() => _apiClient.dio.get(ApiRoutes.categories);

  Future<Response<dynamic>> getDepartments() => _apiClient.dio.get(ApiRoutes.departments);

  Future<Response<dynamic>> getDesignations() => _apiClient.dio.get(ApiRoutes.designations);

  Future<Response<dynamic>> getPurposes() => _apiClient.dio.get(ApiRoutes.purposes);

  Future<Response<dynamic>> getRequisitions() => _apiClient.dio.get(ApiRoutes.requisitions);

  Future<Response<dynamic>> getStockEntries() => _apiClient.dio.get(ApiRoutes.stockEntries);
}
