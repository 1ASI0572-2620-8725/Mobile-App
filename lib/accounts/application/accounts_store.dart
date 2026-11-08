import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/infrastructure/http_client.dart';
import '../domain/model/user_entity.dart';
import '../infrastructure/account_response.dart';
import '../infrastructure/accounts_api.dart';

const _currentUserKey = 'currentUser';

/// Resultado simple de una operación (equivalente a `{ ok, message }` del web).
class StoreResult {
  const StoreResult(this.ok, [this.message]);
  final bool ok;
  final String? message;
}

/// Equivalente a `accounts/application/accounts.store.ts`.
class AccountStore extends ChangeNotifier {
  AccountStore(this._api, this._prefs, this._http);

  final AccountApis _api;
  final SharedPreferences _prefs;
  final HttpClient _http;

  Future<StoreResult> register(User user) async {
    try {
      final resp = await _api.register(email: user.email, password: user.password, fullName: user.name);
      _saveSession(resp);
      return const StoreResult(true);
    } catch (err) {
      return StoreResult(false, backendMessage(err));
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      _saveSession(await _api.login(email, password));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Actualiza el nombre del perfil en el backend y refresca el usuario guardado.
  Future<StoreResult> updateProfile(String fullName) async {
    try {
      _saveSession(await _api.updateProfile(fullName));
      return const StoreResult(true);
    } catch (err) {
      return StoreResult(false, backendMessage(err));
    }
  }

  /// Cambia la contraseña del usuario autenticado.
  Future<StoreResult> changePassword(String currentPassword, String newPassword) async {
    try {
      await _api.changePassword(currentPassword, newPassword);
      return const StoreResult(true);
    } catch (err) {
      return StoreResult(false, backendMessage(err));
    }
  }

  void _saveSession(AuthResponse resp) {
    // El token NO se guarda aquí: viaja en la cookie HttpOnly (cookie jar).
    _prefs.setString(_currentUserKey, jsonEncode(resp.toJson()));
    notifyListeners();
  }

  AuthResponse? getCurrentUser() {
    final raw = _prefs.getString(_currentUserKey);
    if (raw == null) return null;
    try {
      return AuthResponse.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    await _prefs.remove(_currentUserKey);
    try {
      await _api.logout();
    } catch (_) {}
    await _http.clearSession();
    notifyListeners();
  }

  bool isLogged() => getCurrentUser() != null;

  /// Renueva el access token usando el refreshToken (cookie). Usado por el interceptor.
  Future<bool> refreshToken() async {
    try {
      _saveSession(await _api.refresh());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Refresca la sesión tras un cambio de rol (ej. upgrade a premium).
  Future<void> refreshAfterRoleChange() async {
    await refreshToken();
    try {
      _saveSession(await _api.getMe());
    } catch (_) {}
  }

  String? getRole() => getCurrentUser()?.role;

  bool isPremium() {
    final role = getRole();
    return role == 'USER_PREMIUM' || role == 'ADMIN';
  }

  /// Intenta restaurar la sesión con `GET /me` usando la cookie guardada.
  Future<bool> tryRestoreSession() async {
    try {
      _saveSession(await _api.getMe());
      return true;
    } catch (_) {
      return false;
    }
  }
}
