import 'package:flutter_test/flutter_test.dart';
import 'package:freshsense_mobile/alerts/domain/alert_model.dart';
import 'package:freshsense_mobile/monitoring/domain/monitoring_reading_model.dart';

void main() {
  test('La lectura del Edge incluye el etileno (gas)', () {
    final r = MonitoringReading.fromJson({
      'id': 1,
      'temperature': 4.5,
      'humidity': 70,
      'ethyleneLevel': 0.73,
      'recordedAt': '2026-11-08T01:15:00',
      'status': 'GREEN',
      'category': 'Frutas',
    });
    expect(r.ethyleneLevel, 0.73);
    expect(r.humidity, 70.0);
  });

  test('Las alertas se normalizan a minúsculas y se envían en mayúsculas', () {
    final a = Alert.fromJson({
      'id': 3,
      'severity': 'CRITICAL',
      'state': 'ACTIVE',
      'title': 't',
      'message': 'm',
      'source': 's',
      'timeAgo': '1m',
    });
    expect(a.state, 'active');
    a.state = 'resolved';
    expect(a.toJson()['state'], 'RESOLVED');
  });
}
