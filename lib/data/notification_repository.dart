import 'api_client.dart';
import '../models/notification_models.dart';

// Online-only. Backs the Notification Center and the unread badges.
//
// GET /notifications returns one document per channel per event and
// GET /notifications/unread-count counts all of them (including SMS/WhatsApp
// copies nothing ever marks read), so both the list and the badge are built
// here from the grouped list instead — see AppNotification.group.
class NotificationRepository {
  final ApiClient _client;
  NotificationRepository(this._client);

  Future<List<AppNotification>> listNotifications() async {
    final res = await _client.dio
        .get('/notifications', queryParameters: {'limit': 100});
    final raw = (res.data['data'] as List)
        .map((n) => AppNotification.fromJson(n as Map<String, dynamic>))
        .toList();
    return AppNotification.group(raw);
  }

  Future<int> unreadCount() async {
    final items = await listNotifications();
    return items.where((n) => !n.isRead).length;
  }

  /// Marks every channel copy of [notification] as read.
  Future<void> markRead(AppNotification notification) async {
    await Future.wait(notification.ids
        .map((id) => _client.dio.patch('/notifications/$id/read')));
  }
}
