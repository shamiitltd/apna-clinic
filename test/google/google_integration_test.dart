// Apna Clinic - Google Drive & Google Sheets Integration Test Suite (Milestone 2)
// Primary source of truth: User Request Steps 2-9 & Phase 3 Architecture Plan
// Validates: Least-privilege OAuth scopes, Drive folder/file location,
// canonical 20-sheet Master Sheet schema validation, error handling, and offline invariance.

import 'package:flutter_test/flutter_test.dart';

import 'package:apna_clinic/core/config/app_config.dart';
import 'package:apna_clinic/core/errors/failures.dart';
import 'package:apna_clinic/domain/entities/entities.dart';
import 'package:apna_clinic/domain/enums/domain_enums.dart';
import 'package:apna_clinic/infrastructure/database/local_database.dart';
import 'package:apna_clinic/infrastructure/database/storage_adapter.dart';
import 'package:apna_clinic/infrastructure/google/mock_google_integration.dart';
import 'package:apna_clinic/infrastructure/repositories/infrastructure_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('APNA CLINIC — PHASE 3 MILESTONE 2 INTEGRATION TESTS', () {
    // -------------------------------------------------------------------------
    // 1. OAUTH LEAST-PRIVILEGE SCOPES VERIFICATION
    // -------------------------------------------------------------------------
    group('1. OAuth Least-Privilege Scopes', () {
      test('Default configuration specifies least-privilege scopes', () {
        final scopes = AppConfig.current.googleOAuthScopes;

        expect(scopes, contains('openid'));
        expect(scopes, contains('email'));
        expect(scopes, contains('profile'));
        expect(scopes, contains('https://www.googleapis.com/auth/drive.file'));
        expect(scopes, contains('https://www.googleapis.com/auth/spreadsheets'));

        // Non-negotiable security rule: Broad Drive access must NEVER be requested
        expect(
          scopes.contains('https://www.googleapis.com/auth/drive'),
          isFalse,
          reason: 'Broad drive full-access scope must not be requested',
        );
      });
    });

    // -------------------------------------------------------------------------
    // 2. GOOGLE DRIVE INTEGRATION FOUNDATION
    // -------------------------------------------------------------------------
    group('2. Google Drive Integration Foundation', () {
      late MockGoogleDriveClient driveClient;
      const testToken = 'mock_valid_access_token_123';

      setUp(() {
        driveClient = MockGoogleDriveClient();
      });

      test('Verify Google account access via Drive API', () async {
        final accountInfo = await driveClient.verifyAccountAccess(
          accessToken: testToken,
        );

        expect(accountInfo.emailAddress, equals('doctor.sharma@apnaclinic.in'));
        expect(accountInfo.displayName, equals('Dr. Rajesh Sharma'));
      });

      test('Locate or create clinic application folder hierarchy', () async {
        final rootFolderId = await driveClient.getOrCreateFolder(
          accessToken: testToken,
          folderName: 'ApnaClinic',
        );
        expect(rootFolderId, isNotEmpty);

        final clinicFolderId = await driveClient.getOrCreateFolder(
          accessToken: testToken,
          folderName: 'clinic_primary_demo',
          parentFolderId: rootFolderId,
        );
        expect(clinicFolderId, isNotEmpty);
      });

      test('Locate designated Master Sheet file in clinic folder', () async {
        final file = await driveClient.locateMasterSheetFile(
          accessToken: testToken,
          parentFolderId: 'folder_clinic_demo',
          fileName: 'APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL',
        );

        expect(file, isNotNull);
        expect(file?.id, equals('sheet_master_template_001'));
        expect(file?.name, equals('APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL'));
        expect(file?.mimeType, equals('application/vnd.google-apps.spreadsheet'));
      });

      test('Verify file permissions (canEdit, canRead)', () async {
        final permissions = await driveClient.verifyFilePermissions(
          accessToken: testToken,
          fileId: 'sheet_master_template_001',
        );

        expect(permissions.canRead, isTrue);
        expect(permissions.canEdit, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // 3. GOOGLE SHEETS INTEGRATION & CANONICAL MASTER SHEET SCHEMA VALIDATION
    // -------------------------------------------------------------------------
    group('3. Google Sheets Integration & Schema Validation', () {
      late MockGoogleSheetsClient sheetsClient;
      const testToken = 'mock_valid_access_token_123';
      const sheetId = 'sheet_master_template_001';

      setUp(() {
        sheetsClient = MockGoogleSheetsClient();
      });

      test('Reads spreadsheet metadata containing all 20 canonical worksheets', () async {
        final metadata = await sheetsClient.getSpreadsheetMetadata(
          accessToken: testToken,
          spreadsheetId: sheetId,
        );

        expect(metadata.title, equals('ApnaClinic_Master_Production_v1'));
        expect(metadata.sheetNames.length, equals(20));
        expect(
          metadata.sheetNames,
          equals(MasterSheetSchema.canonicalSheetNames),
        );
      });

      test('Validates canonical Phase 2 Master Sheet schema successfully', () async {
        final validation = await sheetsClient.validateMasterSheetSchema(
          accessToken: testToken,
          spreadsheetId: sheetId,
        );

        expect(validation.isValid, isTrue);
        expect(validation.missingSheets, isEmpty);
        expect(validation.missingHeaders, isEmpty);
        expect(validation.misplacedHeaders, isEmpty);
        expect(validation.errorMessage, isNull);
      });

      test('Detects missing worksheet and reports structured error', () async {
        sheetsClient.simulateMissingSheet = true; // Removes 05_PATIENTS

        final validation = await sheetsClient.validateMasterSheetSchema(
          accessToken: testToken,
          spreadsheetId: sheetId,
        );

        expect(validation.isValid, isFalse);
        expect(validation.missingSheets, contains('05_PATIENTS'));
        expect(validation.errorMessage, contains('Missing worksheets: 05_PATIENTS'));
      });

      test('Detects missing column in worksheet and halts operation', () async {
        sheetsClient.simulateMissingColumn = true; // Removes total_amount from 10_BILLING

        final validation = await sheetsClient.validateMasterSheetSchema(
          accessToken: testToken,
          spreadsheetId: sheetId,
        );

        expect(validation.isValid, isFalse);
        expect(validation.missingHeaders.containsKey('10_BILLING'), isTrue);
        expect(validation.missingHeaders['10_BILLING'], contains('total_amount'));
      });

      test('Detects misplaced / reordered column header sequence', () async {
        sheetsClient.simulateMisplacedColumn = true; // Swaps start_time and end_time in 06_APPOINTMENTS

        final validation = await sheetsClient.validateMasterSheetSchema(
          accessToken: testToken,
          spreadsheetId: sheetId,
        );

        expect(validation.isValid, isFalse);
        expect(validation.misplacedHeaders.containsKey('06_APPOINTMENTS'), isTrue);
      });

      test('Reads controlled lookup items from 20_LOOKUPS by category', () async {
        final genders = await sheetsClient.readLookupCategory(
          accessToken: testToken,
          spreadsheetId: sheetId,
          category: 'GENDER',
        );

        expect(genders.length, equals(3));
        expect(genders.map((g) => g.code), containsAll(['MALE', 'FEMALE', 'OTHER']));
        expect(genders.first.category, equals('GENDER'));

        final appointmentStatuses = await sheetsClient.readLookupCategory(
          accessToken: testToken,
          spreadsheetId: sheetId,
          category: 'APPOINTMENT_STATUS',
        );

        expect(appointmentStatuses.length, equals(2));
        expect(appointmentStatuses.map((s) => s.code), containsAll(['SCHEDULED', 'COMPLETED']));
      });
    });

    // -------------------------------------------------------------------------
    // 4. STRUCTURED ERROR HANDLING & RESILIENCE
    // -------------------------------------------------------------------------
    group('4. Structured Error Handling & Resilience', () {
      late MockGoogleDriveClient driveClient;
      late MockGoogleSheetsClient sheetsClient;
      const testToken = 'mock_token';

      setUp(() {
        driveClient = MockGoogleDriveClient();
        sheetsClient = MockGoogleSheetsClient();
      });

      test('Expired Token (401) triggers AuthorizationFailure', () async {
        driveClient.simulateAuthExpired = true;
        sheetsClient.simulateAuthExpired = true;

        expect(
          () => driveClient.verifyAccountAccess(accessToken: testToken),
          throwsA(isA<AuthorizationFailure>()),
        );

        expect(
          () => sheetsClient.getSpreadsheetMetadata(
            accessToken: testToken,
            spreadsheetId: 'sheet1',
          ),
          throwsA(isA<AuthorizationFailure>()),
        );
      });

      test('Permission Denied (403) triggers AuthorizationFailure', () async {
        driveClient.simulatePermissionDenied = true;
        sheetsClient.simulatePermissionDenied = true;

        expect(
          () => driveClient.verifyAccountAccess(accessToken: testToken),
          throwsA(isA<AuthorizationFailure>()),
        );

        expect(
          () => sheetsClient.getSpreadsheetMetadata(
            accessToken: testToken,
            spreadsheetId: 'sheet1',
          ),
          throwsA(isA<AuthorizationFailure>()),
        );
      });

      test('Resource Not Found (404) triggers DatabaseFailure', () async {
        driveClient.simulateFileNotFound = true;
        sheetsClient.simulateSpreadsheetNotFound = true;

        expect(
          () => driveClient.verifyFilePermissions(
            accessToken: testToken,
            fileId: 'non_existent_id',
          ),
          throwsA(isA<DatabaseFailure>()),
        );

        expect(
          () => sheetsClient.getSpreadsheetMetadata(
            accessToken: testToken,
            spreadsheetId: 'non_existent_id',
          ),
          throwsA(isA<DatabaseFailure>()),
        );
      });

      test('Rate Limit Exceeded (429) triggers QuotaExceededFailure', () async {
        driveClient.simulateRateLimit = true;
        sheetsClient.simulateRateLimit = true;

        expect(
          () => driveClient.verifyAccountAccess(accessToken: testToken),
          throwsA(isA<QuotaExceededFailure>()),
        );

        expect(
          () => sheetsClient.getSpreadsheetMetadata(
            accessToken: testToken,
            spreadsheetId: 'sheet1',
          ),
          throwsA(isA<QuotaExceededFailure>()),
        );
      });

      test('Google Service Unavailable (503) triggers NetworkFailure', () async {
        driveClient.simulateServiceUnavailable = true;
        sheetsClient.simulateServiceUnavailable = true;

        expect(
          () => driveClient.verifyAccountAccess(accessToken: testToken),
          throwsA(isA<NetworkFailure>()),
        );

        expect(
          () => sheetsClient.getSpreadsheetMetadata(
            accessToken: testToken,
            spreadsheetId: 'sheet1',
          ),
          throwsA(isA<NetworkFailure>()),
        );
      });

      test('Offline / Disconnected network triggers NetworkFailure safely', () async {
        driveClient.simulateOffline = true;
        sheetsClient.simulateOffline = true;

        expect(
          () => driveClient.verifyAccountAccess(accessToken: testToken),
          throwsA(isA<NetworkFailure>()),
        );

        expect(
          () => sheetsClient.getSpreadsheetMetadata(
            accessToken: testToken,
            spreadsheetId: 'sheet1',
          ),
          throwsA(isA<NetworkFailure>()),
        );
      });
    });

    // -------------------------------------------------------------------------
    // 5. OFFLINE-FIRST INVARIANCE & LOCAL DATABASE ISOLATION
    // -------------------------------------------------------------------------
    group('5. Offline-First Invariance & Local Database Isolation', () {
      test('Complete clinical workflow executes locally while Google Drive & Sheets are offline', () async {
        // 1. Initialize purely local database
        final db = LocalDatabase(MemoryStorageAdapter());
        await db.initialize();

        final patientRepo = PatientRepository(db);
        final visitRepo = VisitRepository(db);
        final billingRepo = BillingRepository(db);
        final syncRepo = SyncRepository(db);

        // 2. Simulate Google Drive & Sheets in completely offline/broken state
        final offlineDrive = MockGoogleDriveClient()..simulateOffline = true;
        final offlineSheets = MockGoogleSheetsClient()..simulateOffline = true;

        expect(
          () => offlineDrive.verifyAccountAccess(accessToken: 'token'),
          throwsA(isA<NetworkFailure>()),
        );
        expect(
          () => offlineSheets.getSpreadsheetMetadata(
            accessToken: 'token',
            spreadsheetId: 'sheet1',
          ),
          throwsA(isA<NetworkFailure>()),
        );

        // 3. Register patient locally (Must succeed 100%)
        final patient = Patient(
          patientId: 'pat_offline_001',
          clinicId: 'clinic_primary_demo',
          patientNumber: 'P-2026-0501',
          fullName: 'Ananya Roy',
          phoneOptional: '+919876500501',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );
        await patientRepo.savePatient(patient);

        final savedPat = await patientRepo.getPatientById(
          'clinic_primary_demo',
          'pat_offline_001',
        );
        expect(savedPat, isNotNull);
        expect(savedPat?.fullName, equals('Ananya Roy'));

        // 4. Create visit and assign monotonic token locally (Must succeed 100%)
        final visit = Visit(
          visitId: 'v_offline_001',
          clinicId: 'clinic_primary_demo',
          patientId: 'pat_offline_001',
          doctorId: 'doc_sharma_01',
          visitDateLocal: '2026-09-30',
          checkinAt: DateTime.now().toUtc(),
          tokenNumber: 0,
          tokenScopeKey: '',
          createdByStaffId: 'staff_reception_01',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );

        final createdVisit = await visitRepo.createVisitAtomic(
          visit: visit,
          idempotencyKey: 'idemp_v_offline_001',
          deviceId: 'device_primary_web',
          staffId: 'staff_reception_01',
        );
        expect(createdVisit.tokenNumber, equals(1));

        // 5. Create invoice and settle payment locally (Must succeed 100%)
        final invoice = Invoice(
          invoiceId: 'inv_offline_001',
          clinicId: 'clinic_primary_demo',
          invoiceNumber: 'INV-2026-0501',
          financialYear: '2026-2027',
          patientId: 'pat_offline_001',
          visitId: createdVisit.visitId,
          issueDateLocal: '2026-09-30',
          subtotalMinor: 50000,
          discountMinor: 5000,
          taxMinor: 0,
          totalMinor: 45000,
          paidMinor: 0,
          balanceMinor: 45000,
          createdByStaffId: 'staff_reception_01',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );

        final item = InvoiceItem(
          invoiceItemId: 'item_offline_001',
          clinicId: 'clinic_primary_demo',
          invoiceId: 'inv_offline_001',
          description: 'Consultation Fee',
          quantity: 1,
          unitPriceMinor: 50000,
          discountMinor: 5000,
          lineTotalMinor: 45000,
          createdAt: DateTime.now().toUtc(),
        );

        await billingRepo.createInvoiceAtomic(
          invoice: invoice,
          items: [item],
          idempotencyKey: 'idemp_inv_offline_001',
        );

        await billingRepo.recordPayment(
          payment: Payment(
            paymentId: 'pay_offline_001',
            clinicId: 'clinic_primary_demo',
            invoiceId: invoice.invoiceId,
            amountMinor: 45000,
            method: PaymentMethod.cash,
            receivedAt: DateTime.now().toUtc(),
            receivedByStaffId: 'staff_reception_01',
            createdAt: DateTime.now().toUtc(),
          ),
          idempotencyKey: 'idemp_pay_offline_001',
        );

        final settledInv = await billingRepo.getInvoiceById(
          'clinic_primary_demo',
          invoice.invoiceId,
        );
        expect(settledInv?.status, equals(InvoiceStatus.paid));
        expect(settledInv?.balanceMinor, equals(0));

        // 6. Verify local outbox staged events cleanly for later sync
        final pendingOutbox =
            await syncRepo.getPendingOutboxEvents('clinic_primary_demo');
        expect(pendingOutbox.isNotEmpty, isTrue);
        expect(
          pendingOutbox.any((e) => e.entityType.toLowerCase() == 'patients'),
          isTrue,
        );
        expect(
          pendingOutbox.any((e) => e.entityType.toLowerCase() == 'visits'),
          isTrue,
        );
        expect(
          pendingOutbox.any((e) => e.entityType.toLowerCase() == 'invoices'),
          isTrue,
        );
      });
    });
  });
}
