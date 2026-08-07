import 'dart:io';
import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/job_models.dart';
import '../sync/sync_repository.dart';
import '../sync/sync_engine.dart';

// Queueable-action exception — the *server* rejected the action (e.g. a
// stale/invalid status transition), as opposed to the action simply still
// being queued because the device is offline. Screens catch this the same
// way they'd catch a direct Dio error; a plain offline queue-and-continue
// never throws at all (see _runQueued below).
class SyncRejectedException implements Exception {
  final String message;
  SyncRejectedException(this.message);
  @override
  String toString() => message;
}

class JobRepository {
  final ApiClient _client;
  final SyncRepository _syncRepo;
  final SyncEngine _syncEngine;
  JobRepository(this._client, this._syncRepo, this._syncEngine);

  Future<List<JobSummary>> listJobs({List<String>? statusIn}) async {
    final res = await _client.dio.get('/service-requests', queryParameters: {
      'limit': 100,
      if (statusIn != null && statusIn.isNotEmpty)
        'status_in': statusIn.join(','),
    });
    return (res.data['data'] as List)
        .map((j) => JobSummary.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<JobDetail> getJob(String id) async {
    final res = await _client.dio.get('/service-requests/$id');
    return JobDetail.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> _runQueued(
      String jobId, String actionType, Map<String, dynamic> payload) async {
    final action = await _syncRepo.enqueue(
        jobId: jobId, actionType: actionType, payload: payload);
    await _syncEngine.syncJob(jobId);
    final latest = await _syncRepo.getById(action.id);
    if (latest.status == 'REJECTED') {
      throw SyncRejectedException(
          latest.resultMessage ?? 'This action was rejected by the server.');
    }
  }

  // Per docs/rohit/06-vendor-app-screen-list.md "Execution" — Accept/Reject,
  // Start Travel, Arrival, and the rest of the status ladder a TECHNICIAN/
  // EMPLOYEE actor can drive are all just this one action type with
  // different `toStatus` values (confirmed against scripts/seed.ts's
  // SERVICE_REQUEST transition table — there's no separate accept/reject
  // endpoint).
  Future<void> changeStatus(String id, String toStatus, {String? reason}) {
    return _runQueued(id, 'STATUS_CHANGE', {
      'toStatus': toStatus,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }

  // Broadcasts live location to the customer (realtime) — deliberately NOT
  // queued. Per docs/manish/09 §5: "old stale pings are dropped rather than
  // sent late... only the most recent unsent ping matters," so a failed ping
  // should just be dropped, not held for later delivery.
  Future<void> sendLocationPing(String id, double lat, double lng) async {
    try {
      await _client.dio.post('/service-requests/$id/location-ping',
          data: {'lat': lat, 'lng': lng});
    } catch (_) {
      // Best-effort — see comment above.
    }
  }

  Future<void> updateInspection(String id,
      {String? defectFound, List<String>? symptoms, String? solutionType}) {
    return _runQueued(id, 'UPDATE_INSPECTION', {
      if (defectFound != null && defectFound.isNotEmpty)
        'defectFound': defectFound,
      if (symptoms != null) 'symptoms': symptoms,
      if (solutionType != null && solutionType.isNotEmpty)
        'solutionType': solutionType,
    });
  }

  Future<void> updateWork(String id,
      {double? labourCharge,
      String? workNotes,
      List<String>? beforeImages,
      List<String>? afterImages}) {
    return _runQueued(id, 'UPDATE_WORK', {
      if (labourCharge != null) 'labourCharge': labourCharge,
      if (workNotes != null && workNotes.isNotEmpty) 'workNotes': workNotes,
      if (beforeImages != null && beforeImages.isNotEmpty)
        'beforeImages': beforeImages,
      if (afterImages != null && afterImages.isNotEmpty)
        'afterImages': afterImages,
    });
  }

  Future<void> addParts(String id, List<PartEntry> parts) {
    return _runQueued(id, 'ADD_PARTS', {
      'parts': parts
          .map((p) => {
                if (p.partId != null && p.partId!.isNotEmpty)
                  'partId': p.partId,
                'name': p.name,
                'qty': p.qty,
                'unitPrice': p.unitPrice,
              })
          .toList(),
    });
  }

  Future<void> completeVisit(String id,
      {required String proofType, String? value, String? url}) {
    return _runQueued(id, 'COMPLETE_VISIT', {
      'completionProof': {
        'type': proofType,
        if (value != null) 'value': value,
        if (url != null) 'url': url,
      },
    });
  }

  // OTP goes to the CUSTOMER's phone, not the technician's — this just
  // triggers/verifies it; the technician asks the customer to read it out.
  // Inherently online-only (the whole point is a live SMS/WhatsApp round
  // trip), so not queued.
  Future<void> requestCompletionOtp(String id) async {
    await _client.dio.post('/service-requests/$id/completion-otp/request');
  }

  Future<void> verifyCompletionOtp(String id, String otp) async {
    try {
      await _client.dio.post('/service-requests/$id/completion-otp/verify',
          data: {'otp': otp});
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is Map<String, dynamic> && body['message'] is String) {
        throw SyncRejectedException(body['message'] as String);
      }
      rethrow;
    }
  }

  // Same signed-upload -> Cloudinary -> confirm flow as
  // citycalls-customer-mobile's booking_repository.dart uploadIssueImage,
  // independently implemented (no shared code between the two apps) —
  // category is BEFORE_SERVICE_IMAGE/AFTER_SERVICE_IMAGE here instead of
  // ISSUE_IMAGE, and entityId is the ServiceRequest, not the Customer. Not
  // queued — queuing a multipart file (not just JSON) through the same
  // pending_actions table is a further phase, not built here.
  Future<String> uploadJobImage(String jobId, File file,
      {required String category}) async {
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
      final cloudinaryRes = await Dio().post(
          'https://api.cloudinary.com/v1_1/${signed['cloudName']}/auto/upload',
          data: form);
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
