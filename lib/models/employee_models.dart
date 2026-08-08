// Mirrors citycalls-api's Employee shape (employees.model.ts), as returned
// by GET /employees/me (employees.controller.ts's getOwnEmployeeHandler) —
// userId/branchId/subBranchId/teamId are all populated server-side.

const _weekdayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

class AvailabilityDay {
  final int day; // 0=Sunday .. 6=Saturday, per IAvailabilitySlot
  final bool available;
  AvailabilityDay({required this.day, required this.available});

  String get label => _weekdayNames[day % 7];

  factory AvailabilityDay.fromJson(Map<String, dynamic> json) {
    return AvailabilityDay(day: (json['day'] as num).toInt(), available: json['available'] as bool? ?? true);
  }
}

class EmployeeProfile {
  final String id;
  final String name;
  final String? mobile;
  final String? email;
  final String? branchName;
  final String? subBranchName;
  final String? teamName;
  final List<String> skills;
  final List<String> certifications;
  final List<AvailabilityDay> availability;
  final int dailyCapacity;
  final bool active;
  // True when this profile actually came from GET /vendor-technicians/me
  // rather than GET /employees/me — a VendorTechnician record has no
  // sub-branch/team/dailyCapacity/certifications/availability concept at
  // all, so profile_screen.dart uses this to skip rendering those sections
  // rather than showing misleading defaults.
  final bool isVendorTechnician;

  EmployeeProfile({
    required this.id,
    required this.name,
    this.mobile,
    this.email,
    this.branchName,
    this.subBranchName,
    this.teamName,
    required this.skills,
    required this.certifications,
    required this.availability,
    required this.dailyCapacity,
    required this.active,
    this.isVendorTechnician = false,
  });

  factory EmployeeProfile.fromJson(Map<String, dynamic> json) {
    final user = json['userId'] as Map<String, dynamic>?;
    final branch = json['branchId'] as Map<String, dynamic>?;
    final subBranch = json['subBranchId'] as Map<String, dynamic>?;
    final team = json['teamId'] as Map<String, dynamic>?;
    return EmployeeProfile(
      id: json['_id'] as String,
      name: user?['name'] as String? ?? 'Technician',
      mobile: user?['mobile'] as String?,
      email: user?['email'] as String?,
      branchName: branch?['name'] as String?,
      subBranchName: subBranch?['name'] as String?,
      teamName: team?['name'] as String?,
      skills: (json['skills'] as List? ?? []).cast<String>(),
      certifications: (json['certifications'] as List? ?? []).cast<String>(),
      availability: (json['availability'] as List? ?? []).map((a) => AvailabilityDay.fromJson(a as Map<String, dynamic>)).toList(),
      dailyCapacity: (json['dailyCapacity'] as num?)?.toInt() ?? 5,
      active: json['active'] as bool? ?? true,
    );
  }

  // GET /vendor-technicians/me shape (vendors.service.ts's
  // getOwnVendorTechnician): {_id, userId: {name,mobile,email},
  // vendorId: {companyName}, skills, active} — no branch/team/capacity/
  // certifications/availability fields exist on this model.
  factory EmployeeProfile.fromVendorTechnicianJson(Map<String, dynamic> json) {
    final user = json['userId'] as Map<String, dynamic>?;
    final vendor = json['vendorId'] as Map<String, dynamic>?;
    return EmployeeProfile(
      id: json['_id'] as String,
      name: user?['name'] as String? ?? 'Technician',
      mobile: user?['mobile'] as String?,
      email: user?['email'] as String?,
      branchName: vendor?['companyName'] as String?,
      skills: (json['skills'] as List? ?? []).cast<String>(),
      certifications: const [],
      availability: const [],
      dailyCapacity: 0,
      active: json['active'] as bool? ?? true,
      isVendorTechnician: true,
    );
  }
}
