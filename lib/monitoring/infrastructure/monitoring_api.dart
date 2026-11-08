import 'package:dio/dio.dart';

import '../../environments/environment.dart';
import '../domain/monitoring_reading_model.dart';

/// Equivalente a `monitoring/infrastructure/monitoring-api.ts`.
class MonitoringApi {
  MonitoringApi(this._http);

  final Dio _http;
  static const _base = '${Environment.apiBaseUrl}/monitoring';

  /// Última lectura; `null` si aún no hay datos (el backend responde 204).
  Future<MonitoringReading?> getLatest() async {
    final res = await _http.get('$_base/latest');
    final data = res.data;
    return data is Map<String, dynamic> ? MonitoringReading.fromJson(data) : null;
  }

  Future<List<MonitoringReading>> getAll() async {
    final res = await _http.get(_base);
    return (res.data as List? ?? []).map((e) => MonitoringReading.fromJson(e as Map<String, dynamic>)).toList();
  }
}
