import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job_models.dart';
import '../providers/vendor_management_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/glow_blob.dart';
import 'job_detail_screen.dart';

class VendorDashboardScreen extends ConsumerWidget {
  const VendorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorAsync = ref.watch(ownVendorProvider);
    final jobsAsync = ref.watch(vendorJobsProvider);
    final techniciansAsync = ref.watch(vendorTechniciansProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(ownVendorProvider);
        ref.invalidate(vendorJobsProvider);
        ref.invalidate(vendorTechniciansProvider);
      },
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(vendorAsync: vendorAsync, jobsAsync: jobsAsync, techniciansAsync: techniciansAsync),
          Padding(
            padding: const EdgeInsets.all(16),
            child: jobsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, __) => Text('Could not load jobs: $err', style: const TextStyle(color: AppColors.urgent)),
              data: (jobs) => _JobsOverview(jobs: jobs),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AsyncValue vendorAsync;
  final AsyncValue<List<JobSummary>> jobsAsync;
  final AsyncValue<List<dynamic>> techniciansAsync;
  const _Header({required this.vendorAsync, required this.jobsAsync, required this.techniciansAsync});

  @override
  Widget build(BuildContext context) {
    final jobs = jobsAsync.value ?? const <JobSummary>[];
    final activeTechs = (techniciansAsync.value ?? const []).where((t) => (t as dynamic).active == true).length;

    return ClipRRect(
      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primary, AppColors.primaryDark]),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned(right: -60, top: -60, child: GlowBlob(color: AppColors.teal400, size: 200)),
                const Positioned(left: -70, bottom: -50, child: GlowBlob(color: AppColors.gold400, size: 170)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
                          child: const Icon(Icons.business, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: vendorAsync.when(
                            data: (v) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Your company', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                                const SizedBox(height: 2),
                                Text(v.companyName,
                                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white),
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                            loading: () => const SizedBox(height: 36),
                            error: (_, __) => const Text('Your company', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(child: _StatChip(icon: Icons.work_outline, label: 'Total Jobs', value: jobsAsync.value?.length)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _StatChip(
                                icon: Icons.pending_actions_outlined,
                                label: 'Active',
                                value: jobs.where((j) => !_completedStatuses.contains(j.status) && !_cancelledStatuses.contains(j.status)).length)),
                        const SizedBox(width: 8),
                        Expanded(child: _StatChip(icon: Icons.groups_outlined, label: 'Active Techs', value: techniciansAsync.value != null ? activeTechs : null)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _completedStatuses = {'SERVICE_COMPLETED', 'CUSTOMER_CONFIRMATION_PENDING', 'PAYMENT_PENDING', 'PARTIALLY_PAID', 'PAID', 'CLOSED'};
const _cancelledStatuses = {'CANCELLED', 'REASSIGNMENT_REQUIRED'};

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? value;
  const _StatChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(height: 6),
          Text(value?.toString() ?? '—', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, height: 1.1)),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _JobsOverview extends StatelessWidget {
  final List<JobSummary> jobs;
  const _JobsOverview({required this.jobs});

  @override
  Widget build(BuildContext context) {
    final total = jobs.length;
    final completed = jobs.where((j) => _completedStatuses.contains(j.status)).length;
    final cancelled = jobs.where((j) => _cancelledStatuses.contains(j.status)).length;
    final active = total - completed - cancelled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (total > 0) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: _StatusDonut(active: active, completed: completed, cancelled: cancelled)),
              const SizedBox(width: 12),
              Expanded(flex: 4, child: _WeekTrend(jobs: jobs)),
            ],
          ),
          const SizedBox(height: 20),
        ],
        Text('Jobs', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: strongSecondaryTextColor(context))),
        const SizedBox(height: 10),
        if (jobs.isEmpty)
          const GlassCard(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(Icons.work_off_outlined, size: 40, color: AppColors.slate400),
                SizedBox(height: 10),
                Text('No jobs assigned to your company yet.', style: TextStyle(color: AppColors.slate500)),
              ],
            ),
          )
        else
          ...jobs.map((j) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  radius: 16,
                  padding: EdgeInsets.zero,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: j.id))),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: statusAccentColor(j.status)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(j.number, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                  const SizedBox(height: 2),
                                  Text(j.serviceName ?? j.city, style: TextStyle(fontSize: 11.5, color: secondaryTextColor(context)), overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            Text(jobStatusLabel(j.status), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusAccentColor(j.status))),
                            const Icon(Icons.chevron_right, size: 18, color: AppColors.slate400),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )),
      ],
    );
  }
}

// Fleet-status breakdown at a glance — how a company owner opens this app: to
// see how much work is in flight vs. wrapped up, not to read a jobs table.
class _StatusDonut extends StatelessWidget {
  final int active;
  final int completed;
  final int cancelled;
  const _StatusDonut({required this.active, required this.completed, required this.cancelled});

  @override
  Widget build(BuildContext context) {
    final total = active + completed + cancelled;
    return GlassCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Job Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: strongSecondaryTextColor(context))),
          const SizedBox(height: 10),
          SizedBox(
            height: 108,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 30,
                    sections: [
                      if (active > 0) PieChartSectionData(value: active.toDouble(), color: AppColors.info, radius: 20, showTitle: false),
                      if (completed > 0) PieChartSectionData(value: completed.toDouble(), color: AppColors.success, radius: 20, showTitle: false),
                      if (cancelled > 0) PieChartSectionData(value: cancelled.toDouble(), color: AppColors.slate300, radius: 20, showTitle: false),
                      if (total == 0) PieChartSectionData(value: 1, color: AppColors.slate200, radius: 20, showTitle: false),
                    ],
                  ),
                ),
                Text('$total', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _LegendRow(color: AppColors.info, label: 'Active', value: active),
          const SizedBox(height: 6),
          _LegendRow(color: AppColors.success, label: 'Done', value: completed),
          if (cancelled > 0) ...[
            const SizedBox(height: 6),
            _LegendRow(color: AppColors.slate300, label: 'Cancelled', value: cancelled),
          ],
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final int value;
  const _LegendRow({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: TextStyle(fontSize: 11.5, color: secondaryTextColor(context)))),
        Text('$value', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// Last-7-days scheduled-jobs trend — the closest thing to an "earnings/rides
// this week" chart the currently-available data supports (no dated
// invoice/payout data is exposed to this app yet).
class _WeekTrend extends StatelessWidget {
  final List<JobSummary> jobs;
  const _WeekTrend({required this.jobs});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(7, (i) => DateTime(today.year, today.month, today.day).subtract(Duration(days: 6 - i)));
    final counts = days.map((d) => jobs.where((j) => j.scheduledDate != null && _isSameDay(j.scheduledDate!, d)).length).toList();
    final maxY = (counts.isEmpty ? 0 : counts.reduce((a, b) => a > b ? a : b)).toDouble();

    return GlassCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(10, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text('This Week', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: strongSecondaryTextColor(context))),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 108,
            child: BarChart(
              BarChartData(
                maxY: maxY < 4 ? 4 : maxY + 1,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= days.length) return const SizedBox.shrink();
                        const labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(labels[days[i].weekday % 7], style: TextStyle(fontSize: 10, color: secondaryTextColor(context))),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < counts.length; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: counts[i].toDouble(),
                        color: i == counts.length - 1 ? AppColors.primary : AppColors.primary.withValues(alpha: 0.35),
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
