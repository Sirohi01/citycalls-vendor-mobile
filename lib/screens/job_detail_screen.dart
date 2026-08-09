import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/job_models.dart';
import '../providers/job_providers.dart';
import '../theme/app_theme.dart';
import 'inspection_form_screen.dart';
import 'work_progress_screen.dart';
import 'parts_entry_screen.dart';
import 'estimate_form_screen.dart';
import 'invoice_screen.dart';
import 'completion_screen.dart';

class JobDetailScreen extends ConsumerStatefulWidget {
  final String jobId;
  const JobDetailScreen({super.key, required this.jobId});

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  bool _submitting = false;
  String? _error;
  Timer? _locationPingTimer;
  bool _locationPingActive = false;

  void _syncLocationPing(String status) {
    final shouldPing = status == 'TECHNICIAN_EN_ROUTE';
    if (shouldPing == _locationPingActive) return;
    _locationPingActive = shouldPing;
    if (shouldPing) {
      _sendLocationPingOnce();
      _locationPingTimer = Timer.periodic(
          const Duration(seconds: 20), (_) => _sendLocationPingOnce());
    } else {
      _locationPingTimer?.cancel();
      _locationPingTimer = null;
    }
  }

  Future<void> _sendLocationPingOnce() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));
      await ref.read(jobRepositoryProvider).sendLocationPing(
          widget.jobId, position.latitude, position.longitude);
    } catch (_) {
      // Best-effort, same as job_repository.dart's own sendLocationPing —
    }
  }

  @override
  void dispose() {
    _locationPingTimer?.cancel();
    super.dispose();
  }

  Future<void> _changeStatus(String toStatus, {String? reason}) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(jobRepositoryProvider)
          .changeStatus(widget.jobId, toStatus, reason: reason);
      ref.invalidate(jobDetailProvider(widget.jobId));
      ref.invalidate(myJobsProvider);
      ref.invalidate(completedJobsProvider);
    } catch (e) {
      setState(() => _error = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _startTravel(JobDetail job) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repository = ref.read(jobRepositoryProvider);
      // ACCEPTED cannot transition directly to EN_ROUTE on the API. Preserve
      // the required workflow hop while keeping this a single user action.
      if (job.status == 'ACCEPTED') {
        await repository.changeStatus(widget.jobId, 'APPOINTMENT_SCHEDULED');
      }
      await repository.changeStatus(widget.jobId, 'TECHNICIAN_EN_ROUTE');
      ref.invalidate(jobDetailProvider(widget.jobId));
      ref.invalidate(myJobsProvider);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _markPartsPending(JobDetail job) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repository = ref.read(jobRepositoryProvider);
      // PARTS_PENDING is only reachable from WORK_IN_PROGRESS on the API —
      // hop through it first if the technician hasn't logged work yet.
      if (job.status == 'WORK_STARTED') {
        await repository.changeStatus(widget.jobId, 'WORK_IN_PROGRESS');
      }
      await repository.changeStatus(widget.jobId, 'PARTS_PENDING');
      ref.invalidate(jobDetailProvider(widget.jobId));
      ref.invalidate(myJobsProvider);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

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
            style: FilledButton.styleFrom(backgroundColor: AppColors.urgent),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason != null) {
      await _changeStatus('REASSIGNMENT_REQUIRED',
          reason: reason.isEmpty ? 'Rejected by technician' : reason);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = ref.watch(jobDetailProvider(widget.jobId));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Job Details')),
      body: job.when(
        data: (j) {
          _syncLocationPing(j.status);
          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(jobDetailProvider(widget.jobId)),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: AppColors.urgent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.urgent, fontSize: 12.5)),
                      ),
                    _JobDetailBody(job: j),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ActionBar(
                  job: j,
                  submitting: _submitting,
                  onChangeStatus: _changeStatus,
                  onStartTravel: () => _startTravel(j),
                  onMarkPartsPending: () => _markPartsPending(j),
                  onConfirmAndChangeStatus: _confirmAndChangeStatus,
                  onReject: _rejectWithReason,
                  onReload: () =>
                      ref.invalidate(jobDetailProvider(widget.jobId)),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, __) => Center(
            child: Text('Could not load this job: $err',
                style: const TextStyle(color: AppColors.slate500))),
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
    'SERVICE_COMPLETED',
    'CUSTOMER_CONFIRMATION_PENDING',
    'PAYMENT_PENDING',
    'PARTIALLY_PAID',
  };

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
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4))
        ],
      ),
      child: submitting
          ? const Center(
              child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator()))
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (content != null) content,
                if (showSupplementaryEstimate)
                  Padding(
                    padding: EdgeInsets.only(top: content != null ? 10 : 0),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(context)
                            .push(MaterialPageRoute(
                                builder: (_) => EstimateFormScreen(job: job)))
                            .then((_) => onReload()),
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text('Add Additional Estimate'),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget? _buildForStatus(BuildContext context) {
    switch (job.status) {
      case 'ASSIGNED_TO_EMPLOYEE':
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
              child: FilledButton(
                onPressed: () => onChangeStatus('ACCEPTED'),
                child: const Text('Accept Job'),
              ),
            ),
          ],
        );

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
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(
                  builder: (_) => InspectionFormScreen(jobId: job.id)))
              .then((_) => onReload()),
          icon: const Icon(Icons.fact_check_outlined, size: 18),
          label: const Text('Enter Inspection Details'),
        );

      case 'INSPECTION_COMPLETED':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(
                        builder: (_) => EstimateFormScreen(job: job)))
                    .then((_) => onReload()),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('Create Estimate'),
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
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(
                            builder: (_) => WorkProgressScreen(jobId: job.id)))
                        .then((_) => onReload()),
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: const Text('Work Progress'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(
                            builder: (_) => CompletionScreen(jobId: job.id)))
                        .then((_) => onReload()),
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
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute(
                            builder: (_) => PartsEntryScreen(jobId: job.id)))
                        .then((_) => onReload()),
                    icon: const Icon(Icons.inventory_2_outlined, size: 18),
                    label: const Text('Parts Used'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onMarkPartsPending,
                    icon: const Icon(Icons.hourglass_empty, size: 18),
                    label: const Text('Waiting For Parts'),
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
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => InvoiceScreen(job: job)))
              .then((_) => onReload()),
          icon: const Icon(Icons.receipt_long_outlined, size: 18),
          label: const Text('Invoice & Payment'),
        );

      default:
        return null;
    }
  }
}

