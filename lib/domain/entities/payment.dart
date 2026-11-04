// Apna Clinic - Payment Entity
// Primary source of truth: TRD Section 7 `Payments`

import '../enums/domain_enums.dart';

class Payment {
  final String paymentId;
  final String clinicId;
  final String invoiceId;
  final int amountMinor; // in paise
  final String currency;
  final PaymentMethod method;
  final String? cashUpiCardReferenceOptional;
  final DateTime receivedAt;
  final String receivedByStaffId;
  final PaymentStatus status;
  final String? reversalOfPaymentIdOptional;
  final DateTime createdAt;

  const Payment({
    required this.paymentId,
    required this.clinicId,
    required this.invoiceId,
    required this.amountMinor,
    this.currency = 'INR',
    required this.method,
    this.cashUpiCardReferenceOptional,
    required this.receivedAt,
    required this.receivedByStaffId,
    this.status = PaymentStatus.completed,
    this.reversalOfPaymentIdOptional,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'payment_id': paymentId,
      'clinic_id': clinicId,
      'invoice_id': invoiceId,
      'amount_minor': amountMinor,
      'currency': currency,
      'method': method.wireValue,
      'cash_upi_card_reference_optional': cashUpiCardReferenceOptional,
      'received_at': receivedAt.toIso8601String(),
      'received_by_staff_id': receivedByStaffId,
      'status': status.wireValue,
      'reversal_of_payment_id_optional': reversalOfPaymentIdOptional,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      paymentId: map['payment_id']?.toString() ?? '',
      clinicId: map['clinic_id']?.toString() ?? '',
      invoiceId: map['invoice_id']?.toString() ?? '',
      amountMinor: (map['amount_minor'] as num?)?.toInt() ?? 0,
      currency: map['currency'] as String? ?? 'INR',
      method: PaymentMethod.fromWire(map['method'] as String? ?? 'cash'),
      cashUpiCardReferenceOptional:
          map['cash_upi_card_reference_optional'] as String?,
      receivedAt: map['received_at'] != null
          ? (DateTime.tryParse(map['received_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      receivedByStaffId: map['received_by_staff_id'] as String? ?? '',
      status: PaymentStatus.fromWire(map['status'] as String? ?? 'completed'),
      reversalOfPaymentIdOptional:
          map['reversal_of_payment_id_optional'] as String?,
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
    );
  }
}
