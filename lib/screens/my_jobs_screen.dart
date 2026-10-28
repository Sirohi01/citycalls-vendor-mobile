import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job_models.dart';
import '../providers/job_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/job_card.dart';
import '../widgets/state_views.dart';
import '../widgets/ui_kit.dart';

// Per docs/rohit/06-vendor-app-screen-list.md "Job Management" — My Jobs.
// Real data via GET /service-requests, scoped server-side to this
// technician's own assigned jobs (serviceRequests.service.ts).
class MyJobsScreen extends ConsumerStatefulWidget {
  const MyJobsScreen({super.key});

  @override
  ConsumerState<MyJobsScreen> createState() => _MyJobsScreenState();
}

enum _Filter { all, fresh, today, waiting }

class _MyJobsScreenState extends ConsumerState<MyJobsScreen> {
  _Filter _filter = _Filter.all;

  // Statuses where the ball is in someone else's court (customer approval,
  // payment, office) — the technician can't move these forward right now.
  static const _waitingStatuses = {
    'ESTIMATE_PENDING',
    'ESTIMATE_SHARED',
    'AWAITING_CUSTOMER_APPROVAL',
    'CUSTOMER_UNAVAILABLE',
    'PARTS_PENDING',
    'ON_HOLD',
    'CUSTOMER_CONFIRMATION_PENDING',
    'PAYMENT_PENDING',
    'PARTIALLY_PAID',
  };

  bool _matches(_Filter filter, JobSummary j) {
    switch (filter) {
      case _Filter.all:
        return true;
      case _Filter.fresh:
        return newJobStatuses.contains(j.status);
      case _Filter.today:
        final d = j.scheduledDate?.toLocal();
        final now = DateTime.now();
        return d != null &&
            d.year == now.year &&
            d.month == now.month &&
            d.day == now.day;
      case _Filter.waiting:
        return _waitingStatuses.contains(j.status);
    }
  }

  String _label(_Filter f) => switch (f) {
        _Filter.all => 'All',
        _Filter.fresh => 'New',
        _Filter.today => 'Today',
        _Filter.waiting => 'Waiting',
      };

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(myJobsProvider);
    final items = jobs.valueOrNull ?? const <JobSummary>[];
    final newCount = items.where((j) => newJobStatuses.contains(j.status)).length;

    return Scaffold(
      body: Column(
        children: [
          UiPageHeader(
            title: 'My Jobs',
            subtitle: jobs.hasValue
                ? '${items.length} active${newCount > 0 ? ' • $newCount new' : ''}'
                : 'Your assigned work',
          ),
          const SizedBox(height: 8),
          UiFilterChips<_Filter>(
            values: _Filter.values,
            selected: _filter,
            label: _label,
            count: jobs.hasValue
                ? (f) => items.where((j) => _matches(f, j)).length
                : null,
            onSelected: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.green,
              onRefresh: () async {
                ref.invalidate(allJobsProvider);
                await ref
                    .read(allJobsProvider.future)
                    .catchError((_) => <JobSummary>[]);
              },
              child: jobs.when(
                data: (items) {
                  final shown = items.where((j) => _matches(_filter, j)).toList()
                    ..sort((a, b) {
                      // New requests first, then by appointment / SLA time.
                      final an = newJobStatuses.contains(a.status) ? 0 : 1;
                      final bn = newJobStatuses.contains(b.status) ? 0 : 1;
                      if (an != bn) return an.compareTo(bn);
                      final aTime = a.scheduledDate?.millisecondsSinceEpoch ??
                          a.slaDueAt?.millisecondsSinceEpoch ??
                          0;
                      final bTime = b.scheduledDate?.millisecondsSinceEpoch ??
                          b.slaDueAt?.millisecondsSinceEpoch ??
                          0;
                      return aTime.compareTo(bTime);
                    });
                  if (shown.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 70),
                        UiEmptyState(
                          icon: _filter == _Filter.all
                              ? Icons.task_alt_rounded
                              : Icons.filter_list_off_rounded,
                          title: _filter == _Filter.all
                              ? "You're all caught up"
                              : 'Nothing here',
                          message: _filter == _Filter.all
                              ? 'New jobs assigned to you will show up here.'
                              : 'No jobs match this filter right now.',
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                        16, 8, 16, bottomNavClearance(context)),
                    itemCount: shown.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => JobCard(
                        job: shown[i],
                        highlight: newJobStatuses.contains(shown[i].status)),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, __) => ListView(
                  children: [
                    const SizedBox(height: 80),
                    AppErrorView(
                        error: err,
                        onRetry: () => ref.invalidate(allJobsProvider)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
