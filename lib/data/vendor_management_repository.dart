import 'api_client.dart';
import '../models/vendor_models.dart';
import '../models/job_models.dart';

// Read-focused — VENDOR_OWNER/VENDOR_MANAGER's own-company view. Billing
// writes (create/approve invoices, create/mark-paid payouts) are
// deliberately NOT exposed here: the backend blocks vendor-role actors from
// authoring their own invoices/payouts (vendorFinance.controller.ts's
// assertNotVendorSelfService), so this app only ever reads that data.
class VendorManagementRepository {
  final ApiClient _client;
  VendorManagementRepository(this._client);

  Future<VendorCompany> getVendor(String vendorId) async {
    final res = await _client.dio.get('/vendors/$vendorId');
    return VendorCompany.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<List<VendorTechnicianEntry>> listTechnicians(String vendorId) async {
    final res = await _client.dio.get('/vendors/$vendorId/technicians');
    return (res.data['data'] as List).map((t) => VendorTechnicianEntry.fromJson(t as Map<String, dynamic>)).toList();
  }

  Future<List<JobSummary>> listJobs() async {
    final res = await _client.dio.get('/service-requests', queryParameters: {'limit': 100});
    return (res.data['data'] as List).map((j) => JobSummary.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<VendorInvoice>> listInvoices(String vendorId) async {
    final res = await _client.dio.get('/vendor-invoices', queryParameters: {'vendorId': vendorId, 'limit': 100});
    return (res.data['data'] as List).map((i) => VendorInvoice.fromJson(i as Map<String, dynamic>)).toList();
  }

  Future<List<VendorPayout>> listPayouts(String vendorId) async {
    final res = await _client.dio.get('/vendor-payouts', queryParameters: {'vendorId': vendorId, 'limit': 100});
    return (res.data['data'] as List).map((p) => VendorPayout.fromJson(p as Map<String, dynamic>)).toList();
  }
}
