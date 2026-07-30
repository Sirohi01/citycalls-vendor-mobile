import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job_models.dart';
import '../providers/employee_providers.dart';
import '../providers/job_providers.dart';
import '../theme/app_theme.dart';
import 'job_detail_screen.dart';

// Per docs/rohit/06-vendor-app-screen-list.md "Job Management" — My Jobs
// (today's route, ordered by scheduled slot). Real data via
// GET /service-requests, scoped server-side to this technician's own
// assigned jobs (serviceRequests.service.ts) — nothing hardcoded/mocked.
class MyJobsScreen extends ConsumerWidget {
  const MyJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(myJobsProvider);
    final profile = ref.watch(myEmployeeProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.slate100,
      appBar: AppBar(
        title: profile.when(
          data: (p) => Text('Hi, ${p.name.split(' ').first}'),
          loading: () => const Text('My Jobs'),
          error: (_, __) => const Text('My Jobs'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myJobsProvider);
          ref.invalidate(myEmployeeProfileProvider);
        },
        child: jobs.when(
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.task_alt, size: 56, color: AppColors.slate400),
                  SizedBox(height: 12),
                  Center(child: Text('No active jobs right now.', style: TextStyle(color: AppColors.slate500))),
                ],
              );
            }
            final sorted = [...items]..sort((a, b) {
                final aTime = a.scheduledDate?.millisecondsSinceEpoch ?? a.slaDueAt?.millisecondsSinceEpoch ?? 0;
                final bTime = b.scheduledDate?.millisecondsSinceEpoch ?? b.slaDueAt?.millisecondsSinceEpoch ?? 0;
                return aTime.compareTo(bTime);
              });
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _JobCard(job: sorted[i]),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, __) => Center(child: Text('Could not load jobs: $err', style: const TextStyle(color: AppColors.slate500))),
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final JobSummary job;
  const _JobCard({required this.job});

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(job.serviceName ?? 'Service Request', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  if (job.priority == 'URGENT' || job.priority == 'HIGH')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.urgent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text(job.priority, style: const TextStyle(color: AppColors.urgent, fontSize: 10.5, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text('#${job.number}', style: const TextStyle(color: AppColors.slate500, fontSize: 12)),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 15, color: AppColors.slate500),
                  const SizedBox(width: 5),
                  Expanded(child: Text(job.customerName ?? 'Customer', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 15, color: AppColors.slate500),
                  const SizedBox(width: 5),
                  Expanded(child: Text(job.city, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                ],
              ),
              if (job.scheduledDate != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 15, color: AppColors.slate500),
                    const SizedBox(width: 5),
                    Text(
                      '${job.scheduledDate!.day}/${job.scheduledDate!.month}${job.scheduledSlot != null ? ' • ${job.scheduledSlot}' : ''}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(jobStatusLabel(job.status), style: TextStyle(color: accent, fontSize: 11.5, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
