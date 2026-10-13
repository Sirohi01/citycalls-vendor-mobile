import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_background.dart';
import 'otp_verify_screen.dart';

// Per docs/rohit/06-vendor-app-screen-list.md "Onboarding" — mobile-number
// entry step of the mobile+OTP login flow (no password). Same look and
// behaviour as citycalls-customer-mobile's login, including offering back
// the last number that signed in on this phone.
class OtpRequestScreen extends ConsumerStatefulWidget {
  // Set when the session expired mid-use (main.dart) rather than the app
  // simply opening logged out — the technician needs to be told why.
  final bool sessionExpired;
  const OtpRequestScreen({super.key, this.sessionExpired = false});

  @override
  ConsumerState<OtpRequestScreen> createState() => _OtpRequestScreenState();
}

class _OtpRequestScreenState extends ConsumerState<OtpRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isFocused = false;
  String? _savedMobile;
  bool _useDifferentNumber = false;

  bool get _showSavedNumber => _savedMobile != null && !_useDifferentNumber;

  @override
  void initState() {
    super.initState();
    _focusNode
        .addListener(() => setState(() => _isFocused = _focusNode.hasFocus));
    _loadRememberedMobile();
    if (widget.sessionExpired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Your session expired. Please sign in again.')));
      });
    }
  }

  Future<void> _loadRememberedMobile() async {
    final mobile =
        await ref.read(authRepositoryProvider).readRememberedMobile();
    if (!mounted || mobile == null || mobile.length != 10) return;
    if (_mobileController.text.isNotEmpty) return;
    setState(() => _savedMobile = mobile);
  }

  static String _pretty(String m) =>
      '+91 ${m.substring(0, 5)} ${m.substring(5)}';

  @override
  void dispose() {
    _mobileController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (previous, next) {
      if (previous?.step != AuthStep.otpSent && next.step == AuthStep.otpSent) {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const OtpVerifyScreen()));
      }
    });

    return AuthBackground(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Welcome, Partner!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            const Text('Login to see your jobs and start working',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.slate400, fontSize: 14)),
            const SizedBox(height: 32),
            if (_showSavedNumber) ...[
              _SavedNumberCard(text: _pretty(_savedMobile!)),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: authState.isLoading
                      ? null
                      : () {
                          setState(() => _useDifferentNumber = true);
                          ref.read(authProvider.notifier).backToMobileEntry();
                          WidgetsBinding.instance.addPostFrameCallback(
                              (_) => _focusNode.requestFocus());
                        },
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.lime400),
                  child: const Text('Use a different number'),
                ),
              ),
            ] else ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _isFocused
                      ? [
                          BoxShadow(
                              color: AppColors.lime500.withValues(alpha: 0.18),
                              blurRadius: 18,
                              spreadRadius: 1)
                        ]
                      : [],
                ),
                child: TextFormField(
                  controller: _mobileController,
                  focusNode: _focusNode,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16, letterSpacing: 1.0),
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: authFieldDecoration(
                    label: 'Mobile number',
                    icon: Icons.phone_outlined,
                    prefixText: '+91  ',
                  ).copyWith(counterText: ''),
                  validator: (value) =>
                      (value == null || value.trim().length < 10)
                          ? 'Enter a valid 10-digit mobile number'
                          : null,
                ),
              ),
              if (_savedMobile != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: authState.isLoading
                        ? null
                        : () => setState(() {
                              _useDifferentNumber = false;
                              _mobileController.clear();
                            }),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.lime400),
                    child: Text('Use ${_pretty(_savedMobile!)} instead'),
                  ),
                ),
            ],
            const SizedBox(height: 20),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: authState.errorMessage != null
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: _ErrorBanner(text: authState.errorMessage!),
                    )
                  : const SizedBox.shrink(),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: authButtonStyle(),
                onPressed: authState.isLoading ? null : _submit,
                child: authState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: AppColors.slate950))
                    : const Text('Send OTP'),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined,
                    color: AppColors.lime500.withValues(alpha: 0.8), size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Only numbers registered by your admin can sign in.',
                    style: TextStyle(
                        color: AppColors.slate400.withValues(alpha: 0.8),
                        fontSize: 12),
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
    if (_showSavedNumber) {
      ref.read(authProvider.notifier).requestOtp(_savedMobile!);
      return;
    }
    if (_formKey.currentState?.validate() ?? false) {
      ref.read(authProvider.notifier).requestOtp(_mobileController.text.trim());
    }
  }
}

class _SavedNumberCard extends StatelessWidget {
  final String text;
  const _SavedNumberCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.lime500.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.lime500.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phone_iphone_rounded,
                color: AppColors.lime400),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Continue with',
                    style:
                        TextStyle(color: AppColors.slate400, fontSize: 12.5)),
                const SizedBox(height: 3),
                Text(text,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: AppColors.lime500),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String text;
  const _ErrorBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.red400.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.red400.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.red400, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: AppColors.red400,
                      fontSize: 13,
                      fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
