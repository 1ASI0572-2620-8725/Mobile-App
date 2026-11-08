import 'package:flutter/foundation.dart';

import '../domain/monitoring_reading_model.dart';
import '../infrastructure/monitoring_api.dart';

/// Equivalente a `monitoring/application/monitoring.store.ts`.
class MonitoringStore extends ChangeNotifier {
  MonitoringStore(this._api);

  final MonitoringApi _api;

  MonitoringReading? _latest;
  List<MonitoringReading> _readings = [];
  bool loading = false;
  String? error;

  MonitoringReading? get latest => _latest;
  List<MonitoringReading> get readings => List.unmodifiable(_readings);

  /// [silent] evita mostrar el estado de carga en los refrescos periódicos.
  Future<void> loadLatest({bool silent = false}) async {
    if (!silent) {
      loading = true;
      error = null;
      notifyListeners();
    }
    try {
      _latest = await _api.getLatest() ?? _latest;
      error = null;
    } catch (_) {
      error = 'Failed to load monitoring data';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadAll() async {
    _readings = await _api.getAll();
    notifyListeners();
  }
}
