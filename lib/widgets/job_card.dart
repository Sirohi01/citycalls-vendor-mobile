import 'package:flutter/material.dart';
import '../models/job_models.dart';
import '../screens/job_detail_screen.dart';
import '../theme/app_theme.dart';
import 'ui_kit.dart';

// One job in a list — used by Dashboard, My Jobs, History and the vendor
// owner's dashboard so a job always reads the same way. A status-coloured
// strip runs down the left edge. [highlight] marks a new assignment that
// still needs Accept/Reject; [compact] drops the customer/time rows.
class JobCard extends StatelessWidget {
  final JobSummary job;
  final bool highlight;
  final bool compact;
  const JobCard(
      {super.key,
      required this.job,
      this.highlight = false,
      this.compact = false});

  void _open(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: job.id)));

  @override
  Widget build(BuildContext context) {
    final accent = statusAccentColor(job.status);
    final urgent = job.priority == 'URGENT' || job.priority == 'HIGH';
    final when = [
      if (job.scheduledDate != null) formatRelativeDay(job.scheduledDate),
      if (job.scheduledSlot != null && job.scheduledSlot!.isNotEmpty)
        job.scheduledSlot!,
    ].join(' • ');

    return UiCard(
      padding: EdgeInsets.zero,
      radius: 22,
      onTap: () => _open(context),
      borderColor: highlight ? AppColors.urgent.withValues(alpha: 0.25) : null,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (highlight) ...[
                      const _NewRibbon(),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(job.serviceName ?? 'Service Request',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15.5,
                                  height: 1.25,
                                  letterSpacing: -0.2,
                                  color: AppColors.ink)),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('#${job.number}',
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.faint)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        UiPill(
                            text: newJobStatuses.contains(job.status)
                                ? 'Awaiting your response'
                                : jobStatusLabel(job.status),
                            color: accent,
                            dot: true),
                        if (urgent)
                          UiPill(
                              text: job.priority,
                              color: AppColors.urgent,
                              icon: Icons.bolt_rounded),
                      ],
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _Avatar(name: job.customerName ?? 'C'),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(job.customerName ?? 'Customer',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.ink2)),
                                if (job.city.isNotEmpty)
                                  Row(
                                    children: [
                                      const Icon(Icons.place_rounded,
                                          size: 13, color: AppColors.faint),
                                      const SizedBox(width: 2),
                                      Expanded(
                                        child: Text(job.city,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.muted)),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (when.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.page,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.schedule_rounded,
                                  size: 15, color: AppColors.slate500),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(when,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.slate700)),
                              ),
                              const Icon(Icons.arrow_forward_rounded,
                                  size: 16, color: AppColors.faint),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewRibbon extends StatelessWidget {
  const _NewRibbon();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFE11D48), Color(0xFFF97316)]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_active_rounded,
              size: 13, color: Colors.white),
          SizedBox(width: 5),
          Flexible(child: Text('NEW REQUEST · RESPOND NOW',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6))),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  static const _palette = [
    Color(0xFF16A34A),
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFFD97706),
    Color(0xFF0891B2),
  ];

  @override
  Widget build(BuildContext context) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? '?'
        : (parts.first[0] + (parts.length > 1 ? parts.last[0] : ''))
            .toUpperCase();
    final color = _palette[name.hashCode.abs() % _palette.length];
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(initials,
          style: TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
    );
  }
}
