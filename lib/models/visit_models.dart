// Mirrors citycalls-api's ServiceVisit (field-execution/serviceVisits.model.ts)
// as returned by GET /service-requests/:id/visits — what was recorded on each
// visit: inspection, parts, labour, notes, photos and completion proof.

class VisitPart {
  final String name;
  final double qty;
  final double unitPrice;
  VisitPart({required this.name, required this.qty, required this.unitPrice});

  double get total => qty * unitPrice;

  factory VisitPart.fromJson(Map<String, dynamic> json) => VisitPart(
        name: json['name'] as String? ?? 'Part',
        qty: (json['qty'] as num?)?.toDouble() ?? 0,
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      );
}

class ServiceVisit {
  final String id;
  final int visitNumber;
  final DateTime? startedAt;
  final DateTime? arrivedAt;
  final DateTime? completedAt;
  final String? defectFound;
  final List<String> symptoms;
  final String? solutionType;
  final List<VisitPart> parts;
  final double? labourCharge;
  final String? workNotes;
  final List<String> beforeImages;
  final List<String> afterImages;
  final String? completionProofType;

  ServiceVisit({
    required this.id,
    required this.visitNumber,
    this.startedAt,
    this.arrivedAt,
    this.completedAt,
    this.defectFound,
    this.symptoms = const [],
    this.solutionType,
    this.parts = const [],
    this.labourCharge,
    this.workNotes,
    this.beforeImages = const [],
    this.afterImages = const [],
    this.completionProofType,
  });

  static DateTime? _date(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;

  factory ServiceVisit.fromJson(Map<String, dynamic> json) {
    final inspection = json['inspection'] as Map<String, dynamic>? ?? const {};
    final proof = json['completionProof'] as Map<String, dynamic>?;
    List<String> strings(Object? v) =>
        (v as List? ?? const []).whereType<String>().toList();
    return ServiceVisit(
      id: json['_id'] as String? ?? '',
      visitNumber: (json['visitNumber'] as num?)?.toInt() ?? 1,
      startedAt: _date(json['startedAt']),
      arrivedAt: _date(json['arrivedAt']),
      completedAt: _date(json['completedAt']),
      defectFound: inspection['defectFound'] as String?,
      symptoms: strings(inspection['symptoms']),
      solutionType: inspection['solutionType'] as String?,
      parts: (json['parts'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(VisitPart.fromJson)
          .toList(),
      labourCharge: (json['labourCharge'] as num?)?.toDouble(),
      workNotes: json['workNotes'] as String?,
      beforeImages: strings(json['beforeImages']),
      afterImages: strings(json['afterImages']),
      completionProofType: proof?['type'] as String?,
    );
  }

  bool get hasInspection =>
      (defectFound?.isNotEmpty ?? false) ||
      symptoms.isNotEmpty ||
      (solutionType?.isNotEmpty ?? false);

  /// True when anything worth showing was recorded on this visit.
  bool get hasContent =>
      hasInspection ||
      parts.isNotEmpty ||
      labourCharge != null ||
      (workNotes?.isNotEmpty ?? false) ||
      beforeImages.isNotEmpty ||
      afterImages.isNotEmpty ||
      completedAt != null;
}

// GET /appointment-slots?branchId=&date= (appointmentSlots.service.ts).
class AppointmentSlot {
  final String key;
  final String label;
  final int remaining;
  final bool available;
  AppointmentSlot(
      {required this.key,
      required this.label,
      required this.remaining,
      required this.available});

  factory AppointmentSlot.fromJson(Map<String, dynamic> json) =>
      AppointmentSlot(
        key: json['key'] as String? ?? '',
        label: json['label'] as String? ?? '',
        remaining: (json['remaining'] as num?)?.toInt() ?? 0,
        available: json['available'] as bool? ?? false,
      );
}

class AppointmentSlots {
  final bool dayClosed;
  final List<AppointmentSlot> slots;
  AppointmentSlots({required this.dayClosed, required this.slots});

  factory AppointmentSlots.fromJson(Map<String, dynamic> json) =>
      AppointmentSlots(
        dayClosed: json['dayClosed'] as bool? ?? false,
        slots: (json['slots'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AppointmentSlot.fromJson)
            .toList(),
      );
}
