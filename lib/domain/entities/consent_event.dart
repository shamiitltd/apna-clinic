// Apna Clinic - Consent Event Entity
// Primary source of truth: TRD Section 7 `Consent_Log`

class ConsentEvent {
  final String consentEventId;
  final String clinicId;
  final String patientId;
  final String noticeVersion; // e.g. "v1.0"
  final String purposeCode; // "registration", "visit_processing", "reminders"
  final String consentAction; // "granted", "refused", "withdrawn"
  final String collectionChannel; // "reception_in_person", "verbal", "written"
  final String recordedByStaffId;
  final DateTime recordedAt;
  final DateTime? withdrawnAtOptional;

  const ConsentEvent({
    required this.consentEventId,
    required this.clinicId,
    required this.patientId,
    required this.noticeVersion,
    required this.purposeCode,
    required this.consentAction,
    this.collectionChannel = 'reception_in_person',
    required this.recordedByStaffId,
    required this.recordedAt,
    this.withdrawnAtOptional,
  });

  Map<String, dynamic> toMap() {
    return {
      'consent_event_id': consentEventId,
      'clinic_id': clinicId,
      'patient_id': patientId,
      'notice_version': noticeVersion,
      'purpose_code': purposeCode,
      'consent_action': consentAction,
      'collection_channel': collectionChannel,
      'recorded_by_staff_id': recordedByStaffId,
      'recorded_at': recordedAt.toIso8601String(),
      'withdrawn_at_optional': withdrawnAtOptional?.toIso8601String(),
    };
  }

  factory ConsentEvent.fromMap(Map<String, dynamic> map) {
    return ConsentEvent(
      consentEventId: map['consent_event_id'] as String,
      clinicId: map['clinic_id'] as String,
      patientId: map['patient_id'] as String,
      noticeVersion: map['notice_version'] as String? ?? 'v1.0',
      purposeCode: map['purpose_code'] as String? ?? 'registration',
      consentAction: map['consent_action'] as String? ?? 'granted',
      collectionChannel:
          map['collection_channel'] as String? ?? 'reception_in_person',
      recordedByStaffId: map['recorded_by_staff_id'] as String? ?? '',
      recordedAt: DateTime.parse(map['recorded_at'] as String),
      withdrawnAtOptional: map['withdrawn_at_optional'] != null
          ? DateTime.tryParse(map['withdrawn_at_optional'] as String)
          : null,
    );
  }
}
