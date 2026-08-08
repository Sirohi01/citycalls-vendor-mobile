import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import '../theme/app_theme.dart';

// Per docs/rohit/06-vendor-app-screen-list.md's Completion screen — the
// SIGNATURE completion-proof path (COMPLETION_PROOF_TYPES in
// serviceVisits.model.ts) that completion_screen.dart previously noted as
// "not built (would need a signature-pad package)". Returns the captured
// pad as PNG bytes via Navigator.pop — the caller uploads it like any other
// job image (uploadJobImage) and passes the resulting URL to completeVisit.
class SignatureCaptureScreen extends StatefulWidget {
  const SignatureCaptureScreen({super.key});

  @override
  State<SignatureCaptureScreen> createState() => _SignatureCaptureScreenState();
}

class _SignatureCaptureScreenState extends State<SignatureCaptureScreen> {
  late final SignatureController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(penStrokeWidth: 3, penColor: Colors.black, exportBackgroundColor: Colors.white);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_controller.isEmpty) return;
    final Uint8List? bytes = await _controller.toPngBytes();
    if (bytes != null && mounted) Navigator.of(context).pop(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Customer Signature'),
        actions: [
          TextButton(
            onPressed: () => _controller.clear(),
            child: const Text('Clear'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Hand the device to the customer to sign below, confirming the work is done to their satisfaction.',
              style: TextStyle(fontSize: 12.5, color: secondaryTextColor(context)),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: secondaryTextColor(context).withValues(alpha: 0.3)),
                ),
                child: Signature(controller: _controller, backgroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Use This Signature'),
            ),
          ],
        ),
      ),
    );
  }
}
