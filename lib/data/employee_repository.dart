import 'api_client.dart';
import '../models/employee_models.dart';

// One repository class per module, per docs/12-frontend-data-contracts.md §3.
class EmployeeRepository {
  final ApiClient _client;
  EmployeeRepository(this._client);

  Future<EmployeeProfile> getOwnProfile() async {
    final res = await _client.dio.get('/employees/me');
    return EmployeeProfile.fromJson(res.data['data'] as Map<String, dynamic>);
  }
}
