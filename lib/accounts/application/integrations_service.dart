import 'package:shared_preferences/shared_preferences.dart';

typedef IntegrationStatus = String; // 'connected' | 'disconnected'

/// Equivalente a `accounts/application/integrations.service.ts`.
/// Solo frontend: el estado se simula localmente (no hay backend de integraciones).
class IntegrationsService {
  IntegrationsService(this._prefs);

  final SharedPreferences _prefs;

  String _key(int id) => 'fs.integrations.$id';

  IntegrationStatus getStatus(int id) {
    final v = _prefs.getString(_key(id));
    return (v == 'connected' || v == 'disconnected') ? v! : 'disconnected';
  }

  Future<bool> toggle(int id, IntegrationStatus next) => _prefs.setString(_key(id), next);
}
