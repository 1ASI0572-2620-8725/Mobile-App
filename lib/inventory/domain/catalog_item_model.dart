/// Equivalente a `inventory/domain/catalog-item.model.ts`.
/// Alimento del catálogo general (`GET /api/catalog`); su categoría es una de
/// las 7 categorías de umbrales del Edge.
class CatalogItem {
  const CatalogItem({required this.id, required this.name, required this.category, this.description, this.imageUrl});

  final int id;
  final String name;
  final String? description;
  final String category;
  final String? imageUrl;

  factory CatalogItem.fromJson(Map<String, dynamic> json) => CatalogItem(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    description: json['description'] as String?,
    category: json['category'] as String? ?? '',
    imageUrl: json['imageUrl'] as String?,
  );
}
