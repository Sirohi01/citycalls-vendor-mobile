// Mirrors citycalls-api's Estimate shape (estimates.model.ts), scoped to
// what this app needs to draft and share one from the field. Independently
// maintained from citycalls-admin-web's and citycalls-customer-mobile's
// copies — no shared package between the apps.
class EstimateLineItem {
  final String description;
  final int qty;
  final double unitPrice;

  EstimateLineItem({required this.description, required this.qty, required this.unitPrice});

  double get total => qty * unitPrice;

  Map<String, dynamic> toJson() => {
        'description': description,
        'qty': qty,
        'unitPrice': unitPrice,
      };
}

class Estimate {
  final String id;
  final String number;
  final String status;
  final double total;

  Estimate({required this.id, required this.number, required this.status, required this.total});

  factory Estimate.fromJson(Map<String, dynamic> json) {
    return Estimate(
      id: json['_id'] as String,
      number: json['number'] as String,
      status: json['status'] as String,
      total: (json['total'] as num?)?.toDouble() ?? 0,
    );
  }
}
