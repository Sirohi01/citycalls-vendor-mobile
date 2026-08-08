import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job_models.dart';
import '../providers/vendor_management_providers.dart';
import '../theme/app_theme.dart';

class VendorDashboardScreen extends ConsumerWidget {
  const VendorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorAsync = ref.watch(ownVendorProvider);
    final jobsAsync = ref.watch(vendorJobsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(ownVendorProvider);
        ref.invalidate(vendorJobsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          vendorAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (vendor) => GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark])),
                    child: Center(child: Icon(Icons.business, color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(vendor.companyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(
                          vendor.blacklisted ? 'Blacklisted' : (vendor.active ? 'Active' : 'Inactive'),
                          style: TextStyle(fontSize: 12, color: vendor.blacklisted ? AppColors.urgent : secondaryTextColor(context)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          jobsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            error: (err, __) => Padding(padding: const EdgeInsets.all(16), child: Text('Could not load jobs: $err', style: const TextStyle(color: AppColors.urgent))),
            data: (jobs) => _JobsOverview(jobs: jobs),
          ),
        ],
      ),
    );
  }
}

class _JobsOverview extends StatelessWidget {
  final List<JobSummary> jobs;
  const _JobsOverview({required this.jobs});

  static const _completedStatuses = {'SERVICE_COMPLETED', 'CUSTOMER_CONFIRMATION_PENDING', 'PAYMENT_PENDING', 'PARTIALLY_PAID', 'PAID', 'CLOSED'};
  static const _cancelledStatuses = {'CANCELLED', 'REASSIGNMENT_REQUIRED'};

  @override
  Widget build(BuildContext context) {
    final total = jobs.length;
    final completed = jobs.where((j) => _completedStatuses.contains(j.status)).length;
    final cancelled = jobs.where((j) => _cancelledStatuses.contains(j.status)).length;
    final active = total - completed - cancelled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _StatChip(label: 'Total', value: total, color: AppColors.primary)),
            const SizedBox(width: 8),
            Expanded(child: _StatChip(label: 'Active', value: active, color: AppColors.gold400)),
            const SizedBox(width: 8),
            Expanded(child: _StatChip(label: 'Done', value: completed, color: Colors.green)),
          ],
        ),
        const SizedBox(height: 20),
        Text('Jobs', style: TextStyle(fontWeight: FontWeight.w700, color: secondaryTextColor(context))),
        const SizedBox(height: 10),
        if (jobs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No jobs assigned to your company yet.', style: TextStyle(color: secondaryTextColor(context)))),
          )
        else
          ...jobs.map((j) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(j.number, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(j.serviceName ?? j.city, style: TextStyle(fontSize: 12, color: secondaryTextColor(context))),
                          ],
                        ),
                      ),
                      Text(jobStatusLabel(j.status), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ],
                  ),
                ),
              )),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11.5, color: secondaryTextColor(context))),
        ],
      ),
    );
  }
}
