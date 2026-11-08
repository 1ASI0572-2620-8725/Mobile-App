import 'package:dio/dio.dart';

import '../domain/catalog_item_model.dart';
import 'inventory_api_endpoints.dart';
import 'inventory_response.dart';

/// Equivalente a `inventory/infrastructure/inventory-api.ts`.
class InventoryApi {
  InventoryApi(this._http);

  final Dio _http;

  Future<List<ProductResponse>> getProducts() async {
    final res = await _http.get(InventoryApiEndpoints.base);
    return (res.data as List? ?? []).map((e) => ProductResponse.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<CatalogItem>> getCatalog() async {
    final res = await _http.get(InventoryApiEndpoints.catalog);
    return (res.data as List? ?? []).map((e) => CatalogItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ProductResponse> createProduct(CreateProductRequest payload) async {
    final res = await _http.post(InventoryApiEndpoints.base, data: payload.toJson());
    return ProductResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ProductResponse> updateProduct(int id, UpdateProductRequest payload) async {
    final res = await _http.patch('${InventoryApiEndpoints.base}/$id', data: payload.toJson());
    return ProductResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteProduct(int id) => _http.delete('${InventoryApiEndpoints.base}/$id');
}
