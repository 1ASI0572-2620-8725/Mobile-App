import 'package:flutter/foundation.dart';

import '../infrastructure/inventory_api.dart';
import '../infrastructure/inventory_response.dart';

/// Equivalente a `inventory/application/inventory.store.ts`.
class InventoryStore extends ChangeNotifier {
  InventoryStore(this._api);

  final InventoryApi _api;

  List<ProductResponse> _products = [];
  List<ProductResponse> get products => List.unmodifiable(_products);

  Future<void> loadProducts() async {
    _products = await _api.getProducts();
    notifyListeners();
  }

  Future<bool> addProduct(CreateProductRequest payload) async {
    try {
      final created = await _api.createProduct(payload);
      _products = [..._products, created];
      notifyListeners();
      return true;
    } catch (err) {
      debugPrint('Error al crear producto: $err');
      return false;
    }
  }
}
