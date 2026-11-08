/// Equivalente a `billing/domain/plan.model.ts` (adaptado a la respuesta real
/// de `GET /api/billing/plans`: id, name, type, priceMonthly, priceAnnual, features).
class Plan {
  const Plan({
    required this.id,
    required this.name,
    required this.type,
    required this.priceMonthly,
    required this.priceAnnual,
    required this.features,
  });

  final int id;
  final String name;

  /// BASIC | PREMIUM
  final String type;
  final double priceMonthly;
  final double priceAnnual;
  final List<String> features;

  bool get isPremium => type.toUpperCase() == 'PREMIUM';

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    type: json['type'] as String? ?? '',
    priceMonthly: (json['priceMonthly'] as num?)?.toDouble() ?? 0,
    priceAnnual: (json['priceAnnual'] as num?)?.toDouble() ?? 0,
    features: (json['features'] as List? ?? []).map((e) => '$e').toList(),
  );
}
