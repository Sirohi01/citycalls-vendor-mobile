import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job_models.dart';
import '../providers/job_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/job_card.dart';
import '../widgets/state_views.dart';
import '../widgets/ui_kit.dart';

// Per docs/rohit/06-vendor-app-screen-list.md "Job Management" — My Jobs
// (today's route, ordered by scheduled slot). Real data via
// GET /service-requests, scoped server-side to this technician's own
// assigned jobs (serviceRequests.service.ts) — nothing hardcoded/mocked.
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

  bool _matches(JobSummary j) => _matchesFilter(_filter, j);

  bool _matchesFilter(_Filter filter, JobSummary j) {
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

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(myJobsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Jobs'), titleSpacing: 16),
      body: RefreshIndicator(
        color: AppColors.green,
        onRefresh: () async {
          ref.invalidate(allJobsProvider);
          await ref
              .read(allJobsProvider.future)
              .catchError((_) => <JobSummary>[]);
        },
        child: jobs.when(
          data: (items) {
            final counts = {
              for (final f in _Filter.values)
                f: items.where((j) => _matchesFilter(f, j)).length,
            };
            final shown = items.where(_matches).toList()
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

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in _Filter.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('${_label(f)} (${counts[f]})'),
                            selected: _filter == f,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _filter = f),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: UiEmptyState(
                      icon: Icons.task_alt_rounded,
                      title: _filter == _Filter.all
                          ? 'No active jobs right now'
                          : 'Nothing here',
                      message: _filter == _Filter.all
                          ? 'New jobs assigned to you will show up here.'
                          : 'No jobs match this filter.',
                    ),
                  )
                else
                  for (final j in shown)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: JobCard(
                          job: j, highlight: newJobStatuses.contains(j.status)),
                    ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, __) => ListView(
            children: [
              const SizedBox(height: 80),
              AppErrorView(
                  error: err, onRetry: () => ref.invalidate(allJobsProvider)),
            ],
          ),
        ),
      ),
    );
  }

  String _label(_Filter f) => switch (f) {
        _Filter.all => 'All',
        _Filter.fresh => 'New',
        _Filter.today => 'Today',
        _Filter.waiting => 'Waiting',
      };
}
