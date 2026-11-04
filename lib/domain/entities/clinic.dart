// Apna Clinic - Clinic Entity

// Primary source of truth: TRD Section 7 `Clinic_Config`

class Clinic {
  final String clinicId;
  final String legalName;
  final String displayName;
  final String ownerName;
  final String contactPhone;
  final String contactEmail;
  final String addressLine1;
  final String addressLine2;
  final String city;
  final String district;
  final String state;
  final String pincode;
  final String timezone;
  final String currency;
  final String language;
  final String? logoDriveFileId;
  final String? logoBase64;
  final String defaultPaperSize;
  final String consultationSlipTemplateId;
  final String receiptTemplateId;
  final int defaultConsultationFee; // in paise
  final String? taxRegistrationNumber;
  final String taxConfigurationJson;
  final String workingDaysJson;
  final String openingTime;
  final String closingTime;
  final String subscriptionPlan;
  final DateTime? subscriptionExpiryAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String schemaVersion;

  const Clinic({
    required this.clinicId,
    required this.legalName,
    required this.displayName,
    required this.ownerName,
    required this.contactPhone,
    required this.contactEmail,
    required this.addressLine1,
    this.addressLine2 = '',
    required this.city,
    required this.district,
    required this.state,
    required this.pincode,
    this.timezone = 'Asia/Kolkata',
    this.currency = 'INR',
    this.language = 'en',
    this.logoDriveFileId,
    this.logoBase64,
    this.defaultPaperSize = 'A5',
    this.consultationSlipTemplateId = 'standard_v1',
    this.receiptTemplateId = 'standard_v1',
    this.defaultConsultationFee = 50000, // ₹500 in paise
    this.taxRegistrationNumber,
    this.taxConfigurationJson = '{}',
    this.workingDaysJson = '["Mon","Tue","Wed","Thu","Fri","Sat"]',
    this.openingTime = '09:00',
    this.closingTime = '21:00',
    this.subscriptionPlan = 'trial',
    this.subscriptionExpiryAt,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = '1.0.0',
  });

  Map<String, dynamic> toMap() {
    return {
      'clinic_id': clinicId,
      'legal_name': legalName,
      'display_name': displayName,
      'owner_name': ownerName,
      'contact_phone': contactPhone,
      'contact_email': contactEmail,
      'address_line1': addressLine1,
      'address_line2': addressLine2,
      'city': city,
      'district': district,
      'state': state,
      'pincode': pincode,
      'timezone': timezone,
      'currency': currency,
      'language': language,
      'logo_drive_file_id': logoDriveFileId,
      'logo_base64': logoBase64,
      'default_paper_size': defaultPaperSize,
      'consultation_slip_template_id': consultationSlipTemplateId,
      'receipt_template_id': receiptTemplateId,
      'default_consultation_fee': defaultConsultationFee,
      'tax_registration_number': taxRegistrationNumber,
      'tax_configuration_json': taxConfigurationJson,
      'working_days_json': workingDaysJson,
      'opening_time': openingTime,
      'closing_time': closingTime,
      'subscription_plan': subscriptionPlan,
      'subscription_expiry_at': subscriptionExpiryAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'schema_version': schemaVersion,
    };
  }

  factory Clinic.fromMap(Map<String, dynamic> map) {
    return Clinic(
      clinicId: map['clinic_id']?.toString() ?? '',
      legalName: map['legal_name'] as String? ?? '',
      displayName: map['display_name'] as String? ?? '',
      ownerName: map['owner_name'] as String? ?? '',
      contactPhone: map['contact_phone'] as String? ?? '',
      contactEmail: map['contact_email'] as String? ?? '',
      addressLine1: map['address_line1'] as String? ?? '',
      addressLine2: map['address_line2'] as String? ?? '',
      city: map['city'] as String? ?? '',
      district: map['district'] as String? ?? '',
      state: map['state'] as String? ?? '',
      pincode: map['pincode'] as String? ?? '',
      timezone: map['timezone'] as String? ?? 'Asia/Kolkata',
      currency: map['currency'] as String? ?? 'INR',
      language: map['language'] as String? ?? 'en',
      logoDriveFileId: map['logo_drive_file_id'] as String?,
      logoBase64: map['logo_base64'] as String?,
      defaultPaperSize: map['default_paper_size'] as String? ?? 'A5',
      consultationSlipTemplateId:
          map['consultation_slip_template_id'] as String? ?? 'standard_v1',
      receiptTemplateId: map['receipt_template_id'] as String? ?? 'standard_v1',
      defaultConsultationFee:
          (map['default_consultation_fee'] as num?)?.toInt() ?? 50000,
      taxRegistrationNumber: map['tax_registration_number'] as String?,
      taxConfigurationJson: map['tax_configuration_json'] as String? ?? '{}',
      workingDaysJson:
          map['working_days_json'] as String? ??
          '["Mon","Tue","Wed","Thu","Fri","Sat"]',
      openingTime: map['opening_time'] as String? ?? '09:00',
      closingTime: map['closing_time'] as String? ?? '21:00',
      subscriptionPlan: map['subscription_plan'] as String? ?? 'trial',
      subscriptionExpiryAt: map['subscription_expiry_at'] != null
          ? DateTime.tryParse(map['subscription_expiry_at'].toString())
          : null,
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      updatedAt: map['updated_at'] != null
          ? (DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      schemaVersion: map['schema_version'] as String? ?? '1.0.0',
    );
  }

  Clinic copyWith({
    String? legalName,
    String? displayName,
    String? ownerName,
    String? contactPhone,
    String? contactEmail,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? district,
    String? state,
    String? pincode,
    String? timezone,
    String? currency,
    String? language,
    String? logoDriveFileId,
    String? logoBase64,
    String? defaultPaperSize,
    String? consultationSlipTemplateId,
    String? receiptTemplateId,
    int? defaultConsultationFee,
    String? taxRegistrationNumber,
    String? taxConfigurationJson,
    String? workingDaysJson,
    String? openingTime,
    String? closingTime,
    String? subscriptionPlan,
    DateTime? subscriptionExpiryAt,
    DateTime? updatedAt,
  }) {
    return Clinic(
      clinicId: clinicId,
      legalName: legalName ?? this.legalName,
      displayName: displayName ?? this.displayName,
      ownerName: ownerName ?? this.ownerName,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      district: district ?? this.district,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      timezone: timezone ?? this.timezone,
      currency: currency ?? this.currency,
      language: language ?? this.language,
      logoDriveFileId: logoDriveFileId ?? this.logoDriveFileId,
      logoBase64: logoBase64 ?? this.logoBase64,
      defaultPaperSize: defaultPaperSize ?? this.defaultPaperSize,
      consultationSlipTemplateId:
          consultationSlipTemplateId ?? this.consultationSlipTemplateId,
      receiptTemplateId: receiptTemplateId ?? this.receiptTemplateId,
      defaultConsultationFee:
          defaultConsultationFee ?? this.defaultConsultationFee,
      taxRegistrationNumber:
          taxRegistrationNumber ?? this.taxRegistrationNumber,
      taxConfigurationJson: taxConfigurationJson ?? this.taxConfigurationJson,
      workingDaysJson: workingDaysJson ?? this.workingDaysJson,
      openingTime: openingTime ?? this.openingTime,
      closingTime: closingTime ?? this.closingTime,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      subscriptionExpiryAt: subscriptionExpiryAt ?? this.subscriptionExpiryAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
      schemaVersion: schemaVersion,
    );
  }
}
