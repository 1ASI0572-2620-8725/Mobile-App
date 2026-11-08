import 'package:dio/dio.dart';

import 'account_api_endpoints.dart';
import 'account_response.dart';

/// Equivalente a `accounts/infrastructure/accounts-api.ts`.
class AccountApis {
  AccountApis(this._http);

  final Dio _http;

  Future<AuthResponse> register({required String email, required String password, required String fullName}) async {
    final res = await _http.post(
      AccountApiEndpoints.register,
      data: {'email': email, 'password': password, 'fullName': fullName},
    );
    return AuthResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<AuthResponse> login(String email, String password) async {
    final res = await _http.post(AccountApiEndpoints.login, data: {'email': email, 'password': password});
    return AuthResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> logout() => _http.post(AccountApiEndpoints.logout, data: {});

  Future<AuthResponse> getMe() async {
    final res = await _http.get(AccountApiEndpoints.me);
    return AuthResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<AuthResponse> refresh() async {
    final res = await _http.post(AccountApiEndpoints.refresh, data: {});
    return AuthResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<AuthResponse> updateProfile(String fullName) async {
    final res = await _http.put(AccountApiEndpoints.me, data: {'fullName': fullName});
    return AuthResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> changePassword(String currentPassword, String newPassword) =>
      _http.post(AccountApiEndpoints.changePassword, data: {'currentPassword': currentPassword, 'newPassword': newPassword});
}
