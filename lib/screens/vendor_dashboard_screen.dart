import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job_models.dart';
import '../providers/vendor_management_providers.dart';
import '../theme/app_theme.dart';
import 'package:flutter/services.dart';
import '../widgets/hero_header.dart';
import '../widgets/job_card.dart';
import '../widgets/state_views.dart';
import '../widgets/ui_kit.dart';

class VendorDashboardScreen extends ConsumerWidget {
  final VoidCallback onLogout;
  const VendorDashboardScreen({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorAsync = ref.watch(ownVendorProvider);
    final jobsAsync = ref.watch(vendorJobsProvider);
    final techniciansAsync = ref.watch(vendorTechniciansProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: RefreshIndicator(
          color: AppColors.green,
          onRefresh: () async {
            ref.invalidate(ownVendorProvider);
            ref.invalidate(vendorJobsProvider);
            ref.invalidate(vendorTechniciansProvider);
          },
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _Header(
                  vendorAsync: vendorAsync,
                  jobsAsync: jobsAsync,
                  techniciansAsync: techniciansAsync,
                  onLogout: onLogout),
              Padding(
                padding: const EdgeInsets.all(16),
                child: jobsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, __) => UiCard(
                    child: AppErrorView(
                        error: err,
                        compact: true,
                        onRetry: () => ref.invalidate(vendorJobsProvider)),
                  ),
                  data: (jobs) => _JobsOverview(jobs: jobs),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AsyncValue vendorAsync;
  final AsyncValue<List<JobSummary>> jobsAsync;
  final AsyncValue<List<dynamic>> techniciansAsync;
  final VoidCallback onLogout;
  const _Header(
      {required this.vendorAsync,
      required this.jobsAsync,
      required this.techniciansAsync,
      required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final jobs = jobsAsync.value ?? const <JobSummary>[];
    final activeTechs = (techniciansAsync.value ?? const [])
        .where((t) => (t as dynamic).active == true)
        .length;
    final companyName = vendorAsync.whenOrNull(
        data: (v) => (v as dynamic).companyName as String?);

    return HeroHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Wordmark(size: 24),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.heroLime.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('PARTNER',
                    style: TextStyle(
                        color: AppColors.heroLime,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2)),
              ),
              const Spacer(),
              HeroIconButton(
                  icon: Icons.logout_rounded,
                  tooltip: 'Log out',
                  onPressed: onLogout),
            ],
          ),
          const SizedBox(height: 18),
          Text('Your company',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 13.5)),
          const SizedBox(height: 2),
          Text(companyName ?? (vendorAsync.isLoading ? '' : 'Vendor'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                  child: HeroStat(
                      icon: Icons.work_outline_rounded,
                      label: 'Total jobs',
                      value: jobsAsync.value?.length)),
              const SizedBox(width: 8),
              Expanded(
                  child: HeroStat(
                      icon: Icons.pending_actions_outlined,
                      label: 'Active',
                      highlight: true,
                      value: jobsAsync.value == null
                          ? null
                          : jobs
                              .where((j) =>
                                  !_completedStatuses.contains(j.status) &&
                                  !_cancelledStatuses.contains(j.status))
                              .length)),
              const SizedBox(width: 8),
              Expanded(
                  child: HeroStat(
                      icon: Icons.groups_outlined,
                      label: 'Active techs',
                      value:
                          techniciansAsync.value != null ? activeTechs : null)),
            ],
          ),
        ],
      ),
    );
  }
}

const _completedStatuses = {
  'SERVICE_COMPLETED',
  'CUSTOMER_CONFIRMATION_PENDING',
  'PAYMENT_PENDING',
  'PARTIALLY_PAID',
  'PAID',
  'CLOSED'
};
const _cancelledStatuses = {'CANCELLED', 'REASSIGNMENT_REQUIRED'};

class _JobsOverview extends StatelessWidget {
  final List<JobSummary> jobs;
  const _JobsOverview({required this.jobs});

  @override
  Widget build(BuildContext context) {
    final total = jobs.length;
    final completed =
        jobs.where((j) => _completedStatuses.contains(j.status)).length;
    final cancelled =
        jobs.where((j) => _cancelledStatuses.contains(j.status)).length;
    final active = total - completed - cancelled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (total > 0) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  flex: 5,
                  child: _StatusDonut(
                      active: active,
                      completed: completed,
                      cancelled: cancelled)),
              const SizedBox(width: 12),
              Expanded(flex: 4, child: _WeekTrend(jobs: jobs)),
            ],
          ),
          const SizedBox(height: 20),
        ],
        const UiSectionLabel('Jobs'),
        if (jobs.isEmpty)
          const UiCard(
            child: UiEmptyState(
              icon: Icons.work_off_outlined,
              title: 'No jobs yet',
              message: 'Jobs assigned to your company will show up here.',
            ),
          )
        else
          ...jobs.map((j) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: JobCard(
                    job: j, highlight: newJobStatuses.contains(j.status)),
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
  const _StatusDonut(
      {required this.active, required this.completed, required this.cancelled});

  @override
  Widget build(BuildContext context) {
    final total = active + completed + cancelled;
    return GlassCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Job Status',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: strongSecondaryTextColor(context))),
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
                      if (active > 0)
                        PieChartSectionData(
                            value: active.toDouble(),
                            color: AppColors.info,
                            radius: 20,
                            showTitle: false),
                      if (completed > 0)
                        PieChartSectionData(
                            value: completed.toDouble(),
                            color: AppColors.success,
                            radius: 20,
                            showTitle: false),
                      if (cancelled > 0)
                        PieChartSectionData(
                            value: cancelled.toDouble(),
                            color: AppColors.slate300,
                            radius: 20,
                            showTitle: false),
                      if (total == 0)
                        PieChartSectionData(
                            value: 1,
                            color: AppColors.slate200,
                            radius: 20,
                            showTitle: false),
                    ],
                  ),
                ),
                Text('$total',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _LegendRow(color: AppColors.info, label: 'Active', value: active),
          const SizedBox(height: 6),
          _LegendRow(color: AppColors.success, label: 'Done', value: completed),
          if (cancelled > 0) ...[
            const SizedBox(height: 6),
            _LegendRow(
                color: AppColors.slate300,
                label: 'Cancelled',
                value: cancelled),
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
  const _LegendRow(
      {required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 6),
        Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 11.5, color: secondaryTextColor(context)))),
        Text('$value',
            style:
                const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
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
    final days = List.generate(
        7,
        (i) => DateTime(today.year, today.month, today.day)
            .subtract(Duration(days: 6 - i)));
    final counts = days
        .map((d) => jobs
            .where((j) =>
                j.scheduledDate != null && _isSameDay(j.scheduledDate!, d))
            .length)
        .toList();
    final maxY = (counts.isEmpty ? 0 : counts.reduce((a, b) => a > b ? a : b))
        .toDouble();

    return GlassCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(10, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text('This Week',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: strongSecondaryTextColor(context))),
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
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= days.length) {
                          return const SizedBox.shrink();
                        }
                        const labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(labels[days[i].weekday % 7],
                              style: TextStyle(
                                  fontSize: 10,
                                  color: secondaryTextColor(context))),
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
                        color: i == counts.length - 1
                            ? AppColors.green
                            : AppColors.green.withValues(alpha: 0.35),
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

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
