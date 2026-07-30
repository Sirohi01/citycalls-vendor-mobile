import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job_models.dart';
import '../providers/job_providers.dart';
import '../theme/app_theme.dart';

// Per docs/rohit/06-vendor-app-screen-list.md "Job Management" — Job Detail.
// Read-only for now — the Execution flow (Accept/Reject, Start Travel,
// Inspection, Completion, etc. per docs/rohit/06 "Execution") is a separate,
// larger phase that needs the offline action-queue foundation
// (docs/manish/09-vendor-app-functional-plan.md §1-2) built first, since
// those actions must work with zero connectivity — not bolted on here.
class JobDetailScreen extends ConsumerWidget {
  final String jobId;
  const JobDetailScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref.watch(jobDetailProvider(jobId));

    return Scaffold(
      backgroundColor: AppColors.slate100,
      appBar: AppBar(title: const Text('Job Details')),
      body: job.when(
        data: (j) => _JobDetailBody(job: j),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, __) => Center(child: Text('Could not load this job: $err', style: const TextStyle(color: AppColors.slate500))),
      ),
    );
  }
}

class _JobDetailBody extends StatelessWidget {
  final JobDetail job;
  const _JobDetailBody({required this.job});

  @override
  Widget build(BuildContext context) {
    final accent = statusAccentColor(job.status);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(job.serviceName ?? 'Service Request', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(jobStatusLabel(job.status), style: TextStyle(color: accent, fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('#${job.number}', style: const TextStyle(color: AppColors.slate500, fontSize: 12.5)),
              if (job.scheduledDate != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 16, color: AppColors.slate500),
                    const SizedBox(width: 6),
                    Text(
                      '${job.scheduledDate!.day}/${job.scheduledDate!.month}/${job.scheduledDate!.year}${job.scheduledSlot != null ? ' • ${job.scheduledSlot}' : ''}',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Customer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              const SizedBox(height: 10),
              Row(children: [const Icon(Icons.person_outline, size: 17, color: AppColors.slate500), const SizedBox(width: 8), Text(job.customerName ?? '—')]),
              if (job.customerMobile != null) ...[
                const SizedBox(height: 8),
                Row(children: [const Icon(Icons.call_outlined, size: 17, color: AppColors.slate500), const SizedBox(width: 8), Text(job.customerMobile!)]),
              ],
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 17, color: AppColors.slate500),
                  const SizedBox(width: 8),
                  Expanded(child: Text(job.addressLine.isEmpty ? '—' : job.addressLine)),
                ],
              ),
            ],
          ),
        ),
        if (job.symptoms.isNotEmpty || (job.notes?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Issue Reported', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 10),
                if (job.symptoms.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: job.symptoms
                        .map((s) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(20)),
                              child: Text(s, style: const TextStyle(fontSize: 12.5)),
                            ))
                        .toList(),
                  ),
                if (job.notes?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 10),
                  Text(job.notes!, style: const TextStyle(color: AppColors.slate700, height: 1.4)),
                ],
              ],
            ),
          ),
        ],
        if (job.images.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Photos', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 84,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: job.images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(job.images[i], width: 84, height: 84, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(width: 84, height: 84, color: AppColors.slate100, child: const Icon(Icons.broken_image_outlined, color: AppColors.slate400))),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: child,
    );
  }
}
