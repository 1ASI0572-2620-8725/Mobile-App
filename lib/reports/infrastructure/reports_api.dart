import 'package:dio/dio.dart';

import '../../environments/environment.dart';
import '../domain/history_model.dart';

/// Equivalente a `reports/infrastructure/reports-api.ts`.
class ReportsApi {
  ReportsApi(this._http);

  final Dio _http;
  static const _base = '${Environment.apiBaseUrl}/history';

  Future<List<HistoryEntry>> getAll() async {
    final res = await _http.get(_base);
    return (res.data as List? ?? []).map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<HistoryEntry> create(HistoryEntry entry) async {
    final res = await _http.post(_base, data: entry.toJson());
    return HistoryEntry.fromJson(res.data as Map<String, dynamic>);
  }
}
