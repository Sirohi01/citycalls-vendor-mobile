import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/job_repository.dart';
import '../data/estimate_repository.dart';
import '../data/invoice_repository.dart';
import '../models/job_models.dart';
import '../models/invoice_models.dart';
import '../models/estimate_models.dart';
import 'auth_providers.dart';
import 'sync_providers.dart';

final jobRepositoryProvider = Provider<JobRepository>((ref) {
  return JobRepository(ref.watch(apiClientProvider), ref.watch(syncRepositoryProvider), ref.watch(syncEngineProvider));
});

final estimateRepositoryProvider = Provider<EstimateRepository>((ref) {
  return EstimateRepository(ref.watch(apiClientProvider));
});

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepository(ref.watch(apiClientProvider));
});

final invoiceForRequestProvider = FutureProvider.family<Invoice?, String>((ref, serviceRequestId) {
  return ref.watch(invoiceRepositoryProvider).getInvoiceForRequest(serviceRequestId);
});

final proformaForRequestProvider = FutureProvider.family<ProformaInvoice?, String>((ref, serviceRequestId) {
  return ref.watch(invoiceRepositoryProvider).getProformaForRequest(serviceRequestId);
});

final approvedEstimateForRequestProvider = FutureProvider.family<Estimate?, String>((ref, serviceRequestId) {
  return ref.watch(estimateRepositoryProvider).getApprovedEstimateForRequest(serviceRequestId);
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

final serviceDiagnosticsProvider = FutureProvider.family<ServiceDiagnostics, String>((ref, serviceId) {
  return ref.watch(jobRepositoryProvider).getServiceDiagnostics(serviceId);
});
