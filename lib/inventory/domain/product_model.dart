/// Equivalente a `inventory/domain/product.model.ts`.
class Product {
  Product({
    required this.id,
    required this.name,
    this.image,
    this.state,
    this.category,
    this.description,
    this.quantity = 0,
    this.expirationDate,
    this.createdAt,
  });

  final int id;
  final String name;
  final String? image;
  final String? state;
  final String? category;
  final String? description;
  int quantity;
  final String? expirationDate;
  final String? createdAt;
}
