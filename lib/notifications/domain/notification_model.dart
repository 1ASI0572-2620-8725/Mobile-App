/// Equivalente a `notifications/domain/notification.model.ts`.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.channel,
    required this.isRead,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String title;
  final String message;
  final String channel;
  final bool isRead;
  final String createdAt;

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    userId: userId,
    title: title,
    message: message,
    channel: channel,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
  );

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: (json['id'] as num).toInt(),
    userId: (json['userId'] as num?)?.toInt() ?? 0,
    title: json['title'] as String? ?? '',
    message: json['message'] as String? ?? '',
    channel: json['channel'] as String? ?? '',
    isRead: json['isRead'] as bool? ?? json['read'] as bool? ?? false,
    createdAt: json['createdAt'] as String? ?? '',
  );
}
