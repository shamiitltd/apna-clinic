// Apna Clinic - Daily Summary Aggregate Entity
// Primary source of truth: PRD Section 5 M07, Section 6.2 `Reports / daily_summary`, and TRD Section 7 `Daily_Summary`
// Materialized aggregate record per clinic / date / doctor.
// Strictly integer paise math, immutable ledger reconciliation, zero clinical data leakage.

class DailySummary {
  final String summaryId;
  final String clinicId;
  final String localDate; // YYYY-MM-DD
  final String? doctorIdOptional; // null or empty for clinic-wide, or doctorId
  final int registeredCount;
  final int walkinCount;
  final int appointmentCount;
  final int completedCount;
  final int noShowCount;
  final int cancelledCount;
  final int invoicedMinor; // Gross billed in paise
  final int paidCashMinor; // Cash collected in paise
  final int paidUpiMinor; // UPI collected in paise
  final int paidCardMinor; // Card collected in paise
  final int refundedMinor; // Refunds settled in paise
  final int outstandingMinor; // Pending dues in paise
  final int expensesMinor; // Clinic expenses in paise
  final DateTime generatedAt;
  final String sourceEventCheckpoint;

  const DailySummary({
    required this.summaryId,
    required this.clinicId,
    required this.localDate,
    this.doctorIdOptional,
    this.registeredCount = 0,
    this.walkinCount = 0,
    this.appointmentCount = 0,
    this.completedCount = 0,
    this.noShowCount = 0,
    this.cancelledCount = 0,
    this.invoicedMinor = 0,
    this.paidCashMinor = 0,
    this.paidUpiMinor = 0,
    this.paidCardMinor = 0,
    this.refundedMinor = 0,
    this.outstandingMinor = 0,
    this.expensesMinor = 0,
    required this.generatedAt,
    this.sourceEventCheckpoint = '',
  });

  // PRD Section 6.2 aliases and convenience getters
  int get totalVisits => registeredCount;
  int get completedVisits => completedCount;
  int get noShows => noShowCount;
  int get cancellations => cancelledCount;
  int get grossBilledPaise => invoicedMinor;
  int get refundsPaise => refundedMinor;
  int get cashPaise => paidCashMinor;
  int get upiPaise => paidUpiMinor;
  int get cardPaise => paidCardMinor;
  int get outstandingPaise => outstandingMinor;
  int get expensesPaise => expensesMinor;

  int get totalCollectedMinor => paidCashMinor + paidUpiMinor + paidCardMinor;
  int get netCollectionsMinor => totalCollectedMinor - refundedMinor;
  int get netCollectionsPaise => netCollectionsMinor;
  int get netCashInHandMinor => paidCashMinor - refundedMinor - expensesMinor;

  double get completionRate =>
      registeredCount > 0 ? (completedCount / registeredCount) * 100 : 0.0;

  Map<String, dynamic> toMap() {
    return {
      'summary_id': summaryId,
      'clinic_id': clinicId,
      'local_date': localDate,
      'doctor_id_optional': doctorIdOptional,
      'registered_count': registeredCount,
      'walkin_count': walkinCount,
      'appointment_count': appointmentCount,
      'completed_count': completedCount,
      'no_show_count': noShowCount,
      'cancelled_count': cancelledCount,
      'invoiced_minor': invoicedMinor,
      'paid_cash_minor': paidCashMinor,
      'paid_upi_minor': paidUpiMinor,
      'paid_card_minor': paidCardMinor,
      'refunded_minor': refundedMinor,
      'outstanding_minor': outstandingMinor,
      'expenses_minor': expensesMinor,
      'generated_at': generatedAt.toIso8601String(),
      'source_event_checkpoint': sourceEventCheckpoint,
    };
  }

