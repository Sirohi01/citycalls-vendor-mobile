import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_navigator.dart';
import '../models/employee_models.dart';
import '../models/job_models.dart';
import '../providers/auth_providers.dart';
import '../providers/employee_providers.dart';
import '../providers/job_providers.dart';
import '../providers/notification_providers.dart';
import '../providers/sync_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/hero_header.dart';
import '../widgets/job_card.dart';
import '../widgets/live_location_card.dart';
import '../widgets/state_views.dart';
import '../widgets/ui_kit.dart';
import 'notification_center_screen.dart';
import 'sync_status_screen.dart';

// Field technician's Home — dark CityCalls header with today's numbers, then
// new job requests, today's route and the live-location card.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myEmployeeProfileProvider);
    final jobs = ref.watch(myJobsProvider);
    final completed = ref.watch(completedJobsProvider);

    final newJobs = jobs.valueOrNull
            ?.where((j) => newJobStatuses.contains(j.status))
            .toList() ??
        const <JobSummary>[];
    final today = DateTime.now();
    final doneToday = completed.valueOrNull
        ?.where((j) =>
            j.status != 'CANCELLED' &&
            j.status != 'REASSIGNMENT_REQUIRED' &&
            j.scheduledDate != null &&
            _isSameDay(j.scheduledDate!, today))
        .length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: RefreshIndicator(
          color: AppColors.green,
          onRefresh: () async {
            ref.invalidate(myEmployeeProfileProvider);
            ref.invalidate(allJobsProvider);
            ref.invalidate(unreadNotificationCountProvider);
            ref.read(syncEngineProvider).syncAll();
            await ref
                .read(allJobsProvider.future)
                .catchError((_) => <JobSummary>[]);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _Header(
                profile: profile,
                fallbackName: ref.watch(authProvider).user?.name,
                newCount: jobs.hasValue ? newJobs.length : null,
                activeCount: jobs.valueOrNull?.length,
                doneToday: doneToday,
              ),
              const _SyncBanner(),
              if (newJobs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UiSectionLabel('New job requests (${newJobs.length})'),
                      for (final j in newJobs)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: JobCard(job: j, highlight: true),
                        ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UiSectionLabel(
                      "Today's route",
                      trailing: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => pendingShellTab.value = ShellTab.myJobs,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text('See all',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.green)),
                        ),
                      ),
                    ),
                    jobs.when(
                      data: (items) {
                        final rest = items
                            .where((j) => !newJobStatuses.contains(j.status))
                            .toList();
                        if (rest.isEmpty) {
                          return const UiCard(
                            child: UiEmptyState(
                              icon: Icons.task_alt_rounded,
                              title: 'No active jobs right now',
                              message:
                                  'New jobs assigned to you will show up here.',
                            ),
                          );
                        }
                        final todays = rest
                            .where((j) =>
                                j.scheduledDate != null &&
                                _isSameDay(j.scheduledDate!, today))
                            .toList()
                          ..sort((a, b) =>
                              a.scheduledDate!.compareTo(b.scheduledDate!));
                        final preview =
                            (todays.isNotEmpty ? todays : rest).take(4);
                        return Column(
                          children: [
                            for (final j in preview)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: JobCard(job: j),
                              ),
                          ],
                        );
                      },
                      loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Center(child: CircularProgressIndicator())),
                      error: (err, __) => UiCard(
                        child: AppErrorView(
                            error: err,
                            compact: true,
                            onRetry: () => ref.invalidate(allJobsProvider)),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UiSectionLabel('Your location'),
                    LiveLocationCard(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    final l = a.toLocal();
    return l.year == b.year && l.month == b.month && l.day == b.day;
  }
}

class _Header extends ConsumerWidget {
  final AsyncValue<EmployeeProfile> profile;
  final String? fallbackName;
  final int? newCount;
  final int? activeCount;
  final int? doneToday;
  const _Header({
    required this.profile,
    required this.fallbackName,
    required this.newCount,
    required this.activeCount,
    required this.doneToday,
  });

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
    final p = profile.valueOrNull;
    final name = (p?.name.isNotEmpty ?? false) ? p!.name : (fallbackName ?? '');
    final place = p == null
        ? null
        : [p.branchName, p.subBranchName, p.teamName]
            .whereType<String>()
            .join(' • ');

    return HeroHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Wordmark(size: 24),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.heroLime.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('FIELD',
                    style: TextStyle(
                        color: AppColors.heroLime,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2)),
              ),
              const Spacer(),
              HeroIconButton(
                icon: Icons.notifications_none_rounded,
                tooltip: 'Notifications',
                badge: unread,
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(
                        builder: (_) => const NotificationCenterScreen()))
                    .then(
                        (_) => ref.invalidate(unreadNotificationCountProvider)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(_greeting(),
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 13.5)),
          const SizedBox(height: 2),
          Text(name.isEmpty ? 'Welcome back' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
          if (place != null && place.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.store_mall_directory_outlined,
                    size: 14, color: AppColors.heroLime),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(place,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12.5)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: HeroStat(
                  icon: Icons.notifications_active_outlined,
                  label: 'New',
                  value: newCount,
                  highlight: (newCount ?? 0) > 0,
                  onTap: () => pendingShellTab.value = ShellTab.myJobs,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: HeroStat(
                  icon: Icons.work_outline_rounded,
                  label: 'Active',
                  value: activeCount,
                  onTap: () => pendingShellTab.value = ShellTab.myJobs,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: HeroStat(
                  icon: Icons.task_alt_rounded,
                  label: 'Done today',
                  value: doneToday,
                  onTap: () => pendingShellTab.value = ShellTab.history,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Shown only while offline actions are queued or were rejected — tapping
// opens the Sync Status screen.
class _SyncBanner extends ConsumerWidget {
  const _SyncBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queued = ref
            .watch(pendingActionsProvider)
            .valueOrNull
            ?.where((a) => a.status != 'SYNCED')
            .toList() ??
        const [];
    if (queued.isEmpty) return const SizedBox.shrink();
    final rejected = queued.where((a) => a.status == 'REJECTED').length;
    final color = rejected > 0 ? AppColors.urgent : AppColors.warning;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: UiCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        color: color.withValues(alpha: 0.06),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const SyncStatusScreen())),
        child: Row(
          children: [
            UiIconTile(
                icon: rejected > 0 ? Icons.sync_problem_rounded : Icons.sync,
                color: color,
                size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                rejected > 0
                    ? '$rejected action(s) need your attention'
                    : '${queued.length} action(s) waiting for internet to sync',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: color),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }
}
