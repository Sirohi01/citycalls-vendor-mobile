import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_models.dart';
import '../providers/notification_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';
import '../widgets/ui_kit.dart';

// The technician's notification history (GET /notifications) — job
// assignments and updates, whether or not the push itself was delivered.
class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  Future<void> _markAllRead(WidgetRef ref, List<AppNotification> unread) async {
    final repo = ref.read(notificationRepositoryProvider);
    await Future.wait(
        unread.map((n) => repo.markRead(n).catchError((_) {})));
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationCountProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final unread =
        notificationsAsync.valueOrNull?.where((n) => !n.isRead).toList() ??
            const <AppNotification>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread.isNotEmpty)
            TextButton(
              onPressed: () => _markAllRead(ref, unread),
              child: const Text('Mark all read'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.green,
        onRefresh: () async {
          ref.invalidate(notificationsProvider);
          ref.invalidate(unreadNotificationCountProvider);
          await ref
              .read(notificationsProvider.future)
              .catchError((_) => <AppNotification>[]);
        },
        child: notificationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, __) => ListView(
            children: [
              const SizedBox(height: 80),
              AppErrorView(
                  error: err,
                  onRetry: () => ref.invalidate(notificationsProvider)),
            ],
          ),
          data: (notifications) => notifications.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 100),
                    UiEmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: 'No notifications yet',
                      message: 'Job assignments and updates will show up here.',
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) =>
                      _NotificationTile(notification: notifications[i]),
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
    final n = notification;
    final hasSubject = n.subject != null && n.subject!.isNotEmpty;
    return UiCard(
      padding: const EdgeInsets.all(14),
      color: n.isRead ? null : const Color(0xFFF0FDF4),
      onTap: n.isRead
          ? null
          : () async {
              try {
                await ref.read(notificationRepositoryProvider).markRead(n);
              } catch (_) {
                // Stays unread; the next refresh reflects the real state.
              }
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadNotificationCountProvider);
            },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UiIconTile(
            icon: n.isRead
                ? Icons.notifications_none_rounded
                : Icons.notifications_active_rounded,
            color: n.isRead ? AppColors.faint : AppColors.green,
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasSubject)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(n.subject!,
                        style: TextStyle(
                            fontWeight:
                                n.isRead ? FontWeight.w600 : FontWeight.w700,
                            fontSize: 14.5,
                            color: AppColors.ink)),
                  ),
                if (n.body.isNotEmpty)
                  Text(n.body,
                      style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.slate700)),
                const SizedBox(height: 6),
                Text(_formatTime(n.createdAt),
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.faint)),
              ],
            ),
          ),
          if (!n.isRead)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(left: 8, top: 6),
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.green),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) return '${diff.inDays} day(s) ago';
    return formatDisplayDate(dt);
  }
}
