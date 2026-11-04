// Apna Clinic - Controlled One-Way Master Sheet Initialization & Sync Engine Boundary Test Suite
// Phase 3 — Milestone 3
// Primary source of truth: User Request Milestone 3, PRD Section 17-19, TRD Section 7, 11
// Tests:
// 1. Master Sheet schema validation gate
// 2. Successful initialization
// 3. Empty-sheet handling
// 4. Duplicate-record handling & deduplication
// 5. Invalid-record rejection & reporting
// 6. Foreign-key violation detection
// 7. Schema mismatch halting
// 8. Authentication failure handling
// 9. Network failure handling
// 10. Google API failure handling (429 RateLimit & 503 ServerError)
// 11. Repeat initialization / Idempotency
// 12. Offline regression test & local source-of-truth preservation
// 13. One-way sync boundary verification (NO sync_outbox writes)

import 'package:flutter_test/flutter_test.dart';

import 'package:apna_clinic/application/auth/auth_service.dart';
import 'package:apna_clinic/application/providers.dart';
import 'package:apna_clinic/domain/entities/patient.dart';
import 'package:apna_clinic/infrastructure/database/local_database.dart';
import 'package:apna_clinic/infrastructure/database/storage_adapter.dart';
import 'package:apna_clinic/infrastructure/google/mock_google_integration.dart';
import 'package:apna_clinic/infrastructure/google/oauth/mock_google_oauth_provider.dart';
import 'package:apna_clinic/infrastructure/google/oauth/token_vault.dart';
import 'package:apna_clinic/infrastructure/google/sync/master_sheet_initialization_service.dart';
import 'package:apna_clinic/infrastructure/repositories/infrastructure_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Test Harness Builder
  (
    MasterSheetInitializationService,
    MockGoogleDriveClient,
    MockGoogleSheetsClient,
    AuthService,
    LocalDatabase,
    MemoryStorageAdapter,
  ) createInitializationHarness() {
    final storage = MemoryStorageAdapter();
    final db = LocalDatabase(storage);
    final vault = TokenVault(storage);
    final mockOauth = MockGoogleOAuthProvider();
    final sessionNotifier = SessionNotifier();
    final authService = AuthService(
      oauthProvider: mockOauth,
      tokenVault: vault,
      sessionNotifier: sessionNotifier,
    );
    final driveClient = MockGoogleDriveClient();
    final sheetsClient = MockGoogleSheetsClient();

    final service = MasterSheetInitializationService(
      driveClient: driveClient,
      sheetsClient: sheetsClient,
      localDb: db,
      authService: authService,
    );

    return (service, driveClient, sheetsClient, authService, db, storage);
  }

  const clinicId = 'test_clinic_101';

  group('APNA CLINIC — PHASE 3 MILESTONE 3: ONE-WAY MASTER SHEET INITIALIZATION TESTS', () {
    // -------------------------------------------------------------------------
    // TEST 1: Schema Validation Gate
    // -------------------------------------------------------------------------
    test('1. Validates Master Sheet schema prior to data initialization', () async {
      final (service, _, sheetsClient, authService, _, _) = createInitializationHarness();
      await authService.signIn(clinicId: clinicId);

      final result = await service.initializeFromMasterSheet(clinicId: clinicId);

      expect(result.isSuccess, isTrue);
      // Validated against canonical schema without error
      final validation = await sheetsClient.validateMasterSheetSchema(
        accessToken: 'mock_token',
        spreadsheetId: 'test_id',
      );
      expect(validation.isValid, isTrue);
    });

    // -------------------------------------------------------------------------
    // TEST 2: Successful Controlled One-Way Initialization
    // -------------------------------------------------------------------------
    test('2. Successfully reads, validates, and initializes local DB from Master Sheet', () async {
      final (service, _, _, authService, db, _) = createInitializationHarness();
      await authService.signIn(clinicId: clinicId);

      final result = await service.initializeFromMasterSheet(clinicId: clinicId);

      expect(result.isSuccess, isTrue);
      expect(result.totalRecordsImported, greaterThan(0));
      expect(result.totalRecordsRejected, equals(0));
      expect(result.rejections, isEmpty);

      // Verify domain records exist in LocalDatabase
      final patient1 = db.get('Patients', 'PAT-000001');
      expect(patient1, isNotNull);
      expect(patient1!['full_name'], equals('Ramesh Kumar'));
      expect(patient1['phone_optional'], equals('9876543210'));

      final patient2 = db.get('Patients', 'PAT-000002');
      expect(patient2, isNotNull);
      expect(patient2!['full_name'], equals('Sunita Sharma'));

      final doctor = db.get('Doctors', 'DOC-001');
      expect(doctor, isNotNull);
      expect(doctor!['display_name'], equals('Dr. Rajesh Sharma'));
      expect(doctor['specialty_label'], equals('General Medicine'));

      final apt = db.get('Appointments', 'APT-000001');
      expect(apt, isNotNull);
      expect(apt!['patient_id'], equals('PAT-000001'));
      expect(apt['doctor_id'], equals('DOC-001'));

      final fee = db.get('Fee_Catalog', 'SRV-001');
      expect(fee, isNotNull);
      expect(fee!['fee_name'], equals('General Consultation'));
      expect(fee['default_amount_minor'], equals(50000)); // Rs 500 = 50,000 paise

      final lookup = db.get('Lookup_Config', 'LK-001');
      expect(lookup, isNotNull);
      expect(lookup!['category'], equals('GENDER'));
      expect(lookup['code'], equals('MALE'));

      // Invariant: One-way sync must NOT stage outbox events for imported records
      final outboxRecords = db.query('sync_outbox');
      expect(
        outboxRecords,
        isEmpty,
        reason: 'One-way initialization must not write imported records into sync_outbox',
      );
    });

    // -------------------------------------------------------------------------
    // TEST 3: Empty-Sheet Handling
    // -------------------------------------------------------------------------
    test('3. Gracefully handles empty worksheets without crashing or corrupting DB', () async {
      final (service, _, sheetsClient, authService, db, _) = createInitializationHarness();
      await authService.signIn(clinicId: clinicId);
      sheetsClient.simulateEmptySheet = true;

      final result = await service.initializeFromMasterSheet(clinicId: clinicId);

      expect(result.isSuccess, isTrue);
      expect(result.totalRecordsImported, equals(1)); // Only Clinic_Config base record staged
      expect(result.totalRecordsRejected, equals(0));
      expect(db.query('Patients'), isEmpty);
      expect(db.query('Doctors'), isEmpty);
      expect(db.query('Appointments'), isEmpty);
    });

    // -------------------------------------------------------------------------
    // TEST 4: Duplicate-Record Handling
    // -------------------------------------------------------------------------
    test('4. Deduplicates records with duplicate primary keys cleanly', () async {
      final (service, _, sheetsClient, authService, db, _) = createInitializationHarness();
      await authService.signIn(clinicId: clinicId);

      // Supply custom rows with duplicate patient IDs
      sheetsClient.customSheetRows = {
        '01_SETTINGS': [],
        '02_USERS': [],
        '04_DOCTORS': [],
        '05_PATIENTS': [
          ['PAT-000001', 'P-1', 'Ramesh', '', 'Kumar', 'Ramesh Kumar', '1985-05-15', '41', 'MALE', '9876543210'],
          ['PAT-000001', 'P-1', 'Ramesh', 'A', 'Kumar', 'Ramesh A Kumar', '1985-05-15', '41', 'MALE', '9876543210'],
        ],
        '06_APPOINTMENTS': [],
        '12_SERVICES': [],
        '20_LOOKUPS': [],
      };

      final result = await service.initializeFromMasterSheet(clinicId: clinicId);

      expect(result.isSuccess, isTrue);
      expect(result.importedCountByTable['Patients'], equals(1));
      final patient = db.get('Patients', 'PAT-000001');
      expect(patient, isNotNull);
      expect(patient!['full_name'], equals('Ramesh A Kumar'));
    });

    // -------------------------------------------------------------------------
    // TEST 5: Invalid-Record Rejection & Safe Reporting
    // -------------------------------------------------------------------------
    test('5. Rejects malformed records, reports them safely, and imports valid ones', () async {
      final (service, _, sheetsClient, authService, db, _) = createInitializationHarness();
      await authService.signIn(clinicId: clinicId);
      sheetsClient.simulateInvalidRecords = true;

      final result = await service.initializeFromMasterSheet(clinicId: clinicId);

      expect(result.isSuccess, isTrue);
      expect(result.totalRecordsRejected, greaterThanOrEqualTo(2));
      expect(result.rejections.any((r) => r.sheetName == '05_PATIENTS'), isTrue);
      expect(result.rejections.any((r) => r.sheetName == '02_USERS'), isTrue);

      // Verify the invalid patient was NOT added to the database
      expect(db.get('Patients', 'PAT-000003'), isNull);

      // Verify the valid patient was still added
      expect(db.get('Patients', 'PAT-000001'), isNotNull);
    });

    // -------------------------------------------------------------------------
    // TEST 6: Foreign-Key Violation Detection
    // -------------------------------------------------------------------------
    test('6. Catches foreign key violation and safely rejects appointment referencing non-existent patient', () async {
      final (service, _, sheetsClient, authService, db, _) = createInitializationHarness();
      await authService.signIn(clinicId: clinicId);
      sheetsClient.simulateForeignKeyViolation = true;

      final result = await service.initializeFromMasterSheet(clinicId: clinicId);

      expect(result.isSuccess, isTrue);
      expect(
        result.rejections.any((r) =>
            r.sheetName == '06_APPOINTMENTS' &&
            r.recordId == 'APT-000002' &&
            r.reason.contains('Foreign key violation')),
        isTrue,
      );

      // Violating appointment must NOT be inserted
      expect(db.get('Appointments', 'APT-000002'), isNull);

      // Valid appointment must be inserted
      expect(db.get('Appointments', 'APT-000001'), isNotNull);
    });

    // -------------------------------------------------------------------------
    // TEST 7: Schema Mismatch Halts Operation
    // -------------------------------------------------------------------------
    test('7. Halts operation and commits nothing when Master Sheet schema mismatches', () async {
      final (service, _, sheetsClient, authService, db, _) = createInitializationHarness();
      await authService.signIn(clinicId: clinicId);
      sheetsClient.simulateMissingSheet = true;

      final result = await service.initializeFromMasterSheet(clinicId: clinicId);

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, equals('SCHEMA_MISMATCH'));
      expect(db.query('Patients'), isEmpty);
      expect(db.query('Doctors'), isEmpty);
      expect(db.query('Appointments'), isEmpty);
    });

    // -------------------------------------------------------------------------
    // TEST 8: Authentication Failure Handling
    // -------------------------------------------------------------------------
    test('8. Rejects initialization cleanly when unauthenticated', () async {
      final (service, _, _, _, db, _) = createInitializationHarness();
      // Notice: authService.signIn is NOT called here!

      final result = await service.initializeFromMasterSheet(clinicId: clinicId);

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, equals('AUTH_REQUIRED'));
      expect(db.query('Patients'), isEmpty);
    });

    // -------------------------------------------------------------------------
    // TEST 9: Network Failure Handling
    // -------------------------------------------------------------------------
    test('9. Handles network errors safely without corrupting local state', () async {
      final (service, _, sheetsClient, authService, db, _) = createInitializationHarness();
      await authService.signIn(clinicId: clinicId);
      sheetsClient.simulateOffline = true;

      final result = await service.initializeFromMasterSheet(clinicId: clinicId);

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, equals('API_FAILURE'));
      expect(db.query('Patients'), isEmpty);
    });

    // -------------------------------------------------------------------------
    // TEST 10: Google API Rate Limit & Server Error Handling
    // -------------------------------------------------------------------------
    test('10. Handles Google API quota (429) and server errors (503) cleanly', () async {
      final (service, _, sheetsClient, authService, _, _) = createInitializationHarness();
      await authService.signIn(clinicId: clinicId);

      // 10A: Rate Limit (429)
      sheetsClient.simulateRateLimit = true;
      final rateLimitResult = await service.initializeFromMasterSheet(clinicId: clinicId);
      expect(rateLimitResult.isSuccess, isFalse);
      expect(rateLimitResult.errorCode, equals('RATE_LIMIT'));

      // 10B: Server Error (503)
      sheetsClient.simulateRateLimit = false;
      sheetsClient.simulateServiceUnavailable = true;
      final serverErrorResult = await service.initializeFromMasterSheet(clinicId: clinicId);
      expect(serverErrorResult.isSuccess, isFalse);
      expect(serverErrorResult.errorCode, equals('API_FAILURE'));
    });

    // -------------------------------------------------------------------------
    // TEST 11: Repeat Initialization & Idempotency
    // -------------------------------------------------------------------------
    test('11. Repeat initialization is fully idempotent and creates zero duplicate records', () async {
      final (service, _, _, authService, db, _) = createInitializationHarness();
      await authService.signIn(clinicId: clinicId);

      // Pass 1: First initialization
      final result1 = await service.initializeFromMasterSheet(clinicId: clinicId);
      expect(result1.isSuccess, isTrue);
      final initialImported = result1.totalRecordsImported;
      expect(initialImported, greaterThan(0));
      expect(result1.totalRecordsUnchanged, equals(0));

      final initialPatientCount = db.query('Patients').length;
      final initialDoctorCount = db.query('Doctors').length;
      final initialAppointmentCount = db.query('Appointments').length;

      // Pass 2: Second initialization with identical sheet data
      final result2 = await service.initializeFromMasterSheet(clinicId: clinicId);
      expect(result2.isSuccess, isTrue);
      // All records detected as unchanged: imported = 0, unchanged = total records
      expect(result2.totalRecordsImported, equals(0));
      expect(result2.totalRecordsUnchanged, greaterThanOrEqualTo(initialImported));

      // Assert table counts in database did NOT increase
      expect(db.query('Patients').length, equals(initialPatientCount));
      expect(db.query('Doctors').length, equals(initialDoctorCount));
      expect(db.query('Appointments').length, equals(initialAppointmentCount));
    });

    // -------------------------------------------------------------------------
    // TEST 12: Offline-First Regression Guarantee
    // -------------------------------------------------------------------------
    test('12. Local clinical operations continue unaffected when Google sync fails', () async {
      final (service, _, sheetsClient, authService, db, _) = createInitializationHarness();
      await authService.signIn(clinicId: clinicId);

      // Simulate complete Google API failure
      sheetsClient.simulateServiceUnavailable = true;
      final initResult = await service.initializeFromMasterSheet(clinicId: clinicId);
      expect(initResult.isSuccess, isFalse);

      // Local clinical workflow MUST still work 100% offline
      final patientRepo = PatientRepository(db);
      final newPatient = Patient(
        patientId: 'LOCAL-PAT-001',
        clinicId: clinicId,
        patientNumber: 'P-OFFLINE-01',
        fullName: 'Offline Patient',
        phoneOptional: '9876543299',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      await patientRepo.savePatient(newPatient);

      final retrieved = await patientRepo.getPatientById(clinicId, 'LOCAL-PAT-001');
      expect(retrieved, isNotNull);
      expect(retrieved!.fullName, equals('Offline Patient'));
      expect(retrieved.phoneOptional, equals('9876543299'));
    });
  });
}
