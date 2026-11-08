import '../../environments/environment.dart';

/// Equivalente a `inventory/infrastructure/inventory-api-endpoints.ts`.
class InventoryApiEndpoints {
  InventoryApiEndpoints._();

  static const base = '${Environment.apiBaseUrl}/products';
  static const catalog = '${Environment.apiBaseUrl}/catalog';
}
