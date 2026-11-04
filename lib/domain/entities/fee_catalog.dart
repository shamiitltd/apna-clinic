// Apna Clinic - Fee Catalog Entity
// Primary source of truth: PRD Section 6.2 `Clinic_Master / fee_catalog` & Section 5 M06
// Consultation fee catalogue by doctor/visit type, integer paise math.

class FeeCatalog {
  final String feeId;
  final String clinicId;
  final String? doctorIdOptional; // doctor-scoped fee (optional)
  final String? visitTypeOptional; // walkin, appointment, followup, emergency (optional)
  final String feeCode;
  final String feeName; // or label
  final String description;
  final int defaultAmountMinor; // in paise
  final String currency;
  final String taxCategory; // "exempt", "standard", "gst_applicable"
  final String taxRateConfig; // e.g. "0.0", "5.0", "12.0", "18.0"
  final DateTime? activeFromOptional;
  final DateTime? activeToOptional;
  final bool active;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FeeCatalog({
    required this.feeId,
    required this.clinicId,
    this.doctorIdOptional,
    this.visitTypeOptional,
    required this.feeCode,
    required this.feeName,
    this.description = '',
    required this.defaultAmountMinor,
    this.currency = 'INR',
    this.taxCategory = 'exempt',
    this.taxRateConfig = '0.0',
    this.activeFromOptional,
    this.activeToOptional,
    this.active = true,
    this.version = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'fee_id': feeId,
      'clinic_id': clinicId,
      'doctor_id_optional': doctorIdOptional,
      'visit_type': visitTypeOptional,
      'visit_type_optional': visitTypeOptional,
      'fee_code': feeCode,
      'fee_name': feeName,
      'label': feeName,
      'description': description,
      'default_amount_minor': defaultAmountMinor,
      'amount_paise': defaultAmountMinor,
      'currency': currency,
      'tax_category': taxCategory,
      'tax_rate_config': taxRateConfig,
      'active_from': activeFromOptional?.toIso8601String(),
      'active_to': activeToOptional?.toIso8601String(),
      'active': active ? 1 : 0,
      'version': version,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory FeeCatalog.fromMap(Map<String, dynamic> map) {
    return FeeCatalog(
      feeId: map['fee_id']?.toString() ?? '',
      clinicId: map['clinic_id']?.toString() ?? '',
      doctorIdOptional: (map['doctor_id_optional'] ?? map['doctor_id']) as String?,
      visitTypeOptional: (map['visit_type_optional'] ?? map['visit_type']) as String?,
      feeCode: map['fee_code'] as String? ?? '',
      feeName: (map['fee_name'] ?? map['label']) as String? ?? '',
      description: map['description'] as String? ?? '',
      defaultAmountMinor: ((map['default_amount_minor'] ?? map['amount_paise']) as num?)?.toInt() ?? 0,
      currency: map['currency'] as String? ?? 'INR',
      taxCategory: map['tax_category'] as String? ?? 'exempt',
      taxRateConfig: map['tax_rate_config'] as String? ?? '0.0',
      activeFromOptional: map['active_from'] != null
          ? DateTime.tryParse(map['active_from'].toString())
          : null,
      activeToOptional: map['active_to'] != null
          ? DateTime.tryParse(map['active_to'].toString())
          : null,
      active: (map['active'] is bool)
          ? map['active'] as bool
          : ((map['active'] as num?)?.toInt() ?? 1) == 1,
      version: (map['version'] as num?)?.toInt() ?? 1,
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      updatedAt: map['updated_at'] != null
          ? (DateTime.tryParse(map['updated_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
    );
  }

  FeeCatalog copyWith({
    String? doctorIdOptional,
    String? visitTypeOptional,
    String? feeCode,
    String? feeName,
    String? description,
    int? defaultAmountMinor,
    String? currency,
    String? taxCategory,
    String? taxRateConfig,
    DateTime? activeFromOptional,
    DateTime? activeToOptional,
    bool? active,
    int? version,
    DateTime? updatedAt,
  }) {
    return FeeCatalog(
      feeId: feeId,
      clinicId: clinicId,
      doctorIdOptional: doctorIdOptional ?? this.doctorIdOptional,
      visitTypeOptional: visitTypeOptional ?? this.visitTypeOptional,
      feeCode: feeCode ?? this.feeCode,
      feeName: feeName ?? this.feeName,
      description: description ?? this.description,
      defaultAmountMinor: defaultAmountMinor ?? this.defaultAmountMinor,
      currency: currency ?? this.currency,
      taxCategory: taxCategory ?? this.taxCategory,
      taxRateConfig: taxRateConfig ?? this.taxRateConfig,
      activeFromOptional: activeFromOptional ?? this.activeFromOptional,
      activeToOptional: activeToOptional ?? this.activeToOptional,
      active: active ?? this.active,
      version: version ?? this.version,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
  }
}
