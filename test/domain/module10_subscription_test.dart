// Apna Clinic - Module 10: Subscription & Licensing Test Suite
// Verifies PRD Section 5 M10, Section 13, and Section 15 Test 17:
// 1. Annual Commercial Pricing (₹3,999/yr strictly in integer paise).
// 2. Cryptographically signed offline license tokens (HMAC-SHA256, tamper-evident).
// 3. Offline grace period continuity (7-day offline buffer).
// 4. Safe Read-Only Limited Mode (Operational writes blocked; patient data NEVER trapped).
// 5. Safe Data Export & Backup guarantees for Owner.
// 6. Annual renewal and offline license key activation workflows with Audit_Events trail.
// 7. Strict RBAC Deny-by-default for non-owners.

import 'package:flutter_test/flutter_test.dart';

import 'package:apna_clinic/core/permissions/roles.dart';
import 'package:apna_clinic/domain/entities/entities.dart';
import 'package:apna_clinic/domain/services/authorization_service.dart';
import 'package:apna_clinic/domain/services/subscription_service.dart';
import 'package:apna_clinic/infrastructure/database/local_database.dart';
import 'package:apna_clinic/infrastructure/database/storage_adapter.dart';

void main() {
  group('MODULE 10 — SUBSCRIPTION & LICENSING (PRD M10)', () {
    late LocalDatabase memoryDb;
    late SubscriptionService subscriptionService;
    const testClinicId = 'clinic_m10_test';
    const testActorId = 'staff_owner_01';

    setUp(() async {
      memoryDb = LocalDatabase(MemoryStorageAdapter());
      await memoryDb.initialize();

      // Seed initial clinic config
      final now = DateTime.now().toUtc();
      final clinic = Clinic(
        clinicId: testClinicId,
        legalName: 'M10 Test Medical Practice',
        displayName: 'M10 Test Clinic',
        ownerName: 'Dr. Sameer Joshi',
        contactPhone: '9876543210',
        contactEmail: 'sameer@m10test.com',
        addressLine1: '404 Health Avenue',
        city: 'Pune',
        district: 'Pune',
        state: 'Maharashtra',
        pincode: '411001',
        createdAt: now,
        updatedAt: now,
      );
      await memoryDb.upsert('Clinic_Config', testClinicId, clinic.toMap());

      subscriptionService = SubscriptionService(memoryDb);
    });

    test('1. Commercial Pricing: Annual plan is ₹3,999/year (399,900 paise)', () {
      expect(SubscriptionTier.annual.pricePaise, 399900,
          reason: 'Financial integrity: Annual license must be exactly 399,900 paise');
      expect(SubscriptionTier.annual.priceFormatted, '₹3,999 / year');
      expect(SubscriptionTier.trial.pricePaise, 0);
    });

    test('2. Cryptographic Offline License Token: Generates HMAC-SHA256 signature and verifies authenticity', () {
      final now = DateTime.now().toUtc();
      final secret = subscriptionService.getClinicSigningSecret(testClinicId);

      final token = OfflineLicenseToken.issue(
        clinicId: testClinicId,
        tier: SubscriptionTier.annual,
        issuedAt: now,
        validUntil: now.add(const Duration(days: 365)),
        graceDays: 7,
        secretKey: secret,
      );

      expect(token.signature.isNotEmpty, isTrue);
      expect(token.verifySignature(secret), isTrue,
          reason: 'Genuine token must pass cryptographic verification');
    });

    test('3. Anti-Tampering: Modifying validUntil, clinicId, or tier invalidates token signature', () {
      final now = DateTime.now().toUtc();
      final secret = subscriptionService.getClinicSigningSecret(testClinicId);

      final genuineToken = OfflineLicenseToken.issue(
        clinicId: testClinicId,
        tier: SubscriptionTier.trial,
        issuedAt: now,
        validUntil: now.add(const Duration(days: 14)),
        graceDays: 7,
        secretKey: secret,
      );

      // Tamper 1: Extend validUntil without valid signature
      final tamperedDateToken = OfflineLicenseToken(
        clinicId: genuineToken.clinicId,
        tier: genuineToken.tier,
        issuedAt: genuineToken.issuedAt,
        validUntil: genuineToken.validUntil.add(const Duration(days: 365)), // Forged 1 year
        graceDays: genuineToken.graceDays,
        signature: genuineToken.signature,
      );
      expect(tamperedDateToken.verifySignature(secret), isFalse,
          reason: 'Tampered expiration date must fail HMAC signature check');

      // Tamper 2: Change clinic ID (replay attack on different clinic)
      final tamperedClinicToken = OfflineLicenseToken(
        clinicId: 'different_clinic_id',
        tier: genuineToken.tier,
        issuedAt: genuineToken.issuedAt,
        validUntil: genuineToken.validUntil,
        graceDays: genuineToken.graceDays,
        signature: genuineToken.signature,
      );
      expect(tamperedClinicToken.verifySignature(secret), isFalse,
          reason: 'Token cannot be reused across different clinic IDs');

      // Tamper 3: Elevate tier from trial to enterprise
      final tamperedTierToken = OfflineLicenseToken(
        clinicId: genuineToken.clinicId,
        tier: SubscriptionTier.enterprise,
        issuedAt: genuineToken.issuedAt,
        validUntil: genuineToken.validUntil,
        graceDays: genuineToken.graceDays,
        signature: genuineToken.signature,
      );
      expect(tamperedTierToken.verifySignature(secret), isFalse,
          reason: 'Tier elevation without new signature must fail');
    });

    test('4. Token Serialization: Exporting and importing license key strings round-trips cleanly', () {
      final now = DateTime.now().toUtc();
      final secret = subscriptionService.getClinicSigningSecret(testClinicId);

      final token = OfflineLicenseToken.issue(
        clinicId: testClinicId,
        tier: SubscriptionTier.annual,
        issuedAt: now,
        validUntil: now.add(const Duration(days: 365)),
        graceDays: 7,
        secretKey: secret,
      );

      final keyString = token.toLicenseKeyString();
      expect(keyString, isNotEmpty);

      final restored = OfflineLicenseToken.fromLicenseKeyString(keyString);
      expect(restored, isNotNull);
      expect(restored!.clinicId, token.clinicId);
      expect(restored.tier, token.tier);
      expect(restored.signature, token.signature);
      expect(restored.verifySignature(secret), isTrue);
    });

    test('5. Lifecycle Transitions: Evaluates active, 7-day offline grace, and expired states', () {
      final base = DateTime.utc(2026, 1, 1, 10, 0);
      final validUntil = DateTime.utc(2026, 12, 31, 23, 59);
      final graceEnd = validUntil.add(const Duration(days: 7)); // 2027-01-07
      expect(graceEnd.isAfter(validUntil), isTrue);
      final secret = subscriptionService.getClinicSigningSecret(testClinicId);

      final token = OfflineLicenseToken.issue(
        clinicId: testClinicId,
        tier: SubscriptionTier.annual,
        issuedAt: base,
        validUntil: validUntil,
        graceDays: 7,
        secretKey: secret,
      );

      // A. During active term
      final activeNow = DateTime.utc(2026, 6, 15);
      expect(token.evaluateStatus(activeNow, secretKey: secret), SubscriptionStatus.paidActive);

      // B. Inside 7-day offline grace buffer
      final graceNow = DateTime.utc(2027, 1, 3);
      expect(token.evaluateStatus(graceNow, secretKey: secret), SubscriptionStatus.gracePeriod);

      // C. Expired beyond grace buffer
      final expiredNow = DateTime.utc(2027, 1, 15);
      expect(token.evaluateStatus(expiredNow, secretKey: secret), SubscriptionStatus.expired);
    });

    test('6. Default Onboarding: Automatic 14-day evaluation trial issued with signed token', () async {
      final sub = await subscriptionService.getSubscription(testClinicId);

      expect(sub.tier, SubscriptionTier.trial);
      expect(sub.status, SubscriptionStatus.trialActive);
      expect(sub.canPerformOperationalWrites, isTrue);
      expect(sub.isLimitedMode, isFalse);
      expect(sub.cachedToken, isNotNull);
      expect(sub.daysRemaining(DateTime.now().toUtc()) >= 13, isTrue);
    });

    test('7. Annual Renewal Workflow: Extends validity by 365 days and writes Audit_Events record', () async {
      final now = DateTime.now().toUtc();
      final renewed = await subscriptionService.renewAnnualSubscription(
        clinicId: testClinicId,
        actorId: testActorId,
        paymentReference: 'UPI_TEST_REF_3999',
        currentTime: now,
      );

      expect(renewed.tier, SubscriptionTier.annual);
      expect(renewed.status, SubscriptionStatus.paidActive);
      expect(renewed.pricePaise, 399900);
      expect(renewed.daysRemaining(now) >= 365, isTrue,
          reason: 'Rollover entitlement: Existing trial days are preserved on annual renewal');

      // Verify Clinic_Config was updated
      final clinicConfig = memoryDb.query('Clinic_Config').first;
      expect(clinicConfig['subscription_plan'], 'annual');
      expect(clinicConfig['payment_reference'], 'UPI_TEST_REF_3999');

      // Verify immutable audit log
      final auditEvents = memoryDb.query('Audit_Events');
      expect(auditEvents.length, 1);
      final event = auditEvents.first;
      expect(event['action'], 'subscription_renewed');
      expect(event['entity_type'], 'clinic_subscription');
      expect(event['actor_id'], testActorId);
      expect(event['correlation_id'], 'UPI_TEST_REF_3999');
    });

    test('8. Offline License Key Activation: Successfully applies valid key and logs audit event', () async {
      final now = DateTime.now().toUtc();
      final secret = subscriptionService.getClinicSigningSecret(testClinicId);

      final token = OfflineLicenseToken.issue(
        clinicId: testClinicId,
        tier: SubscriptionTier.annual,
        issuedAt: now,
        validUntil: now.add(const Duration(days: 365)),
        graceDays: 7,
        secretKey: secret,
      );
      final keyString = token.toLicenseKeyString();

      final activated = await subscriptionService.activateOfflineLicenseKey(
        clinicId: testClinicId,
        licenseKeyString: keyString,
        actorId: testActorId,
        currentTime: now,
      );

      expect(activated.tier, SubscriptionTier.annual);
      expect(activated.status, SubscriptionStatus.paidActive);

      // Verify Audit Event
      final auditEvents = memoryDb.query('Audit_Events');
      final keyEvent = auditEvents.firstWhere((e) => e['action'] == 'offline_license_activated');
      expect(keyEvent['entity_id'], testClinicId);
    });

    test('9. Offline License Key Validation: Rejects mismatched clinic key or corrupt string', () async {
      final now = DateTime.now().toUtc();
      final secret = subscriptionService.getClinicSigningSecret('other_clinic');

      final foreignToken = OfflineLicenseToken.issue(
        clinicId: 'other_clinic',
        tier: SubscriptionTier.annual,
        issuedAt: now,
        validUntil: now.add(const Duration(days: 365)),
        graceDays: 7,
        secretKey: secret,
      );

      expect(
        () => subscriptionService.activateOfflineLicenseKey(
          clinicId: testClinicId,
          licenseKeyString: foreignToken.toLicenseKeyString(),
          actorId: testActorId,
        ),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => subscriptionService.activateOfflineLicenseKey(
          clinicId: testClinicId,
          licenseKeyString: 'MALFORMED_NON_BASE64_KEY',
          actorId: testActorId,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('10. Safe Read-Only Limited Mode: Operational writes BLOCKED, Safe Export ALWAYS permitted', () {
      final expiredSub = ClinicSubscription(
        clinicId: testClinicId,
        tier: SubscriptionTier.annual,
        status: SubscriptionStatus.expired, // EXPIRED
        validFrom: DateTime.utc(2025, 1, 1),
        validUntil: DateTime.utc(2026, 1, 1),
        graceUntil: DateTime.utc(2026, 1, 8),
        pricePaise: 399900,
      );

      expect(expiredSub.isLimitedMode, isTrue);
      expect(expiredSub.canPerformOperationalWrites, isFalse);
      expect(expiredSub.canExportData, isTrue,
          reason: 'PRD M10 & Acceptance Test 17: Patient data must NEVER be trapped');

      // A. Operational writes must throw SubscriptionExpiredException
      expect(
        () => subscriptionService.assertCanPerformOperation(
          permission: AppPermission.registerPatient,
          subscription: expiredSub,
        ),
        throwsA(isA<SubscriptionExpiredException>()),
      );
      expect(
        () => subscriptionService.assertCanPerformOperation(
          permission: AppPermission.createVisit,
          subscription: expiredSub,
        ),
        throwsA(isA<SubscriptionExpiredException>()),
      );
      expect(
        () => subscriptionService.assertCanPerformOperation(
          permission: AppPermission.createInvoice,
          subscription: expiredSub,
        ),
        throwsA(isA<SubscriptionExpiredException>()),
      );

      // B. Safe Exports, Backups, and Audit Logs MUST NOT throw (always allowed)
      expect(
        () => subscriptionService.assertCanPerformOperation(
          permission: AppPermission.bulkExportPatients,
          subscription: expiredSub,
        ),
        returnsNormally,
      );
      expect(
        () => subscriptionService.assertCanPerformOperation(
          permission: AppPermission.exportReports,
          subscription: expiredSub,
        ),
        returnsNormally,
      );
      expect(
        () => subscriptionService.assertCanPerformOperation(
          permission: AppPermission.triggerBackup,
          subscription: expiredSub,
        ),
        returnsNormally,
      );
      expect(
        () => subscriptionService.assertCanPerformOperation(
          permission: AppPermission.searchPatient,
          subscription: expiredSub,
        ),
        returnsNormally,
      );
    });

    test('11. RBAC Deny-by-Default: Subscription management is restricted to Clinic Owner', () {
      expect(
        AuthorizationService.hasPermission(
          role: UserRole.owner,
          permission: AppPermission.manageSubscriptions,
        ),
        isTrue,
        reason: 'Clinic Owner must have permission to manage subscription',
      );

      expect(
        AuthorizationService.hasPermission(
          role: UserRole.receptionist,
          permission: AppPermission.manageSubscriptions,
        ),
        isFalse,
        reason: 'PRD Section 2: Receptionist must be denied subscription settings',
      );

      expect(
        AuthorizationService.hasPermission(
          role: UserRole.doctor,
          permission: AppPermission.manageSubscriptions,
        ),
        isFalse,
        reason: 'Doctor must be denied subscription settings',
      );

      expect(
        AuthorizationService.hasPermission(
          role: UserRole.accountant,
          permission: AppPermission.manageSubscriptions,
        ),
        isFalse,
        reason: 'Accountant must be denied subscription settings',
      );
    });
  });
}
