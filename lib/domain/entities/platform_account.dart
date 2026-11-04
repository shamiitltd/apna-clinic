// Apna Clinic - Platform Account Entity (Layer 2)
// Primary source of truth: Firebase Firestore `users/{uid}`
// Represents customer identity, subscription status, and product entitlement.
// Does NOT store clinic operational or medical data.

class PlatformAccount {
  final String uid;
  final String fullName;
  final String email;
  final String phone;
  final String organizationName;
  final String product; // 'apna_clinic'
  final String plan; // 'starter', 'pro', 'enterprise'
  final String accountStatus; // 'active', 'inactive', 'suspended', 'pending'
  final String subscriptionStatus; // 'active', 'trial', 'expired', 'cancelled'
  final DateTime? subscriptionStart;
  final DateTime? subscriptionEnd;
  final DateTime? trialStart;
  final DateTime? trialEnd;
  final String licenseStatus; // 'valid', 'expired', 'revoked'
  final bool clinicSetupCompleted;
  final bool driveConnected;
  final String? driveEmail;
  final String? driveFolderId;
  final String? spreadsheetId;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PlatformAccount({
    required this.uid,
    required this.fullName,
    required this.email,
    this.phone = '',
    this.organizationName = '',
    this.product = 'apna_clinic',
    this.plan = 'standard',
    this.accountStatus = 'active',
    this.subscriptionStatus = 'trial',
    this.subscriptionStart,
    this.subscriptionEnd,
    this.trialStart,
    this.trialEnd,
    this.licenseStatus = 'valid',
    this.clinicSetupCompleted = false,
    this.driveConnected = false,
    this.driveEmail,
    this.driveFolderId,
    this.spreadsheetId,
    this.lastLoginAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => accountStatus.trim().toLowerCase() == 'active';

  bool get isSubscriptionValid {
    final status = subscriptionStatus.trim().toLowerCase();
    if (status == 'active') return true;
    if (status == 'trial') {
      if (trialEnd == null) return true;
      return DateTime.now().isBefore(trialEnd!);
    }
    return false;
  }

  bool get hasValidAccess => isActive && isSubscriptionValid;

  factory PlatformAccount.fromMap(Map<String, dynamic> map, {String? documentId}) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      // Handle Firestore Timestamp dynamically without requiring direct class import
      if (val is Map && val.containsKey('_seconds')) {
        return DateTime.fromMillisecondsSinceEpoch(
          ((val['_seconds'] as num) * 1000).toInt(),
          isUtc: true,
        );
      }
      try {
        final toDate = (val as dynamic).toDate;
        if (toDate != null) {
          final res = toDate();
          if (res is DateTime) return res;
        }
      } catch (_) {}
      if (val is String) {
        return DateTime.tryParse(val);
      }
      return null;
    }

    return PlatformAccount(
      uid: (map['uid'] as String?) ?? documentId ?? '',
      fullName: (map['fullName'] as String?) ?? (map['full_name'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      organizationName:
          (map['organizationName'] as String?) ??
          (map['organization_name'] as String?) ??
          '',
      product: (map['product'] as String?) ?? 'apna_clinic',
      plan: (map['plan'] as String?) ?? 'standard',
      accountStatus:
          (map['accountStatus'] as String?) ??
          (map['account_status'] as String?) ??
          'active',
      subscriptionStatus:
          (map['subscriptionStatus'] as String?) ??
          (map['subscription_status'] as String?) ??
          'trial',
      subscriptionStart: parseDate(map['subscriptionStart'] ?? map['subscription_start']),
      subscriptionEnd: parseDate(map['subscriptionEnd'] ?? map['subscription_end']),
      trialStart: parseDate(map['trialStart'] ?? map['trial_start']),
      trialEnd: parseDate(map['trialEnd'] ?? map['trial_end']),
      licenseStatus:
          (map['licenseStatus'] as String?) ??
          (map['license_status'] as String?) ??
          'valid',
      clinicSetupCompleted:
          map['clinicSetupCompleted'] == true || map['clinic_setup_completed'] == true,
      driveConnected:
          map['driveConnected'] == true || map['drive_connected'] == true,
      driveEmail:
          (map['driveEmail'] as String?) ?? (map['drive_email'] as String?),
      driveFolderId:
          (map['driveFolderId'] as String?) ?? (map['drive_folder_id'] as String?),
      spreadsheetId:
          (map['spreadsheetId'] as String?) ?? (map['spreadsheet_id'] as String?),
      lastLoginAt: parseDate(map['lastLoginAt'] ?? map['last_login_at']),
      createdAt: parseDate(map['createdAt'] ?? map['created_at']),
      updatedAt: parseDate(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'organizationName': organizationName,
      'product': product,
      'plan': plan,
      'accountStatus': accountStatus,
      'subscriptionStatus': subscriptionStatus,
      'subscriptionStart': subscriptionStart?.toIso8601String(),
      'subscriptionEnd': subscriptionEnd?.toIso8601String(),
      'trialStart': trialStart?.toIso8601String(),
      'trialEnd': trialEnd?.toIso8601String(),
      'licenseStatus': licenseStatus,
      'clinicSetupCompleted': clinicSetupCompleted,
      'driveConnected': driveConnected,
      'driveEmail': driveEmail,
      'driveFolderId': driveFolderId,
      'spreadsheetId': spreadsheetId,
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  PlatformAccount copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? phone,
    String? organizationName,
    String? product,
    String? plan,
    String? accountStatus,
    String? subscriptionStatus,
    DateTime? subscriptionStart,
    DateTime? subscriptionEnd,
    DateTime? trialStart,
    DateTime? trialEnd,
    String? licenseStatus,
    bool? clinicSetupCompleted,
    bool? driveConnected,
    String? driveEmail,
    String? driveFolderId,
    String? spreadsheetId,
    DateTime? lastLoginAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PlatformAccount(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      organizationName: organizationName ?? this.organizationName,
      product: product ?? this.product,
      plan: plan ?? this.plan,
      accountStatus: accountStatus ?? this.accountStatus,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionStart: subscriptionStart ?? this.subscriptionStart,
      subscriptionEnd: subscriptionEnd ?? this.subscriptionEnd,
      trialStart: trialStart ?? this.trialStart,
      trialEnd: trialEnd ?? this.trialEnd,
      licenseStatus: licenseStatus ?? this.licenseStatus,
      clinicSetupCompleted: clinicSetupCompleted ?? this.clinicSetupCompleted,
      driveConnected: driveConnected ?? this.driveConnected,
      driveEmail: driveEmail ?? this.driveEmail,
      driveFolderId: driveFolderId ?? this.driveFolderId,
      spreadsheetId: spreadsheetId ?? this.spreadsheetId,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
