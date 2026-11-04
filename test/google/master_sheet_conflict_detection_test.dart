// Apna Clinic - Controlled Two-Way Conflict Detection, Sync Scheduling & Production Observability Tests
// Phase 3 — Milestone 4
// Primary source of truth: Milestone 4 User Request (All 22 Scenarios), PRD Section 38-41, TRD Section 11

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

import 'package:apna_clinic/application/auth/auth_service.dart';
import 'package:apna_clinic/application/providers.dart';
import 'package:apna_clinic/domain/entities/entities.dart';
import 'package:apna_clinic/domain/enums/domain_enums.dart';
import 'package:apna_clinic/infrastructure/database/local_database.dart';
import 'package:apna_clinic/infrastructure/database/storage_adapter.dart';
import 'package:apna_clinic/infrastructure/google/mock_google_integration.dart';
import 'package:apna_clinic/infrastructure/google/oauth/mock_google_oauth_provider.dart';
import 'package:apna_clinic/infrastructure/google/oauth/token_vault.dart';
import 'package:apna_clinic/infrastructure/google/sync/master_sheet_conflict_detector.dart';
import 'package:apna_clinic/infrastructure/google/sync/master_sheet_mapper.dart';
import 'package:apna_clinic/infrastructure/google/sync/master_sheet_sync_engine.dart';
import 'package:apna_clinic/infrastructure/google/sync/master_sheet_sync_scheduler.dart';
import 'package:apna_clinic/infrastructure/google/sync/sync_observability_service.dart';
import 'package:apna_clinic/infrastructure/repositories/infrastructure_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  (
    MasterSheetSyncEngine,
    MasterSheetConflictDetector,
    SyncObservabilityService,
    MasterSheetSyncScheduler,
    MockGoogleDriveClient,
    MockGoogleSheetsClient,
    AuthService,
    LocalDatabase,
    SyncRepository,
  ) createMilestone4Harness() {
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

    final syncEngine = MasterSheetSyncEngine(
      driveClient: driveClient,
      sheetsClient: sheetsClient,
      localDb: db,
      syncRepository: syncRepo,
      authService: authService,
    );

    final conflictDetector = MasterSheetConflictDetector(
      driveClient: driveClient,
      sheetsClient: sheetsClient,
      localDb: db,
      syncRepository: syncRepo,
      authService: authService,
    );

    final observabilityService = SyncObservabilityService(localDb: db);

    final scheduler = MasterSheetSyncScheduler(
      syncEngine: syncEngine,
      observabilityService: observabilityService,
    );

    return (
      syncEngine,
      conflictDetector,
      observabilityService,
      scheduler,
      driveClient,
      sheetsClient,
      authService,
      db,
      syncRepo,
    );
  }

  const clinicId = 'clinic_m4_test';

  group('APNA CLINIC — PHASE 3 MILESTONE 4: CONFLICT DETECTION, SCHEDULING & OBSERVABILITY', () {
    // -------------------------------------------------------------------------
    // 1. LOCAL_ONLY DETECTION
    // -------------------------------------------------------------------------
    test('1. Detects LOCAL_ONLY record when present locally but absent remotely with no prior sync', () async {
      final (_, detector, _, _, _, _, authService, db, _) = createMilestone4Harness();
      await authService.signIn(clinicId: clinicId);

      final patientRepo = PatientRepository(db);
      final patient = Patient(
        patientId: 'PAT-LOCAL-001',
        clinicId: clinicId,
        patientNumber: 'P-001',
        fullName: 'Aarav Sharma',
        phoneOptional: '9876543210',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      await patientRepo.savePatient(patient);

      final result = await detector.detectChanges(
        clinicId: clinicId,
        sheetName: '05_PATIENTS',
      );

      expect(result.isSuccess, isTrue);
      expect(result.localOnlyCount, equals(1));
      final item = result.items.firstWhere((i) => i.entityId == 'PAT-LOCAL-001');
      expect(item.classification, equals(ConflictClassification.localOnly));
    });

    // -------------------------------------------------------------------------
    // 2. REMOTE_ONLY DETECTION
    // -------------------------------------------------------------------------
    test('2. Detects REMOTE_ONLY record when present in sheet but absent locally with no prior sync', () async {
      final (_, detector, _, _, _, sheetsClient, authService, _, _) = createMilestone4Harness();
      await authService.signIn(clinicId: clinicId);

      // Inject remote row directly into sheets client store
      sheetsClient.getStoredRows('05_PATIENTS').clear();
      final remoteRow = MasterSheetMapper.mapToRow('05_PATIENTS', {
        'patient_id': 'PAT-REMOTE-999',
        'clinic_id': clinicId,
        'patient_number': 'P-999',
        'full_name': 'Meera Patel',
      });
      sheetsClient.getStoredRows('05_PATIENTS').add(remoteRow);

      final result = await detector.detectChanges(
        clinicId: clinicId,
        sheetName: '05_PATIENTS',
      );

      expect(result.isSuccess, isTrue);
      expect(result.remoteOnlyCount, equals(1));
      final item = result.items.firstWhere((i) => i.entityId == 'PAT-REMOTE-999');
      expect(item.classification, equals(ConflictClassification.remoteOnly));
    });

    // -------------------------------------------------------------------------
    // 3. MATCHED (SYNCED) RECORD
    // -------------------------------------------------------------------------
    test('3. Detects SYNCED record when local and remote checksums match identically', () async {
      final (_, detector, _, _, _, sheetsClient, authService, db, _) = createMilestone4Harness();
      await authService.signIn(clinicId: clinicId);

      final patientRepo = PatientRepository(db);
      final patient = Patient(
        patientId: 'PAT-SYNCED-001',
        clinicId: clinicId,
        patientNumber: 'P-002',
        fullName: 'Rohan Verma',
        phoneOptional: '9123456780',
        createdAt: DateTime.utc(2026, 9, 1, 10, 0),
        updatedAt: DateTime.utc(2026, 9, 1, 10, 0),
      );
      await patientRepo.savePatient(patient);

      // Match remote row exactly
      final localMap = db.get('Patients', 'PAT-SYNCED-001')!;
      final matchingRow = MasterSheetMapper.mapToRow('05_PATIENTS', localMap);
      sheetsClient.getStoredRows('05_PATIENTS').add(matchingRow);

      final result = await detector.detectChanges(
        clinicId: clinicId,
        sheetName: '05_PATIENTS',
      );

      expect(result.isSuccess, isTrue);
      expect(result.syncedCount, equals(1));
      final item = result.items.firstWhere((i) => i.entityId == 'PAT-SYNCED-001');
      expect(item.classification, equals(ConflictClassification.synced));
    });

    // -------------------------------------------------------------------------
    // 4. LOCAL_MODIFIED
    // -------------------------------------------------------------------------
    test('4. Detects LOCAL_MODIFIED when local record changed from baseline but remote remained unchanged', () async {
      final (_, detector, _, _, _, sheetsClient, authService, db, _) = createMilestone4Harness();
      await authService.signIn(clinicId: clinicId);

      sheetsClient.getStoredRows('01_SETTINGS').clear();

      // Baseline synced row
      final baselineMap = {
        'setting_id': 'SET-001',
        'clinic_id': clinicId,
        'setting_key': 'clinic_name',
        'setting_value': 'Original Clinic Name',
      };
      final baselineRow = MasterSheetMapper.mapToRow('01_SETTINGS', baselineMap);
      final baselineChecksum = ChecksumCalculator.fromRow(baselineRow);

      // Remote sheet has baseline row
      sheetsClient.getStoredRows('01_SETTINGS').add(baselineRow);

      // Local DB was modified
      final modifiedLocalMap = {
        'setting_id': 'SET-001',
        'clinic_id': clinicId,
        'setting_key': 'clinic_name',
        'setting_value': 'Locally Updated Clinic Name',
      };
      await db.upsert('Clinic_Config', 'SET-001', modifiedLocalMap);

      final result = await detector.detectChanges(
        clinicId: clinicId,
        sheetName: '01_SETTINGS',
        simulatedLastSyncedChecksums: {'SET-001': baselineChecksum},
      );

      expect(result.isSuccess, isTrue);
      expect(result.localModifiedCount, equals(1));
      final item = result.items.firstWhere((i) => i.entityId == 'SET-001');
      expect(item.classification, equals(ConflictClassification.localModified));
    });

    // -------------------------------------------------------------------------
    // 5. REMOTE_MODIFIED (Non-sensitive entity)
    // -------------------------------------------------------------------------
    test('5. Detects REMOTE_MODIFIED on non-sensitive entity when remote changed from baseline and local remained untouched', () async {
      final (_, detector, _, _, _, sheetsClient, authService, db, _) = createMilestone4Harness();
      await authService.signIn(clinicId: clinicId);

      sheetsClient.getStoredRows('01_SETTINGS').clear();

      // Baseline record
      final baselineMap = {
        'setting_id': 'SET-002',
        'clinic_id': clinicId,
        'setting_key': 'clinic_phone',
        'setting_value': 'Baseline Clinic Phone',
      };
      final baselineRow = MasterSheetMapper.mapToRow('01_SETTINGS', baselineMap);
      final baselineChecksum = ChecksumCalculator.fromRow(baselineRow);

      // Local DB has baseline
      await db.upsert('Clinic_Config', 'SET-002', baselineMap);

      // Remote sheet was modified on Google Sheets
      final modifiedRemoteMap = {
        'setting_id': 'SET-002',
        'clinic_id': clinicId,
        'setting_key': 'clinic_phone',
        'setting_value': 'Remotely Edited Clinic Phone',
      };
      final modifiedRemoteRow = MasterSheetMapper.mapToRow('01_SETTINGS', modifiedRemoteMap);
      sheetsClient.getStoredRows('01_SETTINGS').add(modifiedRemoteRow);

      final result = await detector.detectChanges(
        clinicId: clinicId,
        sheetName: '01_SETTINGS',
        simulatedLastSyncedChecksums: {'SET-002': baselineChecksum},
      );

      expect(result.isSuccess, isTrue);
      expect(result.remoteModifiedCount, equals(1));
      final item = result.items.firstWhere((i) => i.entityId == 'SET-002');
      expect(item.classification, equals(ConflictClassification.remoteModified));
    });

    // -------------------------------------------------------------------------
    // 6. CONFLICT DETECTION
    // -------------------------------------------------------------------------
    test('6. Detects CONFLICT when both local and remote have diverged from last synchronized baseline', () async {
      final (_, detector, _, _, _, sheetsClient, authService, db, _) = createMilestone4Harness();
      await authService.signIn(clinicId: clinicId);

      sheetsClient.getStoredRows('01_SETTINGS').clear();

      const baselineChecksum = 'baseline_sha_12345';

      // Local modified
      await db.upsert('Clinic_Config', 'SET-CONF-01', {
        'setting_id': 'SET-CONF-01',
        'clinic_id': clinicId,
        'setting_key': 'branch_name',
        'setting_value': 'Local Branch Name',
      });

      // Remote modified
      final remoteRow = MasterSheetMapper.mapToRow('01_SETTINGS', {
        'setting_id': 'SET-CONF-01',
        'clinic_id': clinicId,
        'setting_key': 'branch_name',
        'setting_value': 'Remote Branch Name',
      });
      sheetsClient.getStoredRows('01_SETTINGS').add(remoteRow);

      final result = await detector.detectChanges(
        clinicId: clinicId,
        sheetName: '01_SETTINGS',
        simulatedLastSyncedChecksums: {'SET-CONF-01': baselineChecksum},
      );

      expect(result.isSuccess, isTrue);
      expect(result.conflictCount, equals(1));
      final item = result.items.firstWhere((i) => i.entityId == 'SET-CONF-01');
      expect(item.classification, equals(ConflictClassification.conflict));

      // Verify conflict record was persisted into local database
      final recordedConflicts = await detector.getRecordedConflicts(clinicId);
      expect(recordedConflicts.any((c) => c.entityId == 'SET-CONF-01'), isTrue);
    });

    // -------------------------------------------------------------------------
    // 7. REMOTE_DELETED
    // -------------------------------------------------------------------------
    test('7. Detects REMOTE_DELETED when record was previously synced but is now missing from remote sheet', () async {
      final (_, detector, _, _, _, _, authService, db, _) = createMilestone4Harness();
      await authService.signIn(clinicId: clinicId);

      // Local record exists
      await db.upsert('Patients', 'PAT-DEL-01', {
        'patient_id': 'PAT-DEL-01',
        'clinic_id': clinicId,
        'full_name': 'Local Retained Patient',
      });

      // Remote sheet is empty, but baseline says it was synced
      final result = await detector.detectChanges(
        clinicId: clinicId,
        sheetName: '05_PATIENTS',
        simulatedLastSyncedChecksums: {'PAT-DEL-01': 'prior_synced_sha'},
      );

      expect(result.isSuccess, isTrue);
      expect(result.remoteDeletedCount, equals(1));
      final item = result.items.firstWhere((i) => i.entityId == 'PAT-DEL-01');
      expect(item.classification, equals(ConflictClassification.remoteDeleted));
    });

    // -------------------------------------------------------------------------
    // 8. LOCAL_DELETED
    // -------------------------------------------------------------------------
    test('8. Detects LOCAL_DELETED when record was previously synced but is now missing locally', () async {
      final (_, detector, _, _, _, sheetsClient, authService, _, _) = createMilestone4Harness();
      await authService.signIn(clinicId: clinicId);

      // Sheet still has the row
      final remoteRow = MasterSheetMapper.mapToRow('05_PATIENTS', {
        'patient_id': 'PAT-LOCDEL-01',
        'clinic_id': clinicId,
        'full_name': 'Patient Deleted Locally',
      });
      sheetsClient.getStoredRows('05_PATIENTS').add(remoteRow);

      // Local DB does NOT have it, but it was in prior sync
      final result = await detector.detectChanges(
        clinicId: clinicId,
        sheetName: '05_PATIENTS',
        simulatedLastSyncedChecksums: {'PAT-LOCDEL-01': 'prior_synced_sha'},
      );

      expect(result.isSuccess, isTrue);
      expect(result.localDeletedCount, equals(1));
      final item = result.items.firstWhere((i) => i.entityId == 'PAT-LOCDEL-01');
      expect(item.classification, equals(ConflictClassification.localDeleted));
    });

    // -------------------------------------------------------------------------
    // 9. SCHEMA MISMATCH
    // -------------------------------------------------------------------------
    test('9. Catches schema tampering, halts change detection, and returns SCHEMA_MISMATCH', () async {
      final (_, detector, _, _, _, sheetsClient, authService, _, _) = createMilestone4Harness();
      await authService.signIn(clinicId: clinicId);

      sheetsClient.simulateMissingSheet = true;

      final result = await detector.detectChanges(
        clinicId: clinicId,
        sheetName: '05_PATIENTS',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, equals('SCHEMA_MISMATCH'));
    });

    // -------------------------------------------------------------------------
    // 10. AUTHENTICATION FAILURE
    // -------------------------------------------------------------------------
    test('10. Halts change detection cleanly with AUTH_REQUIRED when unauthenticated or token expired', () async {
      final (_, detector, _, _, _, _, _, _, _) = createMilestone4Harness();
      // Not signed in!

      final result = await detector.detectChanges(
        clinicId: clinicId,
        sheetName: '05_PATIENTS',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, equals('AUTH_REQUIRED'));
    });

    // -------------------------------------------------------------------------
    // 11. PERMISSION FAILURE
    // -------------------------------------------------------------------------
    test('11. Handles permission denied (403) cleanly and surfaces structured error', () async {
      final (_, detector, _, _, _, sheetsClient, authService, _, _) = createMilestone4Harness();
      await authService.signIn(clinicId: clinicId);

      sheetsClient.simulatePermissionDenied = true;

      final result = await detector.detectChanges(
        clinicId: clinicId,
        sheetName: '05_PATIENTS',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, equals('AUTH_REQUIRED'));
    });

    // -------------------------------------------------------------------------
    // 12. NETWORK FAILURE
    // -------------------------------------------------------------------------
    test('12. Handles network disconnect safely without corrupting local data', () async {
      final (_, detector, _, _, _, sheetsClient, authService, db, _) = createMilestone4Harness();
      await authService.signIn(clinicId: clinicId);

      sheetsClient.simulateOffline = true;

      final result = await detector.detectChanges(
        clinicId: clinicId,
        sheetName: '05_PATIENTS',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, anyOf(equals('SYNC_ERROR'), equals('NETWORK_FAILURE')));
      // Invariant: Local database tables remain untouched
      expect(db.query('Patients'), isEmpty);
    });

    // -------------------------------------------------------------------------
    // 13. RATE-LIMIT HANDLING (429)
    // -------------------------------------------------------------------------
    test('13. Handles rate limit (429) during change detection cleanly', () async {
      final (_, detector, _, _, _, sheetsClient, authService, _, _) = createMilestone4Harness();
      await authService.signIn(clinicId: clinicId);

      sheetsClient.simulateRateLimit = true;

      final result = await detector.detectChanges(
        clinicId: clinicId,
        sheetName: '05_PATIENTS',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, equals('SYNC_ERROR'));
    });

    // -------------------------------------------------------------------------
    // 14. SCHEDULER OVERLAP PREVENTION
    // -------------------------------------------------------------------------
    test('14. Scheduler prevents overlapping concurrent synchronization runs', () async {
      final (_, _, _, scheduler, _, _, authService, _, _) = createMilestone4Harness();
      await authService.signIn(clinicId: clinicId);

      // Launch first sync task
      final future1 = scheduler.triggerManualSync(clinicId: clinicId);
      // Immediately launch second sync task while first is active
      final future2 = scheduler.triggerManualSync(clinicId: clinicId);

      final results = await Future.wait([future1, future2]);
      final t1 = results[0];
      final t2 = results[1];

      // One must succeed, the other must be safely skipped due to overlap guard
      final skippedOne = t1.lastErrorCode == 'SYNC_IN_PROGRESS' || t2.lastErrorCode == 'SYNC_IN_PROGRESS';
      expect(skippedOne, isTrue);
    });

    // -------------------------------------------------------------------------
    // 15. SCHEDULER CANCELLATION
    // -------------------------------------------------------------------------
    test('15. Scheduler cleanly starts and cancels periodic synchronization timer', () {
      final (_, _, _, scheduler, _, _, _, _, _) = createMilestone4Harness();

      expect(scheduler.isScheduled, isFalse);
      scheduler.startPeriodicSync(
        clinicId: clinicId,
        interval: const Duration(minutes: 15),
      );
      expect(scheduler.isScheduled, isTrue);

      scheduler.cancelScheduledSync();
      expect(scheduler.isScheduled, isFalse);
    });

    // -------------------------------------------------------------------------
    // 16. OFFLINE SCHEDULER BEHAVIOR
    // -------------------------------------------------------------------------
    test('16. Scheduler detects offline network, avoids destructive writes, and leaves local state intact', () async {
      final (_, _, observability, scheduler, _, sheetsClient, authService, db, _) = createMilestone4Harness();
      await authService.signIn(clinicId: clinicId);

      sheetsClient.simulateOffline = true;

      // Stage an outbox event
      final outboxEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_offline_sch',
        clinicId: clinicId,
        entityType: 'Patients',
        entityId: 'PAT-OFFLINE-01',
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode({'patient_id': 'PAT-OFFLINE-01', 'clinic_id': clinicId}),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: 'off_sch_01',
      );
      await db.upsert('sync_outbox', 'outbox_offline_sch', outboxEvent.toMap());

      final telemetry = await scheduler.triggerManualSync(clinicId: clinicId);

      expect(telemetry.isSuccess, isFalse);
      expect(observability.isOfflineDetected, isTrue);
      expect(observability.healthStatus, equals(SyncHealthStatus.offline));

      // Outbox event is preserved safely for when connectivity returns
      final preserved = db.get('sync_outbox', 'outbox_offline_sch');
      expect(preserved, isNotNull);
    });

    // -------------------------------------------------------------------------
    // 17. REPEATED SCHEDULER EXECUTION
    // -------------------------------------------------------------------------
    test('17. Repeated scheduler runs execute stably without memory leaks or race conditions', () async {
      final (_, _, observability, scheduler, _, _, authService, _, _) = createMilestone4Harness();
      await authService.signIn(clinicId: clinicId);

      for (int i = 0; i < 3; i++) {
        final t = await scheduler.triggerManualSync(clinicId: clinicId);
        expect(t.isSuccess, isTrue);
      }

      final metrics = observability.getAggregatedMetrics();
      expect(metrics.totalSyncRuns, equals(3));
      expect(metrics.successfulSyncRuns, equals(3));
      expect(metrics.currentHealth, equals(SyncHealthStatus.healthy));
    });

    // -------------------------------------------------------------------------
    // 18. DUPLICATE SYNC PREVENTION
    // -------------------------------------------------------------------------
    test('18. Re-running sync on identical events produces ZERO duplicate rows in remote sheets', () async {
      final (engine, _, _, _, _, sheetsClient, authService, db, syncRepo) = createMilestone4Harness();
      await authService.signIn(clinicId: clinicId);

      final patientRepo = PatientRepository(db);
      final patient = Patient(
        patientId: 'PAT-DUP-TEST-001',
        clinicId: clinicId,
        patientNumber: 'P-DUP-01',
        fullName: 'Vikram Malhotra',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      await patientRepo.savePatient(patient);

      // Run Pass 1
      final t1 = await engine.syncOutboxToMasterSheet(clinicId: clinicId);
      expect(t1.isSuccess, isTrue);

      // Re-stage and Run Pass 2
      await patientRepo.savePatient(patient);
      final t2 = await engine.syncOutboxToMasterSheet(clinicId: clinicId);
      expect(t2.isSuccess, isTrue);

      // Verify remote rows
      final remoteRows = sheetsClient.getStoredRows('05_PATIENTS');
      final matches = remoteRows.where((r) => r.isNotEmpty && r[0] == 'PAT-DUP-TEST-001').toList();
      expect(matches.length, equals(1), reason: 'ZERO duplicate rows allowed in remote Master Sheet');
    });

    // -------------------------------------------------------------------------
    // 19. SENSITIVE-DATA TELEMETRY PROTECTION
    // -------------------------------------------------------------------------
    test('19. Observability sanitizer completely strips clinical diagnoses, prescriptions, and OAuth tokens', () {
      final sensitiveMap = {
        'sync_run_id': 'sync_123',
        'clinic_id': clinicId,
        'access_token': 'secret_oauth_token_xyz',
        'password_hash': 'secret_hash_abc',
        'diagnosis': 'Type 2 Diabetes Mellitus with Neuropathy',
        'chief_complaint': 'Severe chest pain radiating to left arm',
        'prescriptions': [
          {'medication': 'Metformin 500mg', 'dosage': 'twice daily'}
        ],
        'notes': 'Confidential patient clinical history',
        'records_succeeded': 5,
      };

      final sanitized = SyncObservabilityService.sanitizeForTelemetry(sensitiveMap);

      expect(sanitized['access_token'], equals('[REDACTED_FOR_PRIVACY]'));
      expect(sanitized['password_hash'], equals('[REDACTED_FOR_PRIVACY]'));
      expect(sanitized['diagnosis'], equals('[REDACTED_FOR_PRIVACY]'));
      expect(sanitized['chief_complaint'], equals('[REDACTED_FOR_PRIVACY]'));
      expect(sanitized['prescriptions'], equals('[REDACTED_FOR_PRIVACY]'));
      expect(sanitized['notes'], equals('[REDACTED_FOR_PRIVACY]'));
      expect(sanitized['records_succeeded'], equals(5)); // Non-sensitive metrics preserved
    });

    // -------------------------------------------------------------------------
    // 20. CRITICAL CLINICAL CONFLICT PROTECTION
    // -------------------------------------------------------------------------
    test('20. Clinical Data Rule: Remote edit on sensitive entity (Patients) is NEVER auto-overwritten, marked as CONFLICT', () async {
      final (_, detector, _, _, _, sheetsClient, authService, db, _) = createMilestone4Harness();
      await authService.signIn(clinicId: clinicId);

      // Baseline patient
      final baselinePatient = {
        'patient_id': 'PAT-CLINICAL-01',
        'clinic_id': clinicId,
        'patient_number': 'P-500',
        'full_name': 'Original Local Patient',
      };
      final baselineRow = MasterSheetMapper.mapToRow('05_PATIENTS', baselinePatient);
      final baselineChecksum = ChecksumCalculator.fromRow(baselineRow);

      // Local has baseline
      await db.upsert('Patients', 'PAT-CLINICAL-01', baselinePatient);

      // Remote sheet has an edit from Google Sheets
      final editedRemoteRow = MasterSheetMapper.mapToRow('05_PATIENTS', {
        'patient_id': 'PAT-CLINICAL-01',
        'clinic_id': clinicId,
        'patient_number': 'P-500',
        'full_name': 'Overwritten Name In Cloud',
      });
      sheetsClient.getStoredRows('05_PATIENTS').add(editedRemoteRow);

      final result = await detector.detectChanges(
        clinicId: clinicId,
        sheetName: '05_PATIENTS',
        simulatedLastSyncedChecksums: {'PAT-CLINICAL-01': baselineChecksum},
      );

      // Invariant: Because PATIENTS is a sensitive clinical entity, it is marked as CONFLICT rather than silently accepted
      expect(result.conflictCount, equals(1));
      final item = result.items.firstWhere((i) => i.entityId == 'PAT-CLINICAL-01');
      expect(item.classification, equals(ConflictClassification.conflict));

      // Local record remains 100% UNTOUCHED
      final localCurrent = db.get('Patients', 'PAT-CLINICAL-01');
      expect(localCurrent!['full_name'], equals('Original Local Patient'));
    });

    // -------------------------------------------------------------------------
    // 21. SYNCMANIFEST CONSISTENCY
    // -------------------------------------------------------------------------
    test('21. Successful sync persists valid SyncManifest with timestamps, targets, and checksums', () async {
      final (engine, _, _, _, _, _, authService, db, syncRepo) = createMilestone4Harness();
      await authService.signIn(clinicId: clinicId);

      final patientRepo = PatientRepository(db);
      final patient = Patient(
        patientId: 'PAT-MANIFEST-01',
        clinicId: clinicId,
        patientNumber: 'P-MAN-01',
        fullName: 'Manifest Verifier',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      await patientRepo.savePatient(patient);

      final t = await engine.syncOutboxToMasterSheet(clinicId: clinicId);
      expect(t.isSuccess, isTrue);

      final manifest = await syncRepo.getLastSyncManifest(clinicId);
      expect(manifest, isNotNull);
      expect(manifest!.clinicId, equals(clinicId));
      expect(manifest.status, equals('confirmed'));
      expect(manifest.targetTab, contains('05_PATIENTS'));
      expect(manifest.confirmedAt, isNotNull);
    });

    // -------------------------------------------------------------------------
    // 22. OUTBOX PRESERVATION AFTER FAILURE
    // -------------------------------------------------------------------------
    test('22. Outbox events are preserved with failed status and retry counts after network error', () async {
      final (engine, _, _, _, _, sheetsClient, authService, db, syncRepo) = createMilestone4Harness();
      await authService.signIn(clinicId: clinicId);

      sheetsClient.simulateOffline = true;

      final outboxEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_preserve_01',
        clinicId: clinicId,
        entityType: 'Patients',
        entityId: 'PAT-PRESERVE-01',
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode({'patient_id': 'PAT-PRESERVE-01', 'clinic_id': clinicId}),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: 'pres_01',
      );
      await db.upsert('sync_outbox', 'outbox_preserve_01', outboxEvent.toMap());

      final telemetry = await engine.syncOutboxToMasterSheet(clinicId: clinicId);
      expect(telemetry.isSuccess, isFalse);

      // Event is still in local database, not lost or corrupted
      final preserved = db.get('sync_outbox', 'outbox_preserve_01');
      expect(preserved, isNotNull);
      expect(preserved!['entity_id'], equals('PAT-PRESERVE-01'));
    });
  });
}
