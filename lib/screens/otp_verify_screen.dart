import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_background.dart';
import 'role_router.dart';

// Per docs/rohit/06-vendor-app-screen-list.md "Onboarding" — OTP Verify step.
class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({super.key});

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (previous, next) {
      if (previous?.step != AuthStep.loggedIn && next.step == AuthStep.loggedIn && next.user != null) {
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => homeScreenForUser(next.user!)), (route) => false);
      }
    });

    return AuthBackground(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () {
                ref.read(authProvider.notifier).backToMobileEntry();
                Navigator.of(context).pop();
              },
              child: const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Icon(Icons.arrow_back, color: AppColors.slate300, size: 20),
              ),
            ),
            const Text('Verify OTP', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Enter the 6-digit code sent to +91 ${authState.mobile ?? ''}', style: const TextStyle(color: AppColors.slate400, fontSize: 14)),
            const SizedBox(height: 24),
            TextFormField(
              controller: _otpController,
              style: const TextStyle(color: Colors.white, letterSpacing: 4),
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: authFieldDecoration(label: '6-digit OTP', icon: Icons.lock_outline).copyWith(counterText: ''),
              validator: (value) => (value == null || value.length != 6) ? 'Enter the 6-digit OTP' : null,
            ),
            const SizedBox(height: 12),
            if (authState.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.red400, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(authState.errorMessage!, style: const TextStyle(color: AppColors.red400, fontSize: 13))),
                  ],
                ),
              ),
            FilledButton(
              style: authButtonStyle(),
              onPressed: authState.isLoading ? null : _submit,
              child: authState.isLoading
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.slate950))
                  : const Text('Verify'),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: authState.isLoading || authState.mobile == null ? null : () => ref.read(authProvider.notifier).requestOtp(authState.mobile!),
                style: TextButton.styleFrom(foregroundColor: AppColors.teal400),
                child: const Text('Resend OTP'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      ref.read(authProvider.notifier).verifyOtp(_otpController.text.trim());
    }
  }
}
