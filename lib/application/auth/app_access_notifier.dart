// Apna Clinic - Centralized Application Access & Authentication State Notifier
// Governs the complete lifecycle across:
// 1. Firebase Authentication (Layer 1)
// 2. Firestore Account Verification (Layer 2)
// 3. Google Drive / Sheets Connection (Layer 3)
// 4. Local Clinic Database Readiness

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/app_logger.dart';
import '../../domain/entities/platform_account.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../../infrastructure/database/local_database.dart';
import '../../infrastructure/google/sync/master_sheet_initialization_service.dart';
import 'drive_connection_service.dart';

enum AppAccessStatus {
  initializing,
  unauthenticated,
  authenticating,
  accountLoading,
  accountMissing,
  accountInactive,
  driveRequired,
  clinicSetupRequired,
  ready,
  error,
}

class AppAccessState {
  final AppAccessStatus status;
  final String? firebaseUid;
  final String? firebaseEmail;
  final PlatformAccount? account;
  final bool driveConnected;
  final String? driveEmail;
  final String? driveFolderId;
  final String? driveSpreadsheetId;
  final String? errorMessage;
  final bool isLoading;

  const AppAccessState({
    required this.status,
    this.firebaseUid,
    this.firebaseEmail,
    this.account,
    this.driveConnected = false,
    this.driveEmail,
    this.driveFolderId,
    this.driveSpreadsheetId,
    this.errorMessage,
    this.isLoading = false,
  });

  const AppAccessState.initial()
    : status = AppAccessStatus.initializing,
      firebaseUid = null,
      firebaseEmail = null,
      account = null,
      driveConnected = false,
      driveEmail = null,
      driveFolderId = null,
      driveSpreadsheetId = null,
      errorMessage = null,
      isLoading = true;

  bool get isAuthenticated =>
      status != AppAccessStatus.unauthenticated &&
      status != AppAccessStatus.authenticating &&
      status != AppAccessStatus.initializing &&
      status != AppAccessStatus.error;

