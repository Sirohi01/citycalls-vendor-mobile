import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job_models.dart';
import '../providers/employee_providers.dart';
import '../providers/job_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/glow_blob.dart';
import 'job_detail_screen.dart';
import 'my_jobs_screen.dart';

// New "Dashboard" home tab — greeting + at-a-glance stats + today's route
// preview, distinct from My Jobs (the full filterable list). Per Manish's
// ask ("dashboard iska bhi rahega") on top of the existing My Jobs/History/
// Profile screens, mirroring the kind of home-dashboard pattern
// citycalls-customer-mobile's HomeScreen already established for that app.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myEmployeeProfileProvider);
    final jobs = ref.watch(myJobsProvider);
    final completed = ref.watch(completedJobsProvider);

    return Scaffold(
      backgroundColor: AppColors.slate100,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myEmployeeProfileProvider);
          ref.invalidate(myJobsProvider);
          ref.invalidate(completedJobsProvider);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Header(profile: profile, activeCount: jobs.value?.length, completedCount: completed.value?.length),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Today\'s Route', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: AppColors.slate900)),
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
                      if (items.isEmpty) {
                        return _EmptyTodayCard();
                      }
                      final today = DateTime.now();
                      final todays = items.where((j) => j.scheduledDate != null && _isSameDay(j.scheduledDate!, today)).toList()
                        ..sort((a, b) => a.scheduledDate!.compareTo(b.scheduledDate!));
                      final preview = (todays.isNotEmpty ? todays : items).take(3).toList();
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
  final int? completedCount;
  const _Header({required this.profile, this.activeCount, this.completedCount});

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
                        Expanded(child: _StatChip(icon: Icons.work_outline, label: 'Active', value: activeCount)),
                        const SizedBox(width: 10),
                        Expanded(child: _StatChip(icon: Icons.task_alt, label: 'Completed', value: completedCount)),
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
  const _StatChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value?.toString() ?? '—', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, height: 1.1)),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
            ],
          ),
        ],
      ),
    );
  }
}

class _JobPreviewCard extends StatelessWidget {
  final JobSummary job;
  const _JobPreviewCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final accent = statusAccentColor(job.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: glassCardDecoration(),
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
                    child: Icon(Icons.build_outlined, color: accent, size: 20),
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
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: glassCardDecoration(),
      child: const Column(
        children: [
          Icon(Icons.task_alt, size: 44, color: AppColors.slate400),
          SizedBox(height: 10),
          Text('No active jobs right now.', style: TextStyle(color: AppColors.slate500)),
        ],
      ),
    );
  }
}
