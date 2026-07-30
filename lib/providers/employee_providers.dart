import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/employee_repository.dart';
import '../models/employee_models.dart';
import 'auth_providers.dart';

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepository(ref.watch(apiClientProvider));
});

// The technician's own Employee record — this is where the app's own
// employeeId (used to scope "My Jobs") actually comes from client-side;
// the backend independently re-derives/enforces the same id from the JWT
// (serviceRequests.service.ts), this is just what the UI reads to know who
// "me" is.
final myEmployeeProfileProvider = FutureProvider<EmployeeProfile>((ref) {
  return ref.watch(employeeRepositoryProvider).getOwnProfile();
});
