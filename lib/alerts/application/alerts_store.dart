import 'package:flutter/foundation.dart';

import '../domain/alert_model.dart';
import '../infrastructure/alerts_api.dart';

/// Equivalente a `alerts/application/alerts.store.ts`.
class AlertsStore extends ChangeNotifier {
  AlertsStore(this._api);

  final AlertsApi _api;

  List<Alert> _alerts = [];
  bool loading = false;
  String? error;

  List<Alert> get alerts => List.unmodifiable(_alerts);
  List<Alert> get active => _alerts.where((a) => a.state == 'active').toList();
  List<Alert> get critical => _alerts.where((a) => a.severity == 'critical').toList();

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      _alerts = await _api.getAll();
    } catch (_) {
      error = 'Failed to load alerts';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> update(int id, Alert alert) async {
    final updated = await _api.update(id, alert);
    _alerts = _alerts.map((a) => a.id == updated.id ? updated : a).toList();
    notifyListeners();
  }
}
