import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_models.dart';
import '../providers/notification_providers.dart';
import '../theme/app_theme.dart';

// Per the vendor-app backlog's "Notification Center screen" item — push
// notifications already arrive (push_providers.dart), but there was no
// history/list screen. GET /notifications already existed server-side
// (used by other clients) — this app just wasn't consuming it yet.
class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(notificationsProvider);
          ref.invalidate(unreadNotificationCountProvider);
        },
        child: notificationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, __) => Center(child: Text('Could not load notifications: $err', style: const TextStyle(color: AppColors.urgent))),
          data: (notifications) => notifications.isEmpty
              ? ListView(
                  children: [
                    SizedBox(
                      height: 400,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_none, size: 48, color: secondaryTextColor(context)),
                            const SizedBox(height: 12),
                            Text('No notifications yet.', style: TextStyle(color: secondaryTextColor(context))),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _NotificationTile(notification: notifications[i]),
                ),
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final AppNotification notification;
  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: InkWell(
        onTap: notification.isRead
            ? null
            : () async {
                await ref.read(notificationRepositoryProvider).markRead(notification.id);
                ref.invalidate(notificationsProvider);
                ref.invalidate(unreadNotificationCountProvider);
              },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 5, right: 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: notification.isRead ? Colors.transparent : AppColors.primary,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (notification.subject != null && notification.subject!.isNotEmpty)
                    Text(
                      notification.subject!,
                      style: TextStyle(fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.bold, fontSize: 14),
                    ),
                  const SizedBox(height: 2),
                  Text(notification.body, style: TextStyle(fontSize: 13, color: strongSecondaryTextColor(context))),
                  const SizedBox(height: 6),
                  Text(_formatTime(notification.createdAt), style: TextStyle(fontSize: 11, color: secondaryTextColor(context))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
