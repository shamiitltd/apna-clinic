// Apna Clinic - Subscription & Licensing Domain Models (Module 10)
// Primary source of truth: PRD Section 5 M10, Section 13, Section 15

import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Subscription Tier / Plan
enum SubscriptionTier {
  trial,
  annual,
  enterprise,
}

extension SubscriptionTierExtension on SubscriptionTier {
  String get displayName {
    switch (this) {
      case SubscriptionTier.trial:
        return 'Evaluation Trial';
      case SubscriptionTier.annual:
        return 'Annual Commercial Plan';
      case SubscriptionTier.enterprise:
        return 'Enterprise Multi-Doctor';
    }
  }

  /// Annual plan is ₹3,999/year as per PRD Section 5 M10 & Section 13.
  /// Represented strictly in integer paise (₹3,999.00 = 399,900 paise).
  int get pricePaise {
    switch (this) {
      case SubscriptionTier.trial:
        return 0;
      case SubscriptionTier.annual:
        return 399900; // ₹3,999 in paise
      case SubscriptionTier.enterprise:
        return 999900; // ₹9,999 in paise
    }
  }

  String get priceFormatted {
    switch (this) {
      case SubscriptionTier.trial:
        return 'Free (Complimentary)';
      case SubscriptionTier.annual:
        return '₹3,999 / year';
      case SubscriptionTier.enterprise:
        return '₹9,999 / year';
    }
  }
}

/// Lifecycle status of clinic subscription
enum SubscriptionStatus {
  trialActive,
  paidActive,
  gracePeriod,
  expired,
}

extension SubscriptionStatusExtension on SubscriptionStatus {
  String get label {
    switch (this) {
      case SubscriptionStatus.trialActive:
        return 'Active Trial';
      case SubscriptionStatus.paidActive:
        return 'Active Paid';
      case SubscriptionStatus.gracePeriod:
        return 'Offline Grace Period';
      case SubscriptionStatus.expired:
        return 'Expired (Safe Read-Only Mode)';
    }
  }

  bool get isOperational =>
      this == SubscriptionStatus.trialActive ||
      this == SubscriptionStatus.paidActive ||
      this == SubscriptionStatus.gracePeriod;

  bool get isLimitedMode => this == SubscriptionStatus.expired;
}

/// Cryptographically signed offline license token.
/// PRD Section 5 M10: "Server-verified entitlements and signed cached offline grace tokens.
/// Never store universal unlock keys in frontend code or Google Sheets."
class OfflineLicenseToken {
  final String clinicId;
  final SubscriptionTier tier;
  final DateTime issuedAt;
  final DateTime validUntil;
  final int graceDays;
  final String signature;

  const OfflineLicenseToken({
    required this.clinicId,
    required this.tier,
    required this.issuedAt,
    required this.validUntil,
    this.graceDays = 7,
    required this.signature,
  });

  DateTime get gracePeriodUntil => validUntil.add(Duration(days: graceDays));

  /// Canonical payload string used for signing and tamper detection
  static String buildCanonicalPayload({
    required String clinicId,
    required SubscriptionTier tier,
    required DateTime issuedAt,
    required DateTime validUntil,
    required int graceDays,
  }) {
    return '$clinicId|${tier.name}|${issuedAt.toIso8601String()}|${validUntil.toIso8601String()}|$graceDays';
  }

  /// Calculates cryptographic HMAC-SHA256 signature for the token
  static String calculateSignature(String payload, String secretKey) {
    final hmac = Hmac(sha256, utf8.encode(secretKey));
    final digest = hmac.convert(utf8.encode(payload));
    return digest.toString();
  }

  /// Issues a new signed offline license token
  factory OfflineLicenseToken.issue({
    required String clinicId,
    required SubscriptionTier tier,
    required DateTime issuedAt,
    required DateTime validUntil,
    int graceDays = 7,
    required String secretKey,
  }) {
    final payload = buildCanonicalPayload(
      clinicId: clinicId,
      tier: tier,
      issuedAt: issuedAt,
      validUntil: validUntil,
      graceDays: graceDays,
    );
    final sig = calculateSignature(payload, secretKey);
    return OfflineLicenseToken(
      clinicId: clinicId,
      tier: tier,
      issuedAt: issuedAt,
      validUntil: validUntil,
      graceDays: graceDays,
      signature: sig,
    );
  }

  /// Verifies if token signature is genuine and not tampered with
  bool verifySignature(String secretKey) {
    final expectedPayload = buildCanonicalPayload(
      clinicId: clinicId,
      tier: tier,
      issuedAt: issuedAt,
      validUntil: validUntil,
      graceDays: graceDays,
    );
    final expectedSig = calculateSignature(expectedPayload, secretKey);
    return expectedSig == signature;
  }

  /// Checks if token is currently active within primary validity window
  bool isWithinValidity(DateTime now) {
    return now.isBefore(validUntil) || now.isAtSameMomentAs(validUntil);
  }

  /// Checks if token is within 7-day offline grace window after validity expiration
  bool isWithinGrace(DateTime now) {
    return now.isAfter(validUntil) &&
        (now.isBefore(gracePeriodUntil) || now.isAtSameMomentAs(gracePeriodUntil));
  }

