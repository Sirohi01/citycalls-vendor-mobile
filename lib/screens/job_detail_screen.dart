import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/job_models.dart';
import '../models/visit_models.dart';
import '../providers/auth_providers.dart';
import '../providers/job_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/hero_header.dart';
import '../widgets/state_views.dart';
import '../widgets/ui_kit.dart';
import 'inspection_form_screen.dart';
import 'work_progress_screen.dart';
import 'parts_entry_screen.dart';
import 'estimate_form_screen.dart';
import 'invoice_screen.dart';
import 'completion_screen.dart';
import 'reschedule_screen.dart';

// Live-location pings while TECHNICIAN_EN_ROUTE are sent app-wide by
// providers/transit_tracking_provider.dart (started from MainShell), not
// from this screen, so they keep going after the technician leaves it.
class JobDetailScreen extends ConsumerStatefulWidget {
  final String jobId;
  const JobDetailScreen({super.key, required this.jobId});

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  bool _submitting = false;
  String? _error;

  void _refresh() {
    ref.invalidate(jobDetailProvider(widget.jobId));
    ref.invalidate(jobVisitsProvider(widget.jobId));
    ref.invalidate(allJobsProvider);
  }

  // Runs one or more status changes as a single user action. Each step is
  // queued offline-first (job_repository.dart) — offline, it simply waits
  // in the queue; a server rejection comes back as a readable message.
  Future<void> _run(List<String> statuses, {String? reason}) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repository = ref.read(jobRepositoryProvider);
      for (final s in statuses) {
        await repository.changeStatus(widget.jobId, s,
            reason: s == statuses.last ? reason : null);
      }
      _refresh();
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _changeStatus(String toStatus, {String? reason}) =>
      _run([toStatus], reason: reason);

  // ACCEPTED cannot transition directly to EN_ROUTE on the API. Preserve
  // the required workflow hop while keeping this a single user action.
  Future<void> _startTravel(JobDetail job) => _run([
        if (job.status == 'ACCEPTED') 'APPOINTMENT_SCHEDULED',
        'TECHNICIAN_EN_ROUTE',
      ]);

  // PARTS_PENDING is only reachable from WORK_IN_PROGRESS on the API — hop
  // through it first if the technician hasn't logged work yet.
  Future<void> _markPartsPending(JobDetail job) => _run([
        if (job.status == 'WORK_STARTED') 'WORK_IN_PROGRESS',
        'PARTS_PENDING',
      ]);

