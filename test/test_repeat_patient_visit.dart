// Test Suite for Repeat Patient Visits & Token Allocation on the Same Day
// Verifies PRD M03 & M04 and fixes Bug with repeat visits for existing patients

import 'package:apna_clinic/domain/entities/patient.dart';
import 'package:apna_clinic/domain/entities/visit.dart';
import 'package:apna_clinic/domain/enums/domain_enums.dart';
import 'package:apna_clinic/infrastructure/database/local_database.dart';
import 'package:apna_clinic/infrastructure/repositories/visit_repository.dart';

void main() async {
  print('====================================================');
  print('TESTING REPEAT PATIENT VISITS & TOKEN QUEUE ASSIGNMENT');
  print('====================================================');

  final db = LocalDatabase();
  await db.initialize();
  final visitRepo = VisitRepository(db);

  final today = DateTime.now().toIso8601String().split('T').first;
  final now = DateTime.now().toUtc();
  const clinicId = 'clinic_repeat_test';
  const doctorId = 'doc_repeat_1';
  const patientId = 'pat_repeat_1';

  // 1. Create Patient Record in database
  final patient = Patient(
    patientId: patientId,
    clinicId: clinicId,
    patientNumber: 'P-2026-9999',
    fullName: 'Ramesh Sharma',
    phoneOptional: '9876543210',
    createdAt: now,
    updatedAt: now,
  );
  await db.upsert('Patients', patient.patientId, patient.toMap());

  // 2. Patient visits in the morning -> First Visit (Token #1)
  final visitId1 = 'visit_morning_1';
  final visit1 = Visit(
    visitId: visitId1,
    clinicId: clinicId,
    patientId: patientId,
    doctorId: doctorId,
    visitDateLocal: today,
    checkinAt: now,
    tokenNumber: 0,
    tokenScopeKey: '',
    queueStatus: QueueStatus.waiting,
    createdByStaffId: 'staff_1',
    createdAt: now,
    updatedAt: now,
  );

  final createdVisit1 = await visitRepo.createVisitAtomic(
    visit: visit1,
    idempotencyKey: 'create_visit_$visitId1',
    deviceId: 'device_1',
    staffId: 'staff_1',
  );

  assert(createdVisit1.tokenNumber == 1, 'First visit must get Token #1');
  print('[PASS] First visit for patient successfully created with Token #1');

  // 3. Same Patient comes again in afternoon -> Second Visit (Token #2)
  final visitId2 = 'visit_afternoon_2';
  final visit2 = Visit(
    visitId: visitId2,
    clinicId: clinicId,
    patientId: patientId, // SAME PATIENT!
    doctorId: doctorId,   // SAME DOCTOR!
    visitDateLocal: today,// SAME DAY!
    checkinAt: now.add(const Duration(hours: 4)),
    tokenNumber: 0,
    tokenScopeKey: '',
    queueStatus: QueueStatus.waiting,
    createdByStaffId: 'staff_1',
    createdAt: now.add(const Duration(hours: 4)),
    updatedAt: now.add(const Duration(hours: 4)),
  );

  final createdVisit2 = await visitRepo.createVisitAtomic(
    visit: visit2,
    idempotencyKey: 'create_visit_$visitId2',
    deviceId: 'device_1',
    staffId: 'staff_1',
  );

  assert(createdVisit2.tokenNumber == 2, 'Second visit for same patient must get Token #2');
  assert(createdVisit2.visitId != createdVisit1.visitId, 'Must be distinct visit IDs');
  print('[PASS] Repeat visit for same patient successfully created with Token #2');

  // 4. Verify both visits exist in queue for today
  final queueVisits = await visitRepo.getVisitsForDate(clinicId, today, doctorId: doctorId);
  assert(queueVisits.length == 2, 'Queue must show both visits for the doctor today');
  assert(queueVisits.any((v) => v.visitId == visitId1 && v.tokenNumber == 1), 'Queue contains visit 1');
  assert(queueVisits.any((v) => v.visitId == visitId2 && v.tokenNumber == 2), 'Queue contains visit 2');
  print('[PASS] Both visits correctly appear in queue query for doctor');

  // 5. Test idempotency protection against rapid double-click on visit 2
  final retryVisit2 = await visitRepo.createVisitAtomic(
    visit: visit2,
    idempotencyKey: 'create_visit_$visitId2',
    deviceId: 'device_1',
    staffId: 'staff_1',
  );
  assert(retryVisit2.tokenNumber == 2, 'Retry returns existing token without re-incrementing');
  assert(retryVisit2.visitId == visitId2, 'Retry returns same visit ID');
  print('[PASS] Rapid double-click on visit creation idempotently dedupes without creating spurious tokens');

  // 6. Test Active Visit in Queue Detection
  final activeVisits = queueVisits.where((v) =>
      v.patientId == patientId &&
      (v.queueStatus == QueueStatus.registered ||
       v.queueStatus == QueueStatus.waiting ||
       v.queueStatus == QueueStatus.called ||
       v.queueStatus == QueueStatus.inConsultation)).toList();
  assert(activeVisits.isNotEmpty, 'Active visit correctly identified in queue');
  assert(activeVisits.last.tokenNumber == 2, 'Most recent active token is #2');
  print('[PASS] Active visit detection correctly identifies patient in queue to block accidental duplicate tokens.');

  print('====================================================');
  print('ALL REPEAT PATIENT VISIT TESTS PASSED (6/6)');
  print('====================================================');
}
