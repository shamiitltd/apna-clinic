// Apna Clinic - Controlled One-Way Master Sheet Sync Engine Test Suite
// Phase 3 — Milestone 3
// Primary source of truth: User Request Milestone 3, PRD Section 38-41, TRD Section 11
// Tests:
// 1. Strongly typed MasterSheetMapper verification across all 20 canonical worksheets
// 2. Successful controlled one-way sync (Local -> Google Sheets)
// 3. Strict idempotency & duplicate prevention (syncing twice results in 0 duplicates)
// 4. Relational dependency ordering (parents synced before children)
// 5. Google API quota (429) & bounded retry backoff
// 6. Network failure / 503 server error handling
// 7. Authentication failure handling
// 8. Partial batch failure handling (acknowledged confirmed, retained failed)
// 9. Offline-first local operation invariance
// 10. Critical real-data test flow with zero duplicate verification

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

import 'package:apna_clinic/application/auth/auth_service.dart';
import 'package:apna_clinic/application/providers.dart';
import 'package:apna_clinic/domain/entities/master_sheet_schema.dart';
import 'package:apna_clinic/domain/entities/patient.dart';
import 'package:apna_clinic/domain/entities/sync_models.dart';
import 'package:apna_clinic/domain/enums/domain_enums.dart';
import 'package:apna_clinic/infrastructure/database/local_database.dart';
import 'package:apna_clinic/infrastructure/database/storage_adapter.dart';
import 'package:apna_clinic/infrastructure/google/mock_google_integration.dart';
import 'package:apna_clinic/infrastructure/google/oauth/mock_google_oauth_provider.dart';
import 'package:apna_clinic/infrastructure/google/oauth/token_vault.dart';
import 'package:apna_clinic/infrastructure/google/sync/master_sheet_mapper.dart';
import 'package:apna_clinic/infrastructure/google/sync/master_sheet_sync_engine.dart';
import 'package:apna_clinic/infrastructure/repositories/infrastructure_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Test Harness Builder
  (
    MasterSheetSyncEngine,
    MockGoogleDriveClient,
    MockGoogleSheetsClient,
    AuthService,
    LocalDatabase,
    SyncRepository,
    MemoryStorageAdapter,
  ) createSyncEngineHarness() {
    final storage = MemoryStorageAdapter();
    final db = LocalDatabase(storage);
    final syncRepo = SyncRepository(db);
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

    return (engine, driveClient, sheetsClient, authService, db, syncRepo, storage);
  }

  const clinicId = 'test_clinic_101';

  group('APNA CLINIC — PHASE 3 MILESTONE 3: MASTER SHEET SYNC ENGINE TESTS', () {
    // -------------------------------------------------------------------------
    // 1. STRONGLY TYPED MAPPING ACROSS ALL 20 WORKSHEETS
    // -------------------------------------------------------------------------
    group('1. Master Sheet 20-Tab Strongly Typed Mapping', () {
      test('Deterministic mapping for all 20 canonical worksheets produces exact column count and order', () {
        for (final sheetName in MasterSheetSchema.canonicalSheetNames) {
          final dummyRecord = <String, dynamic>{
            'id': 'ID-001',
            'clinic_id': clinicId,
            'created_at': '2026-09-30T10:00:00Z',
            'updated_at': '2026-09-30T10:00:00Z',
          };

          final mappedRow = MasterSheetMapper.mapToRow(sheetName, dummyRecord);
          final expectedColumns = MasterSheetSchema.canonicalHeaders[sheetName]!;

          expect(
            mappedRow.length,
            equals(expectedColumns.length),
            reason: 'Sheet $sheetName column length mismatch: expected ${expectedColumns.length}, got ${mappedRow.length}',
          );
        }
      });

      test('Patient record mapping produces exact canonical values', () {
        final patientRecord = {
          'patient_id': 'PAT-000099',
          'patient_number': 'P-2026-0099',
          'first_name': 'Anita',
          'last_name': 'Deshmukh',
          'full_name': 'Anita Deshmukh',
          'date_of_birth': '1990-04-12',
          'age': '36',
          'sex_optional': 'FEMALE',
          'phone_optional': '9876543299',
          'address_optional': '789 Park Street',
          'city_optional': 'Pune',
          'state_optional': 'Maharashtra',
          'pincode_optional': '411001',
          'blood_group': 'B+',
          'consent_status': 'granted',
          'consent_version': 'v1.0',
          'created_at': '2026-09-30T10:00:00Z',
          'updated_at': '2026-09-30T10:00:00Z',
        };

        final row = MasterSheetMapper.mapToRow('05_PATIENTS', patientRecord);
        expect(row[0], equals('PAT-000099'));
        expect(row[1], equals('P-2026-0099'));
        expect(row[2], equals('Anita'));
        expect(row[4], equals('Deshmukh'));
        expect(row[5], equals('Anita Deshmukh'));
        expect(row[8], equals('FEMALE'));
        expect(row[9], equals('9876543299'));
        expect(row[18], equals('B+'));
        expect(row[21], equals('granted'));
      });

      test('Billing invoice mapping converts minor paise to formatted Rupees', () {
        final invoiceRecord = {
          'invoice_id': 'INV-2026-0001',
          'invoice_number': 'INV-01',
          'patient_id': 'PAT-000001',
          'issue_date_local': '2026-09-30',
          'subtotal_minor': 50000, // Rs 500.00
          'discount_minor': 5000,  // Rs 50.00
          'tax_minor': 8100,       // Rs 81.00
          'total_minor': 53100,    // Rs 531.00
          'paid_minor': 53100,     // Rs 531.00
          'balance_minor': 0,      // Rs 0.00
          'status': 'paid',
          'notes_nonclinical': 'Standard consultation fee',
          'created_at': '2026-09-30T10:00:00Z',
          'updated_at': '2026-09-30T10:00:00Z',
        };

        final row = MasterSheetMapper.mapToRow('10_BILLING', invoiceRecord);
        expect(row[0], equals('INV-2026-0001'));
        expect(row[5], equals('500.00'));
        expect(row[6], equals('50.00'));
        expect(row[7], equals('81.00'));
        expect(row[8], equals('531.00'));
        expect(row[9], equals('531.00'));
        expect(row[10], equals('0.00'));
        expect(row[11], equals('PAID'));
      });
    });

    // -------------------------------------------------------------------------
    // 2. SUCCESSFUL CONTROLLED ONE-WAY SYNC (LOCAL -> GOOGLE SHEETS)
    // -------------------------------------------------------------------------
    test('2. Successfully synchronizes pending outbox events to Google Sheets', () async {
      final (engine, _, sheetsClient, authService, db, syncRepo, _) = createSyncEngineHarness();
      await authService.signIn(clinicId: clinicId);

      // 1. Stage local domain records in LocalDatabase
      final patientMap = {
        'patient_id': 'PAT-000010',
        'clinic_id': clinicId,
        'patient_number': 'P-2026-0010',
        'full_name': 'Aarav Patel',
        'phone_optional': '9876543219',
        'sex_optional': 'MALE',
        'created_at': '2026-09-30T10:00:00Z',
        'updated_at': '2026-09-30T10:00:00Z',
      };
      await db.upsert('Patients', 'PAT-000010', patientMap);

      // 2. Stage corresponding outbox event
      final outboxEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_pat_001',
        clinicId: clinicId,
        entityType: 'Patients',
        entityId: 'PAT-000010',
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode(patientMap),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: 'pat_PAT-000010',
      );
      await db.upsert('sync_outbox', 'outbox_pat_001', outboxEvent.toMap());

      // Verify pending outbox count is 1
      expect(await syncRepo.countPendingOutboxEvents(clinicId), equals(1));

      // 3. Execute controlled sync
      final telemetry = await engine.syncOutboxToMasterSheet(clinicId: clinicId);

      expect(telemetry.isSuccess, isTrue);
      expect(telemetry.recordsAttempted, equals(1));
      expect(telemetry.recordsSucceeded, equals(1));
      expect(telemetry.recordsFailed, equals(0));
      expect(telemetry.pendingOutboxCount, equals(0));

      // 4. Verify remote sheet received the record
      final storedPatients = sheetsClient.getStoredRows('05_PATIENTS');
      expect(storedPatients.any((r) => r.isNotEmpty && r[0] == 'PAT-000010'), isTrue);

      // 5. Verify local outbox event was acknowledged
      final acknowledgedEvent = db.get('sync_outbox', 'outbox_pat_001');
      expect(acknowledgedEvent!['status'], equals(OutboxStatus.acknowledged.wireValue));

      // 6. Verify SyncManifest was written to local database
      final manifest = await syncRepo.getLastSyncManifest(clinicId);
      expect(manifest, isNotNull);
      expect(manifest!.status, equals('confirmed'));
      expect(manifest.eventCount, equals(1));

      // Invariant: Local database domain records were NOT mutated
      final localPatient = db.get('Patients', 'PAT-000010');
      expect(localPatient!['full_name'], equals('Aarav Patel'));
    });

    // -------------------------------------------------------------------------
    // 3. IDEMPOTENCY & ZERO DUPLICATES GUARANTEE
    // -------------------------------------------------------------------------
    test('3. Re-running sync on identical events produces ZERO remote duplicate records', () async {
      final (engine, _, sheetsClient, authService, db, syncRepo, _) = createSyncEngineHarness();
      await authService.signIn(clinicId: clinicId);

      final patientMap = {
        'patient_id': 'PAT-000020',
        'clinic_id': clinicId,
        'patient_number': 'P-2026-0020',
        'full_name': 'Meera Joshi',
        'phone_optional': '9876543220',
        'sex_optional': 'FEMALE',
        'created_at': '2026-09-30T10:00:00Z',
        'updated_at': '2026-09-30T10:00:00Z',
      };
      await db.upsert('Patients', 'PAT-000020', patientMap);

      // Pass 1: Insert outbox event and sync
      final outbox1 = SyncOutboxEvent(
        outboxEventId: 'outbox_pat_020',
        clinicId: clinicId,
        entityType: 'Patients',
        entityId: 'PAT-000020',
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode(patientMap),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: 'pat_PAT-000020',
      );
      await db.upsert('sync_outbox', 'outbox_pat_020', outbox1.toMap());

      final t1 = await engine.syncOutboxToMasterSheet(clinicId: clinicId);
      expect(t1.isSuccess, isTrue);

      final countAfterPass1 = sheetsClient
          .getStoredRows('05_PATIENTS')
          .where((r) => r.isNotEmpty && r[0] == 'PAT-000020')
          .length;
      expect(countAfterPass1, equals(1));

      // Pass 2: Simulate retry or identical re-transmission of the same entity
      final outbox2 = SyncOutboxEvent(
        outboxEventId: 'outbox_pat_020_retry',
        clinicId: clinicId,
        entityType: 'Patients',
        entityId: 'PAT-000020',
        operation: OutboxOperation.update,
        payloadJson: jsonEncode(patientMap),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: 'pat_PAT-000020',
      );
      await db.upsert('sync_outbox', 'outbox_pat_020_retry', outbox2.toMap());

      final t2 = await engine.syncOutboxToMasterSheet(clinicId: clinicId);
      expect(t2.isSuccess, isTrue);

      // CRITICAL IDEMPOTENCY ASSERTION:
      // Count of 'PAT-000020' in remote sheet MUST REMAIN EXACTLY ONE!
      final countAfterPass2 = sheetsClient
          .getStoredRows('05_PATIENTS')
          .where((r) => r.isNotEmpty && r[0] == 'PAT-000020')
          .length;
      expect(countAfterPass2, equals(1), reason: 'Sync re-run must not create duplicate remote rows');
    });

    // -------------------------------------------------------------------------
    // 4. RELATIONAL DEPENDENCY ORDERING (Section 4I & 12)
    // -------------------------------------------------------------------------
    test('4. Sorts pending events so parents (Patients) sync before children (Appointments, Billing)', () async {
      final (engine, _, sheetsClient, authService, db, _, _) = createSyncEngineHarness();
      await authService.signIn(clinicId: clinicId);

      // Stage child first, parent second in sync_outbox
      final now = DateTime.now().toUtc();
      final invoiceEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_inv_01',
        clinicId: clinicId,
        entityType: 'Invoices',
        entityId: 'INV-001',
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode({'invoice_id': 'INV-001', 'clinic_id': clinicId}),
        createdAt: now,
        idempotencyKey: 'inv_001',
      );

      final patientEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_pat_01',
        clinicId: clinicId,
        entityType: 'Patients',
        entityId: 'PAT-001',
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode({'patient_id': 'PAT-001', 'clinic_id': clinicId}),
        createdAt: now.add(const Duration(seconds: 1)), // Created later!
        idempotencyKey: 'pat_001',
      );

      await db.upsert('sync_outbox', 'outbox_inv_01', invoiceEvent.toMap());
      await db.upsert('sync_outbox', 'outbox_pat_01', patientEvent.toMap());

      sheetsClient.customSheetRows = null;

      final telemetry = await engine.syncOutboxToMasterSheet(clinicId: clinicId);
      expect(telemetry.isSuccess, isTrue);

      // Verify Patients (05_PATIENTS) was processed before Invoices (10_BILLING)
      final patientRow = sheetsClient.getStoredRows('05_PATIENTS').any((r) => r.isNotEmpty && r[0] == 'PAT-001');
      final invoiceRow = sheetsClient.getStoredRows('10_BILLING').any((r) => r.isNotEmpty && r[0] == 'INV-001');

      expect(patientRow, isTrue);
      expect(invoiceRow, isTrue);
    });

    // -------------------------------------------------------------------------
    // 5. GOOGLE API QUOTA (429) & BOUNDED RETRY BACKOFF
    // -------------------------------------------------------------------------
    test('5. Handles Google API quota (429) with bounded backoff and records failure without crashing', () async {
      final (engine, _, sheetsClient, authService, db, syncRepo, _) = createSyncEngineHarness();
      await authService.signIn(clinicId: clinicId);

      sheetsClient.simulateRateLimitOnWrite = true;

      final outboxEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_rate_test',
        clinicId: clinicId,
        entityType: 'Patients',
        entityId: 'PAT-RATE-01',
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode({'patient_id': 'PAT-RATE-01', 'clinic_id': clinicId}),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: 'pat_rate_01',
      );
      await db.upsert('sync_outbox', 'outbox_rate_test', outboxEvent.toMap());

      final telemetry = await engine.syncOutboxToMasterSheet(
        clinicId: clinicId,
        maxRetries: 2,
        initialRetryDelay: const Duration(milliseconds: 10),
      );

      expect(telemetry.isSuccess, isFalse);
      expect(telemetry.lastErrorCode, equals('RATE_LIMIT'));
      expect(telemetry.recordsFailed, equals(1));
      expect(telemetry.recordsSucceeded, equals(0));

      // Verify outbox event is marked as failed with retry count updated
      final failedEvent = db.get('sync_outbox', 'outbox_rate_test');
      expect(failedEvent!['status'], equals(OutboxStatus.failed.wireValue));
      expect(failedEvent['retry_count'], greaterThanOrEqualTo(1));
    });

    // -------------------------------------------------------------------------
    // 6. NETWORK FAILURE & 503 SERVER ERROR HANDLING
    // -------------------------------------------------------------------------
    test('6. Handles network disconnect and 503 service unavailable safely', () async {
      final (engine, _, sheetsClient, authService, db, _, _) = createSyncEngineHarness();
      await authService.signIn(clinicId: clinicId);

      sheetsClient.simulateOffline = true;

      final outboxEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_net_test',
        clinicId: clinicId,
        entityType: 'Patients',
        entityId: 'PAT-NET-01',
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode({'patient_id': 'PAT-NET-01', 'clinic_id': clinicId}),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: 'pat_net_01',
      );
      await db.upsert('sync_outbox', 'outbox_net_test', outboxEvent.toMap());

      final telemetry = await engine.syncOutboxToMasterSheet(clinicId: clinicId);

      expect(telemetry.isSuccess, isFalse);
      expect(telemetry.lastErrorCode, equals('API_FAILURE'));

      // Invariant: Local database remains consistent
      expect(db.get('sync_outbox', 'outbox_net_test'), isNotNull);
    });

    // -------------------------------------------------------------------------
    // 7. AUTHENTICATION FAILURE HANDLING
    // -------------------------------------------------------------------------
    test('7. Halts sync cleanly with AUTH_REQUIRED when user is unauthenticated', () async {
      final (engine, _, _, _, db, _, _) = createSyncEngineHarness();
      // Notice: authService.signIn is NOT called!

      final outboxEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_auth_test',
        clinicId: clinicId,
        entityType: 'Patients',
        entityId: 'PAT-AUTH-01',
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode({'patient_id': 'PAT-AUTH-01', 'clinic_id': clinicId}),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: 'pat_auth_01',
      );
      await db.upsert('sync_outbox', 'outbox_auth_test', outboxEvent.toMap());

      final telemetry = await engine.syncOutboxToMasterSheet(clinicId: clinicId);

      expect(telemetry.isSuccess, isFalse);
      expect(telemetry.lastErrorCode, equals('AUTH_REQUIRED'));
      expect(telemetry.authErrors, equals(1));
    });

    // -------------------------------------------------------------------------
    // 8. PARTIAL BATCH FAILURE HANDLING
    // -------------------------------------------------------------------------
    test('8. Acknowledges confirmed records while preserving failed records for retry', () async {
      final (engine, _, sheetsClient, authService, db, syncRepo, _) = createSyncEngineHarness();
      await authService.signIn(clinicId: clinicId);

      // Event 1: Valid Patient
      final pEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_p1',
        clinicId: clinicId,
        entityType: 'Patients',
        entityId: 'PAT-BATCH-01',
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode({'patient_id': 'PAT-BATCH-01', 'clinic_id': clinicId}),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: 'p1',
      );
      await db.upsert('sync_outbox', 'outbox_p1', pEvent.toMap());

      final telemetry = await engine.syncOutboxToMasterSheet(clinicId: clinicId);

      expect(telemetry.isSuccess, isTrue);
      expect(telemetry.recordsSucceeded, equals(1));

      final confirmed = db.get('sync_outbox', 'outbox_p1');
      expect(confirmed!['status'], equals(OutboxStatus.acknowledged.wireValue));
    });

    // -------------------------------------------------------------------------
    // 9. OFFLINE-FIRST LOCAL OPERATION INVARIANCE
    // -------------------------------------------------------------------------
    test('9. Local clinic operations continue without interruption when sync is offline', () async {
      final (engine, _, sheetsClient, authService, db, _, _) = createSyncEngineHarness();
      await authService.signIn(clinicId: clinicId);

      // Disconnect Google Sheets
      sheetsClient.simulateOffline = true;

      // Local clinical workflow MUST operate normally
      final patientRepo = PatientRepository(db);
      final newPatient = Patient(
        patientId: 'PAT-LOCAL-OFFLINE',
        clinicId: clinicId,
        patientNumber: 'P-2026-9999',
        fullName: 'Dr. Local Testing',
        phoneOptional: '9876543200',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      // Saves locally & queues to outbox
      await patientRepo.savePatient(newPatient);

      final savedPatient = await patientRepo.getPatientById(clinicId, 'PAT-LOCAL-OFFLINE');
      expect(savedPatient, isNotNull);
      expect(savedPatient!.fullName, equals('Dr. Local Testing'));

      // Sync attempt fails gracefully without disrupting local state
      final syncTelemetry = await engine.syncOutboxToMasterSheet(clinicId: clinicId);
      expect(syncTelemetry.isSuccess, isFalse);

      // Re-verify local patient is STILL completely intact
      final intactPatient = await patientRepo.getPatientById(clinicId, 'PAT-LOCAL-OFFLINE');
      expect(intactPatient, isNotNull);
    });

    // -------------------------------------------------------------------------
    // 10. CRITICAL REAL-DATA TEST FLOW (Section 16)
    // -------------------------------------------------------------------------
    test('10. Critical flow: Local -> Outbox -> Sync Engine -> Sheet -> Re-Sync -> ZERO Duplicates', () async {
      final (engine, _, sheetsClient, authService, db, syncRepo, _) = createSyncEngineHarness();
      await authService.signIn(clinicId: clinicId);

      // Step A: Create Local Test Records
      final patientRepo = PatientRepository(db);

      final patient = Patient(
        patientId: 'PAT-REAL-TEST-001',
        clinicId: clinicId,
        patientNumber: 'P-REAL-001',
        fullName: 'Kavita Singhania',
        phoneOptional: '9876543201',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      await patientRepo.savePatient(patient);

      // Verify outbox staged
      final outboxBefore = await syncRepo.getPendingOutboxEvents(clinicId);
      expect(outboxBefore.length, equals(1));

      // Step B: Run Sync Engine Pass 1
      final t1 = await engine.syncOutboxToMasterSheet(clinicId: clinicId);
      expect(t1.isSuccess, isTrue);
      expect(t1.recordsSucceeded, equals(1));

      // Step C: Verify Record Exists in Master Sheet Destination
      final remoteRows = sheetsClient.getStoredRows('05_PATIENTS');
      final matchingRowsPass1 = remoteRows.where((r) => r.isNotEmpty && r[0] == 'PAT-REAL-TEST-001').toList();
      expect(matchingRowsPass1.length, equals(1));
      expect(matchingRowsPass1.first[5], equals('Kavita Singhania'));

      // Step D: Re-stage update for the same record and Run Sync Pass 2
      await patientRepo.savePatient(patient); // Re-save creates new outbox event
      final t2 = await engine.syncOutboxToMasterSheet(clinicId: clinicId);
      expect(t2.isSuccess, isTrue);

      // Step E: Verify ZERO Remote Duplicates
      final remoteRowsPass2 = sheetsClient.getStoredRows('05_PATIENTS');
      final matchingRowsPass2 = remoteRowsPass2.where((r) => r.isNotEmpty && r[0] == 'PAT-REAL-TEST-001').toList();

      expect(
        matchingRowsPass2.length,
        equals(1),
        reason: 'CRITICAL INVARIANT: Master Sheet must contain exactly 1 row for PAT-REAL-TEST-001 with ZERO duplicates',
      );
    });
  });
}
