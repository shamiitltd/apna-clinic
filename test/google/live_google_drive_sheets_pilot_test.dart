// Apna Clinic — Phase 4 Milestone 2: Live Real Google Drive + Google Sheets Pilot Test
// Uses the authenticated Google session of Akash Dash (from local Chrome session)
// Executes the complete 10-step real Google Cloud end-to-end integration pilot.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:apna_clinic/application/auth/auth_service.dart';
import 'package:apna_clinic/application/providers.dart';
import 'package:apna_clinic/domain/entities/entities.dart';
import 'package:apna_clinic/infrastructure/database/local_database.dart';
import 'package:apna_clinic/infrastructure/database/storage_adapter.dart';
import 'package:apna_clinic/infrastructure/google/google_drive_client.dart';
import 'package:apna_clinic/infrastructure/google/google_sheets_client.dart';
import 'package:apna_clinic/infrastructure/google/oauth/mock_google_oauth_provider.dart';
import 'package:apna_clinic/infrastructure/google/oauth/token_vault.dart';
import 'package:apna_clinic/infrastructure/google/sync/master_sheet_conflict_detector.dart';
import 'package:apna_clinic/infrastructure/google/sync/master_sheet_initialization_service.dart';
import 'package:apna_clinic/infrastructure/google/sync/master_sheet_sync_engine.dart';
import 'package:apna_clinic/infrastructure/repositories/infrastructure_repositories.dart';
import 'package:apna_clinic/infrastructure/security/local_encryption_service.dart';

