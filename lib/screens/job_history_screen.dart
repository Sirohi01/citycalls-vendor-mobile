import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job_models.dart';
import '../providers/job_providers.dart';
import '../theme/app_theme.dart';
import 'job_detail_screen.dart';

// Per docs/rohit/06-vendor-app-screen-list.md "History" — Completed Jobs
// History. Read-only list of the technician's own completed/closed/paid/
// cancelled jobs; tapping through reuses the same JobDetailScreen as My Jobs
// (that doc's "Job Detail (past, read-only)" is functionally identical to
// the active-job detail view today, since Execution actions aren't built
// yet either way).
class JobHistoryScreen extends ConsumerWidget {
  const JobHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(completedJobsProvider);

    return Scaffold(
      backgroundColor: AppColors.slate100,
      appBar: AppBar(title: const Text('Job History')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(completedJobsProvider),
        child: jobs.when(
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.history, size: 56, color: AppColors.slate400),
                  SizedBox(height: 12),
                  Center(child: Text('No completed jobs yet.', style: TextStyle(color: AppColors.slate500))),
                ],
              );
            }
            final sorted = [...items]..sort((a, b) {
                final aTime = a.scheduledDate?.millisecondsSinceEpoch ?? 0;
                final bTime = b.scheduledDate?.millisecondsSinceEpoch ?? 0;
                return bTime.compareTo(aTime);
              });
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _HistoryCard(job: sorted[i]),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, __) => Center(child: Text('Could not load history: $err', style: const TextStyle(color: AppColors.slate500))),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final JobSummary job;
  const _HistoryCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final accent = statusAccentColor(job.status);
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: job.id))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(Icons.check, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.serviceName ?? 'Service Request', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('#${job.number} • ${job.customerName ?? ''}', style: const TextStyle(color: AppColors.slate500, fontSize: 12), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Text(jobStatusLabel(job.status), style: TextStyle(color: accent, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
