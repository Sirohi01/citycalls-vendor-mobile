import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_navigator.dart';
import '../models/employee_models.dart';
import '../models/job_models.dart';
import '../providers/auth_providers.dart';
import '../providers/employee_providers.dart';
import '../providers/job_providers.dart';
import '../providers/notification_providers.dart';
import '../providers/sync_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/hero_header.dart';
import '../widgets/job_card.dart';
import '../widgets/live_location_card.dart';
import '../widgets/state_views.dart';
import '../widgets/ui_kit.dart';
import 'job_detail_screen.dart';
import 'notification_center_screen.dart';
import 'sync_status_screen.dart';

// Field technician's Home — brand header with today's progress, the next job
// to work on, new requests, quick actions, the rest of today's route and the
// live-location map.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static bool _isToday(DateTime? d) {
    if (d == null) return false;
    final l = d.toLocal();
    final now = DateTime.now();
    return l.year == now.year && l.month == now.month && l.day == now.day;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myEmployeeProfileProvider);
    final jobs = ref.watch(myJobsProvider);
    final completed = ref.watch(completedJobsProvider);

    final active = jobs.valueOrNull ?? const <JobSummary>[];
    final newJobs =
        active.where((j) => newJobStatuses.contains(j.status)).toList();
    final working = active
        .where((j) => !newJobStatuses.contains(j.status))
        .toList()
      ..sort((a, b) {
        final at = a.scheduledDate ?? a.slaDueAt ?? DateTime(2100);
        final bt = b.scheduledDate ?? b.slaDueAt ?? DateTime(2100);
        return at.compareTo(bt);
      });
    final upNext = working.isEmpty ? null : working.first;
    final todaysRest = working
        .skip(1)
        .where((j) => _isToday(j.scheduledDate))
        .toList();
    final restToShow =
        (todaysRest.isNotEmpty ? todaysRest : working.skip(1)).take(3).toList();

    final doneToday = completed.valueOrNull
            ?.where((j) =>
                (j.status == 'PAID' || j.status == 'CLOSED') &&
                _isToday(j.scheduledDate))
            .length ??
        0;
    final todayTotal =
        doneToday + active.where((j) => _isToday(j.scheduledDate)).length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: RefreshIndicator(
          color: AppColors.green,
          edgeOffset: MediaQuery.of(context).padding.top,
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
            padding: EdgeInsets.only(bottom: bottomNavClearance(context)),
            children: [
              _Header(
                profile: profile,
                fallbackName: ref.watch(authProvider).user?.name,
                newCount: jobs.hasValue ? newJobs.length : null,
                activeCount: jobs.hasValue ? active.length : null,
                doneToday: completed.hasValue ? doneToday : null,
                todayTotal: todayTotal,
              ),
              const _SyncBanner(),
              if (jobs.isLoading && !jobs.hasValue)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (jobs.hasError && !jobs.hasValue)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: UiCard(
                    child: AppErrorView(
                        error: jobs.error!,
                        compact: true,
                        onRetry: () => ref.invalidate(allJobsProvider)),
                  ),
                )
              else ...[
                if (newJobs.isNotEmpty)
                  _Section(
                    title: 'New requests',
                    subtitle: 'Accept or reject to keep your rating high',
                    child: Column(
                      children: [
                        for (final j in newJobs)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: JobCard(job: j, highlight: true),
                          ),
                      ],
                    ),
                  ),
                _Section(
                  title: 'Up next',
                  child: upNext == null
                      ? const UiCard(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: UiEmptyState(
                            icon: Icons.task_alt_rounded,
                            title: "You're all caught up",
                            message:
                                'New jobs assigned to you will show up here.',
                          ),
                        )
                      : _UpNextCard(job: upNext),
                ),
                const _Section(title: 'Quick actions', child: _QuickActions()),
                if (restToShow.isNotEmpty)
                  _Section(
                    title: todaysRest.isNotEmpty
                        ? "Today's route"
                        : 'Coming up',
                    trailing: UiLinkButton('See all',
                        onTap: () => pendingShellTab.value = ShellTab.myJobs),
                    child: Column(
                      children: [
                        for (final j in restToShow)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: JobCard(job: j),
                          ),
                      ],
                    ),
                  ),
              ],
              const _Section(title: 'Your location', child: LiveLocationCard()),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  const _Section(
      {required this.title, required this.child, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UiSectionLabel(title, subtitle: subtitle, trailing: trailing),
          child,
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  final AsyncValue<EmployeeProfile> profile;
  final String? fallbackName;
  final int? newCount;
  final int? activeCount;
  final int? doneToday;
  final int todayTotal;
  const _Header({
    required this.profile,
    required this.fallbackName,
    required this.newCount,
    required this.activeCount,
    required this.doneToday,
    required this.todayTotal,
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
    final name =
        (p?.name.isNotEmpty ?? false) ? p!.name : (fallbackName ?? '');
    final firstName = name.trim().split(RegExp(r'\s+')).first;
    final place = p == null
        ? null
        : [p.branchName, p.teamName].whereType<String>().join(' • ');
    final done = doneToday ?? 0;
    final progress = todayTotal == 0 ? 0.0 : done / todayTotal;

    return HeroHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Wordmark(size: 24),
              const SizedBox(width: 8),
              const HeroTag('FIELD'),
              const Spacer(),
              HeroIconButton(
                icon: Icons.notifications_none_rounded,
                tooltip: 'Notifications',
                badge: unread,
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(
                        builder: (_) => const NotificationCenterScreen()))
                    .then((_) =>
                        ref.invalidate(unreadNotificationCountProvider)),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text('${_greeting()},',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(firstName.isEmpty ? 'Welcome back' : firstName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  letterSpacing: -0.8,
                  fontWeight: FontWeight.w800)),
          if (place != null && place.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.storefront_rounded,
                    size: 14, color: Colors.white.withValues(alpha: 0.5)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(place,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          // Today's progress.
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text("Today's progress",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text.rich(TextSpan(children: [
                      TextSpan(
                          text: '$done',
                          style: const TextStyle(
                              color: AppColors.lime400,
                              fontWeight: FontWeight.w800)),
                      TextSpan(
                          text: ' / $todayTotal jobs',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w600)),
                    ]), style: const TextStyle(fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    children: [
                      Container(
                          height: 8,
                          color: Colors.white.withValues(alpha: 0.10)),
                      FractionallySizedBox(
                        widthFactor: progress.clamp(0.0, 1.0),
                        child: Container(
                          height: 8,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [
                              AppColors.green,
                              AppColors.lime400
                            ]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: HeroStat(
                  icon: Icons.notifications_active_rounded,
                  label: 'New',
                  value: newCount,
                  highlight: (newCount ?? 0) > 0,
                  onTap: () => pendingShellTab.value = ShellTab.myJobs,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: HeroStat(
                  icon: Icons.handyman_rounded,
                  label: 'Active',
                  value: activeCount,
                  onTap: () => pendingShellTab.value = ShellTab.myJobs,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: HeroStat(
                  icon: Icons.verified_rounded,
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

// The single most important card on Home: the next job to work on, with its
// status, customer, time and the two things a technician does first.
class _UpNextCard extends StatelessWidget {
  final JobSummary job;
  const _UpNextCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final accent = statusAccentColor(job.status);
    final when = [
      if (job.scheduledDate != null) formatRelativeDay(job.scheduledDate),
      if (job.scheduledSlot != null && job.scheduledSlot!.isNotEmpty)
        job.scheduledSlot!,
    ].join(' • ');
    void open() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: job.id)));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShadows.raised,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: open,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status band.
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    accent.withValues(alpha: 0.14),
                    accent.withValues(alpha: 0.03),
                  ]),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration:
                          BoxDecoration(color: accent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(jobStatusLabel(job.status),
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: accent)),
                    ),
                    Text('#${job.number}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.serviceName ?? 'Service Request',
                        style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: AppColors.ink)),
                    const SizedBox(height: 12),
                    _line(Icons.person_rounded, job.customerName ?? 'Customer'),
                    if (job.city.isNotEmpty)
                      _line(Icons.place_rounded, job.city),
                    if (when.isNotEmpty) _line(Icons.schedule_rounded, when),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (job.customerMobile != null) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 48)),
                              onPressed: () => launchUrl(
                                      Uri(
                                          scheme: 'tel',
                                          path: '+91${job.customerMobile}'),
                                      mode: LaunchMode.externalApplication)
                                  .catchError((_) => false),
                              icon: const Icon(Icons.call_rounded,
                                  size: 18, color: AppColors.green),
                              label: const Text('Call'),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 48),
                                backgroundColor: AppColors.green),
                            onPressed: open,
                            icon: const Icon(Icons.arrow_forward_rounded,
                                size: 18),
                            label: const Text('Open job'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.faint),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate700)),
            ),
          ],
        ),
      );
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queued = (ref.watch(pendingActionsProvider).valueOrNull ?? const [])
        .where((a) => a.status != 'SYNCED')
        .length;
    final unread = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
    void push(Widget screen) => Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen));

    return Row(
      children: [
        _QuickAction(
          icon: Icons.assignment_rounded,
          label: 'My Jobs',
          color: AppColors.green,
          onTap: () => pendingShellTab.value = ShellTab.myJobs,
        ),
        _QuickAction(
          icon: Icons.history_rounded,
          label: 'History',
          color: AppColors.info,
          onTap: () => pendingShellTab.value = ShellTab.history,
        ),
        _QuickAction(
          icon: Icons.cloud_sync_rounded,
          label: 'Sync',
          color: AppColors.violet,
          badge: queued,
          onTap: () => push(const SyncStatusScreen()),
        ),
        _QuickAction(
          icon: Icons.notifications_rounded,
          label: 'Alerts',
          color: AppColors.warning,
          badge: unread,
          onTap: () => push(const NotificationCenterScreen()),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int badge;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: UiCard(
          padding: const EdgeInsets.symmetric(vertical: 14),
          radius: 20,
          onTap: onTap,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  UiIconTile(icon: icon, color: color, size: 44),
                  if (badge > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        constraints: const BoxConstraints(minWidth: 18),
                        decoration: BoxDecoration(
                          color: AppColors.urgent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Text(badge > 9 ? '9+' : '$badge',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(label,
                  maxLines: 1,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink2)),
            ],
          ),
        ),
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
        color: Color.alphaBlend(color.withValues(alpha: 0.07), Colors.white),
        borderColor: color.withValues(alpha: 0.25),
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SyncStatusScreen())),
        child: Row(
          children: [
            UiIconTile(
                icon: rejected > 0
                    ? Icons.sync_problem_rounded
                    : Icons.cloud_upload_rounded,
                color: color,
                size: 38,
                filled: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rejected > 0
                        ? '$rejected action(s) need your attention'
                        : '${queued.length} action(s) waiting to sync',
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink),
                  ),
                  Text(
                    rejected > 0
                        ? 'Tap to review and retry'
                        : 'They will send when you are back online',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }
}