class _JobDetailBody extends StatelessWidget {
  final JobDetail job;
  const _JobDetailBody({required this.job});

  @override
  Widget build(BuildContext context) {
    final accent = statusAccentColor(job.status);
    return Column(
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                      child: Text(job.serviceName ?? 'Service Request',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 17))),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(jobStatusLabel(job.status),
                        style: TextStyle(
                            color: accent,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('#${job.number}',
                  style: TextStyle(
                      color: secondaryTextColor(context), fontSize: 12.5)),
              if (job.scheduledDate != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.schedule,
                        size: 16, color: AppColors.slate500),
                    const SizedBox(width: 6),
                    Text(
                      '${job.scheduledDate!.day}/${job.scheduledDate!.month}/${job.scheduledDate!.year}${job.scheduledSlot != null ? ' • ${job.scheduledSlot}' : ''}',
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w500),
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
              const Text('Customer',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.person_outline,
                    size: 17, color: AppColors.slate500),
                const SizedBox(width: 8),
                Text(job.customerName ?? '—')
              ]),
              if (job.customerMobile != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.call_outlined,
                      size: 17, color: AppColors.slate500),
                  const SizedBox(width: 8),
                  Text(job.customerMobile!)
                ]),
              ],
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 17, color: AppColors.slate500),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          job.addressLine.isEmpty ? '—' : job.addressLine)),
                ],
              ),
            ],
          ),
        ),
        if (job.product != null) ...[
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Appliance',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13.5)),
                    if (job.product!.warrantyExpiresAt != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (job.product!.isUnderWarranty
                                  ? AppColors.success
                                  : AppColors.slate500)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          job.product!.isUnderWarranty
                              ? 'Under Warranty'
                              : 'Warranty Expired',
                          style: TextStyle(
                              color: job.product!.isUnderWarranty
                                  ? AppColors.success
                                  : AppColors.slate500,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (job.product!.brand != null ||
                    job.product!.productType != null)
                  Row(children: [
                    const Icon(Icons.category_outlined,
                        size: 17, color: AppColors.slate500),
                    const SizedBox(width: 8),
                    Text([job.product!.brand, job.product!.productType]
                        .where((s) => s != null)
                        .join(' • ')),
                  ]),
                if (job.product!.modelNumber != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.tag, size: 17, color: AppColors.slate500),
                    const SizedBox(width: 8),
                    Text('Model: ${job.product!.modelNumber}')
                  ]),
                ],
              ],
            ),
          ),
        ],
        if (job.symptoms.isNotEmpty || (job.notes?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Issue Reported',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 10),
                if (job.symptoms.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: job.symptoms
                        .map((s) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                  color: subtleSurfaceColor(context),
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text(s,
                                  style: const TextStyle(fontSize: 12.5)),
                            ))
                        .toList(),
                  ),
                if (job.notes?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 10),
                  Text(job.notes!,
                      style: TextStyle(
                          color: strongSecondaryTextColor(context),
                          height: 1.4)),
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
                const Text('Photos',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 84,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: job.images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(job.images[i],
                          width: 84,
                          height: 84,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              width: 84,
                              height: 84,
                              color: subtleSurfaceColor(context),
                              child: const Icon(Icons.broken_image_outlined,
                                  color: AppColors.slate400))),
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
    return GlassCard(radius: 16, child: child);
  }
}
