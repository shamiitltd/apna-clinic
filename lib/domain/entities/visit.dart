// Apna Clinic - Visit Entity
// Primary source of truth: TRD Section 7 `Visits`

import '../enums/domain_enums.dart';

class Visit {
  final String visitId;
  final String clinicId;
  final String patientId;
  final String doctorId;
  final String? appointmentIdOptional;
  final String visitDateLocal; // YYYY-MM-DD
  final DateTime checkinAt;
  final int tokenNumber; // Daily sequence number for the doctor
  final String tokenScopeKey; // {clinic_id}:{doctor_id}:{local_date}
  final String visitType; // "walkin", "appointment", "followup"
  final String? reasonForVisitEncryptedRef;
  final QueueStatus queueStatus;
  final QueuePriority priority;
  final DateTime? consultationStartedAt;
  final DateTime? consultationCompletedAt;
  final int slipPrintCount;
  final DateTime? lastSlipPrintedAt;
  final String? invoiceIdOptional;
  final String? followupDueDateOptional;
  final String createdByStaffId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const Visit({
    required this.visitId,
    required this.clinicId,
    required this.patientId,
    required this.doctorId,
    this.appointmentIdOptional,
    required this.visitDateLocal,
    required this.checkinAt,
    required this.tokenNumber,
    required this.tokenScopeKey,
    this.visitType = 'walkin',
    this.reasonForVisitEncryptedRef,
    this.queueStatus = QueueStatus.waiting,
    this.priority = QueuePriority.normal,
    this.consultationStartedAt,
    this.consultationCompletedAt,
    this.slipPrintCount = 0,
    this.lastSlipPrintedAt,
    this.invoiceIdOptional,
    this.followupDueDateOptional,
    required this.createdByStaffId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'visit_id': visitId,
      'clinic_id': clinicId,
      'patient_id': patientId,
      'doctor_id': doctorId,
      'appointment_id_optional': appointmentIdOptional,
      'visit_date_local': visitDateLocal,
      'checkin_at': checkinAt.toIso8601String(),
      'token_number': tokenNumber,
      'token_scope_key': tokenScopeKey,
      'visit_type': visitType,
      'reason_for_visit_encrypted_ref': reasonForVisitEncryptedRef,
      'queue_status': queueStatus.wireValue,
      'priority': priority.wireValue,
      'consultation_started_at': consultationStartedAt?.toIso8601String(),
      'consultation_completed_at': consultationCompletedAt?.toIso8601String(),
      'slip_print_count': slipPrintCount,
      'last_slip_printed_at': lastSlipPrintedAt?.toIso8601String(),
      'invoice_id_optional': invoiceIdOptional,
      'followup_due_date_optional': followupDueDateOptional,
      'created_by_staff_id': createdByStaffId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  factory Visit.fromMap(Map<String, dynamic> map) {
    return Visit(
      visitId: map['visit_id']?.toString() ?? '',
      clinicId: map['clinic_id']?.toString() ?? '',
      patientId: map['patient_id']?.toString() ?? '',
      doctorId: map['doctor_id']?.toString() ?? '',
      appointmentIdOptional: map['appointment_id_optional'] as String?,
      visitDateLocal: map['visit_date_local'] as String? ??
          DateTime.now().toIso8601String().split('T').first,
      checkinAt: map['checkin_at'] != null
          ? (DateTime.tryParse(map['checkin_at'].toString()) ?? DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      tokenNumber: (map['token_number'] as num?)?.toInt() ?? 0,
      tokenScopeKey: map['token_scope_key'] as String? ?? '',
      visitType: map['visit_type'] as String? ?? 'walkin',
      reasonForVisitEncryptedRef:
          map['reason_for_visit_encrypted_ref'] as String?,
      queueStatus: QueueStatus.fromWire(
        map['queue_status'] as String? ?? 'waiting',
      ),
      priority: QueuePriority.fromWire(
        map['priority'] as String?,
      ),
      consultationStartedAt: map['consultation_started_at'] != null
          ? DateTime.tryParse(map['consultation_started_at'].toString())
          : null,
      consultationCompletedAt: map['consultation_completed_at'] != null
          ? DateTime.tryParse(map['consultation_completed_at'].toString())
          : null,
      slipPrintCount: (map['slip_print_count'] as num?)?.toInt() ?? 0,
      lastSlipPrintedAt: map['last_slip_printed_at'] != null
          ? DateTime.tryParse(map['last_slip_printed_at'].toString())
          : null,
      invoiceIdOptional: map['invoice_id_optional'] as String?,
      followupDueDateOptional: map['followup_due_date_optional'] as String?,
      createdByStaffId: map['created_by_staff_id'] as String? ?? '',
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

  Visit copyWith({
    QueueStatus? queueStatus,
    QueuePriority? priority,
    DateTime? consultationStartedAt,
    DateTime? consultationCompletedAt,
    int? slipPrintCount,
    DateTime? lastSlipPrintedAt,
    String? invoiceIdOptional,
    String? followupDueDateOptional,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Visit(
      visitId: visitId,
      clinicId: clinicId,
      patientId: patientId,
      doctorId: doctorId,
      appointmentIdOptional: appointmentIdOptional,
      visitDateLocal: visitDateLocal,
      checkinAt: checkinAt,
      tokenNumber: tokenNumber,
      tokenScopeKey: tokenScopeKey,
      visitType: visitType,
      reasonForVisitEncryptedRef: reasonForVisitEncryptedRef,
      queueStatus: queueStatus ?? this.queueStatus,
      priority: priority ?? this.priority,
      consultationStartedAt:
          consultationStartedAt ?? this.consultationStartedAt,
      consultationCompletedAt:
          consultationCompletedAt ?? this.consultationCompletedAt,
      slipPrintCount: slipPrintCount ?? this.slipPrintCount,
      lastSlipPrintedAt: lastSlipPrintedAt ?? this.lastSlipPrintedAt,
      invoiceIdOptional: invoiceIdOptional ?? this.invoiceIdOptional,
      followupDueDateOptional:
          followupDueDateOptional ?? this.followupDueDateOptional,
      createdByStaffId: createdByStaffId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
