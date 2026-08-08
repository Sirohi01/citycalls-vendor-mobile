import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/notification_repository.dart';
import '../models/notification_models.dart';
import 'auth_providers.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(apiClientProvider));
});

final notificationsProvider = FutureProvider<List<AppNotification>>((ref) {
  return ref.watch(notificationRepositoryProvider).listNotifications();
});

final unreadNotificationCountProvider = FutureProvider<int>((ref) {
  return ref.watch(notificationRepositoryProvider).unreadCount();
});
