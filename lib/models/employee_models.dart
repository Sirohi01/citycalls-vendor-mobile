// Mirrors citycalls-api's Employee shape (employees.model.ts), as returned
// by GET /employees/me (employees.controller.ts's getOwnEmployeeHandler) —
// userId is populated server-side into name/mobile/email.
class EmployeeProfile {
  final String id;
  final String name;
  final String? mobile;
  final String? email;
  final List<String> skills;
  final bool active;

  EmployeeProfile({
    required this.id,
    required this.name,
    this.mobile,
    this.email,
    required this.skills,
    required this.active,
  });

  factory EmployeeProfile.fromJson(Map<String, dynamic> json) {
    final user = json['userId'] as Map<String, dynamic>?;
    return EmployeeProfile(
      id: json['_id'] as String,
      name: user?['name'] as String? ?? 'Technician',
      mobile: user?['mobile'] as String?,
      email: user?['email'] as String?,
      skills: (json['skills'] as List? ?? []).cast<String>(),
      active: json['active'] as bool? ?? true,
    );
  }
}
