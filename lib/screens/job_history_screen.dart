import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job_models.dart';
import '../providers/job_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/job_card.dart';
import '../widgets/state_views.dart';
import '../widgets/ui_kit.dart';

// Per docs/rohit/06-vendor-app-screen-list.md "History" — the technician's
// own paid/closed/cancelled jobs, newest first and grouped by day, with a
// summary of how they've done.
class JobHistoryScreen extends ConsumerWidget {
  const JobHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(completedJobsProvider);

    return Scaffold(
      body: Column(
        children: [
          const UiPageHeader(
              title: 'History', subtitle: 'Jobs you have finished'),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.green,
              onRefresh: () async {
                ref.invalidate(allJobsProvider);
                await ref
                    .read(allJobsProvider.future)
                    .catchError((_) => <JobSummary>[]);
              },
              child: jobs.when(
                data: (items) {
                  if (items.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 80),
                        UiEmptyState(
                          icon: Icons.history_rounded,
                          title: 'No completed jobs yet',
                          message: 'Jobs you finish will be listed here.',
                        ),
                      ],
                    );
                  }
                  final sorted = [...items]..sort((a, b) {
                      final aTime =
                          a.scheduledDate?.millisecondsSinceEpoch ?? 0;
                      final bTime =
                          b.scheduledDate?.millisecondsSinceEpoch ?? 0;
                      return bTime.compareTo(aTime);
                    });
                  final done = items
                      .where((j) => j.status == 'PAID' || j.status == 'CLOSED')
                      .length;
                  final now = DateTime.now();
                  final thisMonth = items.where((j) {
                    final d = j.scheduledDate?.toLocal();
                    return d != null &&
                        d.year == now.year &&
                        d.month == now.month &&
                        (j.status == 'PAID' || j.status == 'CLOSED');
                  }).length;

                  // Group by day label, keeping newest-first order.
                  final groups = <String, List<JobSummary>>{};
                  for (final j in sorted) {
                    final key = j.scheduledDate == null
                        ? 'Earlier'
                        : formatRelativeDay(j.scheduledDate);
                    groups.putIfAbsent(key, () => []).add(j);
                  }

                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                        16, 8, 16, bottomNavClearance(context)),
                    children: [
                      _Summary(
                          done: done,
                          other: items.length - done,
                          thisMonth: thisMonth),
                      const SizedBox(height: 22),
                      for (final entry in groups.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 10),
                          child: Text(entry.key.toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.9,
                                  color: AppColors.faint)),
                        ),
                        for (final j in entry.value)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: JobCard(job: j, compact: true),
                          ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, __) => ListView(
                  children: [
                    const SizedBox(height: 80),
                    AppErrorView(
                        error: err,
                        onRetry: () => ref.invalidate(allJobsProvider)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final int done;
  final int other;
  final int thisMonth;
  const _Summary(
      {required this.done, required this.other, required this.thisMonth});

  @override
  Widget build(BuildContext context) {
    Widget cell(String value, String label, Color color) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: color)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.6))),
            ],
          ),
        );
    Widget divider() => Container(
        width: 1,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 14),
        color: Colors.white.withValues(alpha: 0.12));

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroDark, AppColors.heroDark3],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadows.raised,
      ),
      child: Row(
        children: [
          cell('$done', 'Completed', AppColors.lime400),
          divider(),
          cell('$thisMonth', 'This month', Colors.white),
          divider(),
          cell('$other', 'Cancelled', Colors.white),
        ],
      ),
    );
  }
}