  Future<void> _confirmAndChangeStatus(String toStatus,
      {required String title,
      required String message,
      String confirmLabel = 'Confirm'}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirmLabel)),
        ],
      ),
    );
    if (confirmed == true) await _changeStatus(toStatus);
  }

  Future<void> _rejectWithReason() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject this job'),
        content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
                hintText: 'Why are you rejecting this job?')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.urgent,
                minimumSize: const Size(110, 44)),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason != null) {
      await _changeStatus('REASSIGNMENT_REQUIRED',
          reason: reason.isEmpty ? 'Rejected by technician' : reason);
      if (mounted && _error == null) Navigator.of(context).pop();
    }
  }

  // ON_HOLD is only reachable from WORK_IN_PROGRESS — hop through it first.
  Future<void> _putOnHold(JobDetail job) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Put job on hold'),
        content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
                hintText: 'Why is the work paused? (e.g. customer away)')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Put on hold'),
          ),
        ],
      ),
    );
    if (reason == null) return;
    await _run([
      if (job.status == 'WORK_STARTED') 'WORK_IN_PROGRESS',
      'ON_HOLD',
    ], reason: reason.isEmpty ? 'Paused by technician' : reason);
  }

  @override
  Widget build(BuildContext context) {
    final job = ref.watch(jobDetailProvider(widget.jobId));
    // Vendor owners/managers can only accept or reject on their company's
    // behalf — every later step is a field-technician transition on the API
    // (FIELD_ROLES in scripts/seed.ts), and they hold no finance permission.
    final managerView =
        ref.watch(authProvider).user?.isVendorManagement ?? false;

    return Scaffold(
      // The loaded screen draws its own dark hero with a back button; the
      // plain app bar is only for the loading / error states.
      appBar: job.hasValue ? null : AppBar(title: const Text('Job Details')),
      body: job.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        data: (j) => Column(
          children: [
            Expanded(
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle.light,
                child: RefreshIndicator(
                  color: AppColors.green,
                  edgeOffset: MediaQuery.of(context).padding.top,
                  onRefresh: () async {
                    _refresh();
                    await ref
                        .read(jobDetailProvider(widget.jobId).future)
                        .catchError((_) => j);
                  },
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 28),
                    children: [
                      _JobHero(job: j),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_error != null) _ErrorBox(text: _error!),
                            _StatusHint(
                                status: j.status, managerView: managerView),
                            _JobDetailBody(job: j),
                            _VisitLog(jobId: j.id),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _ActionBar(
              job: j,
              managerView: managerView,
              submitting: _submitting,
              onPutOnHold: () => _putOnHold(j),
              onChangeStatus: _changeStatus,
              onStartTravel: () => _startTravel(j),
              onMarkPartsPending: () => _markPartsPending(j),
              onConfirmAndChangeStatus: _confirmAndChangeStatus,
              onReject: _rejectWithReason,
              onReload: _refresh,
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, __) => Center(
          child: AppErrorView(
              error: err,
              onRetry: () => ref.invalidate(jobDetailProvider(widget.jobId))),
        ),
      ),
    );
  }
}

// Dark brand header for a job: back button, service, number, status and a
// progress stepper showing how far along the job is.
class _JobHero extends StatelessWidget {
  final JobDetail job;
  const _JobHero({required this.job});

  static const _steps = ['Accept', 'Travel', 'Inspect', 'Work', 'Payment', 'Done'];

  // Which of [_steps] a status is on; null hides the stepper
  // (cancelled / handed back jobs).
  static int? _completedSteps(String s) {
    if (newJobStatuses.contains(s)) return 0;
    const accepted = {'ACCEPTED', 'APPOINTMENT_SCHEDULED', 'RESCHEDULED'};
    const travel = {
      'TECHNICIAN_EN_ROUTE',
      'TECHNICIAN_ARRIVED',
      'CUSTOMER_UNAVAILABLE'
    };
    const inspect = {
      'INSPECTION_STARTED',
      'INSPECTION_COMPLETED',
      'ESTIMATE_PENDING',
      'ESTIMATE_SHARED',
      'AWAITING_CUSTOMER_APPROVAL',
      'ESTIMATE_REJECTED',
    };
    const work = {
      'ESTIMATE_APPROVED',
      'WORK_STARTED',
      'WORK_IN_PROGRESS',
      'PARTS_PENDING',
      'ON_HOLD'
    };
    const payment = {
      'SERVICE_COMPLETED',
      'CUSTOMER_CONFIRMATION_PENDING',
      'PAYMENT_PENDING',
      'PARTIALLY_PAID'
    };
    // The value is the index of the step in progress: everything before it
    // is ticked. Accepted and en-route both sit on "Travel".
    if (accepted.contains(s) || travel.contains(s)) return 1;
    if (inspect.contains(s)) return 2;
    if (work.contains(s)) return 3;
    if (payment.contains(s)) return 4;
    if (s == 'PAID' || s == 'CLOSED') return 6;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final accent = statusAccentColor(job.status);
    final urgent = job.priority == 'URGENT' || job.priority == 'HIGH';
    final done = _completedSteps(job.status);
    final when = [
      if (job.scheduledDate != null) formatRelativeDay(job.scheduledDate),
      if (job.scheduledSlot != null && job.scheduledSlot!.isNotEmpty)
        job.scheduledSlot!,
    ].join(' • ');

    return HeroHeader(
      padding: const EdgeInsets.fromLTRB(12, 6, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HeroIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const Spacer(),
              Text('#${job.number}',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 4),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 18, 6, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeroPill(
                        text: jobStatusLabel(job.status),
                        color: accent == AppColors.info
                            ? AppColors.lime400
                            : accent),
                    if (urgent)
                      _HeroPill(
                          text: '${job.priority} PRIORITY',
                          color: const Color(0xFFFB7185),
                          icon: Icons.bolt_rounded),
                  ],
                ),
                const SizedBox(height: 12),
                Text(job.serviceName ?? 'Service Request',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        height: 1.2,
                        letterSpacing: -0.6,
                        fontWeight: FontWeight.w800)),
                if (when.isNotEmpty || job.slaDueAt != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      if (when.isNotEmpty)
                        _HeroMeta(icon: Icons.event_rounded, text: when),
                      if (job.slaDueAt != null)
                        _HeroMeta(
                            icon: Icons.timer_outlined,
                            text: 'Due ${formatTime(job.slaDueAt)}'),
                    ],
                  ),
                ],
                if (done != null) ...[
                  const SizedBox(height: 22),
                  _Stepper(steps: _steps, done: done),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const _HeroPill({required this.text, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 13, color: color)
          else
            Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2)),
        ],
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HeroMeta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.55)),
        const SizedBox(width: 6),
        Text(text,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// Horizontal job-progress stepper on the dark hero: completed steps are lime
// with a check, the current one glows, the rest are faint.
class _Stepper extends StatelessWidget {
  final List<String> steps;
  final int done;
  const _Stepper({required this.steps, required this.done});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              _dot(i),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i < done
                          ? AppColors.lime400
                          : Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < steps.length; i++)
              Expanded(
                child: Text(
                  steps[i],
                  textAlign: i == 0
                      ? TextAlign.left
                      : i == steps.length - 1
                          ? TextAlign.right
                          : TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: i == done ? FontWeight.w800 : FontWeight.w600,
                    color: i < done
                        ? AppColors.lime400
                        : i == done
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _dot(int i) {
    final complete = i < done;
    final current = i == done;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: complete
            ? AppColors.lime400
            : current
                ? Colors.white
                : Colors.white.withValues(alpha: 0.10),
        border: current
            ? Border.all(color: AppColors.lime400, width: 3)
            : null,
        boxShadow: current
            ? [
                BoxShadow(
                    color: AppColors.lime400.withValues(alpha: 0.5),
                    blurRadius: 12)
              ]
            : null,
      ),
      child: complete
          ? const Icon(Icons.check_rounded, size: 14, color: AppColors.heroDark)
          : null,
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String text;
  const _ErrorBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.urgent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.urgent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: AppColors.urgent),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: AppColors.urgent, fontSize: 13, height: 1.35))),
        ],
      ),
    );
  }
}

