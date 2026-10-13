import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import '../theme/app_theme.dart';
import '../widgets/form_kit.dart';

// The SIGNATURE completion-proof path (COMPLETION_PROOF_TYPES in
// serviceVisits.model.ts). Returns the captured pad as PNG bytes via
// Navigator.pop — the caller uploads it like any other job image
// (uploadJobImage) and passes the resulting URL to completeVisit.
class SignatureCaptureScreen extends StatefulWidget {
  const SignatureCaptureScreen({super.key});

  @override
  State<SignatureCaptureScreen> createState() => _SignatureCaptureScreenState();
}

class _SignatureCaptureScreenState extends State<SignatureCaptureScreen> {
  late final SignatureController _controller;
  bool _hasInk = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
      onDrawEnd: () => setState(() {
        _hasInk = _controller.isNotEmpty;
        _error = null;
      }),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_controller.isEmpty) {
      setState(() => _error = 'Ask the customer to sign in the box first.');
      return;
    }
    final Uint8List? bytes = await _controller.toPngBytes();
    if (!mounted) return;
    if (bytes == null) {
      setState(
          () => _error = 'Could not read the signature. Please try again.');
      return;
    }
    Navigator.of(context).pop(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Signature'),
        actions: [
          TextButton(
            onPressed: _hasInk
                ? () {
                    _controller.clear();
                    setState(() => _hasInk = false);
                  }
                : null,
            child: const Text('Clear'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const InfoNote(
                'Hand the phone to the customer to sign below, confirming the work is done to their satisfaction.'),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (!_hasInk)
                      const Center(
                        child: Text('Sign here',
                            style: TextStyle(
                                fontSize: 22,
                                color: AppColors.slate300,
                                fontWeight: FontWeight.w600)),
                      ),
                    Signature(
                        controller: _controller,
                        backgroundColor: Colors.transparent),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InlineError(_error),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Use This Signature'),
            ),
          ],
        ),
      ),
    );
  }
}
