// Apna Clinic - Day Close Entity
// Primary source of truth: PRD Section 6.2 `Finance / day_close` & Section 5 M06
// End-of-day reconciliation: cash counted, physical drawer variance, UPI/Card totals, refund totals.

class DayClose {
  final String closeId;
  final String clinicId;
  final String businessDate; // YYYY-MM-DD
  final String openedBy;
  final String closedBy;
  final DateTime closedAt;
  final int openingCashPaise;
  final int expectedCashPaise;
  final int countedCashPaise;
  final int variancePaise;
  final int upiTotalPaise;
  final int cardTotalPaise;
  final int refundTotalPaise;
  final String? notesOptional;
  final int version;

  const DayClose({
    required this.closeId,
    required this.clinicId,
    required this.businessDate,
    required this.openedBy,
    required this.closedBy,
    required this.closedAt,
    this.openingCashPaise = 0,
    required this.expectedCashPaise,
    required this.countedCashPaise,
    required this.variancePaise,
    required this.upiTotalPaise,
    required this.cardTotalPaise,
    required this.refundTotalPaise,
    this.notesOptional,
    this.version = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'close_id': closeId,
      'clinic_id': clinicId,
      'business_date': businessDate,
      'opened_by': openedBy,
      'closed_by': closedBy,
      'closed_at': closedAt.toIso8601String(),
      'opening_cash_paise': openingCashPaise,
      'expected_cash_paise': expectedCashPaise,
      'counted_cash_paise': countedCashPaise,
      'variance_paise': variancePaise,
      'upi_total_paise': upiTotalPaise,
      'card_total_paise': cardTotalPaise,
      'refund_total_paise': refundTotalPaise,
      'notes_optional': notesOptional,
      'version': version,
    };
  }

  factory DayClose.fromMap(Map<String, dynamic> map) {
    return DayClose(
      closeId: map['close_id']?.toString() ?? '',
      clinicId: map['clinic_id']?.toString() ?? '',
      businessDate: map['business_date']?.toString() ?? '',
      openedBy: map['opened_by']?.toString() ?? '',
      closedBy: map['closed_by']?.toString() ?? '',
      closedAt: map['closed_at'] != null
          ? (DateTime.tryParse(map['closed_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      openingCashPaise: (map['opening_cash_paise'] as num?)?.toInt() ?? 0,
      expectedCashPaise: (map['expected_cash_paise'] as num?)?.toInt() ?? 0,
      countedCashPaise: (map['counted_cash_paise'] as num?)?.toInt() ?? 0,
      variancePaise: (map['variance_paise'] as num?)?.toInt() ?? 0,
      upiTotalPaise: (map['upi_total_paise'] as num?)?.toInt() ?? 0,
      cardTotalPaise: (map['card_total_paise'] as num?)?.toInt() ?? 0,
      refundTotalPaise: (map['refund_total_paise'] as num?)?.toInt() ?? 0,
      notesOptional: map['notes_optional'] as String?,
      version: (map['version'] as num?)?.toInt() ?? 1,
    );
  }
}