  factory DailySummary.fromMap(Map<String, dynamic> map) {
    return DailySummary(
      summaryId: map['summary_id']?.toString() ?? '',
      clinicId: map['clinic_id']?.toString() ?? '',
      localDate: (map['local_date'] ?? map['business_date'])?.toString() ?? '',
      doctorIdOptional: map['doctor_id_optional'] as String?,
      registeredCount: ((map['registered_count'] ?? map['total_visits']) as num?)?.toInt() ?? 0,
      walkinCount: (map['walkin_count'] as num?)?.toInt() ?? 0,
      appointmentCount: (map['appointment_count'] as num?)?.toInt() ?? 0,
      completedCount: ((map['completed_count'] ?? map['completed_visits']) as num?)?.toInt() ?? 0,
      noShowCount: ((map['no_show_count'] ?? map['no_shows']) as num?)?.toInt() ?? 0,
      cancelledCount: ((map['cancelled_count'] ?? map['cancellations']) as num?)?.toInt() ?? 0,
      invoicedMinor: ((map['invoiced_minor'] ?? map['gross_billed_paise']) as num?)?.toInt() ?? 0,
      paidCashMinor: ((map['paid_cash_minor'] ?? map['cash_paise']) as num?)?.toInt() ?? 0,
      paidUpiMinor: ((map['paid_upi_minor'] ?? map['upi_paise']) as num?)?.toInt() ?? 0,
      paidCardMinor: ((map['paid_card_minor'] ?? map['card_paise']) as num?)?.toInt() ?? 0,
      refundedMinor: ((map['refunded_minor'] ?? map['refunds_paise']) as num?)?.toInt() ?? 0,
      outstandingMinor: ((map['outstanding_minor'] ?? map['outstanding_paise']) as num?)?.toInt() ?? 0,
      expensesMinor: ((map['expenses_minor'] ?? map['expenses_paise']) as num?)?.toInt() ?? 0,
      generatedAt: map['generated_at'] != null
          ? (DateTime.tryParse(map['generated_at'].toString()) ?? DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      sourceEventCheckpoint: (map['source_event_checkpoint'] ?? map['source_cursor'])?.toString() ?? '',
    );
  }

  DailySummary copyWith({
    String? summaryId,
    String? clinicId,
    String? localDate,
    String? doctorIdOptional,
    int? registeredCount,
    int? walkinCount,
    int? appointmentCount,
    int? completedCount,
    int? noShowCount,
    int? cancelledCount,
    int? invoicedMinor,
    int? paidCashMinor,
    int? paidUpiMinor,
    int? paidCardMinor,
    int? refundedMinor,
    int? outstandingMinor,
    int? expensesMinor,
    DateTime? generatedAt,
    String? sourceEventCheckpoint,
  }) {
    return DailySummary(
      summaryId: summaryId ?? this.summaryId,
      clinicId: clinicId ?? this.clinicId,
      localDate: localDate ?? this.localDate,
      doctorIdOptional: doctorIdOptional ?? this.doctorIdOptional,
      registeredCount: registeredCount ?? this.registeredCount,
      walkinCount: walkinCount ?? this.walkinCount,
      appointmentCount: appointmentCount ?? this.appointmentCount,
      completedCount: completedCount ?? this.completedCount,
      noShowCount: noShowCount ?? this.noShowCount,
      cancelledCount: cancelledCount ?? this.cancelledCount,
      invoicedMinor: invoicedMinor ?? this.invoicedMinor,
      paidCashMinor: paidCashMinor ?? this.paidCashMinor,
      paidUpiMinor: paidUpiMinor ?? this.paidUpiMinor,
      paidCardMinor: paidCardMinor ?? this.paidCardMinor,
      refundedMinor: refundedMinor ?? this.refundedMinor,
      outstandingMinor: outstandingMinor ?? this.outstandingMinor,
      expensesMinor: expensesMinor ?? this.expensesMinor,
      generatedAt: generatedAt ?? this.generatedAt,
      sourceEventCheckpoint: sourceEventCheckpoint ?? this.sourceEventCheckpoint,
    );
  }
}
