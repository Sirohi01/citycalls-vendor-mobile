import 'package:flutter/material.dart';
import '../models/job_models.dart';
import '../screens/job_detail_screen.dart';
import '../theme/app_theme.dart';
import 'ui_kit.dart';

// One job in a list — used by Dashboard, My Jobs, History and the vendor
// owner's dashboard so a job always reads the same way. [highlight] marks
// a new assignment that still needs Accept/Reject.
class JobCard extends StatelessWidget {
  final JobSummary job;
  final bool highlight;
  final bool compact;
  const JobCard(
      {super.key,
      required this.job,
      this.highlight = false,
      this.compact = false});

  @override
  Widget build(BuildContext context) {
    final accent = statusAccentColor(job.status);
    final urgent = job.priority == 'URGENT' || job.priority == 'HIGH';
    final when = [
      if (job.scheduledDate != null) formatDisplayDate(job.scheduledDate),
      if (job.scheduledSlot != null && job.scheduledSlot!.isNotEmpty)
        job.scheduledSlot!,
    ].join(' • ');

    return UiCard(
      padding: const EdgeInsets.all(14),
      color: highlight ? const Color(0xFFFFFBF5) : null,
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: job.id))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UiIconTile(
                icon: highlight
                    ? Icons.notifications_active_outlined
                    : Icons.build_outlined,
                color: accent,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.serviceName ?? 'Service Request',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Text('#${job.number}',
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              ),
              if (urgent)
                UiPill(
                    text: job.priority,
                    color: AppColors.urgent,
                    icon: Icons.priority_high_rounded),
              if (!urgent)
                const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 12),
            _Line(
                icon: Icons.person_outline_rounded,
                text: job.customerName ?? 'Customer'),
            if (job.city.isNotEmpty)
              _Line(icon: Icons.location_on_outlined, text: job.city),
            if (when.isNotEmpty)
              _Line(icon: Icons.schedule_rounded, text: when),
          ],
          const SizedBox(height: 10),
          UiPill(text: jobStatusLabel(job.status), color: accent),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Line({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.faint),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 13, color: AppColors.slate700)),
          ),
        ],
      ),
    );
  }
}
