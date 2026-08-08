// Mirrors citycalls-api's Vendor/VendorTechnician/VendorInvoice/VendorPayout
// shapes, scoped to what VENDOR_OWNER/VENDOR_MANAGER need to see their own
// company. Independently maintained from citycalls-admin-web's copy — no
// shared package between the apps.
class VendorCompany {
  final String id;
  final String companyName;
  final bool active;
  final bool blacklisted;

  VendorCompany({required this.id, required this.companyName, required this.active, required this.blacklisted});

  factory VendorCompany.fromJson(Map<String, dynamic> json) {
    return VendorCompany(
      id: json['_id'] as String,
      companyName: json['companyName'] as String,
      active: json['active'] as bool? ?? true,
      blacklisted: json['blacklisted'] as bool? ?? false,
    );
  }
}

class VendorTechnicianEntry {
  final String id;
  final String? name;
  final String? mobile;
  final List<String> skills;
  final bool active;

  VendorTechnicianEntry({required this.id, this.name, this.mobile, required this.skills, required this.active});

  factory VendorTechnicianEntry.fromJson(Map<String, dynamic> json) {
    final user = json['userId'] as Map<String, dynamic>?;
    return VendorTechnicianEntry(
      id: json['_id'] as String,
      name: user?['name'] as String?,
      mobile: user?['mobile'] as String?,
      skills: (json['skills'] as List? ?? []).cast<String>(),
      active: json['active'] as bool? ?? true,
    );
  }
}

class VendorInvoice {
  final String id;
  final String number;
  final double grossAmount;
  final double commissionAmount;
  final double netAmount;
  final String status;

  VendorInvoice({
    required this.id,
    required this.number,
    required this.grossAmount,
    required this.commissionAmount,
    required this.netAmount,
    required this.status,
  });

  factory VendorInvoice.fromJson(Map<String, dynamic> json) {
    final breakup = json['commissionBreakup'] as Map<String, dynamic>? ?? {};
    return VendorInvoice(
      id: json['_id'] as String,
      number: json['number'] as String,
      grossAmount: (breakup['grossAmount'] as num?)?.toDouble() ?? 0,
      commissionAmount: (breakup['commissionAmount'] as num?)?.toDouble() ?? 0,
      netAmount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String,
    );
  }
}

class VendorPayout {
  final String id;
  final String number;
  final double amount;
  final String status;
  final String? reference;

  VendorPayout({required this.id, required this.number, required this.amount, required this.status, this.reference});

  factory VendorPayout.fromJson(Map<String, dynamic> json) {
    return VendorPayout(
      id: json['_id'] as String,
      number: json['number'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String,
      reference: json['reference'] as String?,
    );
  }
}
