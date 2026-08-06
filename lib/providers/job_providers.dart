import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/job_repository.dart';
import '../models/job_models.dart';
import 'auth_providers.dart';
import 'sync_providers.dart';

final jobRepositoryProvider = Provider<JobRepository>((ref) {
  return JobRepository(ref.watch(apiClientProvider), ref.watch(syncRepositoryProvider), ref.watch(syncEngineProvider));
});

// "Active route" — everything not yet in a completed/closed/cancelled state.
// A plain client-side filter (not a status_in param) so the same fetched
// list backs both My Jobs and (once built) a jobs-history view without a
// second round-trip.
final myJobsProvider = FutureProvider<List<JobSummary>>((ref) async {
  final all = await ref.watch(jobRepositoryProvider).listJobs();
  return all.where((j) => !isCompletedJobStatus(j.status)).toList();
});

final completedJobsProvider = FutureProvider<List<JobSummary>>((ref) async {
  final all = await ref.watch(jobRepositoryProvider).listJobs();
  return all.where((j) => isCompletedJobStatus(j.status)).toList();
});

final jobDetailProvider = FutureProvider.family<JobDetail, String>((ref, id) {
  return ref.watch(jobRepositoryProvider).getJob(id);
});
