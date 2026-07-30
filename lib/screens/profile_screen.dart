import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../providers/employee_providers.dart';
import '../theme/app_theme.dart';
import 'otp_request_screen.dart';

// Per docs/rohit/06-vendor-app-screen-list.md "Profile" — Profile view.
// Availability toggle + Notification Center are separate screens flagged
// there too, not yet built (this is the read-only profile + logout slice).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myEmployeeProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.slate100,
      appBar: AppBar(
        title: const Text('Profile'),
        // Always visible regardless of whether the profile fetch below
        // succeeds — logout was previously only reachable from inside the
        // `data:` branch of profile.when(), so any profile-load failure
        // (network hiccup, permission issue, etc.) left the technician with
        // no way to sign out at all. Fixed as a real bug, not a style tweak.
        actions: [
          IconButton(
            tooltip: 'Log Out',
            icon: const Icon(Icons.logout, color: AppColors.urgent),
            onPressed: () => _logout(context, ref),
          ),
        ],
      ),
      body: profile.when(
        data: (p) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(myEmployeeProfileProvider),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: glassCardDecoration(radius: 20),
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark])),
                      child: Center(child: Text(_initials(p.name), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(height: 14),
                    Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    if (p.mobile != null) ...[
                      const SizedBox(height: 3),
                      Text(p.mobile!, style: const TextStyle(color: AppColors.slate500, fontSize: 13)),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(color: p.active ? AppColors.success.withValues(alpha: 0.1) : AppColors.slate500.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text(p.active ? 'Active' : 'Inactive', style: TextStyle(color: p.active ? AppColors.success : AppColors.slate500, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              if (p.skills.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: glassCardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Skills', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: p.skills
                            .map((s) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(20)),
                                  child: Text(s, style: const TextStyle(fontSize: 12, color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _logout(context, ref),
                icon: const Icon(Icons.logout, size: 18, color: AppColors.urgent),
                label: const Text('Log Out', style: TextStyle(color: AppColors.urgent)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.urgent)),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40, color: AppColors.slate400),
                const SizedBox(height: 12),
                Text('Could not load profile: $err', style: const TextStyle(color: AppColors.slate500), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => _logout(context, ref),
                  icon: const Icon(Icons.logout, size: 18, color: AppColors.urgent),
                  label: const Text('Log Out', style: TextStyle(color: AppColors.urgent)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.urgent)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(authProvider.notifier).logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const OtpRequestScreen()), (route) => false);
    }
  }
}
