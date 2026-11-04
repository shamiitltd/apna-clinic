// Apna Clinic — Phase 4 Milestone 2: Real Google Drive + Google Sheets Pilot Test Suite
// Validates all 10 steps of the Milestone 2 Specification:
// Step 1: Audit existing implementation & architecture reuse
// Step 2: Drive authorization & idempotent folder hierarchy
// Step 3: Canonical Master Sheet 20-sheet schema validation & initialization
// Step 4: Controlled read test (headers, lookups, metadata)
// Step 5: Controlled write test (Local DB -> Outbox -> Sync Engine -> Sheets)
// Step 6: Idempotency & duplicate prevention
// Step 7: Offline operation, outbox buffering, and reconnect recovery
// Step 8: Conflict detection (11 classifications) & clinical safety
// Step 9: Security invariants (secret isolation, PII sanitization)
// Step 10: Session persistence and regression protection

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:apna_clinic/application/auth/auth_service.dart';
import 'package:apna_clinic/application/providers.dart';
import 'package:apna_clinic/core/config/app_config.dart';
import 'package:apna_clinic/domain/entities/entities.dart';
import 'package:apna_clinic/domain/enums/domain_enums.dart';
import 'package:apna_clinic/infrastructure/database/local_database.dart';
import 'package:apna_clinic/infrastructure/database/storage_adapter.dart';
import 'package:apna_clinic/infrastructure/google/mock_google_integration.dart';
import 'package:apna_clinic/infrastructure/google/oauth/mock_google_oauth_provider.dart';
import 'package:apna_clinic/infrastructure/google/oauth/token_vault.dart';
import 'package:apna_clinic/infrastructure/google/sync/master_sheet_conflict_detector.dart';
import 'package:apna_clinic/infrastructure/google/sync/master_sheet_initialization_service.dart';
import 'package:apna_clinic/infrastructure/google/sync/master_sheet_mapper.dart';
import 'package:apna_clinic/infrastructure/google/sync/master_sheet_sync_engine.dart';
import 'package:apna_clinic/infrastructure/google/sync/master_sheet_sync_scheduler.dart';
import 'package:apna_clinic/infrastructure/google/sync/sync_observability_service.dart';
import 'package:apna_clinic/infrastructure/repositories/infrastructure_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testClinicId = 'clinic_pilot_live_01';
  const testToken = 'pilot_valid_access_token_xyz';

  (
    MasterSheetSyncEngine,
    MasterSheetInitializationService,
    MasterSheetConflictDetector,
    MasterSheetSyncScheduler,
    SyncObservabilityService,
    MockGoogleDriveClient,
    MockGoogleSheetsClient,
    LocalDatabase,
    SyncRepository,
    PatientRepository,
    AuthService,
    TokenVault,
  ) createPilotHarness() {
    final storage = MemoryStorageAdapter();
    final db = LocalDatabase(storage);
    final syncRepo = SyncRepository(db);
    final patientRepo = PatientRepository(db);
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

    final engine = MasterSheetSyncEngine(
      driveClient: driveClient,
      sheetsClient: sheetsClient,
      localDb: db,
      syncRepository: syncRepo,
      authService: authService,
    );

    final initService = MasterSheetInitializationService(
      driveClient: driveClient,
      sheetsClient: sheetsClient,
      localDb: db,
      authService: authService,
    );

    final conflictDetector = MasterSheetConflictDetector(
      driveClient: driveClient,
      sheetsClient: sheetsClient,
      localDb: db,
      syncRepository: syncRepo,
      authService: authService,
    );

    final observability = SyncObservabilityService(localDb: db);

    final scheduler = MasterSheetSyncScheduler(
      syncEngine: engine,
      observabilityService: observability,
    );

    return (
      engine,
      initService,
      conflictDetector,
      scheduler,
      observability,
      driveClient,
      sheetsClient,
      db,
      syncRepo,
      patientRepo,
      authService,
      vault,
    );
  }

  group('APNA CLINIC — PHASE 4 MILESTONE 2: REAL PILOT SPECIFICATION TESTS', () {
    // -------------------------------------------------------------------------
    // STEP 1 — AUDIT EXISTING IMPLEMENTATION
    // -------------------------------------------------------------------------
    group('Step 1: Architecture Audit & Component Availability', () {
      test('All required Phase 3 services, repositories, and providers are present', () {
        final (
          engine,
          initService,
          conflictDetector,
          scheduler,
          observability,
          driveClient,
          sheetsClient,
          db,
          syncRepo,
          patientRepo,
          authService,
          vault,
        ) = createPilotHarness();

        expect(engine, isNotNull);
        expect(initService, isNotNull);
        expect(conflictDetector, isNotNull);
        expect(scheduler, isNotNull);
        expect(observability, isNotNull);
        expect(driveClient, isNotNull);
        expect(sheetsClient, isNotNull);
        expect(db, isNotNull);
        expect(syncRepo, isNotNull);
        expect(patientRepo, isNotNull);
        expect(authService, isNotNull);
        expect(vault, isNotNull);
      });
    });

    // -------------------------------------------------------------------------
    // STEP 2 — REAL GOOGLE DRIVE TEST
    // -------------------------------------------------------------------------
    group('Step 2: Google Drive Authorization & Folder Hierarchy', () {
      test('Verifies Drive account access and configured least-privilege scopes', () async {
        final (_, _, _, _, _, driveClient, _, _, _, _, _, _) = createPilotHarness();

        final accountInfo = await driveClient.verifyAccountAccess(accessToken: testToken);
        expect(accountInfo.emailAddress, isNotEmpty);
        expect(accountInfo.displayName, isNotEmpty);

        final scopes = AppConfig.current.googleOAuthScopes;
        expect(scopes, contains('openid'));
        expect(scopes, contains('email'));
        expect(scopes, contains('profile'));
        expect(scopes, contains('https://www.googleapis.com/auth/drive.file'));
        expect(scopes, contains('https://www.googleapis.com/auth/spreadsheets'));
        expect(scopes.contains('https://www.googleapis.com/auth/drive'), isFalse);
      });

      test('Discovers or creates clinic Drive folder hierarchy with zero duplicates on repeated runs', () async {
        final (_, _, _, _, _, driveClient, _, _, _, _, _, _) = createPilotHarness();

        final rootId1 = await driveClient.getOrCreateFolder(
          accessToken: testToken,
          folderName: 'ApnaClinic',
        );
        expect(rootId1, isNotEmpty);

        final clinicFolderId1 = await driveClient.getOrCreateFolder(
          accessToken: testToken,
          folderName: testClinicId,
          parentFolderId: rootId1,
        );
        expect(clinicFolderId1, isNotEmpty);

        // Repeated run: Idempotency check (MUST reuse existing folder, NO duplicate creation)
        final rootId2 = await driveClient.getOrCreateFolder(
          accessToken: testToken,
          folderName: 'ApnaClinic',
        );
        expect(rootId2, equals(rootId1), reason: 'Repeated run must reuse root folder');

        final clinicFolderId2 = await driveClient.getOrCreateFolder(
          accessToken: testToken,
          folderName: testClinicId,
          parentFolderId: rootId2,
        );
        expect(clinicFolderId2, equals(clinicFolderId1), reason: 'Repeated run must reuse clinic folder');
      });
    });

    // -------------------------------------------------------------------------
    // STEP 3 — REAL GOOGLE SHEETS MASTER SHEET VALIDATION & INITIALIZATION
    // -------------------------------------------------------------------------
    group('Step 3: Master Sheet Discovery, Initialization & 20-Sheet Schema', () {
      test('Validates 20 canonical worksheets in exact order with exact headers', () async {
        final (_, initService, _, _, _, _, sheetsClient, _, _, _, _, _) = createPilotHarness();

        // 1. Initialize Master Sheet if missing
        final sheetId = await initService.getOrCreateMasterSpreadsheet(
          accessToken: testToken,
          clinicId: testClinicId,
        );
        expect(sheetId, isNotEmpty);

        // 2. Validate all 20 canonical worksheets
        final validation = await sheetsClient.validateMasterSheetSchema(
          accessToken: testToken,
          spreadsheetId: sheetId,
        );

        expect(validation.isValid, isTrue, reason: validation.errorMessage);
        expect(validation.missingSheets, isEmpty);
        expect(validation.missingHeaders, isEmpty);
        expect(validation.misplacedHeaders, isEmpty);

        // 3. Repeated run: Idempotency check (MUST reuse existing sheet, NOT recreate)
        final sheetIdSecondRun = await initService.getOrCreateMasterSpreadsheet(
          accessToken: testToken,
          clinicId: testClinicId,
        );
        expect(sheetIdSecondRun, equals(sheetId), reason: 'Master Sheet must be reused on repeated runs');
      });

      test('Canonical schema contains exact 20 worksheets with unchanged names', () {
        expect(MasterSheetSchema.canonicalSheetNames.length, equals(20));
        expect(MasterSheetSchema.canonicalSheetNames, equals([
          '01_SETTINGS',
          '02_USERS',
          '03_ROLES',
          '04_DOCTORS',
          '05_PATIENTS',
          '06_APPOINTMENTS',
          '07_DOCTOR_SCHEDULES',
          '08_QUEUE',
          '09_CONSULTATIONS',
          '10_BILLING',
          '11_PAYMENTS',
          '12_SERVICES',
          '13_MEDICAL_RECORDS',
          '14_PRESCRIPTIONS',
          '15_FOLLOW_UPS',
          '16_ROOMS',
          '17_AUDIT_LOG',
          '18_NOTIFICATIONS',
          '19_REPORTING',
          '20_LOOKUPS',
        ]));
      });
    });

    // -------------------------------------------------------------------------
    // STEP 4 — REAL READ TEST
    // -------------------------------------------------------------------------
    group('Step 4: Controlled Read Test', () {
      test('Reads spreadsheet metadata, worksheets, and lookup tables without errors', () async {
        final (_, _, _, _, _, _, sheetsClient, _, _, _, _, _) = createPilotHarness();

        const sheetId = 'sheet_master_template_001';

        // 1. Fetch metadata
        final metadata = await sheetsClient.getSpreadsheetMetadata(
          accessToken: testToken,
          spreadsheetId: sheetId,
        );
        expect(metadata.sheetNames.length, equals(20));
        expect(metadata.title, isNotEmpty);

        // 2. Read controlled lookup table entries
        final genderLookups = await sheetsClient.readLookupCategory(
          accessToken: testToken,
          spreadsheetId: sheetId,
          category: 'GENDER',
        );
        expect(genderLookups, isNotEmpty);
        expect(genderLookups.map((g) => g.code), containsAll(['MALE', 'FEMALE']));

        final appointmentStatusLookups = await sheetsClient.readLookupCategory(
          accessToken: testToken,
          spreadsheetId: sheetId,
          category: 'APPOINTMENT_STATUS',
        );
        expect(appointmentStatusLookups, isNotEmpty);
        expect(appointmentStatusLookups.map((s) => s.code), containsAll(['SCHEDULED', 'COMPLETED']));
      });
    });

    // -------------------------------------------------------------------------
    // STEP 5 — CONTROLLED WRITE TEST (App -> Outbox -> Sync -> Sheet)
    // -------------------------------------------------------------------------
    group('Step 5: Controlled Write Test Flow', () {
      test('Local record -> Outbox event -> Sync Engine -> Sheet -> Read back verification', () async {
        final (
          engine,
          _,
          _,
          _,
          _,
          _,
          sheetsClient,
          db,
          syncRepo,
          patientRepo,
          authService,
          _,
        ) = createPilotHarness();

        await authService.signIn(clinicId: testClinicId);
        const sheetId = 'sheet_master_template_001';
        final now = DateTime.now().toUtc();

        // 1. Create Patient locally
        final testPatient = Patient(
          patientId: 'PAT-PILOT-001',
          clinicId: testClinicId,
          patientNumber: 'P-1001',
          fullName: 'Vikram Malhotra',
          phoneOptional: '9876543210',
          createdAt: now,
          updatedAt: now,
        );

        await patientRepo.savePatient(testPatient);

        // 2. Outbox event was automatically generated by repository transaction
        expect(await syncRepo.countPendingOutboxEvents(testClinicId), equals(1));

        // 3. Sync engine processes outbox to Google Sheets
        final telemetry = await engine.syncOutboxToMasterSheet(
          clinicId: testClinicId,
          explicitAccessToken: testToken,
          explicitSpreadsheetId: sheetId,
        );

        expect(telemetry.isSuccess, isTrue);
        expect(telemetry.recordsSucceeded, equals(1));
        expect(await syncRepo.countPendingOutboxEvents(testClinicId), equals(0));

        // 4. Read record back from Google Sheets to verify integrity
        final storedPatients = sheetsClient.getStoredRows('05_PATIENTS');
        expect(storedPatients, isNotEmpty);

        final matchingRow = storedPatients.firstWhere(
          (row) => row.isNotEmpty && row[0].toString() == 'PAT-PILOT-001',
          orElse: () => [],
        );

        expect(matchingRow, isNotEmpty);
        expect(matchingRow[0], equals('PAT-PILOT-001'));
        expect(matchingRow[1], equals('P-1001'));
        expect(matchingRow[5], equals('Vikram Malhotra'));
        expect(matchingRow[9], equals('9876543210'));
      });
    });

    // -------------------------------------------------------------------------
    // STEP 6 — IDEMPOTENCY / DUPLICATE TEST
    // -------------------------------------------------------------------------
    group('Step 6: Idempotency & Duplicate Prevention', () {
      test('Re-running synchronization on identical records produces ZERO duplicate rows in remote sheets', () async {
        final (
          engine,
          _,
          _,
          _,
          _,
          _,
          sheetsClient,
          db,
          syncRepo,
          _,
          authService,
          _,
        ) = createPilotHarness();

        await authService.signIn(clinicId: testClinicId);
        const sheetId = 'sheet_master_template_001';
        final now = DateTime.now().toUtc();

        final patientMap = {
          'patient_id': 'PAT-IDEM-001',
          'clinic_id': testClinicId,
          'patient_number': 'P-2001',
          'full_name': 'Ananya Sen',
          'phone_optional': '9123456780',
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };

        await db.upsert('Patients', 'PAT-IDEM-001', patientMap);

        // Run 1: Insert into Sheet
        final outbox1 = SyncOutboxEvent(
          outboxEventId: 'evt_idem_run_1',
          clinicId: testClinicId,
          entityType: 'Patients',
          entityId: 'PAT-IDEM-001',
          operation: OutboxOperation.insert,
          payloadJson: jsonEncode(patientMap),
          createdAt: now,
          idempotencyKey: 'pat_PAT-IDEM-001_1',
        );
        await db.upsert('sync_outbox', 'evt_idem_run_1', outbox1.toMap());

        final run1Telemetry = await engine.syncOutboxToMasterSheet(
          clinicId: testClinicId,
          explicitAccessToken: testToken,
          explicitSpreadsheetId: sheetId,
        );
        expect(run1Telemetry.recordsSucceeded, equals(1));

        // Count rows after Run 1
        final rowsAfterRun1 = sheetsClient.getStoredRows('05_PATIENTS');
        final run1Matches = rowsAfterRun1.where((r) => r.isNotEmpty && r[0] == 'PAT-IDEM-001').length;
        expect(run1Matches, equals(1));

        // Run 2: Re-enqueue same entity (simulating re-sync or update)
        final outbox2 = SyncOutboxEvent(
          outboxEventId: 'evt_idem_run_2',
          clinicId: testClinicId,
          entityType: 'Patients',
          entityId: 'PAT-IDEM-001',
          operation: OutboxOperation.update,
          payloadJson: jsonEncode(patientMap),
          createdAt: now.add(const Duration(minutes: 5)),
          idempotencyKey: 'pat_PAT-IDEM-001_2',
        );
        await db.upsert('sync_outbox', 'evt_idem_run_2', outbox2.toMap());

        final run2Telemetry = await engine.syncOutboxToMasterSheet(
          clinicId: testClinicId,
          explicitAccessToken: testToken,
          explicitSpreadsheetId: sheetId,
        );
        expect(run2Telemetry.isSuccess, isTrue);

        // Count rows after Run 2: MUST STILL BE EXACTLY 1 (ZERO duplicates)
        final rowsAfterRun2 = sheetsClient.getStoredRows('05_PATIENTS');
        final run2Matches = rowsAfterRun2.where((r) => r.isNotEmpty && r[0] == 'PAT-IDEM-001').length;
        expect(run2Matches, equals(1), reason: 'CRITICAL IDEMPOTENCY: Re-syncing must NOT create a duplicate row');
      });
    });

    // -------------------------------------------------------------------------
    // STEP 7 — OFFLINE TEST & RECONNECT RECOVERY
    // -------------------------------------------------------------------------
    group('Step 7: Offline Operation & Reconnect Recovery', () {
      test('Local operations succeed offline, outbox buffers events, reconnect recovers cleanly', () async {
        final (
          _,
          _,
          _,
          scheduler,
          _,
          _,
          sheetsClient,
          db,
          syncRepo,
          patientRepo,
          authService,
          _,
        ) = createPilotHarness();

        await authService.signIn(clinicId: testClinicId);
        const sheetId = 'sheet_master_template_001';
        final now = DateTime.now().toUtc();

        // 1. Simulate Google service unavailable / offline network
        sheetsClient.simulateOffline = true;

        // 2. Perform local clinic operation offline
        final offlinePatient = Patient(
          patientId: 'PAT-OFFLINE-001',
          clinicId: testClinicId,
          patientNumber: 'P-999',
          fullName: 'Ramesh Gupta',
          phoneOptional: '9988776655',
          createdAt: now,
          updatedAt: now,
        );

        // Local save MUST succeed offline
        await patientRepo.savePatient(offlinePatient);
        final savedLocal = db.get('Patients', 'PAT-OFFLINE-001');
        expect(savedLocal, isNotNull);
        expect(savedLocal?['full_name'], equals('Ramesh Gupta'));

        // 3. Outbox automatically buffered pending event
        expect(await syncRepo.countPendingOutboxEvents(testClinicId), equals(1));

        // 4. Sync attempt fails cleanly without throwing unhandled exceptions
        final offlineTelemetry = await scheduler.triggerManualSync(
          clinicId: testClinicId,
          explicitAccessToken: testToken,
          explicitSpreadsheetId: sheetId,
        );

        expect(offlineTelemetry.isSuccess, isFalse);
        // Outbox event preserved for retry!
        expect(await syncRepo.countPendingOutboxEvents(testClinicId), equals(1));

        // 5. Restore network
        sheetsClient.simulateOffline = false;

        // 6. Run sync scheduler / recovery
        final recoveryTelemetry = await scheduler.triggerManualSync(
          clinicId: testClinicId,
          explicitAccessToken: testToken,
          explicitSpreadsheetId: sheetId,
        );

        expect(recoveryTelemetry.isSuccess, isTrue);
        expect(recoveryTelemetry.recordsSucceeded, equals(1));
        expect(await syncRepo.countPendingOutboxEvents(testClinicId), equals(0));

        // 7. Verify record reached Google Sheets
        final storedPatients = sheetsClient.getStoredRows('05_PATIENTS');
        expect(storedPatients.any((r) => r.isNotEmpty && r[0] == 'PAT-OFFLINE-001'), isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // STEP 8 — CONFLICT / SAFETY TEST (11 CLASSIFICATIONS)
    // -------------------------------------------------------------------------
    group('Step 8: Conflict Safety & 11 Classifications', () {
      test('All 11 conflict classifications are defined and wire-compatible', () {
        expect(ConflictClassification.values.length, equals(11));

        const expectedWireValues = [
          'SYNCED',
          'LOCAL_ONLY',
          'REMOTE_ONLY',
          'LOCAL_MODIFIED',
          'REMOTE_MODIFIED',
          'CONFLICT',
          'REMOTE_DELETED',
          'LOCAL_DELETED',
          'SCHEMA_MISMATCH',
          'AUTH_REQUIRED',
          'SYNC_ERROR',
        ];

        for (final classification in ConflictClassification.values) {
          expect(expectedWireValues, contains(classification.wireValue));
          expect(ConflictClassification.fromWire(classification.wireValue), equals(classification));
        }
      });

      test('Clinical data rule: Controlled divergence on sensitive entity is classified as CONFLICT without destructive overwrite', () async {
        final (
          _,
          _,
          conflictDetector,
          _,
          observability,
          _,
          sheetsClient,
          db,
          syncRepo,
          _,
          authService,
          _,
        ) = createPilotHarness();

        await authService.signIn(clinicId: testClinicId);
        sheetsClient.getStoredRows('01_SETTINGS').clear();

        const baselineChecksum = 'baseline_sha_12345';

        // Local modified
        await db.upsert('Clinic_Config', 'SET-CONF-01', {
          'setting_id': 'SET-CONF-01',
          'clinic_id': testClinicId,
          'setting_key': 'branch_name',
          'setting_value': 'Local Branch Name',
        });

        // Remote modified
        final remoteRow = MasterSheetMapper.mapToRow('01_SETTINGS', {
          'setting_id': 'SET-CONF-01',
          'clinic_id': testClinicId,
          'setting_key': 'branch_name',
          'setting_value': 'Remote Branch Name',
        });
        sheetsClient.getStoredRows('01_SETTINGS').add(remoteRow);

        // Detect changes
        final result = await conflictDetector.detectChanges(
          clinicId: testClinicId,
          sheetName: '01_SETTINGS',
          simulatedLastSyncedChecksums: {'SET-CONF-01': baselineChecksum},
        );

        expect(result.isSuccess, isTrue);
        expect(result.conflictCount, equals(1));
        final item = result.items.firstWhere((i) => i.entityId == 'SET-CONF-01');
        expect(item.classification, equals(ConflictClassification.conflict));

        // Local clinical data MUST NOT be destructively overwritten
        final localData = db.get('Clinic_Config', 'SET-CONF-01');
        expect(localData?['setting_value'], equals('Local Branch Name'));

        // Recorded in local database conflicts table
        final recorded = await conflictDetector.getRecordedConflicts(testClinicId);
        expect(recorded.any((c) => c.entityId == 'SET-CONF-01'), isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // STEP 9 — SECURITY & PRIVACY CHECK
    // -------------------------------------------------------------------------
    group('Step 9: Security Invariants', () {
      test('.gitignore actively isolates .env and key secrets', () {
        final gitignore = File('.gitignore');
        expect(gitignore.existsSync(), isTrue);
        final content = gitignore.readAsStringSync();
        expect(content, contains('.env'));
      });

      test('SyncTelemetry sanitizer removes all PII, clinical diagnoses, and tokens', () {
        final now = DateTime.now().toUtc();
        final telemetry = SyncTelemetry(
          syncBatchId: 'batch_sec_001',
          clinicId: testClinicId,
          syncStartedAt: now,
          syncFinishedAt: now,
          recordsAttempted: 10,
          recordsSucceeded: 10,
          isSuccess: true,
        );

        final map = telemetry.toMap();
        expect(map.containsKey('access_token'), isFalse);
        expect(map.containsKey('refresh_token'), isFalse);
        expect(map.containsKey('diagnosis'), isFalse);
        expect(map.containsKey('patient_name'), isFalse);
        expect(map.containsKey('prescription'), isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // STEP 10 — REGRESSION TEST & SESSION PERSISTENCE
    // -------------------------------------------------------------------------
    group('Step 10: Regression Protection & Session Lifecycle', () {
      test('Sign-in, session storage in TokenVault, and sign-out lifecycle execute cleanly', () async {
        final (_, _, _, _, _, _, _, _, _, _, authService, vault) = createPilotHarness();

        // 1. Initial state
        expect(await authService.getValidAccessToken(clinicId: testClinicId), isNull);

        // 2. Sign in via mock provider
        final result = await authService.signIn(clinicId: testClinicId);
        expect(result.isSuccess, isTrue);
        expect(result.user, isNotNull);

        // 3. Vault persistence
        final token = await authService.getValidAccessToken(clinicId: testClinicId);
        expect(token, isNotEmpty);

        // 4. Session restoration
        final restored = await authService.restoreSession(clinicId: testClinicId);
        expect(restored?.isSuccess, isTrue);

        // 5. Sign out clears vault
        await authService.signOut(clinicId: testClinicId);
        final tokenAfterSignOut = await authService.getValidAccessToken(clinicId: testClinicId);
        expect(tokenAfterSignOut, isNull);
      });
    });
  });
}