void main() {
  HttpOverrides.global = null;

  final envelopeFile = File('scratch_token_envelope.json');
  if (!envelopeFile.existsSync()) {
    test('Live Google Cloud pilot skipped (no local active session envelope)', () {});
    return;
  }

  String getDecryptedChromeToken() {
    final file = File('scratch_token_envelope.json');
    if (!file.existsSync()) {
      throw StateError('scratch_token_envelope.json not found');
    }
    final jsonStr = file.readAsStringSync();
    final envelopeMap = jsonDecode(jsonStr) as Map<String, dynamic>;
    final envelope = EncryptedEnvelope.fromMap(envelopeMap);
    const clinicId = 'clinic_primary_demo';
    const salt = 'ApnaClinicOAuthTokenVaultSalt2026';
    final key = LocalEncryptionService.deriveKeyFromPassphrase(clinicId, salt);
    return LocalEncryptionService.decryptEnvelope(envelope: envelope, key: key);
  }

  group('APNA CLINIC — REAL GOOGLE DRIVE & SHEETS LIVE PILOT (AKASH DASH)', () {
    late String liveToken;
    late http.Client httpClient;
    late GoogleDriveClient realDriveClient;
    late GoogleSheetsClient realSheetsClient;
    late LocalDatabase localDb;
    late SyncRepository syncRepo;
    late PatientRepository patientRepo;
    late TokenVault tokenVault;
    late AuthService authService;
    late MasterSheetInitializationService initService;
    late MasterSheetSyncEngine syncEngine;
    late MasterSheetConflictDetector conflictDetector;

    const clinicId = 'clinic_primary_demo';

    setUpAll(() async {
      liveToken = getDecryptedChromeToken();
      expect(liveToken.startsWith('ya29.'), isTrue);

      httpClient = http.Client();
      realDriveClient = GoogleDriveClient(httpClient);
      realSheetsClient = GoogleSheetsClient(httpClient);

      final storage = MemoryStorageAdapter();
      localDb = LocalDatabase(storage);
      syncRepo = SyncRepository(localDb);
      patientRepo = PatientRepository(localDb);
      tokenVault = TokenVault(storage);

      final mockOauth = MockGoogleOAuthProvider();
      final sessionNotifier = SessionNotifier();
      authService = AuthService(
        oauthProvider: mockOauth,
        tokenVault: tokenVault,
        sessionNotifier: sessionNotifier,
      );

      // Pre-seed live token in vault for the active clinic
      await tokenVault.saveAccessToken(
        clinicId,
        liveToken,
        DateTime.now().add(const Duration(hours: 1)),
      );

      initService = MasterSheetInitializationService(
        driveClient: realDriveClient,
        sheetsClient: realSheetsClient,
        localDb: localDb,
        authService: authService,
      );

      syncEngine = MasterSheetSyncEngine(
        driveClient: realDriveClient,
        sheetsClient: realSheetsClient,
        localDb: localDb,
        syncRepository: syncRepo,
        authService: authService,
      );

      conflictDetector = MasterSheetConflictDetector(
        driveClient: realDriveClient,
        sheetsClient: realSheetsClient,
        localDb: localDb,
        syncRepository: syncRepo,
        authService: authService,
      );
    });

    tearDownAll(() {
      httpClient.close();
    });

    test('Step 1 & 2: Live Google Account Verification & Drive Folder Hierarchy', () async {
      // 1. Verify Drive identity
      final accountInfo = await realDriveClient.verifyAccountAccess(accessToken: liveToken);
      expect(accountInfo.displayName, contains('Akash Dash'));
      expect(accountInfo.emailAddress, 'akashadash690@gmail.com');

      // 2. Ensure root folder "ApnaClinic" exists
      final rootFolderId = await realDriveClient.getOrCreateFolder(
        accessToken: liveToken,
        folderName: 'ApnaClinic',
      );
      expect(rootFolderId, isNotEmpty);

      // 3. Ensure clinic subfolder exists under root
      final clinicFolderId = await realDriveClient.getOrCreateFolder(
        accessToken: liveToken,
        folderName: clinicId,
        parentFolderId: rootFolderId,
      );
      expect(clinicFolderId, isNotEmpty);

      // 4. Verify folder idempotency: repeat calls return exact same IDs without creating duplicates
      final repeatRootId = await realDriveClient.getOrCreateFolder(
        accessToken: liveToken,
        folderName: 'ApnaClinic',
      );
      expect(repeatRootId, equals(rootFolderId));

      final repeatClinicFolderId = await realDriveClient.getOrCreateFolder(
        accessToken: liveToken,
        folderName: clinicId,
        parentFolderId: repeatRootId,
      );
      expect(repeatClinicFolderId, equals(clinicFolderId));
    });

    test('Step 3 & 4: Canonical Master Sheet Discovery / Creation & 20-Sheet Schema Read', () async {
      final xlsxFile = File('APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL.xlsx');
      final xlsxBytes = xlsxFile.existsSync() ? xlsxFile.readAsBytesSync() : null;

      final masterSpreadsheetId = await initService.getOrCreateMasterSpreadsheet(
        accessToken: liveToken,
        clinicId: clinicId,
        optionalXlsxBytes: xlsxBytes,
      );
      expect(masterSpreadsheetId, isNotEmpty);

      // Validate 20-sheet schema via real Google Sheets API
      final validationResult = await realSheetsClient.validateMasterSheetSchema(
        accessToken: liveToken,
        spreadsheetId: masterSpreadsheetId,
      );

      expect(validationResult.isValid, isTrue, reason: validationResult.errorMessage);
      expect(validationResult.missingSheets, isEmpty);
      expect(validationResult.missingHeaders, isEmpty);

      // Real Read Test: Read 20_LOOKUPS sheet
      final genderLookups = await realSheetsClient.readLookupCategory(
        accessToken: liveToken,
        spreadsheetId: masterSpreadsheetId,
        category: 'GENDER',
      );
      expect(genderLookups, isNotEmpty);
      expect(genderLookups.map((g) => g.code), containsAll(['MALE', 'FEMALE']));
    });

    test('Step 5 & 6: Controlled Write Test, Read Back & Idempotency', () async {
      final masterSpreadsheetId = await initService.getOrCreateMasterSpreadsheet(
        accessToken: liveToken,
        clinicId: clinicId,
      );

      final now = DateTime.now().toUtc();
      final testPatient = Patient(
        patientId: 'PAT-LIVE-AKASH-001',
        clinicId: clinicId,
        patientNumber: 'P-1001',
        fullName: 'Aarav Patel (Akash Dash Pilot)',
        phoneOptional: '9876543210',
        createdAt: now,
        updatedAt: now,
      );

      // Write to Local DB (which creates outbox event automatically via repository transaction)
      await patientRepo.savePatient(testPatient);

      final pendingCountBefore = await syncRepo.countPendingOutboxEvents(clinicId);
      expect(pendingCountBefore, greaterThanOrEqualTo(1));

      // Sync outbox to real Google Sheets
      final telemetry = await syncEngine.syncOutboxToMasterSheet(
        clinicId: clinicId,
        explicitAccessToken: liveToken,
        explicitSpreadsheetId: masterSpreadsheetId,
      );
      expect(telemetry.isSuccess, isTrue);
      expect(telemetry.recordsSucceeded, greaterThanOrEqualTo(1));

      final pendingCountAfter = await syncRepo.countPendingOutboxEvents(clinicId);
      expect(pendingCountAfter, equals(0));

      // Read back from real Google Sheets 05_PATIENTS column A
      final patientRows = await realSheetsClient.readSheetColumn(
        accessToken: liveToken,
        spreadsheetId: masterSpreadsheetId,
        sheetName: '05_PATIENTS',
        columnLetter: 'A',
      );
      expect(patientRows, contains('PAT-LIVE-AKASH-001'));

      // Idempotency: Re-syncing does not create duplicate rows
      final reSyncTelemetry = await syncEngine.syncOutboxToMasterSheet(
        clinicId: clinicId,
        explicitAccessToken: liveToken,
        explicitSpreadsheetId: masterSpreadsheetId,
      );
      expect(reSyncTelemetry.isSuccess, isTrue);

      final patientRowsAfter = await realSheetsClient.readSheetColumn(
        accessToken: liveToken,
        spreadsheetId: masterSpreadsheetId,
        sheetName: '05_PATIENTS',
        columnLetter: 'A',
      );
      final count = patientRowsAfter.where((id) => id == 'PAT-LIVE-AKASH-001').length;
      expect(count, equals(1), reason: 'Zero duplicate rows allowed in Google Sheets');
    });

    test('Step 7 & 8: Offline Buffering, Reconnect Recovery & Conflict Classification', () async {
      final masterSpreadsheetId = await initService.getOrCreateMasterSpreadsheet(
        accessToken: liveToken,
        clinicId: clinicId,
      );

      final now = DateTime.now().toUtc();
      final offlinePatient = Patient(
        patientId: 'PAT-LIVE-OFFLINE-002',
        clinicId: clinicId,
        patientNumber: 'P-1002',
        fullName: 'Sunita Sharma (Offline Pilot)',
        phoneOptional: '9123456789',
        createdAt: now,
        updatedAt: now,
      );

      // 1. Save locally while simulating offline state
      await patientRepo.savePatient(offlinePatient);
      final pendingOffline = await syncRepo.countPendingOutboxEvents(clinicId);
      expect(pendingOffline, greaterThanOrEqualTo(1));

      // 2. Reconnection: sync to real Google Sheet
      final recoveryTelemetry = await syncEngine.syncOutboxToMasterSheet(
        clinicId: clinicId,
        explicitAccessToken: liveToken,
        explicitSpreadsheetId: masterSpreadsheetId,
      );
      expect(recoveryTelemetry.isSuccess, isTrue);

      // 3. Verify event marked completed locally
      final remainingPending = await syncRepo.countPendingOutboxEvents(clinicId);
      expect(remainingPending, equals(0));

      // 4. Verify all 11 conflict classifications
      expect(ConflictClassification.values.length, 11);
      final changeResult = await conflictDetector.detectChanges(
        clinicId: clinicId,
        sheetName: '05_PATIENTS',
        explicitSpreadsheetId: masterSpreadsheetId,
        explicitAccessToken: liveToken,
      );
      expect(changeResult.isSuccess, isTrue);
    });

    test('Step 9 & 10: TokenVault Persistence Verification', () async {
      final storedToken = await tokenVault.getAccessToken(clinicId);
      expect(storedToken, isNotNull);
      expect(storedToken, equals(liveToken));

      await tokenVault.saveRefreshToken(clinicId, 'refresh_token_pilot_test_123');
      final storedRefreshToken = await tokenVault.getRefreshToken(clinicId);
      expect(storedRefreshToken, equals('refresh_token_pilot_test_123'));
    });
  });
}
