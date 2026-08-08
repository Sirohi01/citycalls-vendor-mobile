// Mirrors citycalls-api's ServiceRequest shape (serviceRequests.model.ts),
// as scoped for this app by GET /service-requests?assigneeId=&status_in=
// (the technician's own jobs only — enforced server-side, not just a client
// filter). Independently maintained from citycalls-customer-mobile's copy —
// no shared package between the two Flutter apps.

const _statusLabels = {
  'ASSIGNED_TO_EMPLOYEE': 'New — Awaiting Response',
  'ACCEPTED': 'Accepted',
  'APPOINTMENT_SCHEDULED': 'Appointment Scheduled',
  'RESCHEDULED': 'Rescheduled',
  'CUSTOMER_UNAVAILABLE': 'Customer Unavailable',
  'TECHNICIAN_EN_ROUTE': 'On The Way',
  'TECHNICIAN_ARRIVED': 'Arrived',
  'INSPECTION_STARTED': 'Inspection In Progress',
  'INSPECTION_COMPLETED': 'Inspection Completed',
  'ESTIMATE_PENDING': 'Preparing Estimate',
  'ESTIMATE_SHARED': 'Estimate Shared',
  'AWAITING_CUSTOMER_APPROVAL': 'Awaiting Customer Approval',
  'ESTIMATE_APPROVED': 'Estimate Approved',
  'ESTIMATE_REJECTED': 'Estimate Rejected',
  'PARTS_PENDING': 'Waiting For Parts',
  'WORK_STARTED': 'Work Started',
  'WORK_IN_PROGRESS': 'Work In Progress',
  'ON_HOLD': 'On Hold',
  'SERVICE_COMPLETED': 'Service Completed',
  'CUSTOMER_CONFIRMATION_PENDING': 'Awaiting Customer Confirmation',
  'PAYMENT_PENDING': 'Payment Pending',
  'PARTIALLY_PAID': 'Partially Paid',
  'PAID': 'Paid',
  'CLOSED': 'Closed',
  'REASSIGNMENT_REQUIRED': 'Reassignment Required',
  'CANCELLED': 'Cancelled',
};
String jobStatusLabel(String status) =>
    _statusLabels[status] ?? status.replaceAll('_', ' ');

class PartEntry {
  final String? partId;
  final String name;
  final int qty;
  final double unitPrice;

  PartEntry(
      {this.partId,
      required this.name,
      required this.qty,
      required this.unitPrice});

  double get total => qty * unitPrice;
}

const _completedJobStatuses = {
  'SERVICE_COMPLETED',
  'CUSTOMER_CONFIRMATION_PENDING',
  'PAYMENT_PENDING',
  'PARTIALLY_PAID',
  'PAID',
  'CLOSED',
  'CANCELLED',
};
bool isCompletedJobStatus(String status) =>
    _completedJobStatuses.contains(status);

class JobSummary {
  final String id;
  final String number;
  final String status;
  final String priority;
  final String? serviceName;
  final String? customerName;
  final String? customerMobile;
  final String city;
  final DateTime? scheduledDate;
  final String? scheduledSlot;
  final DateTime? slaDueAt;

  JobSummary({
    required this.id,
    required this.number,
    required this.status,
    required this.priority,
    this.serviceName,
    this.customerName,
    this.customerMobile,
    required this.city,
    this.scheduledDate,
    this.scheduledSlot,
    this.slaDueAt,
  });

  factory JobSummary.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>?;
    final service = json['service'] as Map<String, dynamic>?;
    final address = json['addressSnapshot'] as Map<String, dynamic>?;
    final sla = json['sla'] as Map<String, dynamic>?;
    return JobSummary(
      id: json['_id'] as String,
      number: json['number'] as String,
      status: json['status'] as String,
      priority: json['priority'] as String? ?? 'NORMAL',
      serviceName: service?['name'] as String?,
      customerName: customer?['name'] as String?,
      customerMobile: customer?['mobile'] as String?,
      city: address?['city'] as String? ?? '',
      scheduledDate: json['scheduledDate'] != null
          ? DateTime.tryParse(json['scheduledDate'] as String)
          : null,
      scheduledSlot: json['scheduledSlot'] as String?,
      slaDueAt: sla?['dueAt'] != null
          ? DateTime.tryParse(sla!['dueAt'] as String)
          : null,
    );
  }
}

class CustomerProductInfo {
  final String? brand;
  final String? productType;
  final String? modelNumber;
  final DateTime? warrantyExpiresAt;

  CustomerProductInfo(
      {this.brand, this.productType, this.modelNumber, this.warrantyExpiresAt});

  bool get isUnderWarranty =>
      warrantyExpiresAt != null && warrantyExpiresAt!.isAfter(DateTime.now());

  factory CustomerProductInfo.fromJson(Map<String, dynamic> json) {
    return CustomerProductInfo(
      brand: json['brand'] as String?,
      productType: json['productType'] as String?,
      modelNumber: json['modelNumber'] as String?,
      warrantyExpiresAt: json['warrantyExpiresAt'] != null
          ? DateTime.tryParse(json['warrantyExpiresAt'] as String)
          : null,
    );
  }
}

class JobDetail {
  final String id;
  final String number;
  final String status;
  final String priority;
  final String? serviceName;
  final String? customerName;
  final String? customerMobile;
  final String customerId;
  final String branchId;
  final String addressLine;
  final List<String> symptoms;
  final String? notes;
  final List<String> images;
  final DateTime? scheduledDate;
  final String? scheduledSlot;
  final DateTime? slaDueAt;
  final CustomerProductInfo? product;

  JobDetail({
    required this.id,
    required this.number,
    required this.status,
    required this.priority,
    this.serviceName,
    this.customerName,
    this.customerMobile,
    required this.customerId,
    required this.branchId,
    required this.addressLine,
    required this.symptoms,
    this.notes,
    required this.images,
    this.scheduledDate,
    this.scheduledSlot,
    this.slaDueAt,
    this.product,
  });

  factory JobDetail.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>?;
    final service = json['service'] as Map<String, dynamic>?;
    final address = json['addressSnapshot'] as Map<String, dynamic>?;
    final sla = json['sla'] as Map<String, dynamic>?;
    final product = json['customerProduct'] as Map<String, dynamic>?;
    final addressParts = [
      address?['line1'],
      address?['line2'],
      address?['landmark'],
      address?['city'],
      address?['state'],
      address?['pinCode']
    ].where((s) => s != null && (s as String).isNotEmpty).join(', ');
    return JobDetail(
      id: json['_id'] as String,
      number: json['number'] as String,
      status: json['status'] as String,
      priority: json['priority'] as String? ?? 'NORMAL',
      serviceName: service?['name'] as String?,
      customerName: customer?['name'] as String?,
      customerMobile: customer?['mobile'] as String?,
      customerId: json['customerId'] as String,
      branchId: json['branchId'] as String,
      addressLine: addressParts,
      symptoms: (json['symptoms'] as List? ?? []).cast<String>(),
      notes: json['notes'] as String?,
      images: (json['images'] as List? ?? []).cast<String>(),
      scheduledDate: json['scheduledDate'] != null
          ? DateTime.tryParse(json['scheduledDate'] as String)
          : null,
      scheduledSlot: json['scheduledSlot'] as String?,
      slaDueAt: sla?['dueAt'] != null
          ? DateTime.tryParse(sla!['dueAt'] as String)
          : null,
      product: product != null ? CustomerProductInfo.fromJson(product) : null,
    );
  }
}
