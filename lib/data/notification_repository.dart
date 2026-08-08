import 'api_client.dart';
import '../models/notification_models.dart';

// Online-only, same as estimate_repository.dart/invoice_repository.dart.
// Backs the Notification Center screen — GET /notifications already existed
// server-side (per docs/11-complete-api-contracts.md's Notifications row),
// this app just wasn't consuming it yet.
class NotificationRepository {
  final ApiClient _client;
  NotificationRepository(this._client);

  Future<List<AppNotification>> listNotifications() async {
    final res = await _client.dio.get('/notifications', queryParameters: {'limit': 50});
    return (res.data['data'] as List).map((n) => AppNotification.fromJson(n as Map<String, dynamic>)).toList();
  }

  Future<int> unreadCount() async {
    final res = await _client.dio.get('/notifications/unread-count');
    return (res.data['data']['count'] as num).toInt();
  }

  Future<void> markRead(String id) async {
    await _client.dio.patch('/notifications/$id/read');
  }
}
