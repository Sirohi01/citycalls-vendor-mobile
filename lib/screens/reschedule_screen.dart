import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job_models.dart';
import '../models/visit_models.dart';
import '../providers/job_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/form_kit.dart';
import '../widgets/state_views.dart';
import '../widgets/ui_kit.dart';

// Move a visit to another day/slot agreed with the customer — PATCH
// /service-requests/:id/reschedule, from the same slot list the customer app
// books from (GET /appointment-slots). Allowed by the API from
// APPOINTMENT_SCHEDULED and CUSTOMER_UNAVAILABLE; an ACCEPTED job is first
// moved to APPOINTMENT_SCHEDULED.
class RescheduleScreen extends ConsumerStatefulWidget {
  final JobDetail job;
  const RescheduleScreen({super.key, required this.job});

  @override
  ConsumerState<RescheduleScreen> createState() => _RescheduleScreenState();
}

final _slotsProvider = FutureProvider.autoDispose
    .family<AppointmentSlots, (String, DateTime)>((ref, args) {
  return ref.watch(jobRepositoryProvider).getAppointmentSlots(args.$1, args.$2);
});

class _RescheduleScreenState extends ConsumerState<RescheduleScreen> {
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  late DateTime _date;
  String? _slot;
  final _reasonController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Default to tomorrow: a rescheduled visit is rarely later the same day,
    // and today's earlier slots may already have passed.
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day + 1);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_slot == null) {
      setState(() => _error = 'Pick a time slot.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repo = ref.read(jobRepositoryProvider);
      // RESCHEDULED is reachable from APPOINTMENT_SCHEDULED, not ACCEPTED.
      if (widget.job.status == 'ACCEPTED') {
        await repo.changeStatus(widget.job.id, 'APPOINTMENT_SCHEDULED');
      }
      await repo.reschedule(widget.job.id,
          date: _date, slot: _slot!, reason: _reasonController.text.trim());
      ref.invalidate(jobDetailProvider(widget.job.id));
      ref.invalidate(allJobsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Visit moved to ${_label(_date)}, $_slot. The customer is notified.')));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _label(DateTime d) =>
      '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

  @override
  Widget build(BuildContext context) {
    final branchId = widget.job.branchId;
    final today = DateTime.now();
    final days = List.generate(
        14, (i) => DateTime(today.year, today.month, today.day + i));

    return Scaffold(
      appBar: AppBar(title: const Text('Reschedule Visit')),
      body: branchId.isEmpty
          ? const UiEmptyState(
              icon: Icons.event_busy_rounded,
              title: 'Ask the office to reschedule',
              message:
                  'This job has no branch assigned, so its time slots can only be changed by the office.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: UiCard(
                    child: Row(
                      children: [
                        const UiIconTile(
                            icon: Icons.event_rounded, color: AppColors.info),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Currently booked',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.muted)),
                              const SizedBox(height: 2),
                              Text(
                                  [
                                    if (widget.job.scheduledDate != null)
                                      formatRelativeDay(
                                          widget.job.scheduledDate),
                                    if (widget.job.scheduledSlot != null)
                                      widget.job.scheduledSlot!,
                                  ].join(' • ').ifEmpty('Not scheduled yet'),
                                  style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: UiSectionLabel('Pick a new day'),
                ),
                SizedBox(
                  height: 84,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: days.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final d = days[i];
                      final selected = d == _date;
                      return _DayChip(
                        weekday: i == 0
                            ? 'Today'
                            : i == 1
                                ? 'Tmrw'
                                : _weekdays[d.weekday - 1],
                        day: '${d.day}',
                        month: _months[d.month - 1],
                        selected: selected,
                        onTap: () => setState(() {
                          _date = d;
                          _slot = null;
                          _error = null;
                        }),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UiSectionLabel('Time slot',
                          subtitle: _label(_date)),
                      ref.watch(_slotsProvider((branchId, _date))).when(
                            loading: () => const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child:
                                  Center(child: CircularProgressIndicator()),
                            ),
                            error: (err, _) => UiCard(
                              child: AppErrorView(
                                error: err,
                                compact: true,
                                onRetry: () => ref.invalidate(
                                    _slotsProvider((branchId, _date))),
                              ),
                            ),
                            data: (result) {
                              if (result.dayClosed || result.slots.isEmpty) {
                                return const UiCard(
                                  child: Row(
                                    children: [
                                      Icon(Icons.store_mall_directory_outlined,
                                          color: AppColors.faint),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                            'No slots on this day — the branch is closed. Pick another day.',
                                            style: TextStyle(
                                                fontSize: 13.5,
                                                color: AppColors.muted)),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  for (final s in result.slots)
                                    _SlotChip(
                                      slot: s,
                                      selected: _slot == s.label,
                                      onTap: s.available
                                          ? () => setState(() {
                                                _slot = s.label;
                                                _error = null;
                                              })
                                          : null,
                                    ),
                                ],
                              );
                            },
                          ),
                      const SizedBox(height: 22),
                      const UiSectionLabel('Reason (optional)'),
                      UiCard(
                        child: TextField(
                          controller: _reasonController,
                          maxLines: 2,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                              hintText: 'e.g. Customer asked for evening'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: branchId.isEmpty
          ? null
          : BottomActionBar(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InlineError(_error),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const ButtonSpinner()
                        : const Icon(Icons.event_available_rounded, size: 18),
                    label: Text(_slot == null
                        ? 'Confirm New Time'
                        : 'Move to ${_label(_date)}, $_slot'),
                  ),
                ],
              ),
            ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

class _DayChip extends StatelessWidget {
  final String weekday;
  final String day;
  final String month;
  final bool selected;
  final VoidCallback onTap;
  const _DayChip(
      {required this.weekday,
      required this.day,
      required this.month,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.ink;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 62,
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: selected ? AppColors.ink : AppColors.line, width: 1.2),
          boxShadow: selected ? AppShadows.card : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(weekday,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.lime400 : AppColors.muted)),
            const SizedBox(height: 2),
            Text(day,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: fg)),
            Text(month,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.faint)),
          ],
        ),
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  final AppointmentSlot slot;
  final bool selected;
  final VoidCallback? onTap;
  const _SlotChip({required this.slot, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Material(
        color: selected ? AppColors.green : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
              color: selected ? AppColors.green : AppColors.line, width: 1.2),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(slot.label,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : AppColors.ink)),
                const SizedBox(height: 2),
                Text(disabled ? 'Full' : '${slot.remaining} left',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white.withValues(alpha: 0.8)
                            : disabled
                                ? AppColors.urgent
                                : AppColors.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
