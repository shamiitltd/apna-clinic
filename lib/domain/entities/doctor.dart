// Apna Clinic - Doctor Entity
// Primary source of truth: TRD Section 7 `Doctors`

class Doctor {
  final String doctorId;
  final String clinicId;
  final String displayName;
  final String qualificationText;
  final String registrationNumber;
  final String specialtyLabel;
  final String contactPhone;
  final bool active;
  final int consultationDurationMinutes;
  final int defaultFee; // in paise
  final String workingScheduleJson;
  final String roomLabel;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const Doctor({
    required this.doctorId,
    required this.clinicId,
    required this.displayName,
    this.qualificationText = '',
    this.registrationNumber = '',
    this.specialtyLabel = 'General Physician',
    this.contactPhone = '',
    this.active = true,
    this.consultationDurationMinutes = 15,
    this.defaultFee = 50000, // ₹500 in paise
    this.workingScheduleJson = '{}',
    this.roomLabel = 'Room 1',
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'doctor_id': doctorId,
      'clinic_id': clinicId,
      'display_name': displayName,
      'qualification_text': qualificationText,
      'registration_number': registrationNumber,
      'specialty_label': specialtyLabel,
      'contact_phone': contactPhone,
      'active': active ? 1 : 0,
      'consultation_duration_minutes': consultationDurationMinutes,
      'default_fee': defaultFee,
      'working_schedule_json': workingScheduleJson,
      'room_label': roomLabel,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  factory Doctor.fromMap(Map<String, dynamic> map) {
    return Doctor(
      doctorId: map['doctor_id']?.toString() ?? '',
      clinicId: map['clinic_id']?.toString() ?? '',
      displayName: map['display_name'] as String? ?? '',
      qualificationText: map['qualification_text'] as String? ?? '',
      registrationNumber: map['registration_number'] as String? ?? '',
      specialtyLabel: map['specialty_label'] as String? ?? 'General Physician',
      contactPhone: map['contact_phone'] as String? ?? '',
      active: (map['active'] is bool)
          ? map['active'] as bool
          : ((map['active'] as num?)?.toInt() ?? 1) == 1,
      consultationDurationMinutes:
          (map['consultation_duration_minutes'] as num?)?.toInt() ?? 15,
      defaultFee: (map['default_fee'] as num?)?.toInt() ?? 50000,
      workingScheduleJson: map['working_schedule_json'] as String? ?? '{}',
      roomLabel: map['room_label'] as String? ?? 'Room 1',
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

  Doctor copyWith({
    String? displayName,
    String? qualificationText,
    String? registrationNumber,
    String? specialtyLabel,
    String? contactPhone,
    bool? active,
    int? consultationDurationMinutes,
    int? defaultFee,
    String? workingScheduleJson,
    String? roomLabel,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Doctor(
      doctorId: doctorId,
      clinicId: clinicId,
      displayName: displayName ?? this.displayName,
      qualificationText: qualificationText ?? this.qualificationText,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      specialtyLabel: specialtyLabel ?? this.specialtyLabel,
      contactPhone: contactPhone ?? this.contactPhone,
      active: active ?? this.active,
      consultationDurationMinutes:
          consultationDurationMinutes ?? this.consultationDurationMinutes,
      defaultFee: defaultFee ?? this.defaultFee,
      workingScheduleJson: workingScheduleJson ?? this.workingScheduleJson,
      roomLabel: roomLabel ?? this.roomLabel,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
