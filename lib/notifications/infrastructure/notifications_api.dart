import 'package:dio/dio.dart';

import '../../environments/environment.dart';
import '../domain/notification_model.dart';

class NotificationPreference {
  const NotificationPreference({
    this.userId,
    required this.inAppEnabled,
    required this.emailEnabled,
    required this.pushEnabled,
    this.quietStart,
    this.quietEnd,
  });

  final int? userId;
  final bool inAppEnabled;
  final bool emailEnabled;
  final bool pushEnabled;
  final String? quietStart;
  final String? quietEnd;

  factory NotificationPreference.fromJson(Map<String, dynamic> json) => NotificationPreference(
    userId: (json['userId'] as num?)?.toInt(),
    inAppEnabled: json['inAppEnabled'] as bool? ?? true,
    emailEnabled: json['emailEnabled'] as bool? ?? false,
    pushEnabled: json['pushEnabled'] as bool? ?? false,
    quietStart: json['quietStart'] as String?,
    quietEnd: json['quietEnd'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'inAppEnabled': inAppEnabled,
    'emailEnabled': emailEnabled,
    'pushEnabled': pushEnabled,
    'quietStart': quietStart,
    'quietEnd': quietEnd,
  };
}

/// Equivalente a `notifications/infrastructure/notifications-api.ts`.
class NotificationsApi {
  NotificationsApi(this._http);

  final Dio _http;
  static const _base = Environment.apiBaseUrl;

  Future<List<AppNotification>> getInbox() async {
    final res = await _http.get('$_base/notifications');
    return (res.data as List? ?? []).map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> markAsRead(int id) => _http.patch('$_base/notifications/$id/read', data: {});

  Future<NotificationPreference> getPreferences() async {
    final res = await _http.get('$_base/notifications/preferences');
    return NotificationPreference.fromJson(res.data as Map<String, dynamic>);
  }

  Future<NotificationPreference> updatePreferences(NotificationPreference prefs) async {
    final res = await _http.put('$_base/notifications/preferences', data: prefs.toJson());
    return NotificationPreference.fromJson(res.data as Map<String, dynamic>);
  }
}
