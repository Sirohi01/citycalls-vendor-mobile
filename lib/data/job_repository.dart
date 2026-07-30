import 'dart:io';
import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/job_models.dart';

// One repository class per module, per docs/12-frontend-data-contracts.md §3.
// No assigneeId is ever sent from this app — the backend derives "my jobs"
// server-side from the JWT's employeeId once scope is OWN
// (serviceRequests.service.ts listServiceRequests), so there's nothing here
// for a compromised/tampered client to override.
class JobRepository {
  final ApiClient _client;
  JobRepository(this._client);

  Future<List<JobSummary>> listJobs({List<String>? statusIn}) async {
    final res = await _client.dio.get('/service-requests', queryParameters: {
      'limit': 100,
      if (statusIn != null && statusIn.isNotEmpty) 'status_in': statusIn.join(','),
    });
    return (res.data['data'] as List).map((j) => JobSummary.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<JobDetail> getJob(String id) async {
    final res = await _client.dio.get('/service-requests/$id');
    return JobDetail.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  // Per docs/rohit/06-vendor-app-screen-list.md "Execution" — Accept/Reject,
  // Start Travel, Arrival, and the rest of the status ladder a TECHNICIAN/
  // EMPLOYEE actor can drive are all just this one endpoint with different
  // `toStatus` values (confirmed against scripts/seed.ts's SERVICE_REQUEST
  // transition table — there's no separate accept/reject endpoint).
  Future<void> changeStatus(String id, String toStatus, {String? reason}) async {
    await _client.dio.patch('/service-requests/$id/status', data: {
      'toStatus': toStatus,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }

  // Broadcasts live location to the customer (realtime) — distinct from the
  // `geo` field on changeStatus, which the backend accepts but doesn't
  // actually persist/emit (serviceRequests.service.ts's updateStatus ignores
  // it), so this is the only path that actually updates live tracking.
  Future<void> sendLocationPing(String id, double lat, double lng) async {
    await _client.dio.post('/service-requests/$id/location-ping', data: {'lat': lat, 'lng': lng});
  }

  Future<void> updateInspection(String id, {String? defectFound, List<String>? symptoms, String? solutionType}) async {
    await _client.dio.patch('/service-requests/$id/visits/inspection', data: {
      if (defectFound != null && defectFound.isNotEmpty) 'defectFound': defectFound,
      if (symptoms != null) 'symptoms': symptoms,
      if (solutionType != null && solutionType.isNotEmpty) 'solutionType': solutionType,
    });
  }

  Future<void> updateWork(String id, {double? labourCharge, String? workNotes, List<String>? beforeImages, List<String>? afterImages}) async {
    await _client.dio.patch('/service-requests/$id/visits/work', data: {
      if (labourCharge != null) 'labourCharge': labourCharge,
      if (workNotes != null && workNotes.isNotEmpty) 'workNotes': workNotes,
      if (beforeImages != null && beforeImages.isNotEmpty) 'beforeImages': beforeImages,
      if (afterImages != null && afterImages.isNotEmpty) 'afterImages': afterImages,
    });
  }

  Future<void> completeVisit(String id, {required String proofType, String? value, String? url}) async {
    await _client.dio.post('/service-requests/$id/visits/complete', data: {
      'completionProof': {
        'type': proofType,
        if (value != null) 'value': value,
        if (url != null) 'url': url,
      },
    });
  }

  // OTP goes to the CUSTOMER's phone, not the technician's — this just
  // triggers/verifies it; the technician asks the customer to read it out.
  Future<void> requestCompletionOtp(String id) async {
    await _client.dio.post('/service-requests/$id/completion-otp/request');
  }

  Future<void> verifyCompletionOtp(String id, String otp) async {
    await _client.dio.post('/service-requests/$id/completion-otp/verify', data: {'otp': otp});
  }

  // Same signed-upload -> Cloudinary -> confirm flow as
  // citycalls-customer-mobile's booking_repository.dart uploadIssueImage,
  // independently implemented (no shared code between the two apps) —
  // category is BEFORE_SERVICE_IMAGE/AFTER_SERVICE_IMAGE here instead of
  // ISSUE_IMAGE, and entityId is the ServiceRequest, not the Customer.
  Future<String> uploadJobImage(String jobId, File file, {required String category}) async {
    final signedRes = await _client.dio.post('/files/signed-upload', data: {
      'category': category,
      'entityType': 'SERVICE_REQUEST',
      'entityId': jobId,
    });
    final signed = signedRes.data['data'] as Map<String, dynamic>;

    if (signed['mode'] == 'CLOUDINARY') {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
        'timestamp': signed['timestamp'].toString(),
        'signature': signed['signature'],
        'api_key': signed['apiKey'],
        'folder': signed['folder'],
      });
      // Deliberately a bare Dio(), not _client.dio — Cloudinary must not
      // receive our API's Authorization/Bearer header.
      final cloudinaryRes = await Dio().post('https://api.cloudinary.com/v1_1/${signed['cloudName']}/auto/upload', data: form);
      final confirmRes = await _client.dio.post('/files/confirm', data: {
        'category': category,
        'entityType': 'SERVICE_REQUEST',
        'entityId': jobId,
        'publicId': cloudinaryRes.data['public_id'],
        'url': cloudinaryRes.data['secure_url'],
        'mimeType': 'image/jpeg',
        'sizeBytes': await file.length(),
      });
      return confirmRes.data['data']['url'] as String;
    }

    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
      'category': category,
      'entityType': 'SERVICE_REQUEST',
      'entityId': jobId,
    });
    final res = await _client.dio.post('/files/upload', data: form);
    return res.data['data']['url'] as String;
  }
}
