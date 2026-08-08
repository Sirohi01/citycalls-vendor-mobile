import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/employee_repository.dart';
import '../models/employee_models.dart';
import 'auth_providers.dart';

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepository(ref.watch(apiClientProvider));
});

// The technician's own profile — Employee record for EMPLOYEE/TECHNICIAN,
// or the parallel VendorTechnician record for VENDOR_TECHNICIAN (no Employee
// record exists for that role). The backend independently re-derives/
// enforces "who am I" from the JWT either way (serviceRequests.service.ts);
// this is just what the UI reads to display it.
final myEmployeeProfileProvider = FutureProvider<EmployeeProfile>((ref) {
  final role = ref.watch(authProvider).user?.role;
  final repo = ref.watch(employeeRepositoryProvider);
  return role == 'VENDOR_TECHNICIAN' ? repo.getOwnVendorTechnicianProfile() : repo.getOwnProfile();
});
