import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_background.dart';
import 'otp_verify_screen.dart';

// Per docs/rohit/06-vendor-app-screen-list.md "Onboarding" — mobile-number
// entry step of the mobile+OTP login flow (no password), matching
// citycalls-customer-mobile's pattern.
class OtpRequestScreen extends ConsumerStatefulWidget {
  const OtpRequestScreen({super.key});

  @override
  ConsumerState<OtpRequestScreen> createState() => _OtpRequestScreenState();
}

class _OtpRequestScreenState extends ConsumerState<OtpRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (previous, next) {
      if (previous?.step != AuthStep.otpSent && next.step == AuthStep.otpSent) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OtpVerifyScreen()));
      }
    });

    return AuthBackground(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Welcome back', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Enter your registered mobile number to see your jobs', style: TextStyle(color: AppColors.slate400, fontSize: 14)),
            const SizedBox(height: 24),
            TextFormField(
              controller: _mobileController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.phone,
              maxLength: 10,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: authFieldDecoration(label: 'Mobile number', icon: Icons.phone_iphone, prefixText: '+91  ').copyWith(counterText: ''),
              validator: (value) => (value == null || value.trim().length < 10) ? 'Enter a valid 10-digit mobile number' : null,
            ),
            const SizedBox(height: 20),
            if (authState.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
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
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [Text('Send OTP'), SizedBox(width: 6), Icon(Icons.arrow_forward, size: 18)],
                    ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, color: AppColors.teal400, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Only numbers registered by your admin can sign in.',
                    style: TextStyle(color: AppColors.slate400.withValues(alpha: 0.9), fontSize: 11.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      ref.read(authProvider.notifier).requestOtp(_mobileController.text.trim());
    }
  }
}
