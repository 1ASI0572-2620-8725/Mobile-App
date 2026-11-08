/// Equivalente a `alerts/domain/alert.model.ts`.
/// `severity`: critical | warning | info — `state`: active | muted | resolved.
/// El backend responde en mayúsculas; aquí se normaliza a minúsculas.
class Alert {
  Alert({
    required this.id,
    required this.severity,
    required this.state,
    required this.title,
    required this.message,
    required this.source,
    required this.timeAgo,
  });

  final int id;
  final String severity;
  String state;
  final String title;
  final String message;
  final String source;
  final String timeAgo;

  factory Alert.fromJson(Map<String, dynamic> json) => Alert(
    id: (json['id'] as num).toInt(),
    severity: (json['severity'] as String? ?? 'info').toLowerCase(),
    state: (json['state'] as String? ?? 'active').toLowerCase(),
    title: json['title'] as String? ?? '',
    message: json['message'] as String? ?? '',
    source: json['source'] as String? ?? '',
    timeAgo: json['timeAgo'] as String? ?? '',
  );

  /// Se envía en mayúsculas, como lo guarda el backend (ACTIVE, RESOLVED...).
  Map<String, dynamic> toJson() => {
    'id': id,
    'severity': severity.toUpperCase(),
    'state': state.toUpperCase(),
    'title': title,
    'message': message,
    'source': source,
    'timeAgo': timeAgo,
  };
}
