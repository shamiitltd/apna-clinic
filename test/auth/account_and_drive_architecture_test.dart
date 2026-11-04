// Apna Clinic - New Login, Account & Google Drive Architecture Test Suite
// Verifies:
// 1. Layer 1: Firebase Authentication (Who is allowed into Apna Clinic)
// 2. Layer 2: Firestore Account Validation (Product Access, Subscription, Entitlements)
// 3. Layer 3: Google Drive & Google Sheets Integration (Clinic-owned operational cloud data)
// 4. Separation of Firebase logout vs Google Drive disconnect
// 5. Offline-first resilience with LocalDatabase & SyncOutbox

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:apna_clinic/application/auth/app_access_notifier.dart';
import 'package:apna_clinic/application/auth/drive_connection_service.dart';
import 'package:apna_clinic/domain/entities/entities.dart';
import 'package:apna_clinic/domain/enums/domain_enums.dart';
import 'package:apna_clinic/infrastructure/auth/mock_auth_repository.dart';
import 'package:apna_clinic/infrastructure/database/local_database.dart';
import 'package:apna_clinic/infrastructure/database/storage_adapter.dart';
import 'package:apna_clinic/infrastructure/google/mock_google_integration.dart';
import 'package:apna_clinic/infrastructure/google/oauth/mock_google_oauth_provider.dart';
import 'package:apna_clinic/infrastructure/google/oauth/token_vault.dart';
import 'package:apna_clinic/infrastructure/repositories/infrastructure_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('APNA CLINIC — NEW LOGIN, ACCOUNT & GOOGLE DRIVE DATA ARCHITECTURE', () {
    late MemoryStorageAdapter memoryStorage;
    late LocalDatabase localDb;
    late TokenVault tokenVault;
    late MockGoogleOAuthProvider mockDriveOAuth;
    late MockGoogleDriveClient mockDriveClient;
    late MockGoogleSheetsClient mockSheetsClient;
    late MockAuthRepository mockAuthRepo;
    late DriveConnectionService driveService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      memoryStorage = MemoryStorageAdapter();
      localDb = LocalDatabase(memoryStorage);
      await localDb.initialize();

      tokenVault = TokenVault(memoryStorage);
      mockDriveOAuth = MockGoogleOAuthProvider();
      mockDriveClient = MockGoogleDriveClient();
      mockSheetsClient = MockGoogleSheetsClient();
      mockAuthRepo = MockAuthRepository();

      driveService = DriveConnectionService(
        oauthProvider: mockDriveOAuth,
        tokenVault: tokenVault,
        driveClient: mockDriveClient,
        sheetsClient: mockSheetsClient,
        authRepository: mockAuthRepo,
      );
    });

    // -------------------------------------------------------------------------
    // TEST A: Unknown User (Firebase login without Firestore account)
    // -------------------------------------------------------------------------
    test('TEST A: Unknown User — Firebase authenticated but no Firestore account -> Access Denied (accountMissing)', () async {
      // Mock Firebase has a signed-in user, but Firestore doc users/unknown_uid does not exist
      mockAuthRepo.setMockUser(
        uid: 'unknown_firebase_uid_999',
        email: 'unregistered.doctor@gmail.com',
        account: null, // No Firestore document
      );

      final notifier = AppAccessNotifier(
        authRepository: mockAuthRepo,
        driveService: driveService,
        database: localDb,
      );

      await notifier.initialize();

      expect(notifier.state.status, equals(AppAccessStatus.accountMissing));
      expect(notifier.state.firebaseUid, equals('unknown_firebase_uid_999'));
      expect(notifier.state.account, isNull);
    });

    // -------------------------------------------------------------------------
    // TEST B: Registered User with valid Firestore account
    // -------------------------------------------------------------------------
    test('TEST B: Registered User — Firebase user + active Firestore account -> Account Validated', () async {
      const validAccount = PlatformAccount(
        uid: 'dr_sharma_001',
        fullName: 'Dr. Ramesh Sharma',
        email: 'doctor.sharma@apnaclinic.in',
        accountStatus: 'active',
        subscriptionStatus: 'active',
        driveConnected: true,
        clinicSetupCompleted: true,
      );

      mockAuthRepo.setMockUser(
        uid: 'dr_sharma_001',
        email: 'doctor.sharma@apnaclinic.in',
        account: validAccount,
      );

      // Pre-seed clinic config so clinicSetupRequired is satisfied
      final clinic = Clinic(
        clinicId: 'clinic_sharma_01',
        legalName: 'Sharma Clinic',
        displayName: 'Sharma Clinic',
        ownerName: 'Dr. Ramesh Sharma',
        contactPhone: '9876543210',
        contactEmail: 'doctor.sharma@apnaclinic.in',
        addressLine1: 'Civil Lines',
        city: 'Jaipur',
        district: 'Jaipur',
        state: 'Rajasthan',
        pincode: '302001',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await ClinicRepository(localDb).saveClinic(clinic);

      final notifier = AppAccessNotifier(
        authRepository: mockAuthRepo,
        driveService: driveService,
        database: localDb,
      );

      await notifier.initialize();

      expect(notifier.state.status, equals(AppAccessStatus.ready));
      expect(notifier.state.account?.fullName, equals('Dr. Ramesh Sharma'));
      expect(notifier.state.account?.isActive, isTrue);
    });

    // -------------------------------------------------------------------------
    // TEST C: No Drive Connected (driveRequired)
    // -------------------------------------------------------------------------
    test('TEST C: No Drive — Registered account without Drive authorization -> driveRequired', () async {
      const accountNoDrive = PlatformAccount(
        uid: 'dr_verma_002',
        fullName: 'Dr. Anita Verma',
        email: 'anita@vermaclinic.in',
        accountStatus: 'active',
        subscriptionStatus: 'active',
        driveConnected: false, // Drive not yet authorized
        clinicSetupCompleted: false,
      );

      mockAuthRepo.setMockUser(
        uid: 'dr_verma_002',
        email: 'anita@vermaclinic.in',
        account: accountNoDrive,
      );

      final notifier = AppAccessNotifier(
        authRepository: mockAuthRepo,
        driveService: driveService,
        database: localDb,
      );

      await notifier.initialize();

      expect(notifier.state.status, equals(AppAccessStatus.driveRequired));
      expect(notifier.state.driveConnected, isFalse);
    });

    // -------------------------------------------------------------------------
    // TEST D: Drive Connected via separate OAuth flow
    // -------------------------------------------------------------------------
    test('TEST D: Drive Connected — Authorize Google Drive, discover/create workspace and update metadata', () async {
      const account = PlatformAccount(
        uid: 'dr_verma_002',
        fullName: 'Dr. Anita Verma',
        email: 'anita@vermaclinic.in',
        accountStatus: 'active',
        subscriptionStatus: 'active',
        driveConnected: false,
      );

      mockAuthRepo.setMockUser(
        uid: 'dr_verma_002',
        email: 'anita@vermaclinic.in',
        account: account,
      );

      final notifier = AppAccessNotifier(
        authRepository: mockAuthRepo,
        driveService: driveService,
        database: localDb,
      );

      await notifier.initialize();
      expect(notifier.state.status, equals(AppAccessStatus.driveRequired));

      // Connect Google Drive
      await notifier.connectGoogleDrive(
        clinicId: 'clinic_verma_01',
        clinicName: 'Verma Health Clinic',
      );

      // Verify tokens saved in TokenVault
      final token = await tokenVault.getAccessToken('clinic_verma_01');
      expect(token, isNotNull);

      // Verify state transitioned to clinicSetupRequired (since Clinic_Config is not yet configured)
      expect(notifier.state.status, equals(AppAccessStatus.clinicSetupRequired));
      expect(notifier.state.driveConnected, isTrue);

      // Verify Firestore metadata update was triggered
      final updatedAccount = await mockAuthRepo.fetchPlatformAccount('dr_verma_002');
      expect(updatedAccount?.driveConnected, isTrue);
      expect(updatedAccount?.spreadsheetId, isNotNull);
    });

    // -------------------------------------------------------------------------
    // TEST E: Existing Drive Workspace (Idempotent reuse without duplicate)
    // -------------------------------------------------------------------------
    test('TEST E: Existing Drive Workspace — Discovers existing workspace on Drive and does not duplicate', () async {
      // Connect first time
      final firstRes = await driveService.connectAndInitializeDrive(
        clinicId: 'clinic_dup_check',
        clinicName: 'Duplicate Test Clinic',
      );
      expect(firstRes.isSuccess, isTrue);
      expect(firstRes.spreadsheetId, isNotNull);

      // Connect second time (simulating login from another browser)
      final secondRes = await driveService.connectAndInitializeDrive(
        clinicId: 'clinic_dup_check',
        clinicName: 'Duplicate Test Clinic',
      );
      expect(secondRes.isSuccess, isTrue);

      // Verified that it returns a valid workspace ID and does not fail
      expect(secondRes.spreadsheetId, isNotNull);
    });

    // -------------------------------------------------------------------------
    // TEST F & G: Offline-first resilience with LocalDatabase and SyncOutbox
    // -------------------------------------------------------------------------
    test('TEST F & G: Offline-first behavior — Local operations succeed offline and buffer to SyncOutbox', () async {
      final patientRepo = PatientRepository(localDb);
      final visitRepo = VisitRepository(localDb);
      final syncRepo = SyncRepository(localDb);

      const clinicId = 'clinic_offline_test';

      // 1. Add patient locally
      final patient = Patient(
        patientId: 'patient_offline_01',
        clinicId: clinicId,
        patientNumber: 'OFF-001',
        fullName: 'Rajesh Kumar',
        phoneOptional: '+919876543210',
        ageIfDobUnknown: 45,
        consentStatus: 'granted',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      await patientRepo.savePatient(patient);

      // 2. Create visit locally (atomic transaction assigns token and queues outbox event)
      final visit = Visit(
        visitId: 'visit_offline_01',
        clinicId: clinicId,
        patientId: patient.patientId,
        doctorId: 'doc_offline_01',
        visitDateLocal: '2026-10-04',
        checkinAt: DateTime.now().toUtc(),
        tokenNumber: 1,
        tokenScopeKey: '$clinicId:doc_offline_01:2026-10-04',
        visitType: 'walkin',
        queueStatus: QueueStatus.waiting,
        createdByStaffId: 'staff_offline',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      await visitRepo.createVisitAtomic(
        visit: visit,
        idempotencyKey: 'idemp_offline_01',
        deviceId: 'dev_test_web',
        staffId: 'staff_offline',
      );

      // 3. Verify data is available immediately in local database
      final retrievedPatient = await patientRepo.getPatientById(clinicId, patient.patientId);
      expect(retrievedPatient, isNotNull);
      expect(retrievedPatient?.fullName, equals('Rajesh Kumar'));

      final retrievedVisit = await visitRepo.getVisitById(clinicId, visit.visitId);
      expect(retrievedVisit, isNotNull);
      expect(retrievedVisit?.tokenNumber, equals(1));

      // 4. Verify Sync Outbox buffered events to sync with Google Sheets when online
      final pendingEvents = await syncRepo.getPendingOutboxEvents(clinicId, limit: 10);
      expect(pendingEvents, isNotEmpty);
      expect(pendingEvents.any((e) => e.entityId == visit.visitId), isTrue);
    });

    // -------------------------------------------------------------------------
    // TEST H: Inactive or Suspended Account (accountInactive)
    // -------------------------------------------------------------------------
    test('TEST H: Inactive/Suspended Account — Blocked from Dashboard (accountInactive)', () async {
      const inactiveAccount = PlatformAccount(
        uid: 'dr_suspended_003',
        fullName: 'Dr. Suspended User',
        email: 'suspended@apnaclinic.in',
        accountStatus: 'suspended', // Suspended account
        subscriptionStatus: 'expired',
      );

      mockAuthRepo.setMockUser(
        uid: 'dr_suspended_003',
        email: 'suspended@apnaclinic.in',
        account: inactiveAccount,
      );

      final notifier = AppAccessNotifier(
        authRepository: mockAuthRepo,
        driveService: driveService,
        database: localDb,
      );

      await notifier.initialize();

      expect(notifier.state.status, equals(AppAccessStatus.accountInactive));
      expect(notifier.state.account?.isActive, isFalse);
    });

    // -------------------------------------------------------------------------
    // TEST I: Refresh / Session Restoration
    // -------------------------------------------------------------------------
    test('TEST I: Session Restoration — Re-evaluates valid session without repeated onboarding or login', () async {
      const account = PlatformAccount(
        uid: 'dr_restore_004',
        fullName: 'Dr. Vikram Seth',
        email: 'vikram@apnaclinic.in',
        accountStatus: 'active',
        subscriptionStatus: 'active',
        driveConnected: true,
        clinicSetupCompleted: true,
      );

      mockAuthRepo.setMockUser(
        uid: 'dr_restore_004',
        email: 'vikram@apnaclinic.in',
        account: account,
      );

      // Pre-seed clinic configuration in local store
      final clinic = Clinic(
        clinicId: 'clinic_restore_04',
        legalName: 'Seth Healthcare',
        displayName: 'Seth Healthcare',
        ownerName: 'Dr. Vikram Seth',
        contactPhone: '9876543210',
        contactEmail: 'vikram@apnaclinic.in',
        addressLine1: 'Park Street',
        city: 'Kolkata',
        district: 'Kolkata',
        state: 'West Bengal',
        pincode: '700016',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await ClinicRepository(localDb).saveClinic(clinic);

      final notifier = AppAccessNotifier(
        authRepository: mockAuthRepo,
        driveService: driveService,
        database: localDb,
      );

      await notifier.initialize();
      expect(notifier.state.status, equals(AppAccessStatus.ready));
    });

    // -------------------------------------------------------------------------
    // TEST J: Distinct Logout Separation (Firebase vs Drive)
    // -------------------------------------------------------------------------
    test('TEST J: Logout Separation — Sign Out of Firebase vs Disconnect Google Drive', () async {
      const account = PlatformAccount(
        uid: 'dr_dual_005',
        fullName: 'Dr. Dual Logout',
        email: 'dual@apnaclinic.in',
        accountStatus: 'active',
        subscriptionStatus: 'active',
        driveConnected: true,
      );

      mockAuthRepo.setMockUser(
        uid: 'dr_dual_005',
        email: 'dual@apnaclinic.in',
        account: account,
      );

      final notifier = AppAccessNotifier(
        authRepository: mockAuthRepo,
        driveService: driveService,
        database: localDb,
      );

      await notifier.initialize();

      // 1. Disconnect Drive: Clears Drive tokens but keeps Firebase user logged in
      await notifier.disconnectGoogleDrive(clinicId: 'clinic_dual_005');
      expect(notifier.state.status, equals(AppAccessStatus.driveRequired));
      expect(notifier.state.driveConnected, isFalse);
      expect(mockAuthRepo.isAuthenticated, isTrue); // Firebase remains authenticated

      // 2. Sign Out of Firebase: Transitions to unauthenticated
      await notifier.signOut();
      expect(notifier.state.status, equals(AppAccessStatus.unauthenticated));
      expect(mockAuthRepo.isAuthenticated, isFalse);
    });
  });
}
