// Test Suite for Minor Patient Registration & Guardian Management
// Validates PRD Section M02 Line 90 requirements

import 'package:apna_clinic/domain/entities/patient.dart';
import 'package:apna_clinic/infrastructure/database/local_database.dart';

void main() async {
  print('=============================================');
  print('TESTING MINOR PATIENT REGISTRATION & GUARDIAN');
  print('=============================================');

  // 1. Test Entity serialization with Guardian
  final now = DateTime.now().toUtc();
  final minorPatient = Patient(
    patientId: 'pat-minor-001',
    clinicId: 'clinic-test-1',
    patientNumber: 'P-2026-0042',
    fullName: 'Aarav Sharma',
    phoneOptional: '9876543210',
    ageIfDobUnknown: 8,
    sexOptional: 'Male',
    guardianNameOptional: 'Vikram Sharma',
    guardianRelationOptional: 'Father, +91 9876543210',
    consentStatus: 'granted',
    consentVersion: 'v1.0',
    createdAt: now,
    updatedAt: now,
  );

  assert(minorPatient.displayAge == 8, 'Age should be 8');
  assert(minorPatient.guardianNameOptional == 'Vikram Sharma', 'Guardian name should match');
  assert(minorPatient.guardianRelationOptional == 'Father, +91 9876543210', 'Guardian relation should match');
  print('[PASS] Minor patient entity instantiated with guardian properties.');

  // 2. Test toMap and fromMap
  final map = minorPatient.toMap();
  assert(map['guardian_name_optional'] == 'Vikram Sharma', 'Map must have guardian_name_optional');
  assert(map['guardian_relation_optional'] == 'Father, +91 9876543210', 'Map must have guardian_relation_optional');

  final reconstructed = Patient.fromMap(map);
  assert(reconstructed.guardianNameOptional == 'Vikram Sharma', 'Reconstructed patient must have guardian');
  assert(reconstructed.guardianRelationOptional == 'Father, +91 9876543210', 'Reconstructed patient must have guardian relation');
  print('[PASS] Patient serialization roundtrip preserves guardian metadata.');

  // 3. Test LocalDatabase persistence
  final db = LocalDatabase();
  await db.initialize();

  await db.upsert('Patients', minorPatient.patientId, minorPatient.toMap());
  final retrievedMap = db.get('Patients', minorPatient.patientId);
  assert(retrievedMap != null, 'Patient must exist in database');

  final retrievedPatient = Patient.fromMap(retrievedMap!);
  assert(retrievedPatient.fullName == 'Aarav Sharma', 'Name matches');
  assert(retrievedPatient.guardianNameOptional == 'Vikram Sharma', 'Guardian matches in DB');
  assert(retrievedPatient.guardianRelationOptional == 'Father, +91 9876543210', 'Guardian relation matches in DB');
  print('[PASS] Local database upsert & retrieval preserves minor guardian fields.');

  // 4. Test adult patient has null guardian
  final adultPatient = Patient(
    patientId: 'pat-adult-001',
    clinicId: 'clinic-test-1',
    patientNumber: 'P-2026-0043',
    fullName: 'Sunita Verma',
    phoneOptional: '9876543211',
    ageIfDobUnknown: 32,
    sexOptional: 'Female',
    consentStatus: 'granted',
    consentVersion: 'v1.0',
    createdAt: now,
    updatedAt: now,
  );
  assert(adultPatient.guardianNameOptional == null, 'Adult has null guardian');
  assert(adultPatient.guardianRelationOptional == null, 'Adult has null guardian relation');
  print('[PASS] Adult patient safely defaults to null guardian fields.');

  print('=============================================');
  print('ALL GUARDIAN TESTS PASSED (4/4)');
  print('=============================================');
}
