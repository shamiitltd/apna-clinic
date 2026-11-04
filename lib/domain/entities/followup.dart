// Apna Clinic - Followup Entity
// Primary source of truth: PRD Section 5 M12 & TRD Section 7 `Followups`
// CLINICAL BOUNDARY: Administrative scheduling only. Strictly no clinical treatment history or prescriptions.

class Followup {
  final String followupId;
  final String clinicId;
  final String patientId;
  final String? sourceVisitIdOptional;
  final String doctorId;
  final String dueDate; // YYYY-MM-DD
  final String? administrativeNoteOptional;
  final String status; // "scheduled", "completed", "cancelled", "missed"
  final bool reminderConsent;
  final String channelPreference; // "sms", "whatsapp", "call"
  final String reminderStatus; // "scheduled", "sent", "failed", "cancelled"
  final DateTime? reminderSentAt;
  final String? convertedAppointmentIdOptional;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Followup({
    required this.followupId,
    required this.clinicId,
    required this.patientId,
    this.sourceVisitIdOptional,
    required this.doctorId,
    required this.dueDate,
    this.administrativeNoteOptional,
    this.status = 'scheduled',
    this.reminderConsent = false,
    this.channelPreference = 'sms',
    this.reminderStatus = 'scheduled',
    this.reminderSentAt,
    this.convertedAppointmentIdOptional,
    required this.createdAt,
    required this.updatedAt,
  });

  bool isOverdue(String todayDate) {
    if (status != 'scheduled') return false;
    return dueDate.compareTo(todayDate) < 0;
  }

  bool isDueToday(String todayDate) {
    return status == 'scheduled' && dueDate == todayDate;
  }

  Followup copyWith({
    String? followupId,
    String? clinicId,
    String? patientId,
    String? sourceVisitIdOptional,
    String? doctorId,
    String? dueDate,
    String? administrativeNoteOptional,
    String? status,
    bool? reminderConsent,
    String? channelPreference,
    String? reminderStatus,
    DateTime? reminderSentAt,
    String? convertedAppointmentIdOptional,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Followup(
      followupId: followupId ?? this.followupId,
      clinicId: clinicId ?? this.clinicId,
      patientId: patientId ?? this.patientId,
      sourceVisitIdOptional:
          sourceVisitIdOptional ?? this.sourceVisitIdOptional,
      doctorId: doctorId ?? this.doctorId,
      dueDate: dueDate ?? this.dueDate,
      administrativeNoteOptional:
          administrativeNoteOptional ?? this.administrativeNoteOptional,
      status: status ?? this.status,
      reminderConsent: reminderConsent ?? this.reminderConsent,
      channelPreference: channelPreference ?? this.channelPreference,
      reminderStatus: reminderStatus ?? this.reminderStatus,
      reminderSentAt: reminderSentAt ?? this.reminderSentAt,
      convertedAppointmentIdOptional:
          convertedAppointmentIdOptional ?? this.convertedAppointmentIdOptional,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'followup_id': followupId,
      'clinic_id': clinicId,
      'patient_id': patientId,
      'source_visit_id_optional': sourceVisitIdOptional,
      'doctor_id': doctorId,
      'due_date': dueDate,
      'administrative_note_optional': administrativeNoteOptional,
      'status': status,
      'reminder_consent': reminderConsent ? 1 : 0,
      'channel_preference': channelPreference,
      'reminder_status': reminderStatus,
      'reminder_sent_at': reminderSentAt?.toIso8601String(),
      'converted_appointment_id_optional': convertedAppointmentIdOptional,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Followup.fromMap(Map<String, dynamic> map) {
    return Followup(
      followupId: map['followup_id'] as String,
      clinicId: map['clinic_id'] as String,
      patientId: map['patient_id'] as String,
      sourceVisitIdOptional: map['source_visit_id_optional'] as String?,
      doctorId: map['doctor_id'] as String,
      dueDate: map['due_date'] as String,
      administrativeNoteOptional:
          map['administrative_note_optional'] as String?,
      status: map['status'] as String? ?? 'scheduled',
      reminderConsent: (map['reminder_consent'] is bool)
          ? map['reminder_consent'] as bool
          : ((map['reminder_consent'] as num?)?.toInt() ?? 0) == 1,
      channelPreference: map['channel_preference'] as String? ?? 'sms',
      reminderStatus: map['reminder_status'] as String? ?? 'scheduled',
      reminderSentAt: map['reminder_sent_at'] != null
          ? DateTime.tryParse(map['reminder_sent_at'] as String)
          : null,
      convertedAppointmentIdOptional:
          map['converted_appointment_id_optional'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
