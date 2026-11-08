/// Equivalente a `inventory/infrastructure/inventory-response.ts`.
class ProductResponse {
  const ProductResponse({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.quantity,
    required this.imageUrl,
    this.expirationDate,
    this.createdAt,
  });

  final int id;
  final String name;
  final String description;
  final String category;
  final int quantity;
  final String imageUrl;
  final String? expirationDate;
  final String? createdAt;

  factory ProductResponse.fromJson(Map<String, dynamic> json) => ProductResponse(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    category: json['category'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    imageUrl: json['imageUrl'] as String? ?? '',
    expirationDate: json['expirationDate'] as String?,
    createdAt: json['createdAt'] as String?,
  );
}

class CreateProductRequest {
  const CreateProductRequest({
    required this.name,
    required this.description,
    required this.category,
    required this.quantity,
    required this.imageUrl,
    required this.expirationDate,
  });

  final String name;
  final String description;
  final String category;
  final int quantity;
  final String imageUrl;
  final String expirationDate;

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'category': category,
    'quantity': quantity,
    'imageUrl': imageUrl,
    'expirationDate': expirationDate,
  };
}

class UpdateProductRequest {
  const UpdateProductRequest({this.quantity, this.expirationDate});

  final int? quantity;
  final String? expirationDate;

  Map<String, dynamic> toJson() => {
    if (quantity != null) 'quantity': quantity,
    if (expirationDate != null) 'expirationDate': expirationDate,
  };
}
