// Mirrors citycalls-api's Invoice/PaymentReceipt shape, scoped to what this
// app needs to bill a completed job and collect payment from the field.
// Independently maintained from citycalls-admin-web's and
// citycalls-customer-mobile's copies — no shared package between the apps.
const paymentMethods = ['CASH', 'UPI', 'CARD', 'BANK_TRANSFER', 'GATEWAY', 'CHEQUE', 'CREDIT'];

class InvoiceLineItem {
  final String description;
  final int qty;
  final double unitPrice;

  InvoiceLineItem({required this.description, required this.qty, required this.unitPrice});

  double get total => qty * unitPrice;

  Map<String, dynamic> toJson() => {
        'description': description,
        'qty': qty,
        'unitPrice': unitPrice,
      };
}

class Invoice {
  final String id;
  final String number;
  final String status;
  final double total;
  final double amountPaid;

  Invoice({required this.id, required this.number, required this.status, required this.total, required this.amountPaid});

  double get outstanding => total - amountPaid;

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['_id'] as String,
      number: json['number'] as String,
      status: json['status'] as String,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      amountPaid: (json['amountPaid'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PaymentReceipt {
  final String number;
  final String method;
  final double amount;
  final String? reference;

  PaymentReceipt({required this.number, required this.method, required this.amount, this.reference});

  factory PaymentReceipt.fromJson(Map<String, dynamic> json) {
    return PaymentReceipt(
      number: json['number'] as String,
      method: json['method'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      reference: json['reference'] as String?,
    );
  }
}
