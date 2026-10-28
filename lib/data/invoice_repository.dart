import 'api_client.dart';
import '../models/invoice_models.dart';

// Online-only, same as estimate_repository.dart — /invoices is a separate
// finance module, not part of the offline sync-batch queue. Recording a
// payment here also drives the linked ServiceRequest's status forward
// server-side (payments.service.ts's existing recordPayment sync) — this
// app just needs to re-fetch the job after.
class InvoiceRepository {
  final ApiClient _client;
  InvoiceRepository(this._client);

  // The job's live invoice — newest first, skipping CANCELLED ones (a
  // cancelled invoice can't take payments; the office may have re-billed).
  Future<Invoice?> getInvoiceForRequest(String serviceRequestId) async {
    final res = await _client.dio.get('/invoices', queryParameters: {'serviceRequestId': serviceRequestId, 'limit': 10});
    final items = (res.data['data'] as List).map((i) => Invoice.fromJson(i as Map<String, dynamic>));
    return items.where((i) => i.status != 'CANCELLED').firstOrNull;
  }

  // The bill still in play — CANCELLED ones are dead and CONVERTED ones have
  // already become the invoice above, so neither should hold the screen on
  // "waiting for the customer".
  Future<ProformaInvoice?> getProformaForRequest(String serviceRequestId) async {
    final res = await _client.dio.get('/proforma-invoices', queryParameters: {'serviceRequestId': serviceRequestId, 'limit': 10});
    final items = (res.data['data'] as List).map((p) => ProformaInvoice.fromJson(p as Map<String, dynamic>));
    return items.where((p) => p.status != 'CANCELLED' && p.status != 'CONVERTED').firstOrNull;
  }

  // Carries the approved Estimate's exact items straight through to a
  // customer-facing bill — no re-typing. Stops at SHARED; the customer still
  // has to accept it (their own app) before convertProformaToInvoice below
  // will succeed.
  Future<ProformaInvoice> generateProformaInvoice(String serviceRequestId) async {
    final res = await _client.dio.post('/service-requests/$serviceRequestId/generate-proforma-invoice');
    return ProformaInvoice.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<Invoice> convertProformaToInvoice(String proformaId) async {
    final res = await _client.dio.post('/proforma-invoices/$proformaId/convert');
    return Invoice.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<Invoice> createInvoice({
    required String customerId,
    required String branchId,
    required String serviceRequestId,
    required List<InvoiceLineItem> items,
  }) async {
    final res = await _client.dio.post('/invoices', data: {
      'customerId': customerId,
      'branchId': branchId,
      'serviceRequestId': serviceRequestId,
      'items': items.map((i) => i.toJson()).toList(),
    });
    return Invoice.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> recordPayment(String invoiceId, {required double amount, required String method, String? reference}) async {
    await _client.dio.post('/invoices/$invoiceId/payments', data: {
      'amount': amount,
      'method': method,
      if (reference != null && reference.isNotEmpty) 'reference': reference,
    });
  }

  Future<List<PaymentReceipt>> listPayments(String invoiceId) async {
    final res = await _client.dio.get('/invoices/$invoiceId/payments');
    return (res.data['data'] as List).map((p) => PaymentReceipt.fromJson(p as Map<String, dynamic>)).toList();
  }
}
