import 'package:dio/dio.dart';

import '../../environments/environment.dart';
import '../domain/alert_model.dart';

/// Equivalente a `alerts/infrastructure/alerts-api.ts`.
class AlertsApi {
  AlertsApi(this._http);

  final Dio _http;
  static const _baseUrl = '${Environment.apiBaseUrl}/alerts';

  Future<List<Alert>> getAll() async {
    final res = await _http.get(_baseUrl);
    return (res.data as List? ?? []).map((e) => Alert.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Alert> update(int id, Alert alert) async {
    final res = await _http.put('$_baseUrl/$id', data: alert.toJson());
    return Alert.fromJson(res.data as Map<String, dynamic>);
  }
}
