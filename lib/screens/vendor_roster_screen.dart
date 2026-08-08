import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/vendor_management_providers.dart';
import '../theme/app_theme.dart';

// Read-only technician roster — adding a technician needs picking an
// existing User account with role VENDOR_TECHNICIAN, which requires
// users:view permission this role deliberately doesn't have (scripts/seed.ts)
// — that onboarding step stays an admin-web/admin action for now.
class VendorRosterScreen extends ConsumerWidget {
  const VendorRosterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final techniciansAsync = ref.watch(vendorTechniciansProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(vendorTechniciansProvider),
      child: techniciansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, __) => Center(child: Text('Could not load roster: $err', style: const TextStyle(color: AppColors.urgent))),
        data: (technicians) => technicians.isEmpty
            ? ListView(
                children: [
                  SizedBox(
                    height: 400,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.groups_outlined, size: 48, color: secondaryTextColor(context)),
                          const SizedBox(height: 12),
                          Text('No technicians on your roster yet.', style: TextStyle(color: secondaryTextColor(context))),
                          const SizedBox(height: 4),
                          Text('Contact CityCalls admin to add one.', style: TextStyle(fontSize: 12, color: secondaryTextColor(context))),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: technicians.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final t = technicians[i];
                  return GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                          child: Center(child: Icon(Icons.person, color: AppColors.primary, size: 20)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.name ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              if (t.mobile != null) Text(t.mobile!, style: TextStyle(fontSize: 12, color: secondaryTextColor(context))),
                              if (t.skills.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: t.skills
                                      .map((s) => Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(color: subtleSurfaceColor(context), borderRadius: BorderRadius.circular(20)),
                                            child: Text(s, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                                          ))
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (t.active ? Colors.green : AppColors.slate500).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            t.active ? 'Active' : 'Inactive',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: t.active ? Colors.green : AppColors.slate500),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
