// Apna Clinic - Platform Authentication Repository Interface (Layer 1 & 2)
// Governs Firebase Authentication and Firestore Platform Account retrieval.
// Completely decoupled from Google Drive / Sheets data authorization.

import '../entities/platform_account.dart';

class PlatformAuthResult {
  final bool isSuccess;
  final bool isCancelled;
  final bool isError;
  final String? uid;
  final String? email;
  final String? displayName;
  final String? errorMessage;
  final String? errorCode;

  const PlatformAuthResult.success({
    required this.uid,
    required this.email,
    this.displayName,
  }) : isSuccess = true,
       isCancelled = false,
       isError = false,
       errorMessage = null,
       errorCode = null;

  const PlatformAuthResult.cancelled()
    : isSuccess = false,
      isCancelled = true,
      isError = false,
      uid = null,
      email = null,
      displayName = null,
      errorMessage = null,
      errorCode = null;

  const PlatformAuthResult.error(this.errorMessage, {this.errorCode})
    : isSuccess = false,
      isCancelled = false,
      isError = true,
      uid = null,
      email = null,
      displayName = null;
}

abstract class IAuthRepository {
  Stream<String?> get authStateChanges;
  String? get currentUid;
  String? get currentEmail;
  bool get isAuthenticated;

  Future<PlatformAuthResult> signInWithGoogle();
  Future<PlatformAuthResult> registerWithGoogle({
    String? phone,
    String? organizationName,
  });

  Future<PlatformAuthResult> signInWithEmailPassword({
    required String email,
    required String password,
  });

  Future<PlatformAuthResult> registerWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
    String phone = '',
    String organizationName = '',
  });

  Future<void> sendPasswordResetEmail(String email);

  Future<void> logout();

  Future<PlatformAccount?> fetchPlatformAccount(String uid);

  Future<void> updateUserProfile({
    required String uid,
    required String fullName,
    String phone = '',
    String organizationName = '',
  });

  Future<void> updateDriveConnectionMetadata({
    required String uid,
    required String driveEmail,
    required String driveFolderId,
    required String spreadsheetId,
  });

  Future<void> updateClinicSetupStatus({
    required String uid,
    required bool completed,
  });

  Future<bool> checkAccess(PlatformAccount? account);

  Future<bool> submitContactInquiry({
    required String name,
    required String email,
    required String phone,
    required String organization,
    required String subject,
    required String category,
    required String message,
  });
}
