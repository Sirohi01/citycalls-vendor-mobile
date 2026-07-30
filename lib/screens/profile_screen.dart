import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../providers/employee_providers.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

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
      appBar: AppBar(title: const Text('Profile')),
      body: profile.when(
        data: (p) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Column(
                children: [
                  const CircleAvatar(radius: 36, backgroundColor: AppColors.primaryLight, child: Icon(Icons.person, size: 36, color: AppColors.primary)),
                  const SizedBox(height: 12),
                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  if (p.mobile != null) Text(p.mobile!, style: const TextStyle(color: AppColors.slate500, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (p.skills.isNotEmpty) ...[
              const Text('Skills', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              const SizedBox(height: 8),
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
              const SizedBox(height: 24),
            ],
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
                }
              },
              icon: const Icon(Icons.logout, size: 18, color: AppColors.urgent),
              label: const Text('Log Out', style: TextStyle(color: AppColors.urgent)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.urgent)),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, __) => Center(child: Text('Could not load profile: $err', style: const TextStyle(color: AppColors.slate500))),
      ),
    );
  }
}