// Plain-language "what happens next" for statuses where the technician has
// no button to press — otherwise the action bar is just empty and it looks
// like the app is stuck.
class _StatusHint extends StatelessWidget {
  final String status;
  final bool managerView;
  const _StatusHint({required this.status, this.managerView = false});

  static const _hints = {
    'ESTIMATE_PENDING':
        'The estimate is being prepared. Once it is shared, the customer will be asked to approve it.',
    'ESTIMATE_SHARED':
        'Estimate sent to the customer. You can start work once they approve it.',
    'AWAITING_CUSTOMER_APPROVAL':
        'Waiting for the customer to approve the estimate. This screen updates when they do — pull down to refresh.',
    'ESTIMATE_REJECTED':
        'The customer rejected the estimate. The office will close or follow up on this job.',
    'CUSTOMER_UNAVAILABLE':
        'Marked as customer unavailable. Agree a new time with the customer and reschedule below, or the office will follow up.',
    'ON_HOLD': 'Work is paused. Resume when you are ready to continue.',
    'REASSIGNMENT_REQUIRED':
        'You rejected this job. The office will assign it to someone else.',
    'PAID': 'Payment received. This job is complete.',
    'CLOSED': 'This job is closed.',
    'CANCELLED': 'This job was cancelled.',
  };

