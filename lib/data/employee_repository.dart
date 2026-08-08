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

  // VENDOR_TECHNICIAN has no Employee record — a parallel self-profile
  // fetch, adapted to the same EmployeeProfile shape so Dashboard/Profile
  // screens don't need role-specific rendering logic.
  Future<EmployeeProfile> getOwnVendorTechnicianProfile() async {
    final res = await _client.dio.get('/vendor-technicians/me');
    return EmployeeProfile.fromVendorTechnicianJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> registerFcmToken(String token) async {
    await _client.dio.post('/employees/me/fcm-token', data: {'token': token});
  }

  Future<void> unregisterFcmToken(String token) async {
    await _client.dio.delete('/employees/me/fcm-token', data: {'token': token});
  }

  Future<EmployeeProfile> updateAvailability(List<AvailabilityDay> availability) async {
    final res = await _client.dio.patch('/employees/me/availability', data: {
      'availability': availability.map((a) => {'day': a.day, 'available': a.available}).toList(),
    });
    return EmployeeProfile.fromJson(res.data['data'] as Map<String, dynamic>);
  }
}
