import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/employee_models.dart';
import '../models/job_models.dart';
import '../providers/employee_providers.dart';
import '../providers/job_providers.dart';
import '../providers/sync_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/glow_blob.dart';
import 'job_detail_screen.dart';
import 'my_jobs_screen.dart';
import 'sync_status_screen.dart';

// "Dashboard" home tab — greeting + branch context + new-lead alerts +
// at-a-glance stats + today's route preview, distinct from My Jobs (the
// full filterable list). Per Manish's feedback that the first version was
// "bhut basic" — this pass adds the branch/team context strip, a dedicated
// "New Job Requests" section for ASSIGNED_TO_EMPLOYEE jobs (the actual
// moment "unke paas lead aata hai" — surfaced prominently since Accept/
// Reject is time-sensitive), and a second stats row.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myEmployeeProfileProvider);
    final jobs = ref.watch(myJobsProvider);
    final completed = ref.watch(completedJobsProvider);

    final pendingAcceptance = jobs.value?.where((j) => j.status == 'ASSIGNED_TO_EMPLOYEE').toList() ?? [];
    final urgentCount = jobs.value?.where((j) => j.priority == 'URGENT' || j.priority == 'HIGH').length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myEmployeeProfileProvider);
          ref.invalidate(myJobsProvider);
          ref.invalidate(completedJobsProvider);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Header(profile: profile, activeCount: jobs.value?.length, pendingCount: pendingAcceptance.length, completedCount: completed.value?.length),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: profile.when(
                data: (p) => _BranchStrip(profile: p),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
            Consumer(
              builder: (context, ref, _) {
                final pending = ref.watch(pendingActionsProvider);
                final queued = pending.value?.where((a) => a.status != 'SYNCED').toList() ?? [];
                if (queued.isEmpty) return const SizedBox.shrink();
                final rejected = queued.where((a) => a.status == 'REJECTED').length;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: GlassCard(
                    radius: 14,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    borderColor: rejected > 0 ? AppColors.urgent.withValues(alpha: 0.4) : null,
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SyncStatusScreen())),
                      child: Row(
                        children: [
                          Icon(rejected > 0 ? Icons.sync_problem : Icons.sync, size: 18, color: rejected > 0 ? AppColors.urgent : AppColors.warning),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              rejected > 0
                                  ? '$rejected action(s) need attention'
                                  : '${queued.length} action(s) waiting to sync',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: rejected > 0 ? AppColors.urgent : AppColors.slate700),
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 18, color: AppColors.slate400),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            if (pendingAcceptance.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notifications_active, color: AppColors.urgent, size: 18),
                        const SizedBox(width: 6),
                        Text('New Job Requests (${pendingAcceptance.length})', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('These need your Accept/Reject response.', style: TextStyle(fontSize: 12, color: AppColors.slate500)),
                    const SizedBox(height: 12),
                    Column(children: pendingAcceptance.map((j) => _JobPreviewCard(job: j, highlight: true)).toList()),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (urgentCount != null) ...[
                    Row(
                      children: [
                        Expanded(child: _MiniStat(icon: Icons.priority_high, label: 'Urgent / High Priority', value: urgentCount, color: AppColors.urgent)),
                        const SizedBox(width: 8),
                        Expanded(child: _MiniStat(icon: Icons.calendar_today_outlined, label: 'This Week Completed', value: completed.value?.length, color: AppColors.success)),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Today\'s Route', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyJobsScreen())),
                        style: TextButton.styleFrom(foregroundColor: AppColors.primary, padding: EdgeInsets.zero, minimumSize: Size.zero),
                        child: const Text('See all', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  jobs.when(
                    data: (items) {
                      final rest = items.where((j) => j.status != 'ASSIGNED_TO_EMPLOYEE').toList();
                      if (rest.isEmpty) {
                        return const _EmptyTodayCard();
                      }
                      final today = DateTime.now();
                      final todays = rest.where((j) => j.scheduledDate != null && _isSameDay(j.scheduledDate!, today)).toList()
                        ..sort((a, b) => a.scheduledDate!.compareTo(b.scheduledDate!));
                      final preview = (todays.isNotEmpty ? todays : rest).take(4).toList();
                      return Column(children: preview.map((j) => _JobPreviewCard(job: j)).toList());
                    },
                    loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: CircularProgressIndicator())),
                    error: (err, __) => Text('Could not load jobs: $err', style: const TextStyle(color: AppColors.slate500)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

class _Header extends StatelessWidget {
  final AsyncValue profile;
  final int? activeCount;
  final int pendingCount;
  final int? completedCount;
  const _Header({required this.profile, this.activeCount, required this.pendingCount, this.completedCount});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primary, AppColors.primaryDark]),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned(right: -60, top: -60, child: GlowBlob(color: AppColors.teal400, size: 200)),
                const Positioned(left: -70, bottom: -50, child: GlowBlob(color: AppColors.cyan400, size: 170)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    profile.when(
                      data: (p) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Good to see you', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 3),
                          Text(p.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                        ],
                      ),
                      loading: () => const SizedBox(height: 44),
                      error: (_, __) => const Text('Hi there', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: _StatChip(icon: Icons.mark_email_unread_outlined, label: 'New', value: pendingCount, badge: pendingCount > 0)),
                        const SizedBox(width: 8),
                        Expanded(child: _StatChip(icon: Icons.work_outline, label: 'Active', value: activeCount)),
                        const SizedBox(width: 10),
                        Expanded(child: _StatChip(icon: Icons.task_alt, label: 'Done', value: completedCount)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? value;
  final bool badge;
  const _StatChip({required this.icon, required this.label, required this.value, this.badge = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: badge ? Colors.white.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badge ? Colors.white.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(height: 6),
          Text(value?.toString() ?? '—', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, height: 1.1)),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
        ],
      ),
    );
  }
}

// Branch/sub-branch/team at a glance — the "abhi kuch pata hi nahi chalta"
// complaint was partly about not knowing which branch/team context a job
// falls under; this puts it right under the header, always visible.
class _BranchStrip extends StatelessWidget {
  final EmployeeProfile profile;
  const _BranchStrip({required this.profile});

  @override
  Widget build(BuildContext context) {
    final parts = [profile.branchName, profile.subBranchName, profile.teamName].where((s) => s != null).cast<String>().toList();
    if (parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GlassCard(
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.store_outlined, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(parts.join(' • '), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.slate700))),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? value;
  final Color color;
  const _MiniStat({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, height: 1.1)),
                Text(label, style: const TextStyle(color: AppColors.slate500, fontSize: 10.5), maxLines: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JobPreviewCard extends StatelessWidget {
  final JobSummary job;
  final bool highlight;
  const _JobPreviewCard({required this.job, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final accent = statusAccentColor(job.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        radius: 18,
        padding: EdgeInsets.zero,
        borderColor: highlight ? AppColors.urgent.withValues(alpha: 0.4) : null,
        borderWidth: highlight ? 1.4 : 1.2,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: job.id))),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                    child: Icon(highlight ? Icons.notifications_active_outlined : Icons.build_outlined, color: accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(job.serviceName ?? 'Service Request', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(
                          job.scheduledSlot != null ? '${job.customerName ?? ''} • ${job.scheduledSlot}' : job.customerName ?? '',
                          style: const TextStyle(color: AppColors.slate500, fontSize: 11.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.slate400),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyTodayCard extends StatelessWidget {
  const _EmptyTodayCard();

  @override
  Widget build(BuildContext context) {
    return const GlassCard(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.task_alt, size: 44, color: AppColors.slate400),
          SizedBox(height: 10),
          Text('No active jobs right now.', style: TextStyle(color: AppColors.slate500)),
        ],
      ),
    );
  }
}
