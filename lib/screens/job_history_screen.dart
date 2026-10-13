import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job_models.dart';
import '../providers/job_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/job_card.dart';
import '../widgets/state_views.dart';
import '../widgets/ui_kit.dart';

// Per docs/rohit/06-vendor-app-screen-list.md "History" — the technician's
// own paid/closed/cancelled jobs, newest first. Tapping through reuses
// JobDetailScreen (which shows no actions for a finished job).
class JobHistoryScreen extends ConsumerWidget {
  const JobHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(completedJobsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Job History'), titleSpacing: 16),
      body: RefreshIndicator(
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
                  SizedBox(height: 100),
                  UiEmptyState(
                    icon: Icons.history_rounded,
                    title: 'No completed jobs yet',
                    message: 'Jobs you finish will be listed here.',
                  ),
                ],
              );
            }
            final sorted = [...items]..sort((a, b) {
                final aTime = a.scheduledDate?.millisecondsSinceEpoch ?? 0;
                final bTime = b.scheduledDate?.millisecondsSinceEpoch ?? 0;
                return bTime.compareTo(aTime);
              });
            final paid = items
                .where((j) => j.status == 'PAID' || j.status == 'CLOSED')
                .length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                UiSectionLabel(
                    '$paid completed • ${items.length - paid} other'),
                for (final j in sorted)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: JobCard(job: j, compact: true),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, __) => ListView(
            children: [
              const SizedBox(height: 80),
              AppErrorView(
                  error: err, onRetry: () => ref.invalidate(allJobsProvider)),
            ],
          ),
        ),
      ),
    );
  }
}
