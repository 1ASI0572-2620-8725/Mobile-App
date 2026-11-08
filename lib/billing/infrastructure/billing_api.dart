import 'package:dio/dio.dart';

import '../../environments/environment.dart';
import '../domain/plan_model.dart';

/// Equivalente a `billing/infrastructure/billing-api.ts`.
class BillingApi {
  BillingApi(this._http);

  final Dio _http;
  static const _base = '${Environment.apiBaseUrl}/billing';

  Future<List<Plan>> getPlans() async {
    final res = await _http.get('$_base/plans');
    return (res.data as List? ?? []).map((e) => Plan.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> subscribe(int planId, String paymentReference) =>
      _http.post('$_base/subscribe', data: {'planId': planId, 'paymentReference': paymentReference});
}
