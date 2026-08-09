import 'api_client.dart';
import '../models/estimate_models.dart';

// Not part of the offline sync-batch protocol (ADD_PARTS/STATUS_CHANGE etc.
// in job_repository.dart) — /estimates is a separate finance module with its
// own online-only endpoints, same as citycalls-admin-web's useEstimates.
// Creating/sharing an estimate here also drives the linked ServiceRequest's
// own status forward server-side (estimates.service.ts's
// syncServiceRequestStatus) — this app just needs to re-fetch the job after.
class EstimateRepository {
  final ApiClient _client;
  EstimateRepository(this._client);

  Future<Estimate> createEstimate({
    required String customerId,
    required String branchId,
    required String serviceRequestId,
    required List<EstimateLineItem> items,
  }) async {
    final res = await _client.dio.post('/estimates', data: {
      'customerId': customerId,
      'branchId': branchId,
      'serviceRequestId': serviceRequestId,
      'items': items.map((i) => i.toJson()).toList(),
    });
    return Estimate.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<Estimate> shareEstimate(String id, {List<String> channels = const ['WHATSAPP']}) async {
    final res = await _client.dio.post('/estimates/$id/share', data: {'channels': channels});
    return Estimate.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<Estimate?> getApprovedEstimateForRequest(String serviceRequestId) async {
    final res = await _client.dio.get('/estimates', queryParameters: {'serviceRequestId': serviceRequestId, 'status': 'APPROVED', 'limit': 1});
    final items = res.data['data'] as List;
    return items.isEmpty ? null : Estimate.fromJson(items.first as Map<String, dynamic>);
  }
}