  @override
  Widget build(BuildContext context) {
    const terminal = {'PAID', 'CLOSED', 'CANCELLED', 'REASSIGNMENT_REQUIRED'};
    final hint = managerView &&
            !newJobStatuses.contains(status) &&
            !terminal.contains(status)
        ? 'Your field technician updates this job from their own login. You can follow every step here.'
        : _hints[status];
    if (hint == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: UiCard(
        color: AppColors.info.withValues(alpha: 0.05),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 18, color: AppColors.info),
            const SizedBox(width: 8),
            Expanded(
                child: Text(hint,
                    style: const TextStyle(
                        fontSize: 13, height: 1.4, color: AppColors.slate700))),
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final JobDetail job;
  final bool managerView;
  final bool submitting;
  final VoidCallback onPutOnHold;
  final Future<void> Function(String toStatus, {String? reason}) onChangeStatus;
  final VoidCallback onStartTravel;
  final VoidCallback onMarkPartsPending;
  final Future<void> Function(String toStatus,
      {required String title,
      required String message,
      String confirmLabel}) onConfirmAndChangeStatus;
  final VoidCallback onReject;
  final VoidCallback onReload;

  const _ActionBar({
    required this.job,
    required this.managerView,
    required this.submitting,
    required this.onPutOnHold,
    required this.onChangeStatus,
    required this.onStartTravel,
    required this.onMarkPartsPending,
    required this.onConfirmAndChangeStatus,
    required this.onReject,
    required this.onReload,
  });

  static const _supplementaryEstimateStatuses = {
    'ESTIMATE_APPROVED',
    'WORK_STARTED',
    'WORK_IN_PROGRESS',
    'PARTS_PENDING',
    'ON_HOLD',
  };

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) => onReload());
  }

  @override
  Widget build(BuildContext context) {
    final content = managerView
        ? (newJobStatuses.contains(job.status)
            ? _buildForStatus(context)
            : null)
        : _buildForStatus(context);
    final showSupplementaryEstimate = !managerView &&
        _supplementaryEstimateStatuses.contains(job.status);
    final showHold = !managerView &&
        (job.status == 'WORK_STARTED' || job.status == 'WORK_IN_PROGRESS');
    if (content == null && !showSupplementaryEstimate) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).padding.bottom + 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, -8))
        ],
      ),
      child: submitting
          ? const Center(
              child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator()))
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (content != null) content,
                if (showSupplementaryEstimate)
                  Padding(
                    padding: EdgeInsets.only(top: content != null ? 6 : 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (showHold) ...[
                          TextButton.icon(
                            style: TextButton.styleFrom(
                                foregroundColor: AppColors.gold400),
                            onPressed: onPutOnHold,
                            icon: const Icon(Icons.pause_circle_outline,
                                size: 18),
                            label: const Text('Put on hold'),
                          ),
                          Container(
                              width: 1,
                              height: 18,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              color: AppColors.line),
                        ],
                        TextButton.icon(
                          onPressed: () =>
                              _open(context, EstimateFormScreen(job: job)),
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: Text(
                              showHold ? 'Add estimate' : 'Add Additional Estimate'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget? _buildForStatus(BuildContext context) {
    if (newJobStatuses.contains(job.status)) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.urgent),
                  foregroundColor: AppColors.urgent),
              onPressed: onReject,
              child: const Text('Reject'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.green),
              onPressed: () => onChangeStatus('ACCEPTED'),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Accept Job'),
            ),
          ),
        ],
      );
    }

    switch (job.status) {
      case 'RESCHEDULED':
        return FilledButton.icon(
          onPressed: onStartTravel,
          icon: const Icon(Icons.directions_car_outlined, size: 18),
          label: const Text('Start Travel'),
        );

      case 'ACCEPTED':
      case 'APPOINTMENT_SCHEDULED':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _open(context, RescheduleScreen(job: job)),
                icon: const Icon(Icons.event_repeat_rounded, size: 18),
                label: const Text('Reschedule'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: onStartTravel,
                icon: const Icon(Icons.directions_car_outlined, size: 18),
                label: const Text('Start Travel'),
              ),
            ),
          ],
        );

      case 'CUSTOMER_UNAVAILABLE':
        return FilledButton.icon(
          onPressed: () => _open(context, RescheduleScreen(job: job)),
          icon: const Icon(Icons.event_repeat_rounded, size: 18),
          label: const Text('Reschedule Visit'),
        );

      case 'TECHNICIAN_EN_ROUTE':
        return FilledButton.icon(
          onPressed: () => onChangeStatus('TECHNICIAN_ARRIVED'),
          icon: const Icon(Icons.location_on_outlined, size: 18),
          label: const Text('Mark Arrived'),
        );

      case 'TECHNICIAN_ARRIVED':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => onConfirmAndChangeStatus(
                  'CUSTOMER_UNAVAILABLE',
                  title: 'Customer unavailable?',
                  message:
                      'This marks the visit as unable to proceed — office will follow up.',
                  confirmLabel: 'Mark Unavailable',
                ),
                child: const Text('Customer N/A'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: () => onChangeStatus('INSPECTION_STARTED'),
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Start Inspection'),
              ),
            ),
          ],
        );

      case 'INSPECTION_STARTED':
        return FilledButton.icon(
          onPressed: () => _open(context, InspectionFormScreen(jobId: job.id)),
          icon: const Icon(Icons.fact_check_outlined, size: 18),
          label: const Text('Enter Inspection Details'),
        );

      case 'INSPECTION_COMPLETED':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _open(context, EstimateFormScreen(job: job)),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('Estimate'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => onChangeStatus('WORK_STARTED'),
                icon: const Icon(Icons.build_outlined, size: 18),
                label: const Text('Start Work'),
              ),
            ),
          ],
        );

      case 'ESTIMATE_APPROVED':
        return FilledButton.icon(
          onPressed: () => onChangeStatus('WORK_STARTED'),
          icon: const Icon(Icons.build_outlined, size: 18),
          label: const Text('Start Work'),
        );

      case 'WORK_STARTED':
      case 'WORK_IN_PROGRESS':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _open(context, WorkProgressScreen(jobId: job.id)),
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: const Text('Work Progress'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.green),
                    onPressed: () =>
                        _open(context, CompletionScreen(jobId: job.id)),
                    icon: const Icon(Icons.task_alt, size: 18),
                    label: const Text('Complete'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _open(context, PartsEntryScreen(jobId: job.id)),
                    icon: const Icon(Icons.inventory_2_outlined, size: 18),
                    label: const Text('Parts Used'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onMarkPartsPending,
                    icon: const Icon(Icons.hourglass_empty, size: 18),
                    label: const Text('Need Parts'),
                  ),
                ),
              ],
            ),
          ],
        );

      case 'PARTS_PENDING':
        return FilledButton.icon(
          onPressed: () => onChangeStatus('WORK_IN_PROGRESS'),
          icon: const Icon(Icons.inventory_2_outlined, size: 18),
          label: const Text('Parts Received — Resume Work'),
        );

      case 'ON_HOLD':
        return FilledButton.icon(
          onPressed: () => onChangeStatus('WORK_IN_PROGRESS'),
          icon: const Icon(Icons.play_arrow, size: 18),
          label: const Text('Resume Work'),
        );

      case 'SERVICE_COMPLETED':
        return FilledButton.icon(
          onPressed: () => onChangeStatus('CUSTOMER_CONFIRMATION_PENDING'),
          icon: const Icon(Icons.send_outlined, size: 18),
          label: const Text('Send for Customer Confirmation'),
        );

      case 'CUSTOMER_CONFIRMATION_PENDING':
        return FilledButton.icon(
          onPressed: () => onChangeStatus('PAYMENT_PENDING'),
          icon: const Icon(Icons.payments_outlined, size: 18),
          label: const Text('Proceed to Payment'),
        );

      case 'PAYMENT_PENDING':
      case 'PARTIALLY_PAID':
        return FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.green),
          onPressed: () => _open(context, InvoiceScreen(job: job)),
          icon: const Icon(Icons.receipt_long_outlined, size: 18),
          label: const Text('Invoice & Collect Payment'),
        );

      default:
        return null;
    }
  }
}

