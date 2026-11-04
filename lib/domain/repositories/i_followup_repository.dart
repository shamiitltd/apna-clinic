// Apna Clinic - Follow-up Repository Interface (Module 12)
// Primary source of truth: PRD Section 5 M12 & TRD Section 7 `Followups`
// CLINICAL BOUNDARY: Administrative scheduling & reminders only. Strictly no clinical prescriptions or treatment advice.

import '../entities/appointment.dart';
import '../entities/doctor.dart';
import '../entities/followup.dart';
import '../entities/patient.dart';

abstract class IFollowupRepository {
  /// Records a new administrative follow-up reminder
  Future<void> scheduleFollowup(Followup followup);

  /// Retrieves a follow-up by ID
  Future<Followup?> getFollowupById(String clinicId, String followupId);

  /// Retrieves follow-ups due on a specific calendar date (YYYY-MM-DD)
  Future<List<Followup>> getFollowupsForDate(String clinicId, String dueDate);

  /// Retrieves follow-ups in a date range [startDate, endDate]
  Future<List<Followup>> getFollowupsForDateRange(
    String clinicId,
    String startDate,
    String endDate,
  );

  /// Retrieves follow-ups for a specific patient
  Future<List<Followup>> getFollowupsForPatient(
    String clinicId,
    String patientId,
  );

  /// Retrieves follow-ups for a specific doctor
  Future<List<Followup>> getFollowupsForDoctor(
    String clinicId,
    String doctorId, {
    String? status,
  });

  /// Retrieves all follow-ups for a clinic with optional status filter
  Future<List<Followup>> getAllFollowups(
    String clinicId, {
    String? status,
  });

  /// Updates status of a follow-up ("scheduled", "completed", "cancelled", "missed")
  Future<void> updateFollowupStatus({
    required String clinicId,
    required String followupId,
    required String status,
    String? reason,
    required String actorId,
  });

  /// Records that a reminder was sent/attempted (SMS, WhatsApp, Call)
  Future<void> recordReminderNotification({
    required String clinicId,
    required String followupId,
    required String status,
    required String channel,
    required String actorId,
  });

  /// Converts a follow-up into a confirmed appointment slot
  Future<void> convertToAppointment({
    required String clinicId,
    required String followupId,
    required Appointment appointment,
    required String actorId,
  });

  /// Exports follow-ups to CSV format strictly preserving patient confidentiality (no symptoms/clinical data)
  String exportFollowupsToCsv(
    List<Followup> followups,
    Map<String, Patient> patientMap,
    Map<String, Doctor> doctorMap,
  );
}

