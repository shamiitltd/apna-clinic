// Apna Clinic - Patient Repository Interface

import '../entities/entities.dart';

abstract class IPatientRepository {
  Future<Patient?> getPatientById(String clinicId, String patientId);
  Future<List<Patient>> searchPatients(
    String clinicId,
    String query, {
    int limit = 50,
  });
  Future<List<Patient>> findPossibleDuplicates(
    String clinicId, {
    String? phone,
    String? fullName,
    DateTime? dob,
  });
  Future<String> generateNextPatientNumber(String clinicId);
  Future<void> savePatient(Patient patient, {ConsentEvent? consentEvent});
  Future<int> countPatients(String clinicId);

  // Sensitive reason for visit storage (isolated)
  Future<void> saveReasonForVisitSecret(ReasonForVisitSecret secret);
  Future<ReasonForVisitSecret?> getReasonForVisitSecret(
    String clinicId,
    String refId,
  );

  // Edit with change history & controlled deletion (PRD M02)
  Future<void> updatePatient(
    Patient patient, {
    required String actorId,
    required String actorRole,
    required List<String> changedFields,
  });

  Future<void> deletePatient(
    String clinicId,
    String patientId, {
    required String actorId,
    required String actorRole,
    String? reason,
  });

  Future<List<AuditEvent>> getPatientAuditHistory(
    String clinicId,
    String patientId,
  );
}
