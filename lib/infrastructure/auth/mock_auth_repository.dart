// Apna Clinic - Mock Authentication Repository (Testing & Development)
// Enables running test suites and offline mock validation without external Firebase network calls.

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/platform_account.dart';
import '../../domain/repositories/i_auth_repository.dart';

class MockAuthRepository implements IAuthRepository {
  static const String _mockUidKey = 'apna_clinic_mock_auth_uid';
  static const String _mockEmailKey = 'apna_clinic_mock_auth_email';

  final StreamController<String?> _authStateController =
      StreamController<String?>.broadcast();

  String? _mockUid;
  String? _mockEmail;
  PlatformAccount? _mockAccount;

  bool shouldCancel = false;
  String? forcedError;

  MockAuthRepository({
    String? initialUid,
    String? initialEmail,
    PlatformAccount? initialAccount,
  }) : _mockUid = initialUid,
       _mockEmail = initialEmail,
       _mockAccount = initialAccount {
    _restoreFromStorage();
  }

  void _restoreFromStorage() {
    try {
      if (_mockUid != null) return;
      SharedPreferences.getInstance().then((prefs) {
        final savedUid = prefs.getString(_mockUidKey);
        final savedEmail = prefs.getString(_mockEmailKey);
        if (savedUid != null && savedUid.isNotEmpty && _mockUid == null) {
          _mockUid = savedUid;
          _mockEmail = savedEmail ?? 'doctor.sharma@apnaclinic.in';
          _authStateController.add(savedUid);
        }
      }).catchError((_) {});
    } catch (_) {}
  }

  void setMockUser({
    required String uid,
    required String email,
    PlatformAccount? account,
  }) {
    _mockUid = uid;
    _mockEmail = email;
    _mockAccount = account;
    _authStateController.add(uid);
    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(_mockUidKey, uid);
        prefs.setString(_mockEmailKey, email);
      }).catchError((_) {});
    } catch (_) {}
  }

  void clearMockUser() {
    _mockUid = null;
    _mockEmail = null;
    _mockAccount = null;
    _authStateController.add(null);
    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.remove(_mockUidKey);
        prefs.remove(_mockEmailKey);
      }).catchError((_) {});
    } catch (_) {}
  }

  @override
  Stream<String?> get authStateChanges => _authStateController.stream;

  @override
  String? get currentUid => _mockUid;

  @override
  String? get currentEmail => _mockEmail;

  @override
  bool get isAuthenticated => _mockUid != null;

  @override
  Future<PlatformAuthResult> signInWithGoogle() async {
    if (shouldCancel) {
      return const PlatformAuthResult.cancelled();
    }
    if (forcedError != null) {
      return PlatformAuthResult.error(forcedError!);
    }

    final uid = _mockUid ?? 'mock_firebase_uid_123';
    final email = _mockEmail ?? 'doctor.sharma@apnaclinic.in';
    setMockUser(uid: uid, email: email, account: _mockAccount);
    return PlatformAuthResult.success(
      uid: uid,
      email: email,
      displayName: 'Dr. Sharma',
    );
  }

  @override
  Future<PlatformAuthResult> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    if (forcedError != null) {
      return PlatformAuthResult.error(forcedError!);
    }
    final uid = 'mock_firebase_uid_${email.hashCode}';
    setMockUser(uid: uid, email: email, account: _mockAccount);
    return PlatformAuthResult.success(
      uid: uid,
      email: email,
      displayName: email.split('@').first,
    );
  }

  @override
  Future<void> logout() async {
    clearMockUser();
  }

  @override
  Future<PlatformAccount?> fetchPlatformAccount(String uid) async {
    if (_mockAccount != null && _mockAccount!.uid == uid) {
      return _mockAccount;
    }
    if (_mockUid != null && _mockUid == uid) {
      return _mockAccount;
    }
    return null;
  }

  @override
  Future<void> updateDriveConnectionMetadata({
    required String uid,
    required String driveEmail,
    required String driveFolderId,
    required String spreadsheetId,
  }) async {
    if (_mockAccount != null) {
      _mockAccount = _mockAccount!.copyWith(
        driveConnected: true,
        driveEmail: driveEmail,
        driveFolderId: driveFolderId,
        spreadsheetId: spreadsheetId,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> updateClinicSetupStatus({
    required String uid,
    required bool completed,
  }) async {
    if (_mockAccount != null) {
      _mockAccount = _mockAccount!.copyWith(
        clinicSetupCompleted: completed,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<bool> checkAccess(PlatformAccount? account) async {
    if (account == null) return false;
    return account.isActive && account.isSubscriptionValid;
  }

  final List<Map<String, dynamic>> submittedInquiries = [];

  @override
  Future<PlatformAuthResult> registerWithGoogle({
    String? organizationName,
    String? phone,
  }) async {
    if (shouldCancel) {
      return const PlatformAuthResult.cancelled();
    }
    if (forcedError != null) {
      return PlatformAuthResult.error(forcedError!);
    }

    _mockUid ??= 'mock_firebase_uid_new_123';
    _mockEmail ??= 'new.doctor@apnaclinic.in';

    _mockAccount = PlatformAccount(
      uid: _mockUid!,
      email: _mockEmail!,
      fullName: 'New Doctor',
      phone: phone ?? '',
      organizationName: organizationName ?? 'Apna Health Clinic',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
      trialStart: DateTime.now(),
      trialEnd: DateTime.now().add(const Duration(days: 30)),
    );

    setMockUser(uid: _mockUid!, email: _mockEmail!, account: _mockAccount);
    return PlatformAuthResult.success(
      uid: _mockUid!,
      email: _mockEmail!,
      displayName: 'New Doctor',
    );
  }

  @override
  Future<PlatformAuthResult> registerWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
    String phone = '',
    String organizationName = '',
  }) async {
    if (forcedError != null) {
      return PlatformAuthResult.error(forcedError!);
    }

    final uid = 'mock_firebase_uid_${email.hashCode}';
    final account = PlatformAccount(
      uid: uid,
      email: email,
      fullName: fullName,
      phone: phone,
      organizationName: organizationName.isEmpty ? 'Clinic' : organizationName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
      trialStart: DateTime.now(),
      trialEnd: DateTime.now().add(const Duration(days: 30)),
    );

    setMockUser(uid: uid, email: email, account: account);
    return PlatformAuthResult.success(
      uid: uid,
      email: email,
      displayName: fullName,
    );
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (forcedError != null) {
      throw Exception(forcedError);
    }
  }

  @override
  Future<void> updateUserProfile({
    required String uid,
    required String fullName,
    String phone = '',
    String organizationName = '',
  }) async {
    if (forcedError != null) {
      throw Exception(forcedError);
    }
    if (_mockAccount != null) {
      _mockAccount = _mockAccount!.copyWith(
        fullName: fullName,
        phone: phone,
        organizationName: organizationName,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<bool> submitContactInquiry({
    required String name,
    required String email,
    required String message,
    String? phone,
    String? organization,
    String? subject,
    String? category,
  }) async {
    if (forcedError != null) {
      return false;
    }
    submittedInquiries.add({
      'name': name,
      'email': email,
      'message': message,
      'phone': phone,
      'organization': organization,
      'subject': subject,
      'category': category,
      'submittedAt': DateTime.now(),
    });
    return true;
  }
}
