// Apna Clinic - Invoice & Invoice Item Entities
// Primary source of truth: PRD Section 6.2 `Finance / invoices` & Section 5 M06
// Sequential display numbers with immutable UUID transaction IDs, paise math.

import '../enums/domain_enums.dart';

class InvoiceItem {
  final String invoiceItemId;
  final String clinicId;
  final String invoiceId;
  final String? feeIdOptional;
  final String description;
  final int quantity;
  final int unitPriceMinor; // in paise
  final int discountMinor; // in paise
  final String taxRateSnapshot; // e.g. "0.0"
  final int taxMinor; // in paise
  final int lineTotalMinor; // in paise
  final DateTime createdAt;

  const InvoiceItem({
    required this.invoiceItemId,
    required this.clinicId,
    required this.invoiceId,
    this.feeIdOptional,
    required this.description,
    this.quantity = 1,
    required this.unitPriceMinor,
    this.discountMinor = 0,
    this.taxRateSnapshot = '0.0',
    this.taxMinor = 0,
    required this.lineTotalMinor,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'invoice_item_id': invoiceItemId,
      'clinic_id': clinicId,
      'invoice_id': invoiceId,
      'fee_id_optional': feeIdOptional,
      'description': description,
      'quantity': quantity,
      'unit_price_minor': unitPriceMinor,
      'discount_minor': discountMinor,
      'tax_rate_snapshot': taxRateSnapshot,
      'tax_minor': taxMinor,
      'line_total_minor': lineTotalMinor,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      invoiceItemId: map['invoice_item_id']?.toString() ?? '',
      clinicId: map['clinic_id']?.toString() ?? '',
      invoiceId: map['invoice_id']?.toString() ?? '',
      feeIdOptional: map['fee_id_optional'] as String?,
      description: map['description'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      unitPriceMinor: (map['unit_price_minor'] as num?)?.toInt() ?? 0,
      discountMinor: (map['discount_minor'] as num?)?.toInt() ?? 0,
      taxRateSnapshot: map['tax_rate_snapshot'] as String? ?? '0.0',
      taxMinor: (map['tax_minor'] as num?)?.toInt() ?? 0,
      lineTotalMinor: (map['line_total_minor'] as num?)?.toInt() ?? 0,
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
    );
  }
}

class Invoice {
  final String invoiceId;
  final String clinicId;
  final String invoiceNumber; // e.g. "INV-2026-0001" monotonic per financial year
  final String financialYear; // e.g. "2026-2027"
  final String patientId;
  final String? visitId;
  final String issueDateLocal; // YYYY-MM-DD
  final InvoiceStatus status;
  final int subtotalMinor; // in paise
  final int discountMinor; // in paise
  final String? discountReasonOptional; // mandatory when discount > 0
  final String? discountApprovedByOptional; // required when exceeding threshold
  final int taxMinor; // in paise
  final int totalMinor; // in paise
  final int paidMinor; // in paise
  final int balanceMinor; // in paise
  final String currency;
  final String notesNonclinical;
  final String createdByStaffId;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? voidedAt;
  final String? voidReason;

  // Embedded transient line items
  final List<InvoiceItem> items;

  const Invoice({
    required this.invoiceId,
    required this.clinicId,
    required this.invoiceNumber,
    required this.financialYear,
    required this.patientId,
    this.visitId,
    required this.issueDateLocal,
    this.status = InvoiceStatus.issued,
    required this.subtotalMinor,
    this.discountMinor = 0,
    this.discountReasonOptional,
    this.discountApprovedByOptional,
    this.taxMinor = 0,
    required this.totalMinor,
    this.paidMinor = 0,
    required this.balanceMinor,
    this.currency = 'INR',
    this.notesNonclinical = '',
    required this.createdByStaffId,
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
    this.voidedAt,
    this.voidReason,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'invoice_id': invoiceId,
      'clinic_id': clinicId,
      'invoice_number': invoiceNumber,
      'financial_year': financialYear,
      'patient_id': patientId,
      'visit_id': visitId,
      'issue_date_local': issueDateLocal,
      'issued_at': createdAt.toIso8601String(),
      'status': status.wireValue,
      'payment_status': status.wireValue,
      'subtotal_minor': subtotalMinor,
      'subtotal_paise': subtotalMinor,
      'discount_minor': discountMinor,
      'discount_paise': discountMinor,
      'discount_reason_optional': discountReasonOptional,
      'discount_approved_by_optional': discountApprovedByOptional,
      'tax_minor': taxMinor,
      'tax_paise': taxMinor,
      'total_minor': totalMinor,
      'total_paise': totalMinor,
      'paid_minor': paidMinor,
      'balance_minor': balanceMinor,
      'currency': currency,
      'notes_nonclinical': notesNonclinical,
      'created_by': createdByStaffId,
      'created_by_staff_id': createdByStaffId,
      'version': version,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'voided_at': voidedAt?.toIso8601String(),
      'voided_at_optional': voidedAt?.toIso8601String(),
      'void_reason': voidReason,
      'void_reason_optional': voidReason,
    };
  }

