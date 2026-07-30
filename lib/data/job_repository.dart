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
}