class _JobDetailBody extends StatelessWidget {
  final JobDetail job;
  const _JobDetailBody({required this.job});

  Future<void> _launch(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication)
        .catchError((_) => false);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't open that on this phone.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const UiSectionLabel('Customer'),
        UiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UiInfoRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Name',
                  value: job.customerName ?? '—'),
              if (job.customerMobile != null)
                UiInfoRow(
                    icon: Icons.call_outlined,
                    label: 'Mobile',
                    value: '+91 ${job.customerMobile}'),
              UiInfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Address',
                  value: job.addressLine.isEmpty ? '—' : job.addressLine),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (job.customerMobile != null) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _launch(
                            context,
                            Uri(
                                scheme: 'tel',
                                path: '+91${job.customerMobile}')),
                        icon: const Icon(Icons.call_rounded,
                            size: 18, color: AppColors.green),
                        label: const Text('Call'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (job.addressLine.isNotEmpty)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _launch(
                            context,
                            Uri.https('www.google.com', '/maps/dir/', {
                              'api': '1',
                              'destination': job.addressLine,
                            })),
                        icon: const Icon(Icons.navigation_rounded,
                            size: 18, color: AppColors.info),
                        label: const Text('Navigate'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (job.product != null) ...[
          const SizedBox(height: 18),
          UiSectionLabel(
            'Appliance',
            trailing: job.product!.warrantyExpiresAt == null
                ? null
                : UiPill(
                    text: job.product!.isUnderWarranty
                        ? 'Under Warranty'
                        : 'Warranty Expired',
                    color: job.product!.isUnderWarranty
                        ? AppColors.success
                        : AppColors.slate500),
          ),
          UiCard(
            child: Column(
              children: [
                if (job.product!.brand != null ||
                    job.product!.productType != null)
                  UiInfoRow(
                      icon: Icons.category_outlined,
                      label: 'Product',
                      value: [job.product!.brand, job.product!.productType]
                          .whereType<String>()
                          .join(' • ')),
                if (job.product!.modelNumber != null)
                  UiInfoRow(
                      icon: Icons.tag_rounded,
                      label: 'Model',
                      value: job.product!.modelNumber!),
                if (job.product!.warrantyExpiresAt != null)
                  UiInfoRow(
                      icon: Icons.verified_user_outlined,
                      label: 'Warranty till',
                      value: formatDisplayDate(job.product!.warrantyExpiresAt)),
              ],
            ),
          ),
        ],
        if (job.symptoms.isNotEmpty || (job.notes?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 18),
          const UiSectionLabel('Issue reported'),
          UiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (job.symptoms.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in job.symptoms)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: AppColors.slate100,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(s,
                              style: const TextStyle(
                                  fontSize: 12.5, color: AppColors.slate700)),
                        ),
                    ],
                  ),
                if (job.notes?.isNotEmpty ?? false) ...[
                  if (job.symptoms.isNotEmpty) const SizedBox(height: 10),
                  Text(job.notes!,
                      style: const TextStyle(
                          color: AppColors.slate700, height: 1.4)),
                ],
              ],
            ),
          ),
        ],
        if (job.images.isNotEmpty) ...[
          const SizedBox(height: 18),
          const UiSectionLabel('Photos from customer'),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: job.images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    clipBehavior: Clip.antiAlias,
                    child: InteractiveViewer(
                        child:
                            Image.network(job.images[i], fit: BoxFit.contain)),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(job.images[i],
                      width: 92,
                      height: 92,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          width: 92,
                          height: 92,
                          color: AppColors.slate100,
                          child: const Icon(Icons.broken_image_outlined,
                              color: AppColors.slate400))),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// Everything recorded on this job so far (GET /service-requests/:id/visits):