  factory Invoice.fromMap(
    Map<String, dynamic> map, [
    List<InvoiceItem> items = const [],
  ]) {
    return Invoice(
      invoiceId: map['invoice_id']?.toString() ?? '',
      clinicId: map['clinic_id']?.toString() ?? '',
      invoiceNumber: map['invoice_number']?.toString() ?? '',
      financialYear: map['financial_year']?.toString() ?? '',
      patientId: map['patient_id']?.toString() ?? '',
      visitId: map['visit_id'] as String?,
      issueDateLocal: map['issue_date_local'] as String? ??
          (map['issued_at'] != null
              ? map['issued_at'].toString().split('T').first
              : DateTime.now().toIso8601String().split('T').first),
      status: InvoiceStatus.fromWire(
        (map['status'] ?? map['payment_status']) as String? ?? 'issued',
      ),
      subtotalMinor: ((map['subtotal_minor'] ?? map['subtotal_paise']) as num?)?.toInt() ?? 0,
      discountMinor: ((map['discount_minor'] ?? map['discount_paise']) as num?)?.toInt() ?? 0,
      discountReasonOptional: map['discount_reason_optional'] as String?,
      discountApprovedByOptional: map['discount_approved_by_optional'] as String?,
      taxMinor: ((map['tax_minor'] ?? map['tax_paise']) as num?)?.toInt() ?? 0,
      totalMinor: ((map['total_minor'] ?? map['total_paise']) as num?)?.toInt() ?? 0,
      paidMinor: (map['paid_minor'] as num?)?.toInt() ?? 0,
      balanceMinor: (map['balance_minor'] as num?)?.toInt() ?? 0,
      currency: map['currency'] as String? ?? 'INR',
      notesNonclinical: map['notes_nonclinical'] as String? ?? '',
      createdByStaffId: (map['created_by_staff_id'] ?? map['created_by']) as String? ?? '',
      version: (map['version'] as num?)?.toInt() ?? 1,
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'].toString()) ??
              DateTime.now().toUtc())
          : (map['issued_at'] != null
              ? (DateTime.tryParse(map['issued_at'].toString()) ?? DateTime.now().toUtc())
              : DateTime.now().toUtc()),
      updatedAt: map['updated_at'] != null
          ? (DateTime.tryParse(map['updated_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      voidedAt: (map['voided_at'] ?? map['voided_at_optional']) != null
          ? DateTime.tryParse((map['voided_at'] ?? map['voided_at_optional']).toString())
          : null,
      voidReason: (map['void_reason'] ?? map['void_reason_optional']) as String?,
      items: items,
    );
  }

  Invoice copyWith({
    InvoiceStatus? status,
    int? subtotalMinor,
    int? discountMinor,
    String? discountReasonOptional,
    String? discountApprovedByOptional,
    int? taxMinor,
    int? totalMinor,
    int? paidMinor,
    int? balanceMinor,
    DateTime? updatedAt,
    DateTime? voidedAt,
    String? voidReason,
    int? version,
    List<InvoiceItem>? items,
  }) {
    return Invoice(
      invoiceId: invoiceId,
      clinicId: clinicId,
      invoiceNumber: invoiceNumber,
      financialYear: financialYear,
      patientId: patientId,
      visitId: visitId,
      issueDateLocal: issueDateLocal,
      status: status ?? this.status,
      subtotalMinor: subtotalMinor ?? this.subtotalMinor,
      discountMinor: discountMinor ?? this.discountMinor,
      discountReasonOptional: discountReasonOptional ?? this.discountReasonOptional,
      discountApprovedByOptional: discountApprovedByOptional ?? this.discountApprovedByOptional,
      taxMinor: taxMinor ?? this.taxMinor,
      totalMinor: totalMinor ?? this.totalMinor,
      paidMinor: paidMinor ?? this.paidMinor,
      balanceMinor: balanceMinor ?? this.balanceMinor,
      currency: currency,
      notesNonclinical: notesNonclinical,
      createdByStaffId: createdByStaffId,
      version: version ?? this.version,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
      voidedAt: voidedAt ?? this.voidedAt,
      voidReason: voidReason ?? this.voidReason,
      items: items ?? this.items,
    );
  }
}