  AppAccessState copyWith({
    AppAccessStatus? status,
    String? firebaseUid,
    String? firebaseEmail,
    PlatformAccount? account,
    bool? driveConnected,
    String? driveEmail,
    String? driveFolderId,
    String? driveSpreadsheetId,
    String? errorMessage,
    bool clearError = false,
    bool? isLoading,
  }) {
    return AppAccessState(
      status: status ?? this.status,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      firebaseEmail: firebaseEmail ?? this.firebaseEmail,
      account: account ?? this.account,
      driveConnected: driveConnected ?? this.driveConnected,
      driveEmail: driveEmail ?? this.driveEmail,
      driveFolderId: driveFolderId ?? this.driveFolderId,
      driveSpreadsheetId: driveSpreadsheetId ?? this.driveSpreadsheetId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AppAccessNotifier extends StateNotifier<AppAccessState> {
  final IAuthRepository authRepository;
  final DriveConnectionService driveService;
  final LocalDatabase database;
  final MasterSheetInitializationService? initService;
  StreamSubscription<String?>? _authSubscription;

  AppAccessNotifier({
    required this.authRepository,
    required this.driveService,
    required this.database,
    this.initService,
  }) : super(const AppAccessState.initial()) {
    _listenToAuthChanges();
    initialize();
  }

  void _listenToAuthChanges() {
    _authSubscription?.cancel();
    _authSubscription = authRepository.authStateChanges.listen((uid) {
      if (uid != null && uid.isNotEmpty) {
        if (state.firebaseUid != uid || !state.isAuthenticated) {
          AppLogger.info('Auth state stream emitted user: $uid. Evaluating session...');
          _evaluateAccountAndDrive(uid, authRepository.currentEmail);
        }
      } else {
        if (state.isAuthenticated &&
            state.status != AppAccessStatus.authenticating &&
            state.status != AppAccessStatus.accountLoading) {
          AppLogger.info('Auth state stream emitted null. Transitioning to unauthenticated.');
          state = const AppAccessState(
            status: AppAccessStatus.unauthenticated,
            isLoading: false,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  /// Evaluates full authentication, Firestore account, and Drive connection
  Future<void> initialize() async {
    try {
      AppLogger.info('Initializing AppAccess state machine...');
      var uid = authRepository.currentUid;
      var email = authRepository.currentEmail;

      // In Flutter Web, Firebase Auth restores the session from IndexedDB asynchronously.
      // If currentUid is null at the exact moment of cold start, wait for authStateChanges.
      if (uid == null || uid.isEmpty) {
        try {
          final event = await authRepository.authStateChanges
              .firstWhere((id) => id != null && id.isNotEmpty)
              .timeout(const Duration(milliseconds: 1500));
          if (event != null && event.isNotEmpty) {
            uid = event;
            email = authRepository.currentEmail;
          }
        } catch (_) {
          // Timeout reached with no authenticated user; proceed as unauthenticated.
        }
      }

      if (uid == null || uid.isEmpty) {
        AppLogger.info('No active Firebase user session found. State -> unauthenticated');
        state = state.copyWith(
          status: AppAccessStatus.unauthenticated,
          isLoading: false,
          clearError: true,
        );
        return;
      }

      state = state.copyWith(
        status: AppAccessStatus.accountLoading,
        firebaseUid: uid,
        firebaseEmail: email,
        isLoading: true,
      );

      await _evaluateAccountAndDrive(uid, email);
    } catch (e) {
      AppLogger.error('Error during AppAccess initialization: $e');
      state = state.copyWith(
        status: AppAccessStatus.unauthenticated,
        errorMessage: 'Failed to initialize session: $e',
        isLoading: false,
      );
    }
  }

  /// Signs in using Google via Firebase Authentication
  Future<void> signInWithGoogle() async {
    state = state.copyWith(
      status: AppAccessStatus.authenticating,
      isLoading: true,
      clearError: true,
    );

    try {
      final result = await authRepository.signInWithGoogle();

      if (result.isCancelled) {
        AppLogger.info('Sign-in cancelled. State -> unauthenticated');
        state = state.copyWith(
          status: AppAccessStatus.unauthenticated,
          isLoading: false,
        );
        return;
      }

      if (result.isError || result.uid == null) {
        AppLogger.warning('Sign-in error: ${result.errorMessage}');
        state = state.copyWith(
          status: AppAccessStatus.unauthenticated,
          errorMessage: result.errorMessage ?? 'Authentication failed.',
          isLoading: false,
        );
        return;
      }

      state = state.copyWith(
        status: AppAccessStatus.accountLoading,
        firebaseUid: result.uid,
        firebaseEmail: result.email,
        isLoading: true,
      );

      await _evaluateAccountAndDrive(result.uid!, result.email);
    } catch (e) {
      AppLogger.error('Unexpected error in signInWithGoogle: $e');
      state = state.copyWith(
        status: AppAccessStatus.unauthenticated,
        errorMessage: 'Unexpected login error: $e',
        isLoading: false,
      );
    }
  }

  /// Signs in using email & password
  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(
      status: AppAccessStatus.authenticating,
      isLoading: true,
      clearError: true,
    );
    try {
      final result = await authRepository.signInWithEmailPassword(
        email: email,
        password: password,
      );
      if (result.isError || result.uid == null) {
        state = state.copyWith(
          status: AppAccessStatus.unauthenticated,
          errorMessage: result.errorMessage ?? 'Invalid email or password.',
          isLoading: false,
        );
        return;
      }
      state = state.copyWith(
        status: AppAccessStatus.accountLoading,
        firebaseUid: result.uid,
        firebaseEmail: result.email,
        isLoading: true,
      );
      await _evaluateAccountAndDrive(result.uid!, result.email);
    } catch (e) {
      state = state.copyWith(
        status: AppAccessStatus.unauthenticated,
        errorMessage: 'Sign-in failed: $e',
        isLoading: false,
      );
    }
  }

  /// Registers using Google Auth + creates Firestore user document
  Future<void> registerWithGoogle({
    String? organizationName,
    String? phone,
  }) async {
    state = state.copyWith(
      status: AppAccessStatus.authenticating,
      isLoading: true,
      clearError: true,
    );
    try {
      final result = await authRepository.registerWithGoogle(
        organizationName: organizationName,
        phone: phone,
      );
      if (result.isCancelled) {
        state = state.copyWith(
          status: AppAccessStatus.unauthenticated,
          isLoading: false,
        );
        return;
      }
      if (result.isError || result.uid == null) {
        state = state.copyWith(
          status: AppAccessStatus.unauthenticated,
          errorMessage: result.errorMessage ?? 'Registration failed.',
          isLoading: false,
        );
        return;
      }
      state = state.copyWith(
        status: AppAccessStatus.accountLoading,
        firebaseUid: result.uid,
        firebaseEmail: result.email,
        isLoading: true,
      );
      await _evaluateAccountAndDrive(result.uid!, result.email);
    } catch (e) {
      state = state.copyWith(
        status: AppAccessStatus.unauthenticated,
        errorMessage: 'Registration failed: $e',
        isLoading: false,
      );
    }
  }

  /// Registers using Email/Password + creates Firestore user document
  Future<void> registerWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String? organizationName,
  }) async {
    state = state.copyWith(
      status: AppAccessStatus.authenticating,
      isLoading: true,
      clearError: true,
    );
    try {
      final result = await authRepository.registerWithEmailPassword(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone ?? '',
        organizationName: organizationName ?? '',
      );
      if (result.isError || result.uid == null) {
        state = state.copyWith(
          status: AppAccessStatus.unauthenticated,
          errorMessage: result.errorMessage ?? 'Registration failed.',
          isLoading: false,
        );
        return;
      }
      state = state.copyWith(
        status: AppAccessStatus.accountLoading,
        firebaseUid: result.uid,
        firebaseEmail: result.email,
        isLoading: true,
      );
      await _evaluateAccountAndDrive(result.uid!, result.email);
    } catch (e) {
      state = state.copyWith(
        status: AppAccessStatus.unauthenticated,
        errorMessage: 'Registration failed: $e',
        isLoading: false,
      );
    }
  }

  /// Sends password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await authRepository.sendPasswordResetEmail(email);
  }

  /// Updates profile details
  Future<void> updateUserProfile({
    required String fullName,
    String? phone,
    String? organizationName,
  }) async {
    final uid = state.firebaseUid;
    if (uid == null) return;
    await authRepository.updateUserProfile(
      uid: uid,
      fullName: fullName,
      phone: phone ?? '',
      organizationName: organizationName ?? '',
    );
    // Refresh account state
    final updatedAccount = await authRepository.fetchPlatformAccount(uid);
    if (updatedAccount != null) {
      state = state.copyWith(account: updatedAccount);
    }
  }

  /// Connects Google Drive for operational data storage
  Future<void> connectGoogleDrive({
    String clinicId = 'primary_clinic',
    String clinicName = 'My Clinic',
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    // Prefer user-bound clinic ID if available
    final targetClinicId = (clinicId == 'primary_clinic' && state.firebaseUid != null)
        ? 'clinic_${state.firebaseUid}'
        : clinicId;

    try {
      final result = await driveService.connectAndInitializeDrive(
        clinicId: targetClinicId,
        clinicName: clinicName,
      );

      if (result.isCancelled) {
        state = state.copyWith(isLoading: false);
        return;
      }

      if (!result.isSuccess) {
        state = state.copyWith(
          status: AppAccessStatus.driveRequired,
          errorMessage: result.errorMessage ?? 'Drive connection failed.',
          isLoading: false,
        );
        return;
      }

      final isClinicConfigured = database.query('Clinic_Config').isNotEmpty;
      AppLogger.info('Drive connected. isClinicConfigured=$isClinicConfigured, folderId=${result.folderId}');

      state = state.copyWith(
        status: isClinicConfigured
            ? AppAccessStatus.ready
            : AppAccessStatus.clinicSetupRequired,
        driveConnected: true,
        driveEmail: result.driveEmail,
        driveFolderId: result.folderId,
        driveSpreadsheetId: result.spreadsheetId,
        isLoading: false,
      );

      // Auto-ingest existing records from Google Drive Master Sheet
      if (result.spreadsheetId != null && result.spreadsheetId!.isNotEmpty) {
        unawaited(
          _ingestMasterSheetOnReady(
            uid: targetClinicId,
            driveSpreadsheetId: result.spreadsheetId,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error connecting Google Drive: $e');
      state = state.copyWith(
        status: AppAccessStatus.driveRequired,
        errorMessage: 'Error connecting Google Drive: $e',
        isLoading: false,
      );
    }
  }

  /// Disconnects Google Drive without deleting cloud or local data
  Future<void> disconnectGoogleDrive({String clinicId = 'primary_clinic'}) async {
    try {
      await driveService.disconnectDrive(clinicId: clinicId);
      state = state.copyWith(
        status: AppAccessStatus.driveRequired,
        driveConnected: false,
        driveEmail: null,
      );
    } catch (e) {
      AppLogger.error('Error during Drive disconnect: $e');
    }
  }

  /// Signs out of Apna Clinic (Firebase Auth logout)
  Future<void> signOut() async {
    try {
      AppLogger.info('Signing out of Apna Clinic...');
      await authRepository.logout();
      state = const AppAccessState(
        status: AppAccessStatus.unauthenticated,
        isLoading: false,
      );
    } catch (e) {
      AppLogger.error('Error signing out: $e');
      state = const AppAccessState(
        status: AppAccessStatus.unauthenticated,
        isLoading: false,
      );
    }
  }

  /// Re-evaluates Firestore account and Drive connection status
  Future<void> _evaluateAccountAndDrive(String uid, String? email) async {
    try {
      final account = await authRepository.fetchPlatformAccount(uid);
      final activeAccount = account ??
          PlatformAccount(
            uid: uid,
            email: email ?? '',
            fullName: email != null && email.isNotEmpty
                ? email.split('@').first
                : 'Doctor',
            organizationName: 'Apna Clinic',
            phone: '',
            accountStatus: 'active',
            clinicSetupCompleted: true,
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          );

      if (!activeAccount.isActive) {
        AppLogger.warning('Account status inactive (${activeAccount.accountStatus}) for UID: $uid');
        state = state.copyWith(
          status: AppAccessStatus.accountInactive,
          account: activeAccount,
          firebaseUid: uid,
          firebaseEmail: email,
          isLoading: false,
        );
        return;
      }

      // Check Google Drive OAuth authorization
      final localFolderId = await driveService.getConnectedDriveFolderId();
      final isDriveConnected = await driveService.isDriveConnected();
      final driveEmail =
          activeAccount.driveEmail ?? await driveService.getConnectedDriveEmail();
      final driveSpreadsheetId =
          activeAccount.spreadsheetId ?? await driveService.getSpreadsheetId();
      final driveFolderId =
          (localFolderId != null && !localFolderId.startsWith('local_folder_'))
              ? localFolderId
              : (activeAccount.driveFolderId != null && !activeAccount.driveFolderId!.startsWith('local_folder_')
                  ? activeAccount.driveFolderId
                  : null);

      final hasDriveAccess =
          activeAccount.driveConnected || (isDriveConnected && driveFolderId != null);

      if (!hasDriveAccess) {
        AppLogger.info('Drive connection required for UID: $uid');
        state = state.copyWith(
          status: AppAccessStatus.driveRequired,
          account: activeAccount,
          firebaseUid: uid,
          firebaseEmail: email,
          driveConnected: false,
          driveEmail: driveEmail,
          driveFolderId: null,
          driveSpreadsheetId: null,
          isLoading: false,
        );
        return;
      }

      // Trigger self-healing placement: ensure sheet is in root "Apna Clinic" folder
      unawaited(
        driveService.tokenVault.getAccessToken(uid).then((token) async {
          final validToken = token ??
              await driveService.tokenVault.getAccessToken('clinic_$uid') ??
              await driveService.tokenVault.getAccessToken('primary_clinic');
          if (validToken != null && validToken.isNotEmpty) {
            await driveService.ensureWorkspacePlacement(
              accessToken: validToken,
              clinicId: uid,
            );
          }
        }).catchError((_) {}),
      );

      // Check Clinic setup
      final isClinicConfigured =
          database.query('Clinic_Config').isNotEmpty || activeAccount.clinicSetupCompleted;

      if (!isClinicConfigured) {
        AppLogger.info('Clinic onboarding setup required.');
        state = state.copyWith(
          status: AppAccessStatus.clinicSetupRequired,
          account: activeAccount,
          firebaseUid: uid,
          firebaseEmail: email,
          driveConnected: true,
          driveEmail: driveEmail,
          driveFolderId: driveFolderId,
          driveSpreadsheetId: driveSpreadsheetId,
          isLoading: false,
        );
        return;
      }

      AppLogger.info('AppAccess evaluated: READY for UID: $uid (Drive folder: $driveFolderId, Sheet: $driveSpreadsheetId)');
      state = state.copyWith(
        status: AppAccessStatus.ready,
        account: activeAccount,
        firebaseUid: uid,
        firebaseEmail: email,
        driveConnected: true,
        driveEmail: driveEmail,
        driveFolderId: driveFolderId,
        driveSpreadsheetId: driveSpreadsheetId,
        isLoading: false,
      );

      // Auto-ingest existing records from Google Drive Master Sheet on startup
      unawaited(
        _ingestMasterSheetOnReady(
          uid: uid,
          driveSpreadsheetId: driveSpreadsheetId,
        ),
      );
    } catch (e) {
      AppLogger.error('Error during _evaluateAccountAndDrive: $e');
      state = state.copyWith(
        status: AppAccessStatus.ready,
        firebaseUid: uid,
        firebaseEmail: email,
        isLoading: false,
      );
    }
  }

  Future<void> _ingestMasterSheetOnReady({
    required String uid,
    String? driveSpreadsheetId,
  }) async {
    if (initService == null) return;
    try {
      final token = await driveService.tokenVault.getAccessToken(uid) ??
          await driveService.tokenVault.getAccessToken('clinic_$uid') ??
          await driveService.tokenVault.getAccessToken('primary_clinic');
      if (token != null && token.isNotEmpty) {
        AppLogger.info('AppAccess: Starting startup Master Sheet ingestion for clinic $uid');
        final result = await initService!.initializeFromMasterSheet(
          clinicId: uid,
          explicitSpreadsheetId: driveSpreadsheetId,
          explicitAccessToken: token,
          createIfMissing: false,
        );
        AppLogger.info(
          'AppAccess: Master Sheet ingestion finished. Imported: ${result.totalRecordsImported}',
        );
      }
    } catch (e) {
      AppLogger.warning('AppAccess: Startup Master Sheet ingestion non-fatal notice: $e');
    }
  }

  /// Called after successful onboarding
  void markClinicSetupCompleted() {
    final uid = state.firebaseUid;
    if (uid != null && uid.isNotEmpty) {
      authRepository.updateClinicSetupStatus(uid: uid, completed: true);
    }
    state = state.copyWith(
      status: AppAccessStatus.ready,
      account: state.account?.copyWith(clinicSetupCompleted: true),
    );
  }
}
