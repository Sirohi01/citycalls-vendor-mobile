// Mirrors citycalls-api's Notification shape (notificationTemplates.model.ts's
// INotification) — the technician's own delivery history across all
// channels (push/in-app/etc.), not just unread ones.
class AppNotification {
  final String id;
  final String? subject;
  final String body;
  final String channel;
  final String status;
  final DateTime? readAt;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    this.subject,
    required this.body,
    required this.channel,
    required this.status,
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['_id'] as String,
      subject: json['subject'] as String?,
      body: json['body'] as String,
      channel: json['channel'] as String,
      status: json['status'] as String,
      readAt: json['readAt'] != null ? DateTime.tryParse(json['readAt'] as String) : null,
      createdAt: DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now(),
    );
  }
}
