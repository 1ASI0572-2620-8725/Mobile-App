/// Equivalente a `monitoring/domain/monitoring-reading.model.ts`.
/// Temperatura, humedad y etileno (gas) enviados por el Edge al backend.
class MonitoringReading {
  const MonitoringReading({
    required this.id,
    required this.temperature,
    required this.humidity,
    required this.recordedAt,
    this.ethyleneLevel,
    this.status,
    this.category,
  });

  final int id;
  final double temperature;
  final double humidity;

  /// Etileno en ppm medido por el sensor de gas (null en lecturas antiguas).
  final double? ethyleneLevel;
  final String recordedAt;

  /// Estado de frescura ya clasificado por el Edge: GREEN | YELLOW | RED | UNKNOWN.
  final String? status;

  /// Categoría contra la que el Edge clasificó la lectura.
  final String? category;

  factory MonitoringReading.fromJson(Map<String, dynamic> json) => MonitoringReading(
    id: (json['id'] as num).toInt(),
    temperature: (json['temperature'] as num?)?.toDouble() ?? 0,
    humidity: (json['humidity'] as num?)?.toDouble() ?? 0,
    ethyleneLevel: (json['ethyleneLevel'] as num?)?.toDouble(),
    recordedAt: json['recordedAt'] as String? ?? '',
    status: json['status'] as String?,
    category: json['category'] as String?,
  );
}
