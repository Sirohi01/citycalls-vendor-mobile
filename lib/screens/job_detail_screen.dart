import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/job_models.dart';
import '../providers/job_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';
import '../widgets/ui_kit.dart';
import 'inspection_form_screen.dart';
import 'work_progress_screen.dart';
import 'parts_entry_screen.dart';
import 'estimate_form_screen.dart';
import 'invoice_screen.dart';
import 'completion_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final job = ref.watch(jobDetailProvider(widget.jobId));

    return Scaffold(
      appBar: AppBar(title: const Text('Job Details')),
      body: job.when(
        data: (j) => Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: AppColors.green,
                onRefresh: () async {
                  _refresh();
                  await ref
                      .read(jobDetailProvider(widget.jobId).future)
                      .catchError((_) => j);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    if (_error != null) _ErrorBox(text: _error!),
                    _StatusHint(status: j.status),
                    _JobDetailBody(job: j),
                  ],
                ),
              ),
            ),
            _ActionBar(
              job: j,
              submitting: _submitting,
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
  const _StatusHint({required this.status});

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
        'Marked as customer unavailable. The office will reschedule this visit.',
    'REASSIGNMENT_REQUIRED':
        'You rejected this job. The office will assign it to someone else.',
    'PAID': 'Payment received. This job is complete.',
    'CLOSED': 'This job is closed.',
    'CANCELLED': 'This job was cancelled.',
  };

  @override
  Widget build(BuildContext context) {
    final hint = _hints[status];
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
  final bool submitting;
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
    required this.submitting,
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
    final content = _buildForStatus(context);
    final showSupplementaryEstimate =
        _supplementaryEstimateStatuses.contains(job.status);
    if (content == null && !showSupplementaryEstimate) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.hairline)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, -4))
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
                    child: TextButton.icon(
                      onPressed: () =>
                          _open(context, EstimateFormScreen(job: job)),
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Add Additional Estimate'),
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
      case 'ACCEPTED':
      case 'APPOINTMENT_SCHEDULED':
      case 'RESCHEDULED':
        return FilledButton.icon(
          onPressed: onStartTravel,
          icon: const Icon(Icons.directions_car_outlined, size: 18),
          label: const Text('Start Travel'),
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
    final accent = statusAccentColor(job.status);
    final when = [
      if (job.scheduledDate != null) formatDisplayDate(job.scheduledDate),
      if (job.scheduledSlot != null && job.scheduledSlot!.isNotEmpty)
        job.scheduledSlot!,
    ].join(' • ');
    final urgent = job.priority == 'URGENT' || job.priority == 'HIGH';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UiIconTile(
                      icon: Icons.build_outlined, color: accent, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(job.serviceName ?? 'Service Request',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                                color: AppColors.ink)),
                        const SizedBox(height: 2),
                        Text('#${job.number}',
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  UiPill(text: jobStatusLabel(job.status), color: accent),
                  if (urgent)
                    UiPill(
                        text: '${job.priority} PRIORITY',
                        color: AppColors.urgent,
                        icon: Icons.priority_high_rounded),
                ],
              ),
              if (when.isNotEmpty) ...[
                const SizedBox(height: 8),
                UiInfoRow(
                    icon: Icons.schedule_rounded,
                    label: 'Appointment',
                    value: when),
              ],
              if (job.slaDueAt != null)
                UiInfoRow(
                    icon: Icons.timer_outlined,
                    label: 'Due by',
                    value: formatDisplayDateTime(job.slaDueAt)),
            ],
          ),
        ),
        const SizedBox(height: 18),
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
