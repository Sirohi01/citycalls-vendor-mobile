// Mirrors citycalls-api's Notification shape (notificationTemplates.model.ts's
// INotification) — the technician's own delivery history.
//
// The backend stores ONE document per channel per event (IN_APP, PUSH, SMS,
// WHATSAPP, EMAIL), so a single "job assigned" event comes back as several
// rows. [AppNotification.group] folds those back into one entry per event.
class AppNotification {
  final String id;
  // Every channel document that belongs to this event — marking it read
  // marks all of them, so the unread count can actually reach zero.
  final List<String> ids;
  final String? subject;
  final String body;
  final String channel;
  final String status;
  final String? triggerKey;
  final DateTime? readAt;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    List<String>? ids,
    this.subject,
    required this.body,
    required this.channel,
    required this.status,
    this.triggerKey,
    this.readAt,
    required this.createdAt,
  }) : ids = ids ?? [id];

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['_id'] as String,
      subject: json['subject'] as String?,
      body: json['body'] as String? ?? '',
      channel: json['channel'] as String? ?? '',
      status: json['status'] as String? ?? '',
      triggerKey: json['triggerKey'] as String?,
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'] as String)
          : null,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  // Channel whose text reads best inside the app.
  static const _channelPreference = ['IN_APP', 'PUSH', 'WHATSAPP', 'SMS', 'EMAIL'];

  /// Folds per-channel copies of the same event (same triggerKey, created
  /// within two minutes of each other) into one entry, newest first. The
  /// entry is unread while any of its copies is unread.
  static List<AppNotification> group(List<AppNotification> raw) {
    final sorted = [...raw]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final groups = <List<AppNotification>>[];
    for (final n in sorted) {
      final match = n.triggerKey == null
          ? null
          : groups.where((g) {
              final head = g.first;
              return head.triggerKey == n.triggerKey &&
                  head.createdAt.difference(n.createdAt).inSeconds.abs() <=
                      120;
            }).firstOrNull;
      if (match != null) {
        match.add(n);
      } else {
        groups.add([n]);
      }
    }
    return groups.map((g) {
      int rank(AppNotification n) {
        final i = _channelPreference.indexOf(n.channel);
        return i < 0 ? 99 : i;
      }

      final best = ([...g]..sort((a, b) => rank(a).compareTo(rank(b)))).first;
      final unread = g.where((n) => !n.isRead).toList();
      return AppNotification(
        id: best.id,
        ids: unread.isEmpty ? g.map((n) => n.id).toList() : unread.map((n) => n.id).toList(),
        subject: g
            .map((n) => n.subject)
            .firstWhere((s) => s != null && s.isNotEmpty, orElse: () => null) ??
            best.subject,
        body: best.body,
        channel: best.channel,
        status: best.status,
        triggerKey: best.triggerKey,
        readAt: unread.isEmpty ? (best.readAt ?? g.first.readAt) : null,
        createdAt: g.first.createdAt,
      );
    }).toList();
  }
}
