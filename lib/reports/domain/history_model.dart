/// Equivalente a `reports/domain/history.model.ts`.
/// `action`: CONSUMED | DISCARDED (formato nuevo) o consume | discard | add (antiguo).
class HistoryEntry {
  const HistoryEntry({
    this.id,
    required this.productId,
    required this.productName,
    required this.category,
    required this.action,
    required this.quantity,
    required this.date,
  });

  final int? id;
  final int productId;
  final String productName;
  final String category;
  final String action;
  final int quantity;
  final String date;

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    id: (json['id'] as num?)?.toInt(),
    productId: (json['productId'] as num?)?.toInt() ?? 0,
    productName: json['productName'] as String? ?? '',
    category: json['category'] as String? ?? '',
    action: json['action'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    date: json['date'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'category': category,
    'action': action,
    'quantity': quantity,
  };
}
