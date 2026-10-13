import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/vendor_models.dart';
import '../providers/vendor_management_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';
import '../widgets/ui_kit.dart';

// Read-only technician roster — adding a technician needs picking an
// existing User account with role VENDOR_TECHNICIAN, which requires
// users:view permission this role deliberately doesn't have (scripts/seed.ts)
// — that onboarding step stays an admin-web action for now.
class VendorRosterScreen extends ConsumerWidget {
  const VendorRosterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final techniciansAsync = ref.watch(vendorTechniciansProvider);
    return RefreshIndicator(
      color: AppColors.green,
      onRefresh: () async {
        ref.invalidate(vendorTechniciansProvider);
        await ref
            .read(vendorTechniciansProvider.future)
            .catchError((_) => <VendorTechnicianEntry>[]);
      },
      child: techniciansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, __) => ListView(
          children: [
            const SizedBox(height: 80),
            AppErrorView(
                error: err,
                onRetry: () => ref.invalidate(vendorTechniciansProvider)),
          ],
        ),
        data: (technicians) {
          if (technicians.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 100),
                UiEmptyState(
                  icon: Icons.groups_outlined,
                  title: 'No technicians yet',
                  message:
                      'Contact CityCalls admin to add technicians to your company.',
                ),
              ],
            );
          }
          final active = technicians.where((t) => t.active).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              UiSectionLabel(
                  '$active active • ${technicians.length - active} inactive'),
              for (final t in technicians)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TechnicianCard(technician: t),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TechnicianCard extends StatelessWidget {
  final VendorTechnicianEntry technician;
  const _TechnicianCard({required this.technician});

  @override
  Widget build(BuildContext context) {
    final t = technician;
    return UiCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UiIconTile(
              icon: Icons.person_rounded,
              color: t.active ? AppColors.green : AppColors.faint,
              size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name ?? 'Technician',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: AppColors.ink)),
                if (t.mobile != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('+91 ${t.mobile}',
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.muted)),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    UiPill(
                        text: t.active ? 'Active' : 'Inactive',
                        color: t.active ? AppColors.success : AppColors.muted),
                    for (final s in t.skills)
                      UiPill(text: s, color: AppColors.info),
                  ],
                ),
              ],
            ),
          ),
          if (t.mobile != null)
            IconButton(
              tooltip: 'Call',
              onPressed: () => launchUrl(
                      Uri(scheme: 'tel', path: '+91${t.mobile}'),
                      mode: LaunchMode.externalApplication)
                  .catchError((_) => false),
              style: IconButton.styleFrom(
                  backgroundColor: AppColors.green.withValues(alpha: 0.1)),
              icon: const Icon(Icons.call_rounded,
                  size: 20, color: AppColors.green),
            ),
        ],
      ),
    );
  }
}