  /// Evaluates subscription status from token
  SubscriptionStatus evaluateStatus(DateTime now, {required String secretKey}) {
    if (!verifySignature(secretKey)) {
      return SubscriptionStatus.expired;
    }
    if (isWithinValidity(now)) {
      return tier == SubscriptionTier.trial
          ? SubscriptionStatus.trialActive
          : SubscriptionStatus.paidActive;
    }
    if (isWithinGrace(now)) {
      return SubscriptionStatus.gracePeriod;
    }
    return SubscriptionStatus.expired;
  }

  /// Serializes token to exportable key string
  String toLicenseKeyString() {
    final map = {
      'c': clinicId,
      't': tier.name,
      'i': issuedAt.toIso8601String(),
      'v': validUntil.toIso8601String(),
      'g': graceDays,
      's': signature,
    };
    return base64Url.encode(utf8.encode(jsonEncode(map)));
  }

  /// Deserializes token from key string
  static OfflineLicenseToken? fromLicenseKeyString(String keyString) {
    try {
      final decodedJson = utf8.decode(base64Url.decode(keyString.trim()));
      final map = jsonDecode(decodedJson) as Map<String, dynamic>;
      final clinicId = map['c'] as String;
      final tierName = map['t'] as String;
      final issuedAt = DateTime.parse(map['i'] as String);
      final validUntil = DateTime.parse(map['v'] as String);
      final graceDays = (map['g'] as num?)?.toInt() ?? 7;
      final signature = map['s'] as String;

      final tier = SubscriptionTier.values.firstWhere(
        (e) => e.name == tierName,
        orElse: () => SubscriptionTier.trial,
      );

      return OfflineLicenseToken(
        clinicId: clinicId,
        tier: tier,
        issuedAt: issuedAt,
        validUntil: validUntil,
        graceDays: graceDays,
        signature: signature,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'clinic_id': clinicId,
      'tier': tier.name,
      'issued_at': issuedAt.toIso8601String(),
      'valid_until': validUntil.toIso8601String(),
      'grace_days': graceDays,
      'signature': signature,
    };
  }

  factory OfflineLicenseToken.fromMap(Map<String, dynamic> map) {
    final tierName = map['tier'] as String? ?? 'trial';
    final tier = SubscriptionTier.values.firstWhere(
      (e) => e.name == tierName,
      orElse: () => SubscriptionTier.trial,
    );
    return OfflineLicenseToken(
      clinicId: map['clinic_id'] as String? ?? '',
      tier: tier,
      issuedAt: DateTime.parse(map['issued_at'] as String),
      validUntil: DateTime.parse(map['valid_until'] as String),
      graceDays: (map['grace_days'] as num?)?.toInt() ?? 7,
      signature: map['signature'] as String? ?? '',
    );
  }
}

/// Comprehensive Clinic Subscription Entitlement Model
class ClinicSubscription {
  final String clinicId;
  final SubscriptionTier tier;
  final SubscriptionStatus status;
  final DateTime validFrom;
  final DateTime validUntil;
  final DateTime graceUntil;
  final int pricePaise;
  final OfflineLicenseToken? cachedToken;
  final DateTime? lastVerifiedAt;
  final String? paymentReference;

  const ClinicSubscription({
    required this.clinicId,
    required this.tier,
    required this.status,
    required this.validFrom,
    required this.validUntil,
    required this.graceUntil,
    required this.pricePaise,
    this.cachedToken,
    this.lastVerifiedAt,
    this.paymentReference,
  });

  /// PRD Section 5 M10: Expired subscription enters clearly documented limited mode
  bool get isLimitedMode => status.isLimitedMode;

  /// Operational writes (new patients, new visits, new invoices) are allowed only in operational status
  bool get canPerformOperationalWrites => status.isOperational;

  /// PRD Section 5 M10 & Section 15 Test 17:
  /// "Expired subscription must not trap patient data: permit secure export and legally required access"
  /// Safe export is ALWAYS true for authorized roles.
  bool get canExportData => true;

  int daysRemaining(DateTime now) {
    if (now.isAfter(validUntil)) return 0;
    return validUntil.difference(now).inDays;
  }

  int graceDaysRemaining(DateTime now) {
    if (now.isBefore(validUntil)) return cachedToken?.graceDays ?? 7;
    if (now.isAfter(graceUntil)) return 0;
    return graceUntil.difference(now).inDays;
  }

  ClinicSubscription copyWith({
    String? clinicId,
    SubscriptionTier? tier,
    SubscriptionStatus? status,
    DateTime? validFrom,
    DateTime? validUntil,
    DateTime? graceUntil,
    int? pricePaise,
    OfflineLicenseToken? cachedToken,
    DateTime? lastVerifiedAt,
    String? paymentReference,
  }) {
    return ClinicSubscription(
      clinicId: clinicId ?? this.clinicId,
      tier: tier ?? this.tier,
      status: status ?? this.status,
      validFrom: validFrom ?? this.validFrom,
      validUntil: validUntil ?? this.validUntil,
      graceUntil: graceUntil ?? this.graceUntil,
      pricePaise: pricePaise ?? this.pricePaise,
      cachedToken: cachedToken ?? this.cachedToken,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      paymentReference: paymentReference ?? this.paymentReference,
    );
  }
}
