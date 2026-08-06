import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/job_providers.dart';
import '../theme/app_theme.dart';

// Per docs/rohit/06-vendor-app-screen-list.md "Execution" — Completion screen
// (remarks + OTP/signature capture). Signature capture isn't built (would
// need a signature-pad package not yet in this app) — OTP (sent to the
// customer's phone, verified here) and a manual "app confirmation" fallback
// (for when the customer's phone is unreachable) are the two completion-proof
// paths per completeVisitSchema's COMPLETION_PROOF_TYPES.
class CompletionScreen extends ConsumerStatefulWidget {
  final String jobId;
  const CompletionScreen({super.key, required this.jobId});

  @override
  ConsumerState<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends ConsumerState<CompletionScreen> {
  final _otpController = TextEditingController();
  bool _otpRequested = false;
  bool _submitting = false;
  bool _requestingOtp = false;
  String? _error;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    setState(() {
      _requestingOtp = true;
      _error = null;
    });
    try {
      await ref.read(jobRepositoryProvider).requestCompletionOtp(widget.jobId);
      setState(() => _otpRequested = true);
    } catch (e) {
      setState(() => _error = 'Could not send OTP: $e');
    } finally {
      if (mounted) setState(() => _requestingOtp = false);
    }
  }

  Future<void> _completeWithOtp() async {
    if (_otpController.text.trim().length != 6) {
      setState(() => _error = 'Enter the 6-digit OTP the customer received.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repo = ref.read(jobRepositoryProvider);
      final otp = _otpController.text.trim();
      await repo.verifyCompletionOtp(widget.jobId, otp);
      await repo.completeVisit(widget.jobId, proofType: 'OTP', value: otp);
      await _markServiceCompleted();
      ref.invalidate(jobDetailProvider(widget.jobId));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Could not complete: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _completeWithoutOtp() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete without customer OTP?'),
        content: const Text(
            'Use this only if the customer\'s phone is unreachable. This is recorded as an app-only confirmation, not a customer-verified one.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Complete Anyway')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repo = ref.read(jobRepositoryProvider);
      await repo.completeVisit(widget.jobId, proofType: 'APP_CONFIRMATION');
      await _markServiceCompleted();
      ref.invalidate(jobDetailProvider(widget.jobId));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Could not complete: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _markServiceCompleted() async {
    final repo = ref.read(jobRepositoryProvider);
    final job = await repo.getJob(widget.jobId);
    if (job.status == 'WORK_STARTED') {
      await repo.changeStatus(widget.jobId, 'WORK_IN_PROGRESS');
    }
    await repo.changeStatus(widget.jobId, 'SERVICE_COMPLETED');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Complete Job')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(
                        'Ask the customer for the OTP sent to their phone to confirm the work is done to their satisfaction.',
                        style: TextStyle(color: strongSecondaryTextColor(context)))),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (!_otpRequested)
            FilledButton.icon(
              onPressed: _requestingOtp ? null : _requestOtp,
              icon: _requestingOtp
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sms_outlined, size: 18),
              label: const Text('Send OTP to Customer'),
            )
          else ...[
            const Text('6-digit OTP',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            const SizedBox(height: 8),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(letterSpacing: 4, fontSize: 18),
              decoration:
                  const InputDecoration(hintText: '••••••', counterText: ''),
            ),
            const SizedBox(height: 12),
            TextButton(
                onPressed: _requestingOtp ? null : _requestOtp,
                child: const Text('Resend OTP')),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _submitting ? null : _completeWithOtp,
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Verify & Complete'),
            ),
          ],
          if (_error != null)
            Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(_error!,
                    style: const TextStyle(color: AppColors.urgent))),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: _submitting ? null : _completeWithoutOtp,
              child: Text('Customer unreachable — complete without OTP',
                  style: TextStyle(color: secondaryTextColor(context), fontSize: 12.5)),
            ),
          ),
        ],
      ),
    );
  }
}
