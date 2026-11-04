// Apna Clinic - Patient Entity
// Primary source of truth: TRD Section 7 `Patients`

import '../../core/utils/phone_normalizer.dart';

class Patient {
  final String patientId;
  final String clinicId;
  final String patientNumber; // e.g. "P-2026-0001" human-facing sequence
  final String fullName;
  final String preferredName;
  final DateTime? dateOfBirth;
  final int? ageIfDobUnknown;
  final String? sexOptional;
  final String? phoneOptional;
  final String? alternatePhoneOptional;
  final String? guardianNameOptional;
  final String? guardianRelationOptional;
  final String? addressOptional;
  final String? cityOptional;
  final String? pincodeOptional;
  final String preferredLanguage;
  final String consentStatus; // e.g. "granted", "withdrawn"
  final String consentVersion; // e.g. "v1.0"
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const Patient({
    required this.patientId,
    required this.clinicId,
    required this.patientNumber,
    required this.fullName,
    this.preferredName = '',
    this.dateOfBirth,
    this.ageIfDobUnknown,
    this.sexOptional,
    this.phoneOptional,
    this.alternatePhoneOptional,
    this.guardianNameOptional,
    this.guardianRelationOptional,
    this.addressOptional,
    this.cityOptional,
    this.pincodeOptional,
    this.preferredLanguage = 'en',
    this.consentStatus = 'granted',
    this.consentVersion = 'v1.0',
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  /// Computed display age
  int? get displayAge {
    if (ageIfDobUnknown != null) return ageIfDobUnknown;
    if (dateOfBirth != null) {
      final now = DateTime.now();
      int age = now.year - dateOfBirth!.year;
      if (now.month < dateOfBirth!.month ||
          (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
        age--;
      }
      return age;
    }
    return null;
  }

  /// Normalized phone for indexing and deduplication
  String? get normalizedPhone => PhoneNormalizer.normalize(phoneOptional);

  /// Masked phone for display on shared screens
  String get maskedPhone => PhoneNormalizer.maskForDisplay(phoneOptional);

  Map<String, dynamic> toMap() {
    return {
      'patient_id': patientId,
      'clinic_id': clinicId,
      'patient_number': patientNumber,
      'full_name': fullName,
      'preferred_name': preferredName,
      'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
      'age_if_dob_unknown': ageIfDobUnknown,
      'sex_optional': sexOptional,
      'phone_optional': phoneOptional,
      'alternate_phone_optional': alternatePhoneOptional,
      'guardian_name_optional': guardianNameOptional,
      'guardian_relation_optional': guardianRelationOptional,
      'address_optional': addressOptional,
      'city_optional': cityOptional,
      'pincode_optional': pincodeOptional,
      'preferred_language': preferredLanguage,
      'consent_status': consentStatus,
      'consent_version': consentVersion,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  factory Patient.fromMap(Map<String, dynamic> map) {
    return Patient(
      patientId: map['patient_id']?.toString() ?? '',
      clinicId: map['clinic_id']?.toString() ?? '',
      patientNumber: map['patient_number'] as String? ?? '',
      fullName: map['full_name'] as String? ?? '',
      preferredName: map['preferred_name'] as String? ?? '',
      dateOfBirth: map['date_of_birth'] != null
          ? DateTime.tryParse(map['date_of_birth'].toString())
          : null,
      ageIfDobUnknown: (map['age_if_dob_unknown'] as num?)?.toInt(),
      sexOptional: map['sex_optional'] as String?,
      phoneOptional: map['phone_optional'] as String?,
      alternatePhoneOptional: map['alternate_phone_optional'] as String?,
      guardianNameOptional: map['guardian_name_optional'] as String?,
      guardianRelationOptional: map['guardian_relation_optional'] as String?,
      addressOptional: map['address_optional'] as String?,
      cityOptional: map['city_optional'] as String?,
      pincodeOptional: map['pincode_optional'] as String?,
      preferredLanguage: map['preferred_language'] as String? ?? 'en',
      consentStatus: map['consent_status'] as String? ?? 'granted',
      consentVersion: map['consent_version'] as String? ?? 'v1.0',
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      updatedAt: map['updated_at'] != null
          ? (DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      deletedAt: map['deleted_at'] != null
          ? DateTime.tryParse(map['deleted_at'].toString())
          : null,
    );
  }

  Patient copyWith({
    String? patientNumber,
    String? fullName,
    String? preferredName,
    DateTime? dateOfBirth,
    int? ageIfDobUnknown,
    String? sexOptional,
    String? phoneOptional,
    String? alternatePhoneOptional,
    String? guardianNameOptional,
    String? guardianRelationOptional,
    String? addressOptional,
    String? cityOptional,
    String? pincodeOptional,
    String? preferredLanguage,
    String? consentStatus,
    String? consentVersion,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Patient(
      patientId: patientId,
      clinicId: clinicId,
      patientNumber: patientNumber ?? this.patientNumber,
      fullName: fullName ?? this.fullName,
      preferredName: preferredName ?? this.preferredName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      ageIfDobUnknown: ageIfDobUnknown ?? this.ageIfDobUnknown,
      sexOptional: sexOptional ?? this.sexOptional,
      phoneOptional: phoneOptional ?? this.phoneOptional,
      alternatePhoneOptional:
          alternatePhoneOptional ?? this.alternatePhoneOptional,
      guardianNameOptional: guardianNameOptional ?? this.guardianNameOptional,
      guardianRelationOptional:
          guardianRelationOptional ?? this.guardianRelationOptional,
      addressOptional: addressOptional ?? this.addressOptional,
      cityOptional: cityOptional ?? this.cityOptional,
      pincodeOptional: pincodeOptional ?? this.pincodeOptional,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      consentStatus: consentStatus ?? this.consentStatus,
      consentVersion: consentVersion ?? this.consentVersion,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
