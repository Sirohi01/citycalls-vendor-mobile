import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../theme/app_theme.dart';
import 'main_shell.dart';

// Per docs/rohit/06-vendor-app-screen-list.md "Onboarding". Serves both
// Employee and Vendor Technician roles from one binary (docs/manish/09 §6).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next.user != null && (previous == null || previous.user == null)) {
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MainShell()), (route) => false);
      }
    });
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.engineering, color: AppColors.primary, size: 34),
                ),
                const SizedBox(height: 20),
                const Text('CityCalls Field', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.slate900)),
                const SizedBox(height: 4),
                const Text('Sign in to see your assigned jobs', style: TextStyle(fontSize: 13.5, color: AppColors.slate500)),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _identifierController,
                  decoration: const InputDecoration(labelText: 'Mobile number or email', prefixIcon: Icon(Icons.person_outline)),
                  validator: (value) => (value == null || value.length < 3) ? 'Enter a valid mobile or email' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  obscureText: _obscure,
                  validator: (value) => (value == null || value.isEmpty) ? 'Password is required' : null,
                ),
                const SizedBox(height: 22),
                if (authState.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(authState.errorMessage!, style: const TextStyle(color: AppColors.urgent, fontSize: 13), textAlign: TextAlign.center),
                  ),
                FilledButton(
                  onPressed: authState.isLoading ? null : _submit,
                  child: authState.isLoading
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                      : const Text('Sign In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      ref.read(authProvider.notifier).login(_identifierController.text, _passwordController.text);
    }
  }
}
