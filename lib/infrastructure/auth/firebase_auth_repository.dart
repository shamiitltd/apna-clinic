// Apna Clinic - Firebase Authentication Repository Implementation (Layer 1 & 2)
// Handles Firebase Authentication, Firestore account profiles, and website contact inquiries.

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/logging/app_logger.dart';
import '../../domain/entities/platform_account.dart';
import '../../domain/repositories/i_auth_repository.dart';

class FirebaseAuthRepository implements IAuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  FirebaseAuthRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<String?> get authStateChanges =>
      _firebaseAuth.authStateChanges().map((user) => user?.uid);

  @override
  String? get currentUid => _firebaseAuth.currentUser?.uid;

  @override
  String? get currentEmail => _firebaseAuth.currentUser?.email;

  @override
  bool get isAuthenticated => _firebaseAuth.currentUser != null;

  @override
  Future<PlatformAuthResult> signInWithGoogle() async {
    try {
      AppLogger.info('Starting Firebase Google Sign-In popup...');
      final provider = GoogleAuthProvider();
      provider.addScope('email');
      provider.addScope('profile');

      final userCredential = await _firebaseAuth.signInWithPopup(provider);
      final user = userCredential.user;

      if (user == null) {
        return const PlatformAuthResult.error('No user profile returned from Google Sign-In.');
      }

      AppLogger.info('Firebase Google Sign-In successful for UID: ${user.uid} (${user.email})');
      return PlatformAuthResult.success(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName,
      );
    } on FirebaseAuthException catch (e) {
      AppLogger.warning('FirebaseAuthException: ${e.code} - ${e.message}');
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled') {
        return const PlatformAuthResult.cancelled();
      }
      if (e.code == 'popup-blocked') {
        return const PlatformAuthResult.error(
          'Login popup was blocked by your browser. Please allow popups for this site and try again.',
          errorCode: 'POPUP_BLOCKED',
        );
      }
      if (e.code == 'network-request-failed') {
        return const PlatformAuthResult.error(
          'Network connection error. Please verify your internet connection.',
          errorCode: 'NETWORK_ERROR',
        );
      }
      return PlatformAuthResult.error(
        e.message ?? 'Authentication failed with code: ${e.code}',
        errorCode: e.code,
      );
    } catch (e) {
      AppLogger.error('Unexpected error during Firebase Google Sign-In: $e');
      return PlatformAuthResult.error('Authentication error: $e');
    }
  }

  @override
  Future<PlatformAuthResult> registerWithGoogle({
    String? phone,
    String? organizationName,
  }) async {
    final authResult = await signInWithGoogle();
    if (!authResult.isSuccess || authResult.uid == null) {
      return authResult;
    }

    final uid = authResult.uid!;
    try {
      final docRef = _firestore.collection('users').doc(uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        final now = DateTime.now().toUtc();
        final trialEnd = now.add(const Duration(days: 30));

        await docRef.set({
          'uid': uid,
          'fullName': authResult.displayName ?? 'Clinic Doctor',
          'email': authResult.email ?? '',
          'phone': phone ?? '',
          'organizationName': organizationName ?? '',
          'product': 'apna_clinic',
          'plan': 'standard',
          'accountStatus': 'active',
          'subscriptionStatus': 'trial',
          'trialStart': FieldValue.serverTimestamp(),
          'trialEnd': trialEnd.toIso8601String(),
          'licenseStatus': 'valid',
          'clinicSetupCompleted': false,
          'driveConnected': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
        AppLogger.info('Successfully registered new Firestore user: $uid');
      }
      return authResult;
    } catch (e) {
      AppLogger.error('Failed to initialize Firestore document for new Google user: $e');
      return authResult; // Still return success since Auth succeeded
    }
  }

  @override
  Future<PlatformAuthResult> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        return const PlatformAuthResult.error('Failed to authenticate with email/password.');
      }
      return PlatformAuthResult.success(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return const PlatformAuthResult.error(
          'Invalid email or password. Please verify your credentials or register a new account.',
          errorCode: 'INVALID_CREDENTIALS',
        );
      }
      return PlatformAuthResult.error(e.message ?? e.code, errorCode: e.code);
    } catch (e) {
      return PlatformAuthResult.error('Authentication error: $e');
    }
  }

  @override
  Future<PlatformAuthResult> registerWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
    String phone = '',
    String organizationName = '',
  }) async {
    try {
      final cred = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        return const PlatformAuthResult.error('Failed to create account.');
      }

      await user.updateDisplayName(fullName.trim());

      final now = DateTime.now().toUtc();
      final trialEnd = now.add(const Duration(days: 30));

      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'fullName': fullName.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'organizationName': organizationName.trim(),
        'product': 'apna_clinic',
        'plan': 'standard',
        'accountStatus': 'active',
        'subscriptionStatus': 'trial',
        'trialStart': FieldValue.serverTimestamp(),
        'trialEnd': trialEnd.toIso8601String(),
        'licenseStatus': 'valid',
        'clinicSetupCompleted': false,
        'driveConnected': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      return PlatformAuthResult.success(
        uid: user.uid,
        email: email.trim(),
        displayName: fullName.trim(),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return const PlatformAuthResult.error(
          'An account with this email already exists. Please log in instead.',
          errorCode: 'EMAIL_IN_USE',
        );
      }
      if (e.code == 'weak-password') {
        return const PlatformAuthResult.error(
          'Password is too weak. Please use at least 6 characters with letters and numbers.',
          errorCode: 'WEAK_PASSWORD',
        );
      }
      return PlatformAuthResult.error(e.message ?? e.code, errorCode: e.code);
    } catch (e) {
      return PlatformAuthResult.error('Registration error: $e');
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
      AppLogger.info('Password reset email dispatched to: $email');
    } catch (e) {
      AppLogger.error('Failed to send password reset email: $e');
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    try {
      AppLogger.info('Signing out of Firebase Auth session for UID: $currentUid');
      await _firebaseAuth.signOut();
    } catch (e) {
      AppLogger.error('Error during Firebase signOut: $e');
    }
  }

  @override
  Future<PlatformAccount?> fetchPlatformAccount(String uid) async {
    try {
      AppLogger.info('Querying Firestore users/$uid for platform account...');
      final doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists || doc.data() == null) {
        AppLogger.warning('No Firestore account document found at users/$uid.');
        return null;
      }

      final data = doc.data()!;
      final account = PlatformAccount.fromMap(data, documentId: doc.id);

      // Best-effort update of lastLoginAt (allowed under Firestore security rules)
      unawaited(
        _firestore.collection('users').doc(uid).update({
          'lastLoginAt': FieldValue.serverTimestamp(),
        }).catchError((Object err) {
          AppLogger.warning('Unable to update lastLoginAt on users/$uid: $err');
        }),
      );

      return account;
    } catch (e) {
      AppLogger.error('Error querying Firestore for user $uid: $e');
      return null;
    }
  }

  @override
  Future<void> updateUserProfile({
    required String uid,
    required String fullName,
    String phone = '',
    String organizationName = '',
  }) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'fullName': fullName.trim(),
        'phone': phone.trim(),
        'organizationName': organizationName.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      AppLogger.info('Updated profile in Firestore for user: $uid');
    } catch (e) {
      AppLogger.error('Failed to update profile: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateDriveConnectionMetadata({
    required String uid,
    required String driveEmail,
    required String driveFolderId,
    required String spreadsheetId,
  }) async {
    try {
      AppLogger.info('Updating Drive connection metadata in Firestore users/$uid');
      await _firestore.collection('users').doc(uid).update({
        'driveConnected': true,
        'driveEmail': driveEmail,
        'driveFolderId': driveFolderId,
        'spreadsheetId': spreadsheetId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.error('Failed to update Drive connection metadata in Firestore: $e');
    }
  }

  @override
  Future<void> updateClinicSetupStatus({
    required String uid,
    required bool completed,
  }) async {
    try {
      AppLogger.info('Updating clinicSetupCompleted=$completed in Firestore users/$uid');
      await _firestore.collection('users').doc(uid).update({
        'clinicSetupCompleted': completed,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.error('Failed to update clinic setup status in Firestore: $e');
    }
  }

  @override
  Future<bool> checkAccess(PlatformAccount? account) async {
    if (account == null) return false;
    return account.isActive && account.isSubscriptionValid;
  }

  @override
  Future<bool> submitContactInquiry({
    required String name,
    required String email,
    required String phone,
    required String organization,
    required String subject,
    required String category,
    required String message,
  }) async {
    try {
      await _firestore.collection('contact_inquiries').add({
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'organization': organization.trim(),
        'subject': subject.trim(),
        'category': category.trim(),
        'message': message.trim(),
        'status': 'new',
        'source': 'apna_clinic_website',
        'createdAt': FieldValue.serverTimestamp(),
      });
      AppLogger.info('Contact inquiry saved to Firestore for $email');
      return true;
    } catch (e) {
      AppLogger.error('Failed to save contact inquiry to Firestore: $e');
      return false;
    }
  }
}
