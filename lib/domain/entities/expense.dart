// Apna Clinic - Expense Entity
// Primary source of truth: TRD Section 7 `Expenses`

import '../enums/domain_enums.dart';

class Expense {
  final String expenseId;
  final String clinicId;
  final String expenseDate; // YYYY-MM-DD
  final String category; // "supplies", "utilities", "rent", "tea_refreshments", "maintenance", "other"
  final String? vendorOptional;
  final String description;
  final int amountMinor; // in paise
  final PaymentMethod paymentMethod;
  final String? paymentReferenceOptional;
  final String? receiptDriveFileIdOptional;
  final String createdByStaffId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const Expense({
    required this.expenseId,
    required this.clinicId,
    required this.expenseDate,
    required this.category,
    this.vendorOptional,
    required this.description,
    required this.amountMinor,
    this.paymentMethod = PaymentMethod.cash,
    this.paymentReferenceOptional,
    this.receiptDriveFileIdOptional,
    required this.createdByStaffId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'expense_id': expenseId,
      'clinic_id': clinicId,
      'expense_date': expenseDate,
      'category': category,
      'vendor_optional': vendorOptional,
      'description': description,
      'amount_minor': amountMinor,
      'payment_method': paymentMethod.wireValue,
      'payment_reference_optional': paymentReferenceOptional,
      'receipt_drive_file_id_optional': receiptDriveFileIdOptional,
      'created_by_staff_id': createdByStaffId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      expenseId: map['expense_id'] as String,
      clinicId: map['clinic_id'] as String,
      expenseDate: map['expense_date'] as String,
      category: map['category'] as String? ?? 'supplies',
      vendorOptional: map['vendor_optional'] as String?,
      description: map['description'] as String? ?? '',
      amountMinor: (map['amount_minor'] as num).toInt(),
      paymentMethod: PaymentMethod.fromWire(
        map['payment_method'] as String? ?? 'cash',
      ),
      paymentReferenceOptional: map['payment_reference_optional'] as String?,
      receiptDriveFileIdOptional:
          map['receipt_drive_file_id_optional'] as String?,
      createdByStaffId: map['created_by_staff_id'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deletedAt: map['deleted_at'] != null
          ? DateTime.tryParse(map['deleted_at'] as String)
          : null,
    );
  }
}
