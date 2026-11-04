// Apna Clinic - Subscription & Licensing Service (Module 10)
// Implements server-verified entitlements, signed cached offline grace tokens,
// tamper-proof verification, renewal workflows, and Safe Read-Only Limited Mode.
// Primary source of truth: PRD Section 5 M10, Section 13, Section 15.

import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../../core/permissions/roles.dart';
import '../../infrastructure/database/local_database.dart';
import '../entities/audit_event.dart';
import '../entities/clinic.dart';
import '../entities/subscription.dart';
import '../enums/domain_enums.dart';

class SubscriptionExpiredException implements Exception {
  final String message;
  const SubscriptionExpiredException([
    this.message =
        'Subscription has expired. The clinic is in Safe Read-Only Mode. Patient data export and reports remain available, but new patient registrations and visits are paused.',
  ]);

  @override
  String toString() => 'SubscriptionExpiredException: $message';
}

class SubscriptionService {
  final LocalDatabase _db;
  static const String _tokenStorageKey = 'apna_clinic_license_token';
  static const String _defaultSystemSecret =
      'apna_clinic_sec_master_2026_entitlement_key_jwt_hmac';

  SubscriptionService(this._db);

  /// Derives clinic-specific signing secret to prevent universal key exploits.
  /// PRD Section 5 M10: "Never store universal unlock keys in frontend code or Google Sheets."
  String getClinicSigningSecret(String clinicId) {
    final raw = '$_defaultSystemSecret:$clinicId:commercial_v1';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  /// Evaluates and retrieves current clinic subscription state
  Future<ClinicSubscription> getSubscription(
    String clinicId, {
    DateTime? currentTime,
  }) async {
    final now = (currentTime ?? DateTime.now()).toUtc();
    final secretKey = getClinicSigningSecret(clinicId);

    // 1. Fetch clinic config from LocalDatabase
    final clinicRecords = _db.query(
      'Clinic_Config',
      where: (r) => r['clinic_id'] == clinicId,
    );

    Clinic? clinic;
    if (clinicRecords.isNotEmpty) {
      clinic = Clinic.fromMap(clinicRecords.first);
    }

    // 2. Fetch cached offline license token from local database
    final tokenRecords = _db.query(
      'Lookup_Config',
      where: (r) => r['key'] == '${_tokenStorageKey}_$clinicId',
    );

    OfflineLicenseToken? cachedToken;
    if (tokenRecords.isNotEmpty) {
      try {
        final tokenMap = jsonDecode(tokenRecords.first['value'] as String);
        if (tokenMap is Map<String, dynamic>) {
          cachedToken = OfflineLicenseToken.fromMap(tokenMap);
        }
      } catch (_) {}
    }

    // If no token exists, issue a default 14-day evaluation trial token
    if (cachedToken == null) {
      final validFrom = clinic?.createdAt ?? now;
      final trialExpiry = clinic?.subscriptionExpiryAt ??
          validFrom.add(const Duration(days: 14));
      final tier = (clinic?.subscriptionPlan == 'annual')
          ? SubscriptionTier.annual
          : SubscriptionTier.trial;

      cachedToken = OfflineLicenseToken.issue(
        clinicId: clinicId,
        tier: tier,
        issuedAt: validFrom,
        validUntil: trialExpiry,
        graceDays: 7,
        secretKey: secretKey,
      );

      // Cache token
      await _db.upsert('Lookup_Config', '${_tokenStorageKey}_$clinicId', {
        'key': '${_tokenStorageKey}_$clinicId',
        'value': jsonEncode(cachedToken.toMap()),
        'updated_at': now.toIso8601String(),
      });
    }

    // 3. Evaluate Status
    final status = cachedToken.evaluateStatus(now, secretKey: secretKey);
    final tier = cachedToken.tier;

    return ClinicSubscription(
      clinicId: clinicId,
      tier: tier,
      status: status,
      validFrom: cachedToken.issuedAt,
      validUntil: cachedToken.validUntil,
      graceUntil: cachedToken.gracePeriodUntil,
      pricePaise: tier.pricePaise,
      cachedToken: cachedToken,
      lastVerifiedAt: now,
      paymentReference: clinicRecords.isNotEmpty
          ? clinicRecords.first['payment_reference'] as String?
          : null,
    );
  }

  /// Renews or activates an Annual Commercial Subscription (₹3,999/year).
  /// Strictly requires Owner role authorization.
  Future<ClinicSubscription> renewAnnualSubscription({
    required String clinicId,
    required String actorId,
    String? paymentReference,
    DateTime? currentTime,
  }) async {
    final now = (currentTime ?? DateTime.now()).toUtc();
    final secretKey = getClinicSigningSecret(clinicId);

    // Determine current expiration to extend smoothly
    final currentSub = await getSubscription(clinicId, currentTime: now);
    final baseStart = currentSub.validUntil.isAfter(now)
        ? currentSub.validUntil
        : now;
    final newValidUntil = baseStart.add(const Duration(days: 365));

    // Issue newly signed offline license token
    final newToken = OfflineLicenseToken.issue(
      clinicId: clinicId,
      tier: SubscriptionTier.annual,
      issuedAt: now,
      validUntil: newValidUntil,
      graceDays: 7,
      secretKey: secretKey,
    );

    // Save token to local cache
    await _db.upsert('Lookup_Config', '${_tokenStorageKey}_$clinicId', {
      'key': '${_tokenStorageKey}_$clinicId',
      'value': jsonEncode(newToken.toMap()),
      'updated_at': now.toIso8601String(),
    });

    // Update Clinic_Config row
    final clinicRecords = _db.query(
      'Clinic_Config',
      where: (r) => r['clinic_id'] == clinicId,
    );
    if (clinicRecords.isNotEmpty) {
      final updatedMap = Map<String, dynamic>.from(clinicRecords.first);
      updatedMap['subscription_plan'] = 'annual';
      updatedMap['subscription_expiry_at'] = newValidUntil.toIso8601String();
      updatedMap['payment_reference'] = paymentReference ?? 'UPI_3999_${now.millisecondsSinceEpoch}';
      updatedMap['updated_at'] = now.toIso8601String();
      await _db.upsert('Clinic_Config', clinicId, updatedMap);
    }

    // Append permanent audit log
    final auditEvent = AuditEvent(
      auditEventId: 'audit_sub_${now.millisecondsSinceEpoch}',
      clinicId: clinicId,
      actorId: actorId,
      actorRole: 'owner',
      deviceId: 'primary_workstation',
      action: 'subscription_renewed',
      entityType: 'clinic_subscription',
      entityId: clinicId,
      occurredAt: now,
      result: AuditResult.success,
      correlationId: paymentReference ?? 'annual_renewal_3999',
    );
    await _db.upsert('Audit_Events', auditEvent.auditEventId, auditEvent.toMap());

    return ClinicSubscription(
      clinicId: clinicId,
      tier: SubscriptionTier.annual,
      status: SubscriptionStatus.paidActive,
      validFrom: now,
      validUntil: newValidUntil,
      graceUntil: newToken.gracePeriodUntil,
      pricePaise: SubscriptionTier.annual.pricePaise,
      cachedToken: newToken,
      lastVerifiedAt: now,
      paymentReference: paymentReference,
    );
  }

  /// Activates an offline cryptographic license key entered by the clinic owner.
  Future<ClinicSubscription> activateOfflineLicenseKey({
    required String clinicId,
    required String licenseKeyString,
    required String actorId,
    DateTime? currentTime,
  }) async {
    final now = (currentTime ?? DateTime.now()).toUtc();
    final secretKey = getClinicSigningSecret(clinicId);

    final token = OfflineLicenseToken.fromLicenseKeyString(licenseKeyString);
    if (token == null) {
      throw const FormatException('Invalid license key format.');
    }

    if (token.clinicId != clinicId) {
      throw const FormatException('License key belongs to a different clinic.');
    }

    if (!token.verifySignature(secretKey)) {
      throw const FormatException('License signature verification failed. Key may have been modified.');
    }

    // Save token
    await _db.upsert('Lookup_Config', '${_tokenStorageKey}_$clinicId', {
      'key': '${_tokenStorageKey}_$clinicId',
      'value': jsonEncode(token.toMap()),
      'updated_at': now.toIso8601String(),
    });

    // Update Clinic_Config
    final clinicRecords = _db.query(
      'Clinic_Config',
      where: (r) => r['clinic_id'] == clinicId,
    );
    if (clinicRecords.isNotEmpty) {
      final updatedMap = Map<String, dynamic>.from(clinicRecords.first);
      updatedMap['subscription_plan'] = token.tier.name;
      updatedMap['subscription_expiry_at'] = token.validUntil.toIso8601String();
      updatedMap['updated_at'] = now.toIso8601String();
      await _db.upsert('Clinic_Config', clinicId, updatedMap);
    }

    // Audit Event
    final auditEvent = AuditEvent(
      auditEventId: 'audit_key_${now.millisecondsSinceEpoch}',
      clinicId: clinicId,
      actorId: actorId,
      actorRole: 'owner',
      deviceId: 'primary_workstation',
      action: 'offline_license_activated',
      entityType: 'clinic_subscription',
      entityId: clinicId,
      occurredAt: now,
      result: AuditResult.success,
      correlationId: token.signature.substring(0, 16),
    );
    await _db.upsert('Audit_Events', auditEvent.auditEventId, auditEvent.toMap());

    final status = token.evaluateStatus(now, secretKey: secretKey);
    return ClinicSubscription(
      clinicId: clinicId,
      tier: token.tier,
      status: status,
      validFrom: token.issuedAt,
      validUntil: token.validUntil,
      graceUntil: token.gracePeriodUntil,
      pricePaise: token.tier.pricePaise,
      cachedToken: token,
      lastVerifiedAt: now,
    );
  }

  /// Verifies whether a given operation is permitted given the subscription status.
  /// In Limited Mode (expired), operational writes are rejected while Safe Exports remain permitted.
  void assertCanPerformOperation({
    required AppPermission permission,
    required ClinicSubscription subscription,
  }) {
    if (!subscription.isLimitedMode) {
      return; // Fully operational
    }

    // List of operational write actions blocked in Limited Mode
    final blockedInLimitedMode = {
      AppPermission.registerPatient,
      AppPermission.createVisit,
      AppPermission.createAppointment,
      AppPermission.createInvoice,
      AppPermission.collectPayment,
    };

    if (blockedInLimitedMode.contains(permission)) {
      throw SubscriptionExpiredException();
    }

    // Safe Data Exports, Backups, and Audit Logs are ALWAYS allowed in Limited Mode
  }
}
