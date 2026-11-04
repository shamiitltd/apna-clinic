// Apna Clinic - Google Authentication Test Suite (Milestone 1)
// Primary source of truth: User Request Step 7 & Phase 3 Architecture Plan
// Tests all 11 mandatory scenarios (A through K) for Google Authentication & Offline Invariance.

import 'package:flutter_test/flutter_test.dart';

import 'package:apna_clinic/application/auth/auth_service.dart';
import 'package:apna_clinic/application/providers.dart';
import 'package:apna_clinic/core/permissions/roles.dart';
import 'package:apna_clinic/domain/entities/entities.dart';
import 'package:apna_clinic/domain/enums/domain_enums.dart';
import 'package:apna_clinic/infrastructure/database/local_database.dart';
import 'package:apna_clinic/infrastructure/database/storage_adapter.dart';
import 'package:apna_clinic/infrastructure/google/oauth/mock_google_oauth_provider.dart';
import 'package:apna_clinic/infrastructure/google/oauth/token_vault.dart';
import 'package:apna_clinic/infrastructure/repositories/infrastructure_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Common Test Fixtures Helper
  (AuthService, MockGoogleOAuthProvider, TokenVault, SessionNotifier, MemoryStorageAdapter) createAuthTestHarness([
    MemoryStorageAdapter? sharedStorage,
  ]) {
    final storage = sharedStorage ?? MemoryStorageAdapter();
    final vault = TokenVault(storage);
    final mockOauth = MockGoogleOAuthProvider();
    final notifier = SessionNotifier();
    final service = AuthService(
      oauthProvider: mockOauth,
      tokenVault: vault,
      sessionNotifier: notifier,
    );
    return (service, mockOauth, vault, notifier, storage);
  }

  group('APNA CLINIC — PHASE 3 MILESTONE 1 AUTHENTICATION TESTS', () {
    // ----------------------------------------------------
    // TEST A: Google Sign-In Success
    // ----------------------------------------------------
    test('Scenario A: Google Sign-In Success', () async {
      final (service, _, vault, notifier, _) = createAuthTestHarness();

      final result = await service.signIn(clinicId: 'clinic_test_001');

      expect(result.isSuccess, isTrue);
      expect(result.user, isNotNull);
      expect(result.user?.email, equals('doctor.sharma@apnaclinic.in'));
      expect(result.tokens, isNotNull);
      expect(result.tokens!.isExpired, isFalse);
      expect(notifier.currentSessionState.isGoogleAuthenticated, isTrue);
      expect(
        notifier.currentSessionState.googleUserEmail,
        equals('doctor.sharma@apnaclinic.in'),
      );
      expect(
        notifier.currentSessionState.authStatus,
        equals(AuthStatus.authenticated),
      );

      // Verify encrypted persistence in vault
      final savedToken = await vault.getRefreshToken('clinic_test_001');
      expect(savedToken, isNotNull);
      expect(savedToken!.startsWith('mock_refresh_token_'), isTrue);

      final cachedUser = await vault.getCachedUser('clinic_test_001');
      expect(cachedUser, isNotNull);
      expect(cachedUser?.email, equals('doctor.sharma@apnaclinic.in'));
    });

    // ----------------------------------------------------
    // TEST B: User Cancellation
    // ----------------------------------------------------
    test('Scenario B: User Cancellation Handling', () async {
      final (service, mockOauth, _, notifier, _) = createAuthTestHarness();
      mockOauth.simulateCancellation = true;

      final result = await service.signIn(clinicId: 'clinic_test_001');

      expect(result.isSuccess, isFalse);
      expect(result.isCancelled, isTrue);
      expect(result.errorCode, equals('CANCELLED'));
      expect(notifier.currentSessionState.isGoogleAuthenticated, isFalse);
      expect(
        notifier.currentSessionState.authStatus,
        equals(AuthStatus.cancelled),
      );
      expect(
        notifier.currentSessionState.role,
        equals(UserRole.receptionist),
      );
      expect(notifier.currentClinicId, equals('clinic_primary_demo'));
    });

    // ----------------------------------------------------
    // TEST C: Authentication Failure
    // ----------------------------------------------------
    test('Scenario C: Authentication Failure Handling', () async {
      final (service, mockOauth, _, notifier, _) = createAuthTestHarness();
      mockOauth.simulateServiceUnavailable = true;

      final result = await service.signIn(clinicId: 'clinic_test_001');

      expect(result.isSuccess, isFalse);
      expect(result.isCancelled, isFalse);
      expect(result.errorCode, equals('SERVICE_UNAVAILABLE'));
      expect(
        notifier.currentSessionState.authStatus,
        equals(AuthStatus.error),
      );
      expect(notifier.currentSessionState.authError, isNotNull);
    });

    // ----------------------------------------------------
    // TEST D: Sign-Out & Vault Purge
    // ----------------------------------------------------
    test('Scenario D: Sign-Out and Vault Purge', () async {
      final (service, _, vault, notifier, _) = createAuthTestHarness();

      // Sign in first
      await service.signIn(clinicId: 'clinic_test_001');
      expect(notifier.currentSessionState.isGoogleAuthenticated, isTrue);

      // Now sign out
      await service.signOut(clinicId: 'clinic_test_001');

      expect(notifier.currentSessionState.isGoogleAuthenticated, isFalse);
      expect(notifier.currentSessionState.googleUserEmail, isNull);
      expect(
        notifier.currentSessionState.authStatus,
        equals(AuthStatus.unauthenticated),
      );

      // Verify vault purge
      final tokenAfter = await vault.getRefreshToken('clinic_test_001');
      expect(tokenAfter, isNull);
      final userAfter = await vault.getCachedUser('clinic_test_001');
      expect(userAfter, isNull);
    });

    // ----------------------------------------------------
    // TEST E: Session Restoration
    // ----------------------------------------------------
    test('Scenario E: Silent Session Restoration', () async {
      final storage = MemoryStorageAdapter();
      final (service1, _, vault1, _, _) = createAuthTestHarness(storage);

      // Initial sign-in saves credentials to storage
      await service1.signIn(clinicId: 'clinic_test_001');
      expect(await vault1.getRefreshToken('clinic_test_001'), isNotNull);

      // Instantiate a new AuthService (simulating app reload)
      final vault2 = TokenVault(storage);
      final mockOauth2 = MockGoogleOAuthProvider();
      final notifier2 = SessionNotifier();
      final service2 = AuthService(
        oauthProvider: mockOauth2,
        tokenVault: vault2,
        sessionNotifier: notifier2,
      );

      final restored = await service2.restoreSession(clinicId: 'clinic_test_001');

      expect(restored, isNotNull);
      expect(restored?.isSuccess, isTrue);
      expect(restored?.user?.email, equals('doctor.sharma@apnaclinic.in'));
      expect(restored?.tokens?.accessToken.isNotEmpty, isTrue);
      expect(notifier2.currentSessionState.isGoogleAuthenticated, isTrue);
    });

    // ----------------------------------------------------
    // TEST F: Invalid/Expired Authentication State & Token Auto-Refresh
    // ----------------------------------------------------
    test('Scenario F: Invalid/Expired Token Auto-Refresh', () async {
      final (service, mockOauth, _, _, _) = createAuthTestHarness();

      // 1. Sign in with expired token
      mockOauth.simulateExpiredToken = true;
      final signinRes = await service.signIn(clinicId: 'clinic_test_001');
      expect(signinRes.tokens?.isExpired, isTrue);

      // 2. Requesting valid access token automatically refreshes via vault
      final validToken =
          await service.getValidAccessToken(clinicId: 'clinic_test_001');
      expect(validToken, isNotNull);
      expect(validToken!.startsWith('mock_refreshed_access_token_'), isTrue);

      // 3. Test revoked refresh token (invalid grant)
      mockOauth.simulateInvalidGrant = true;
      final tokenAfterRevoke = await service.getValidAccessToken(
        clinicId: 'clinic_test_001',
        forceRefresh: true,
      );
      expect(tokenAfterRevoke, isNull);
    });

    // ----------------------------------------------------
    // TEST G: No Internet / Offline Mode
    // ----------------------------------------------------
    test('Scenario G: No Internet / Offline Invariant', () async {
      final (service, mockOauth, _, notifier, _) = createAuthTestHarness();
      mockOauth.simulateNetworkError = true;

      final result = await service.signIn(clinicId: 'clinic_test_001');

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, equals('NETWORK_ERROR'));
      expect(
        notifier.currentSessionState.authStatus,
        equals(AuthStatus.error),
      );
      // Workstation must continue operating locally
      expect(notifier.currentClinicId, equals('clinic_primary_demo'));
    });

    // ----------------------------------------------------
    // TEST H: Google Service Unavailable (503)
    // ----------------------------------------------------
    test('Scenario H: Google Service Unavailable (503)', () async {
      final (service, mockOauth, _, notifier, _) = createAuthTestHarness();
      mockOauth.simulateServiceUnavailable = true;

      final result = await service.signIn(clinicId: 'clinic_test_001');

      expect(result.isSuccess, isFalse);
      expect(result.errorCode, equals('SERVICE_UNAVAILABLE'));
      expect(
        notifier.currentSessionState.clinicId,
        equals('clinic_primary_demo'),
      );
    });

    // ----------------------------------------------------
    // TEST I: Repeated Sign-In / Sign-Out Stability
    // ----------------------------------------------------
    test('Scenario I: Repeated Sign-In / Sign-Out Stability', () async {
      final (service, _, vault, notifier, _) = createAuthTestHarness();

      for (int i = 1; i <= 5; i++) {
        final res = await service.signIn(clinicId: 'clinic_test_001');
        expect(res.isSuccess, isTrue);
        expect(notifier.currentSessionState.isGoogleAuthenticated, isTrue);

        await service.signOut(clinicId: 'clinic_test_001');
        expect(notifier.currentSessionState.isGoogleAuthenticated, isFalse);
        expect(await vault.getRefreshToken('clinic_test_001'), isNull);
      }
    });

    // ----------------------------------------------------
    // TEST J: App Restart After Authentication
    // ----------------------------------------------------
    test('Scenario J: App Restart After Authentication', () async {
      final storage = MemoryStorageAdapter();

      // Session 1: User signs in
      final (serviceA, _, _, _, _) = createAuthTestHarness(storage);
      await serviceA.signIn(clinicId: 'clinic_test_001');

      // Session 2: Cold app start with same persistent storage
      final (serviceB, _, _, notifierB, _) = createAuthTestHarness(storage);
      expect(notifierB.currentSessionState.isGoogleAuthenticated, isFalse);

      final restored = await serviceB.restoreSession(clinicId: 'clinic_test_001');
      expect(restored?.isSuccess, isTrue);
      expect(
        notifierB.currentSessionState.googleUserEmail,
        equals('doctor.sharma@apnaclinic.in'),
      );
    });

    // ----------------------------------------------------
    // TEST K: Existing Application Functionality After Authentication
    // ----------------------------------------------------
    test('Scenario K: Existing Application Functionality After Authentication', () async {
      final db = LocalDatabase(MemoryStorageAdapter());
      await db.initialize();

      final patientRepo = PatientRepository(db);
      final visitRepo = VisitRepository(db);
      final billingRepo = BillingRepository(db);
      final syncRepo = SyncRepository(db);

      final (authService, _, _, notifier, _) = createAuthTestHarness();

      // 1. Authenticate with Google
      await authService.signIn(clinicId: 'clinic_live_01');
      expect(notifier.currentSessionState.isGoogleAuthenticated, isTrue);

      // 2. Execute full patient clinical workflow
      final patient = Patient(
        patientId: 'pat_auth_test_01',
        clinicId: 'clinic_live_01',
        patientNumber: 'P-2026-0099',
        fullName: 'Vikram Seth',
        phoneOptional: '+919876543299',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      await patientRepo.savePatient(patient);

      final retrievedPatient =
          await patientRepo.getPatientById('clinic_live_01', 'pat_auth_test_01');
      expect(retrievedPatient?.fullName, equals('Vikram Seth'));

      // 3. Create visit and monotonic token
      final visit = Visit(
        visitId: 'v_auth_test_01',
        clinicId: 'clinic_live_01',
        patientId: 'pat_auth_test_01',
        doctorId: 'doc_sharma_01',
        visitDateLocal: '2026-09-29',
        checkinAt: DateTime.now().toUtc(),
        tokenNumber: 0,
        tokenScopeKey: '',
        createdByStaffId: 'staff_rec_01',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      final createdVisit = await visitRepo.createVisitAtomic(
        visit: visit,
        idempotencyKey: 'idemp_v_auth_01',
        deviceId: 'dev_primary',
        staffId: 'staff_rec_01',
      );
      expect(createdVisit.tokenNumber, equals(1));

      // 4. Generate invoice and settle
      final invoice = Invoice(
        invoiceId: 'inv_auth_test_01',
        clinicId: 'clinic_live_01',
        invoiceNumber: 'INV-2026-0099',
        financialYear: '2026-2027',
        patientId: 'pat_auth_test_01',
        visitId: createdVisit.visitId,
        issueDateLocal: '2026-09-29',
        subtotalMinor: 50000,
        discountMinor: 0,
        taxMinor: 0,
        totalMinor: 50000,
        paidMinor: 0,
        balanceMinor: 50000,
        createdByStaffId: 'staff_rec_01',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      final invoiceItem = InvoiceItem(
        invoiceItemId: 'item_auth_test_01',
        clinicId: 'clinic_live_01',
        invoiceId: 'inv_auth_test_01',
        description: 'Consultation Fee',
        quantity: 1,
        unitPriceMinor: 50000,
        discountMinor: 0,
        lineTotalMinor: 50000,
        createdAt: DateTime.now().toUtc(),
      );
      await billingRepo.createInvoiceAtomic(
        invoice: invoice,
        items: [invoiceItem],
        idempotencyKey: 'idemp_inv_auth_01',
      );

      await billingRepo.recordPayment(
        payment: Payment(
          paymentId: 'pay_auth_test_01',
          clinicId: 'clinic_live_01',
          invoiceId: invoice.invoiceId,
          amountMinor: 50000,
          method: PaymentMethod.upi,
          receivedAt: DateTime.now().toUtc(),
          receivedByStaffId: 'staff_rec_01',
          createdAt: DateTime.now().toUtc(),
        ),
        idempotencyKey: 'idemp_pay_auth_01',
      );

      final settledInvoice =
          await billingRepo.getInvoiceById('clinic_live_01', invoice.invoiceId);
      expect(settledInvoice?.status, equals(InvoiceStatus.paid));
      expect(settledInvoice?.balanceMinor, equals(0));

      // 5. Verify sync outbox contains all transactions staged cleanly
      final pendingOutbox =
          await syncRepo.getPendingOutboxEvents('clinic_live_01');
      expect(pendingOutbox.isNotEmpty, isTrue);
      expect(pendingOutbox.length >= 3, isTrue);
    });
  });
}