// inspection findings, parts, labour, notes and before/after photos.
class _VisitLog extends ConsumerWidget {
  final String jobId;
  const _VisitLog({required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visits = ref.watch(jobVisitsProvider(jobId)).valueOrNull;
    final withContent =
        (visits ?? const <ServiceVisit>[]).where((v) => v.hasContent).toList();
    if (withContent.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const UiSectionLabel('Work record'),
          for (final v in withContent) ...[
            _VisitCard(visit: v, showNumber: withContent.length > 1),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  final ServiceVisit visit;
  final bool showNumber;
  const _VisitCard({required this.visit, required this.showNumber});

  @override
  Widget build(BuildContext context) {
    final partsTotal = visit.parts.fold<double>(0, (s, p) => s + p.total);
    Widget row(IconData icon, String label, String value) =>
        UiInfoRow(icon: icon, label: label, value: value);

    return UiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showNumber || visit.completedAt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  if (showNumber)
                    Text('Visit ${visit.visitNumber}',
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink)),
                  const Spacer(),
                  if (visit.completedAt != null)
                    UiPill(
                        text: 'Completed ${formatTime(visit.completedAt)}',
                        color: AppColors.success,
                        icon: Icons.check_circle_rounded),
                ],
              ),
            ),
          if (visit.defectFound?.isNotEmpty ?? false)
            row(Icons.report_problem_outlined, 'Defect found',
                visit.defectFound!),
          if (visit.symptoms.isNotEmpty)
            row(Icons.sick_outlined, 'Symptoms', visit.symptoms.join(', ')),
          if (visit.solutionType?.isNotEmpty ?? false)
            row(Icons.lightbulb_outline_rounded, 'Solution',
                visit.solutionType!),
          if (visit.parts.isNotEmpty)
            row(
                Icons.inventory_2_outlined,
                'Parts (₹${partsTotal.round()})',
                visit.parts
                    .map((p) =>
                        '${p.name} × ${p.qty % 1 == 0 ? p.qty.toInt() : p.qty}')
                    .join(', ')),
          if (visit.labourCharge != null)
            row(Icons.engineering_outlined, 'Labour',
                '₹${visit.labourCharge!.round()}'),
          if (visit.workNotes?.isNotEmpty ?? false)
            row(Icons.notes_rounded, 'Work notes', visit.workNotes!),
          if (visit.beforeImages.isNotEmpty || visit.afterImages.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 78,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final url in visit.beforeImages)
                    _Thumb(url: url, tag: 'Before'),
                  for (final url in visit.afterImages)
                    _Thumb(url: url, tag: 'After'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String url;
  final String tag;
  const _Thumb({required this.url, required this.tag});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => showDialog(
          context: context,
          builder: (_) => Dialog(
            clipBehavior: Clip.antiAlias,
            child: InteractiveViewer(
                child: Image.network(url, fit: BoxFit.contain)),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Image.network(url,
                  width: 78,
                  height: 78,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      width: 78,
                      height: 78,
                      color: AppColors.slate100,
                      child: const Icon(Icons.broken_image_outlined,
                          color: AppColors.slate400))),
              Positioned(
                left: 4,
                bottom: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(tag,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
