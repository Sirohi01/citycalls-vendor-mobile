import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sync_providers.dart';
import '../sync/local_database.dart';
import '../theme/app_theme.dart';

// Per docs/rohit/06-vendor-app-screen-list.md "Sync" — Sync Status / Sync
// Issues (Conflict Resolution). Per docs/manish/09-vendor-app-functional-plan.md
// §3: a REJECTED (conflict) action shows the server's rejection message and
// offers Discard or Retry against current state — never auto-resolved.
class SyncStatusScreen extends ConsumerWidget {
  const SyncStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.watch(pendingActionsProvider);

    return Scaffold(
      backgroundColor: AppColors.bgWarm,
      appBar: AppBar(
        title: const Text('Sync Status'),
        actions: [
          IconButton(
            tooltip: 'Sync Now',
            icon: const Icon(Icons.sync),
            onPressed: () async {
              await ref.read(syncEngineProvider).syncAll();
              ref.invalidate(pendingActionsProvider);
            },
          ),
        ],
      ),
      body: actions.when(
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                Icon(Icons.cloud_done_outlined, size: 56, color: AppColors.success),
                SizedBox(height: 12),
                Center(child: Text('Nothing queued — everything is synced.', style: TextStyle(color: AppColors.slate500))),
              ],
            );
          }
          final pending = items.where((a) => a.status == 'PENDING').toList();
          final rejected = items.where((a) => a.status == 'REJECTED').toList();
          final synced = items.where((a) => a.status == 'SYNCED').toList();
          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(syncEngineProvider).syncAll();
              ref.invalidate(pendingActionsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (rejected.isNotEmpty) ..._section(context, ref, 'Needs Attention — Rejected', rejected, AppColors.urgent),
                if (pending.isNotEmpty) ..._section(context, ref, 'Waiting to Sync', pending, AppColors.warning),
                if (synced.isNotEmpty) ..._section(context, ref, 'Synced', synced, AppColors.success),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, __) => Center(child: Text('Could not load sync queue: $err', style: const TextStyle(color: AppColors.slate500))),
      ),
    );
  }

  List<Widget> _section(BuildContext context, WidgetRef ref, String title, List<PendingAction> items, Color color) {
    return [
      Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 10),
      ...items.map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              borderColor: a.status == 'REJECTED' ? AppColors.urgent.withValues(alpha: 0.4) : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_iconFor(a.actionType), size: 18, color: color),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_labelFor(a.actionType), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
                      Text(_timeAgo(a.clientTimestamp), style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Job #${a.jobId.substring(a.jobId.length - 6)}', style: const TextStyle(fontSize: 11.5, color: AppColors.slate500)),
                  if (a.resultMessage != null) ...[
                    const SizedBox(height: 6),
                    Text(a.resultMessage!, style: TextStyle(fontSize: 12, color: a.status == 'REJECTED' ? AppColors.urgent : AppColors.slate700)),
                  ],
                  if (a.status == 'REJECTED') ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              await ref.read(syncRepositoryProvider).discard(a.id);
                              ref.invalidate(pendingActionsProvider);
                            },
                            child: const Text('Discard'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              final retried = await ref.read(syncRepositoryProvider).retryRejected(a.id);
                              await ref.read(syncEngineProvider).syncJob(retried.jobId);
                              ref.invalidate(pendingActionsProvider);
                            },
                            child: const Text('Retry'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          )),
      const SizedBox(height: 12),
    ];
  }

  IconData _iconFor(String actionType) {
    switch (actionType) {
      case 'STATUS_CHANGE':
        return Icons.swap_horiz;
      case 'UPDATE_INSPECTION':
        return Icons.fact_check_outlined;
      case 'UPDATE_WORK':
        return Icons.build_outlined;
      case 'COMPLETE_VISIT':
        return Icons.task_alt;
      default:
        return Icons.sync;
    }
  }

  String _labelFor(String actionType) {
    switch (actionType) {
      case 'STATUS_CHANGE':
        return 'Status Update';
      case 'UPDATE_INSPECTION':
        return 'Inspection Details';
      case 'UPDATE_WORK':
        return 'Work Progress';
      case 'COMPLETE_VISIT':
        return 'Job Completion';
      default:
        return actionType;
    }
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
