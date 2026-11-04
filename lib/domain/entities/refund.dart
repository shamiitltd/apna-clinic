// Apna Clinic - Refund Entity
// Primary source of truth: TRD Section 7 `Refunds`

import '../enums/domain_enums.dart';

class Refund {
  final String refundId;
  final String clinicId;
  final String invoiceId;
  final String? paymentIdOptional;
  final int amountMinor; // in paise
  final String reason;
  final String requestedByStaffId;
  final String approvedByStaffId;
  final RefundStatus status;
  final DateTime refundedAt;
  final PaymentMethod refundMethod;
  final String? referenceOptional;
  final DateTime createdAt;

  const Refund({
    required this.refundId,
    required this.clinicId,
    required this.invoiceId,
    this.paymentIdOptional,
    required this.amountMinor,
    required this.reason,
    required this.requestedByStaffId,
    required this.approvedByStaffId,
    this.status = RefundStatus.settled,
    required this.refundedAt,
    required this.refundMethod,
    this.referenceOptional,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'refund_id': refundId,
      'clinic_id': clinicId,
      'invoice_id': invoiceId,
      'payment_id_optional': paymentIdOptional,
      'amount_minor': amountMinor,
      'reason': reason,
      'requested_by_staff_id': requestedByStaffId,
      'approved_by_staff_id': approvedByStaffId,
      'status': status.wireValue,
      'refunded_at': refundedAt.toIso8601String(),
      'refund_method': refundMethod.wireValue,
      'reference_optional': referenceOptional,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Refund.fromMap(Map<String, dynamic> map) {
    return Refund(
      refundId: map['refund_id']?.toString() ?? '',
      clinicId: map['clinic_id']?.toString() ?? '',
      invoiceId: map['invoice_id']?.toString() ?? '',
      paymentIdOptional: map['payment_id_optional'] as String?,
      amountMinor: (map['amount_minor'] as num?)?.toInt() ?? 0,
      reason: map['reason'] as String? ?? '',
      requestedByStaffId: map['requested_by_staff_id'] as String? ?? '',
      approvedByStaffId: map['approved_by_staff_id'] as String? ?? '',
      status: RefundStatus.fromWire(map['status'] as String? ?? 'settled'),
      refundedAt: map['refunded_at'] != null
          ? (DateTime.tryParse(map['refunded_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      refundMethod: PaymentMethod.fromWire(
        map['refund_method'] as String? ?? 'cash',
      ),
      referenceOptional: map['reference_optional'] as String?,
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
    );
  }
}
