// Apna Clinic - Appointment Entity
// Primary source of truth: TRD Section 7 `Appointments`

import '../enums/domain_enums.dart';

class Appointment {
  final String appointmentId;
  final String clinicId;
  final String patientId;
  final String doctorId;
  final DateTime scheduledStartAt;
  final DateTime scheduledEndAt;
  final String appointmentType; // "new_consultation", "followup"
  final String bookingSource; // "walkin", "phone", "reception"
  final AppointmentStatus status;
  final String? reasonForVisitEncryptedRef;
  final String createdByStaffId;
  final bool reminderConsent;
  final String reminderStatus; // "none", "scheduled", "sent", "failed"
  final String? rescheduledFromId;
  final String? cancelReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const Appointment({
    required this.appointmentId,
    required this.clinicId,
    required this.patientId,
    required this.doctorId,
    required this.scheduledStartAt,
    required this.scheduledEndAt,
    this.appointmentType = 'new_consultation',
    this.bookingSource = 'reception',
    this.status = AppointmentStatus.scheduled,
    this.reasonForVisitEncryptedRef,
    required this.createdByStaffId,
    this.reminderConsent = false,
    this.reminderStatus = 'none',
    this.rescheduledFromId,
    this.cancelReason,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'appointment_id': appointmentId,
      'clinic_id': clinicId,
      'patient_id': patientId,
      'doctor_id': doctorId,
      'scheduled_start_at': scheduledStartAt.toIso8601String(),
      'scheduled_end_at': scheduledEndAt.toIso8601String(),
      'appointment_type': appointmentType,
      'booking_source': bookingSource,
      'status': status.wireValue,
      'reason_for_visit_encrypted_ref': reasonForVisitEncryptedRef,
      'created_by_staff_id': createdByStaffId,
      'reminder_consent': reminderConsent ? 1 : 0,
      'reminder_status': reminderStatus,
      'rescheduled_from_id': rescheduledFromId,
      'cancel_reason': cancelReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> map) {
    return Appointment(
      appointmentId: map['appointment_id']?.toString() ?? '',
      clinicId: map['clinic_id']?.toString() ?? '',
      patientId: map['patient_id']?.toString() ?? '',
      doctorId: map['doctor_id']?.toString() ?? '',
      scheduledStartAt: map['scheduled_start_at'] != null
          ? (DateTime.tryParse(map['scheduled_start_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      scheduledEndAt: map['scheduled_end_at'] != null
          ? (DateTime.tryParse(map['scheduled_end_at'].toString()) ??
              DateTime.now().toUtc().add(const Duration(minutes: 15)))
          : DateTime.now().toUtc().add(const Duration(minutes: 15)),
      appointmentType: map['appointment_type'] as String? ?? 'new_consultation',
      bookingSource: map['booking_source'] as String? ?? 'reception',
      status: AppointmentStatus.fromWire(
        map['status'] as String? ?? 'scheduled',
      ),
      reasonForVisitEncryptedRef:
          map['reason_for_visit_encrypted_ref'] as String?,
      createdByStaffId: map['created_by_staff_id'] as String? ?? '',
      reminderConsent: (map['reminder_consent'] is bool)
          ? map['reminder_consent'] as bool
          : ((map['reminder_consent'] as num?)?.toInt() ?? 0) == 1,
      reminderStatus: map['reminder_status'] as String? ?? 'none',
      rescheduledFromId: map['rescheduled_from_id'] as String?,
      cancelReason: map['cancel_reason'] as String?,
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      updatedAt: map['updated_at'] != null
          ? (DateTime.tryParse(map['updated_at'].toString()) ??
              DateTime.now().toUtc())
          : DateTime.now().toUtc(),
      deletedAt: map['deleted_at'] != null
          ? DateTime.tryParse(map['deleted_at'].toString())
          : null,
    );
  }

  Appointment copyWith({
    String? doctorId,
    DateTime? scheduledStartAt,
    DateTime? scheduledEndAt,
    String? appointmentType,
    String? bookingSource,
    AppointmentStatus? status,
    String? reasonForVisitEncryptedRef,
    bool? reminderConsent,
    String? reminderStatus,
    String? rescheduledFromId,
    String? cancelReason,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Appointment(
      appointmentId: appointmentId,
      clinicId: clinicId,
      patientId: patientId,
      doctorId: doctorId ?? this.doctorId,
      scheduledStartAt: scheduledStartAt ?? this.scheduledStartAt,
      scheduledEndAt: scheduledEndAt ?? this.scheduledEndAt,
      appointmentType: appointmentType ?? this.appointmentType,
      bookingSource: bookingSource ?? this.bookingSource,
      status: status ?? this.status,
      reasonForVisitEncryptedRef:
          reasonForVisitEncryptedRef ?? this.reasonForVisitEncryptedRef,
      createdByStaffId: createdByStaffId,
      reminderConsent: reminderConsent ?? this.reminderConsent,
      reminderStatus: reminderStatus ?? this.reminderStatus,
      rescheduledFromId: rescheduledFromId ?? this.rescheduledFromId,
      cancelReason: cancelReason ?? this.cancelReason,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
