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

  Future<Invoice?> getInvoiceForRequest(String serviceRequestId) async {
    final res = await _client.dio.get('/invoices', queryParameters: {'serviceRequestId': serviceRequestId, 'limit': 1});
    final items = res.data['data'] as List;
    return items.isEmpty ? null : Invoice.fromJson(items.first as Map<String, dynamic>);
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
