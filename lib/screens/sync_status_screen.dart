import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job_models.dart';
import '../providers/job_providers.dart';
import '../providers/sync_providers.dart';
import '../sync/local_database.dart';
import '../theme/app_theme.dart';
import '../widgets/form_kit.dart';
import '../widgets/state_views.dart';
import '../widgets/ui_kit.dart';

// Per docs/rohit/06-vendor-app-screen-list.md "Sync" — Sync Status / Sync
// Issues. Per docs/manish/09-vendor-app-functional-plan.md §3: a REJECTED
// (conflict) action shows the server's rejection message and offers Discard
// or Retry against current state — never auto-resolved.
class SyncStatusScreen extends ConsumerStatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  ConsumerState<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends ConsumerState<SyncStatusScreen> {
  bool _syncing = false;

  Future<void> _syncNow() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    await ref.read(syncEngineProvider).syncAll();
    ref.invalidate(allJobsProvider);
    if (!mounted) return;
    setState(() => _syncing = false);
    final left = (ref.read(pendingActionsProvider).valueOrNull ?? const [])
        .where((a) => a.status == 'PENDING')
        .length;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(left == 0
            ? 'Everything is synced.'
            : '$left action(s) still waiting — check your internet.')));
  }

  @override
  Widget build(BuildContext context) {
    final actions = ref.watch(pendingActionsProvider);
    // Job numbers for the queue rows — the queue only stores the job's id.
    final numbers = {
      for (final j
          in ref.watch(allJobsProvider).valueOrNull ?? const <JobSummary>[])
        j.id: j.number
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Sync Status')),
      body: actions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, __) => Center(child: AppErrorView(error: err)),
        data: (items) {
          final pending = items.where((a) => a.status == 'PENDING').toList();
          final rejected = items.where((a) => a.status == 'REJECTED').toList();
          final synced = items.where((a) => a.status == 'SYNCED').toList();
          if (items.isEmpty) {
            return const UiEmptyState(
              icon: Icons.cloud_done_outlined,
              title: 'Everything is synced',
              message:
                  'Actions you take without internet wait here and are sent automatically when you are back online.',
            );
          }
          return RefreshIndicator(
            color: AppColors.green,
            onRefresh: _syncNow,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (rejected.isNotEmpty) ...[
                  const UiSectionLabel('Needs your attention'),
                  for (final a in rejected) _tile(a, numbers, AppColors.urgent),
                  const SizedBox(height: 12),
                ],
                if (pending.isNotEmpty) ...[
                  const UiSectionLabel('Waiting to sync'),
                  for (final a in pending) _tile(a, numbers, AppColors.warning),
                  const SizedBox(height: 12),
                ],
                if (synced.isNotEmpty) ...[
                  UiSectionLabel(
                    'Synced',
                    trailing: InkWell(
                      onTap: () =>
                          ref.read(syncRepositoryProvider).clearSynced(),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text('Clear',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.green)),
                      ),
                    ),
                  ),
                  for (final a in synced) _tile(a, numbers, AppColors.success),
                ],
              ],
            ),
          );
        },
      ),
      bottomNavigationBar:
          (actions.valueOrNull ?? const []).any((a) => a.status == 'PENDING')
              ? BottomActionBar(
                  child: FilledButton.icon(
                    onPressed: _syncing ? null : _syncNow,
                    icon: _syncing
                        ? const ButtonSpinner(color: AppColors.muted)
                        : const Icon(Icons.sync_rounded, size: 18),
                    label: Text(_syncing ? 'Syncing…' : 'Sync Now'),
                  ),
                )
              : null,
    );
  }

  Widget _tile(PendingAction a, Map<String, String> numbers, Color color) {
    final rejected = a.status == 'REJECTED';
    final jobLabel = numbers[a.jobId] != null
        ? 'Job #${numbers[a.jobId]}'
        : 'Job …${a.jobId.substring(a.jobId.length > 6 ? a.jobId.length - 6 : 0)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: UiCard(
        padding: const EdgeInsets.all(14),
        color: rejected ? AppColors.urgent.withValues(alpha: 0.04) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UiIconTile(
                    icon: _iconFor(a.actionType), color: color, size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_labelFor(a),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                              color: AppColors.ink)),
                      const SizedBox(height: 2),
                      Text('$jobLabel • ${_timeAgo(a.clientTimestamp)}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
            if (rejected && a.resultMessage != null) ...[
              const SizedBox(height: 10),
              Text(_readable(a.resultMessage!),
                  style: const TextStyle(
                      fontSize: 13, height: 1.35, color: AppColors.urgent)),
            ],
            if (rejected) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(64, 42)),
                      onPressed: () =>
                          ref.read(syncRepositoryProvider).discard(a.id),
                      child: const Text('Discard'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(64, 42)),
                      onPressed: () async {
                        final retried = await ref
                            .read(syncRepositoryProvider)
                            .retryRejected(a.id);
                        await ref
                            .read(syncEngineProvider)
                            .syncJob(retried.jobId);
                        ref.invalidate(allJobsProvider);
                      },
                      child: const Text('Try Again'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String actionType) {
    switch (actionType) {
      case 'STATUS_CHANGE':
        return Icons.swap_horiz_rounded;
      case 'UPDATE_INSPECTION':
        return Icons.fact_check_outlined;
      case 'UPDATE_WORK':
        return Icons.build_outlined;
      case 'ADD_PARTS':
        return Icons.inventory_2_outlined;
      case 'COMPLETE_VISIT':
        return Icons.task_alt_rounded;
      default:
        return Icons.sync_rounded;
    }
  }

  String _labelFor(PendingAction a) {
    switch (a.actionType) {
      case 'STATUS_CHANGE':
        try {
          final to = (jsonDecode(a.payloadJson) as Map)['toStatus'] as String?;
          if (to != null) return 'Mark as ${jobStatusLabel(to)}';
        } catch (_) {}
        return 'Status update';
      case 'UPDATE_INSPECTION':
        return 'Inspection details';
      case 'UPDATE_WORK':
        return 'Work progress';
      case 'ADD_PARTS':
        return 'Parts used';
      case 'COMPLETE_VISIT':
        return 'Job completion';
      default:
        return a.actionType.replaceAll('_', ' ').toLowerCase();
    }
  }

  // Server rejections name raw statuses ("…from ACCEPTED to WORK_STARTED");
  // show them the way the rest of the app labels them.
  String _readable(String message) => message.replaceAllMapped(
      RegExp(r'\b[A-Z]{3,}(?:_[A-Z]+)+\b|\bACCEPTED\b|\bPAID\b|\bCLOSED\b'),
      (m) => '"${jobStatusLabel(m[0]!)}"');

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day(s) ago';
  }
}
