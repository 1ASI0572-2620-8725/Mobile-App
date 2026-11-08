import '../../environments/environment.dart';

/// Equivalente a `accounts/infrastructure/account-api-endpoints.ts`.
class AccountApiEndpoints {
  AccountApiEndpoints._();

  static const register = '${Environment.apiBaseUrl}/accounts/register';
  static const login = '${Environment.apiBaseUrl}/accounts/login';
  static const logout = '${Environment.apiBaseUrl}/accounts/logout';
  static const refresh = '${Environment.apiBaseUrl}/accounts/refresh';
  static const me = '${Environment.apiBaseUrl}/accounts/me';
  static const changePassword = '${Environment.apiBaseUrl}/accounts/change-password';
}
