import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../data/job_repository.dart';
import '../providers/job_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/form_kit.dart';
import '../widgets/state_views.dart';
import '../widgets/ui_kit.dart';
import 'signature_capture_screen.dart';

// Per docs/rohit/06-vendor-app-screen-list.md "Execution" — Completion screen.
// Three completion-proof paths per completeVisitSchema's
// COMPLETION_PROOF_TYPES: OTP (sent to the customer's phone, verified here),
// SIGNATURE (captured on-device, uploaded like any other job image), and a
// manual "app confirmation" fallback for when the customer is unreachable.
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
      if (!mounted) return;
      setState(() => _otpRequested = true);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("OTP sent to the customer's phone.")));
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _requestingOtp = false);
    }
  }

  // Records the proof, then moves the job to SERVICE_COMPLETED. [recordProof]
  // does whatever is specific to the chosen path.
  Future<void> _finish(
      Future<void> Function(JobRepository repo) recordProof) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repo = ref.read(jobRepositoryProvider);
      await recordProof(repo);
      await _markServiceCompleted(repo);
      ref.invalidate(jobDetailProvider(widget.jobId));
      ref.invalidate(allJobsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Job marked complete.')));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // SERVICE_COMPLETED is only reachable from WORK_IN_PROGRESS on the API.
  Future<void> _markServiceCompleted(JobRepository repo) async {
    final job = await repo.getJob(widget.jobId);
    if (job.status == 'WORK_STARTED') {
      await repo.changeStatus(widget.jobId, 'WORK_IN_PROGRESS');
    }
    if (job.status != 'SERVICE_COMPLETED') {
      await repo.changeStatus(widget.jobId, 'SERVICE_COMPLETED');
    }
  }

  Future<void> _completeWithOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Enter the 6-digit OTP the customer received.');
      return;
    }
    await _finish((repo) async {
      await repo.verifyCompletionOtp(widget.jobId, otp);
      await repo.completeVisit(widget.jobId, proofType: 'OTP', value: otp);
    });
  }

  Future<void> _completeWithSignature() async {
    final bytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => const SignatureCaptureScreen()),
    );
    if (bytes == null) return;
    await _finish((repo) async {
      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/signature_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      final url =
          await repo.uploadJobImage(widget.jobId, file, category: 'SIGNATURE');
      await repo.completeVisit(widget.jobId, proofType: 'SIGNATURE', url: url);
    });
  }

  Future<void> _completeWithoutOtp() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete without customer proof?'),
        content: const Text(
            'Use this only if the customer cannot be reached. It is recorded as an app-only confirmation, not a customer-verified one.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(150, 44)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Complete Anyway')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _finish((repo) =>
        repo.completeVisit(widget.jobId, proofType: 'APP_CONFIRMATION'));
  }

  @override
  Widget build(BuildContext context) {
    final busy = _submitting || _requestingOtp;
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Job')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const InfoNote(
              'Get the customer to confirm the work is done — by OTP or by signing on your phone.'),
          const SizedBox(height: 20),
          InlineError(_error),
          const UiSectionLabel('Option 1 — Customer OTP'),
          UiCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_otpRequested) ...[
                  const Text(
                      'We send a 6-digit code to the customer. Ask them to read it out to you.',
                      style: TextStyle(
                          fontSize: 13, height: 1.4, color: AppColors.muted)),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.green),
                    onPressed: busy ? null : _requestOtp,
                    icon: _requestingOtp
                        ? const ButtonSpinner(color: AppColors.muted)
                        : const Icon(Icons.sms_outlined, size: 18),
                    label: const Text('Send OTP to Customer'),
                  ),
                ] else ...[
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(
                        letterSpacing: 10,
                        fontSize: 22,
                        fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(
                        hintText: '••••••', counterText: ''),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.green),
                    onPressed: busy ? null : _completeWithOtp,
                    child: _submitting
                        ? const ButtonSpinner(color: AppColors.muted)
                        : const Text('Verify & Complete'),
                  ),
                  TextButton(
                    onPressed: busy ? null : _requestOtp,
                    child: Text(_requestingOtp ? 'Sending…' : 'Resend OTP'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          const UiSectionLabel('Option 2 — Customer signature'),
          UiCard(
            onTap: busy ? null : _completeWithSignature,
            child: const Row(
              children: [
                UiIconTile(icon: Icons.draw_outlined, color: AppColors.info),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sign on this phone',
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink)),
                      SizedBox(height: 2),
                      Text('Hand the phone to the customer to sign',
                          style: TextStyle(
                              fontSize: 12.5, color: AppColors.muted)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.faint),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: busy ? null : _completeWithoutOtp,
              style: TextButton.styleFrom(foregroundColor: AppColors.muted),
              child: const Text('Customer unreachable? Complete without proof'),
            ),
          ),
        ],
      ),
    );
  }
}
