import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/vendor_management_repository.dart';
import '../models/vendor_models.dart';
import '../models/job_models.dart';
import 'auth_providers.dart';

final vendorManagementRepositoryProvider = Provider<VendorManagementRepository>((ref) {
  return VendorManagementRepository(ref.watch(apiClientProvider));
});

// The logged-in VENDOR_OWNER/VENDOR_MANAGER's own vendorId, from the JWT-
// adjacent auth response (auth.service.ts's issueTokens now includes it).
final ownVendorIdProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).user?.vendorId;
});

final ownVendorProvider = FutureProvider<VendorCompany>((ref) async {
  final vendorId = ref.watch(ownVendorIdProvider);
  if (vendorId == null) throw Exception('No vendor company linked to this account');
  return ref.watch(vendorManagementRepositoryProvider).getVendor(vendorId);
});

final vendorTechniciansProvider = FutureProvider<List<VendorTechnicianEntry>>((ref) async {
  final vendorId = ref.watch(ownVendorIdProvider);
  if (vendorId == null) return [];
  return ref.watch(vendorManagementRepositoryProvider).listTechnicians(vendorId);
});

final vendorJobsProvider = FutureProvider<List<JobSummary>>((ref) {
  return ref.watch(vendorManagementRepositoryProvider).listJobs();
});

final vendorInvoicesProvider = FutureProvider<List<VendorInvoice>>((ref) async {
  final vendorId = ref.watch(ownVendorIdProvider);
  if (vendorId == null) return [];
  return ref.watch(vendorManagementRepositoryProvider).listInvoices(vendorId);
});

final vendorPayoutsProvider = FutureProvider<List<VendorPayout>>((ref) async {
  final vendorId = ref.watch(ownVendorIdProvider);
  if (vendorId == null) return [];
  return ref.watch(vendorManagementRepositoryProvider).listPayouts(vendorId);
});
