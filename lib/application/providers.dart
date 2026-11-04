import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../core/permissions/roles.dart';
import '../domain/entities/auth_session.dart';
import '../infrastructure/database/local_database.dart';
import '../infrastructure/database/shared_preferences_storage_adapter.dart';
import '../infrastructure/google/google_drive_client.dart';
import '../infrastructure/google/google_sheets_client.dart';
import '../infrastructure/google/mock_google_integration.dart';
import '../infrastructure/google/oauth/google_oauth_provider.dart';
import '../infrastructure/google/oauth/i_google_oauth_provider.dart';
import '../infrastructure/google/oauth/mock_google_oauth_provider.dart';
import '../infrastructure/google/oauth/oauth_browser_helper.dart';
import '../infrastructure/google/oauth/token_vault.dart';
import '../infrastructure/google/sync/master_sheet_conflict_detector.dart';
import '../infrastructure/google/sync/master_sheet_initialization_service.dart';
import '../infrastructure/google/sync/master_sheet_sync_engine.dart';
import '../infrastructure/google/sync/master_sheet_sync_scheduler.dart';
import '../infrastructure/google/sync/sync_observability_service.dart';
import '../domain/repositories/i_auth_repository.dart';
import '../infrastructure/auth/firebase_auth_repository.dart';
import '../infrastructure/auth/mock_auth_repository.dart';
import '../infrastructure/repositories/infrastructure_repositories.dart';
import 'auth/app_access_notifier.dart';
import 'auth/auth_service.dart';
import 'auth/drive_connection_service.dart';
import '../domain/enums/domain_enums.dart';
import '../domain/entities/audit_event.dart';
import '../domain/entities/subscription.dart';
import '../domain/services/subscription_service.dart';

/// Global ProviderContainer reference for reliable route guard lookups and outside-of-tree resolution
ProviderContainer? appProviderContainer;

/// Database Singleton Provider
final localDatabaseProvider = Provider<LocalDatabase>((ref) {
  final storage = SharedPreferencesStorageAdapter();
  return LocalDatabase(storage);
});

/// Repositories Providers
final clinicRepositoryProvider = Provider<ClinicRepository>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return ClinicRepository(db);
});

final patientRepositoryProvider = Provider<PatientRepository>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return PatientRepository(db);
});

final visitRepositoryProvider = Provider<VisitRepository>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return VisitRepository(db);
});

final appointmentRepositoryProvider = Provider<AppointmentRepository>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return AppointmentRepository(db);
});

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return BillingRepository(db);
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return ExpenseRepository(db);
});

final followupRepositoryProvider = Provider<FollowupRepository>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return FollowupRepository(db);
});

final deviceCollaborationRepositoryProvider =
    Provider<DeviceCollaborationRepository>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return DeviceCollaborationRepository(db);
});

final branchRepositoryProvider = Provider<BranchRepository>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return BranchRepository(db);
});

final auditRepositoryProvider = Provider<AuditRepository>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return AuditRepository(db);
});

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return SyncRepository(db);
});

final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return BackupRepository(db);
});

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return ReportsRepository(
    db: db,
    visitRepo: ref.watch(visitRepositoryProvider),
    billingRepo: ref.watch(billingRepositoryProvider),
    clinicRepo: ref.watch(clinicRepositoryProvider),
    patientRepo: ref.watch(patientRepositoryProvider),
    syncRepo: ref.watch(syncRepositoryProvider),
  );
});

/// Secure OAuth Token Vault Provider
final tokenVaultProvider = Provider<TokenVault>((ref) {
  final storage = SharedPreferencesStorageAdapter();
  return TokenVault(storage);
});

/// Google OAuth Provider (Factory based on AppConfig)
final googleOAuthProvider = Provider<IGoogleOAuthProvider>((ref) {
  final config = AppConfig.current;
  // In development, testing, or when client ID is unconfigured, utilize MockGoogleOAuthProvider
  // to ensure 100% offline-first operation and deterministic reliability.
  if (config.useMockAuth || config.googleClientId.isEmpty) {
    return MockGoogleOAuthProvider();
  }
  final currentOrigin = OAuthBrowserHelper.getCurrentOrigin();
  final redirectUri = currentOrigin.isNotEmpty
      ? currentOrigin
      : config.appBaseUrl;
  return GoogleOAuthProvider(
    clientId: config.googleClientId,
    redirectUri: redirectUri,
    scopes: config.googleOAuthScopes,
  );
});

/// Authentication Application Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  final oauth = ref.watch(googleOAuthProvider);
  final vault = ref.watch(tokenVaultProvider);
  final notifier = ref.watch(sessionProvider.notifier);
  final clinicRepo = ref.watch(clinicRepositoryProvider);
  return AuthService(
    oauthProvider: oauth,
    tokenVault: vault,
    sessionNotifier: notifier,
    clinicRepository: clinicRepo,
  );
});

/// Layer 1 & 2 Platform Authentication Repository (Firebase Auth + Firestore)
final authRepositoryProvider = Provider<IAuthRepository>((ref) {
  final config = AppConfig.current;
  if (config.isProduction) {
    return FirebaseAuthRepository();
  }
  if (config.useMockAuth || !config.hasFirebaseConfig) {
    return MockAuthRepository();
  }
  return FirebaseAuthRepository();
});

/// Layer 3 Google Drive Connection Service (Clinic-Owned Cloud Data)
final driveConnectionServiceProvider = Provider<DriveConnectionService>((ref) {
  final oauth = ref.watch(googleOAuthProvider);
  final vault = ref.watch(tokenVaultProvider);
  final driveClient = ref.watch(googleDriveClientProvider);
  final sheetsClient = ref.watch(googleSheetsClientProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  return DriveConnectionService(
    oauthProvider: oauth,
    tokenVault: vault,
    driveClient: driveClient,
    sheetsClient: sheetsClient,
    authRepository: authRepo,
  );
});

/// Centralized Application Access State Machine Notifier
final appAccessProvider =
    StateNotifierProvider<AppAccessNotifier, AppAccessState>((ref) {
      final authRepo = ref.watch(authRepositoryProvider);
      final driveService = ref.watch(driveConnectionServiceProvider);
      final db = ref.watch(localDatabaseProvider);
      final initService = ref.watch(masterSheetInitializationServiceProvider);
      return AppAccessNotifier(
        authRepository: authRepo,
        driveService: driveService,
        database: db,
        initService: initService,
      );
    });

/// Google Drive Client Provider
final googleDriveClientProvider = Provider<GoogleDriveClient>((ref) {
  final config = AppConfig.current;
  if (config.useMockAuth || config.googleClientId.isEmpty) {
    return MockGoogleDriveClient();
  }
  return GoogleDriveClient();
});

/// Google Sheets Client Provider
final googleSheetsClientProvider = Provider<GoogleSheetsClient>((ref) {
  final config = AppConfig.current;
  if (config.useMockAuth || config.googleClientId.isEmpty) {
    return MockGoogleSheetsClient();
  }
  return GoogleSheetsClient();
});

/// Master Sheet One-Way Initialization Service Provider (Milestone 3)
final masterSheetInitializationServiceProvider =
    Provider<MasterSheetInitializationService>((ref) {
      final driveClient = ref.watch(googleDriveClientProvider);
      final sheetsClient = ref.watch(googleSheetsClientProvider);
      final db = ref.watch(localDatabaseProvider);
      final authService = ref.watch(authServiceProvider);
      return MasterSheetInitializationService(
        driveClient: driveClient,
        sheetsClient: sheetsClient,
        localDb: db,
        authService: authService,
      );
    });

/// Master Sheet One-Way Sync Engine Provider (Milestone 3)
final masterSheetSyncEngineProvider = Provider<MasterSheetSyncEngine>((ref) {
  final driveClient = ref.watch(googleDriveClientProvider);
  final sheetsClient = ref.watch(googleSheetsClientProvider);
  final db = ref.watch(localDatabaseProvider);
  final syncRepo = ref.watch(syncRepositoryProvider);
  final authService = ref.watch(authServiceProvider);
  return MasterSheetSyncEngine(
    driveClient: driveClient,
    sheetsClient: sheetsClient,
    localDb: db,
    syncRepository: syncRepo,
    authService: authService,
  );
});

/// Master Sheet Two-Way Conflict Detector Provider (Milestone 4)
final masterSheetConflictDetectorProvider =
    Provider<MasterSheetConflictDetector>((ref) {
      final driveClient = ref.watch(googleDriveClientProvider);
      final sheetsClient = ref.watch(googleSheetsClientProvider);
      final db = ref.watch(localDatabaseProvider);
      final syncRepo = ref.watch(syncRepositoryProvider);
      final authService = ref.watch(authServiceProvider);
      return MasterSheetConflictDetector(
        driveClient: driveClient,
        sheetsClient: sheetsClient,
        localDb: db,
        syncRepository: syncRepo,
        authService: authService,
      );
    });

/// Production Sync Observability Service Provider (Milestone 4)
final syncObservabilityServiceProvider = Provider<SyncObservabilityService>((
  ref,
) {
  final db = ref.watch(localDatabaseProvider);
  return SyncObservabilityService(localDb: db);
});

/// Controlled Master Sheet Sync Scheduler Provider (Milestone 4)
final masterSheetSyncSchedulerProvider = Provider<MasterSheetSyncScheduler>((
  ref,
) {
  final engine = ref.watch(masterSheetSyncEngineProvider);
  final observability = ref.watch(syncObservabilityServiceProvider);
  final scheduler = MasterSheetSyncScheduler(
    syncEngine: engine,
    observabilityService: observability,
  );
  ref.onDispose(() {
    scheduler.dispose();
  });
  return scheduler;
});

/// Current Active Session State
class SessionState {
  final String clinicId;
  final String staffId;
  final String staffName;
  final UserRole role;
  final String deviceId;
  final bool isPrimaryWriter;
  final bool isGoogleAuthenticated;
  final String? googleUserEmail;
  final String? googleUserDisplayName;
  final String? googleUserPhotoUrl;
  final AuthStatus authStatus;
  final String? authError;
  final String? authErrorCode;
  final bool isWorkstationLocked;
  final bool isAutoLocked;
  final String? assignedDoctorId;
  final int failedPinAttempts;
  final DateTime? lockoutUntil;

  const SessionState({
    required this.clinicId,
    required this.staffId,
    required this.staffName,
    required this.role,
    required this.deviceId,
    this.isPrimaryWriter = true,
    this.isGoogleAuthenticated = false,
    this.googleUserEmail,
    this.googleUserDisplayName,
    this.googleUserPhotoUrl,
    this.authStatus = AuthStatus.unauthenticated,
    this.authError,
    this.authErrorCode,
    this.isWorkstationLocked = false,
    this.isAutoLocked = false,
    this.assignedDoctorId,
    this.failedPinAttempts = 0,
    this.lockoutUntil,
  });

  bool get isLockedOut =>
      lockoutUntil != null && DateTime.now().isBefore(lockoutUntil!);

  int get lockoutSecondsRemaining => lockoutUntil != null
      ? lockoutUntil!.difference(DateTime.now()).inSeconds.clamp(0, 60)
      : 0;

  SessionState copyWith({
    String? clinicId,
    String? staffId,
    String? staffName,
    UserRole? role,
    String? deviceId,
    bool? isPrimaryWriter,
    bool? isGoogleAuthenticated,
    String? googleUserEmail,
    String? googleUserDisplayName,
    String? googleUserPhotoUrl,
    AuthStatus? authStatus,
    String? authError,
    String? authErrorCode,
    bool? isWorkstationLocked,
    bool? isAutoLocked,
    String? assignedDoctorId,
    int? failedPinAttempts,
    DateTime? lockoutUntil,
    bool clearAuthError = false,
    bool clearGoogleUser = false,
    bool clearLockout = false,
  }) {
    return SessionState(
      clinicId: clinicId ?? this.clinicId,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      role: role ?? this.role,
      deviceId: deviceId ?? this.deviceId,
      isPrimaryWriter: isPrimaryWriter ?? this.isPrimaryWriter,
      isGoogleAuthenticated:
          isGoogleAuthenticated ?? this.isGoogleAuthenticated,
      googleUserEmail: clearGoogleUser
          ? null
          : (googleUserEmail ?? this.googleUserEmail),
      googleUserDisplayName: clearGoogleUser
          ? null
          : (googleUserDisplayName ?? this.googleUserDisplayName),
      googleUserPhotoUrl: clearGoogleUser
          ? null
          : (googleUserPhotoUrl ?? this.googleUserPhotoUrl),
      authStatus: authStatus ?? this.authStatus,
      authError: clearAuthError ? null : (authError ?? this.authError),
      authErrorCode: clearAuthError
          ? null
          : (authErrorCode ?? this.authErrorCode),
      isWorkstationLocked: isWorkstationLocked ?? this.isWorkstationLocked,
      isAutoLocked: isAutoLocked ?? this.isAutoLocked,
      assignedDoctorId: assignedDoctorId ?? this.assignedDoctorId,
      failedPinAttempts: failedPinAttempts ?? this.failedPinAttempts,
      lockoutUntil: clearLockout ? null : (lockoutUntil ?? this.lockoutUntil),
    );
  }
}

class SessionNotifier extends StateNotifier<SessionState> {
  static const String _savedRoleKey = 'apna_clinic_active_user_role';
  static const String _ownerPinKey = 'apna_clinic_owner_workstation_pin';
  static const String _workstationLockedKey = 'apna_clinic_workstation_locked';
  static const String defaultOwnerPin = '1234';

  SessionNotifier()
    : super(
        const SessionState(
          clinicId: 'clinic_primary_demo',
          staffId: 'staff_reception_01',
          staffName: 'Reception Desk',
          role: UserRole.receptionist,
          deviceId: 'device_primary_web',
          isPrimaryWriter: true,
          isGoogleAuthenticated: false,
          authStatus: AuthStatus.unauthenticated,
          isWorkstationLocked: false,
          isAutoLocked: false,
          failedPinAttempts: 0,
        ),
      );

  String get currentClinicId => state.clinicId;
  SessionState get currentSessionState => state;

  /// Retrieves the configured Owner PIN (default: '1234')
  Future<String> getOwnerPin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_ownerPinKey) ?? defaultOwnerPin;
    } catch (_) {
      return defaultOwnerPin;
    }
  }

  /// Sets a new Owner PIN for unlocking the workstation
  Future<void> setOwnerPin(String newPin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ownerPinKey, newPin.trim());
    } catch (_) {}
  }

  /// Verifies entered PIN against saved Owner PIN
  Future<bool> verifyOwnerPin(String pin) async {
    final current = await getOwnerPin();
    return pin.trim() == current.trim();
  }

  /// Locks the workstation into a specific staff role (Receptionist, Doctor, Accountant).
  /// Once locked, non-owner staff cannot switch roles or elevate privileges without Owner PIN.
  /// For Doctor role, binds the workstation to a specific [doctorId] to enforce PRD queue isolation.
  Future<void> lockWorkstationToRole(
    UserRole role, {
    String? doctorId,
    String? doctorName,
  }) async {
    final locked = role != UserRole.owner;
    state = state.copyWith(
      role: role,
      assignedDoctorId: doctorId,
      staffId: doctorId ?? state.staffId,
      staffName: doctorName ?? state.staffName,
      isWorkstationLocked: locked,
      isAutoLocked: false,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_savedRoleKey, role.wireValue);
      await prefs.setBool(_workstationLockedKey, locked);
      if (doctorId != null) {
        await prefs.setString('apna_clinic_assigned_doctor_id', doctorId);
      } else if (role == UserRole.owner) {
        await prefs.remove('apna_clinic_assigned_doctor_id');
      }
      if (doctorName != null) {
        await prefs.setString('apna_clinic_assigned_doctor_name', doctorName);
      } else if (role == UserRole.owner) {
        await prefs.remove('apna_clinic_assigned_doctor_name');
      }
    } catch (_) {}
  }

  /// Explicitly locks workstation with audit logging
  Future<void> lockWorkstation({
    LocalDatabase? db,
    String? reason,
  }) async {
    state = state.copyWith(isWorkstationLocked: true, isAutoLocked: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_workstationLockedKey, true);
    } catch (_) {}

    _logAuditEvent(
      db: db,
      action: 'workstation.lock',
      entityType: 'workstation',
      entityId: state.deviceId,
      reason: reason ?? 'Explicit workstation lock by staff',
    );
  }

  /// Automatically locks workstation on inactivity timeout with audit logging
  Future<void> autoLockWorkstation([LocalDatabase? db]) async {
    if (state.isAutoLocked) return;
    state = state.copyWith(isWorkstationLocked: true, isAutoLocked: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_workstationLockedKey, true);
    } catch (_) {}

    _logAuditEvent(
      db: db,
      action: 'workstation.autolock',
      entityType: 'workstation',
      entityId: state.deviceId,
      reason: 'Workstation auto-locked after inactivity timeout',
    );
  }

  /// Unlocks the workstation back using Owner PIN or distinct Staff PIN.
  /// Enforces brute-force lockout after 5 consecutive failures.
  Future<bool> unlockWorkstation(
    String pin, {
    ClinicRepository? clinicRepo,
    LocalDatabase? db,
  }) async {
    final trimmedPin = pin.trim();

    // Check brute-force lockout
    if (state.isLockedOut) {
      _logAuditEvent(
        db: db,
        action: 'auth.pin_blocked',
        entityType: 'workstation',
        entityId: state.deviceId,
        result: AuditResult.denied,
        reason: 'PIN entry blocked during active lockout window',
      );
      return false;
    }

    // 1. Verify against Owner PIN
    final isOwnerValid = await verifyOwnerPin(trimmedPin);
    if (isOwnerValid) {
      state = state.copyWith(
        role: UserRole.owner,
        isWorkstationLocked: false,
        isAutoLocked: false,
        failedPinAttempts: 0,
        clearLockout: true,
      );
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_savedRoleKey, UserRole.owner.wireValue);
        await prefs.setBool(_workstationLockedKey, false);
      } catch (_) {}

      _logAuditEvent(
        db: db,
        action: 'workstation.unlock',
        entityType: 'workstation',
        entityId: state.deviceId,
        reason: 'Workstation unlocked with Owner PIN (Admin mode restored)',
      );
      return true;
    }

    // 2. Check against individual staff member PINs
    if (clinicRepo != null) {
      try {
        final staffList = await clinicRepo.getStaffMembers(
          state.clinicId,
          activeOnly: true,
        );
        for (final staff in staffList) {
          if (staff.verifyPin(trimmedPin)) {
            final isLocked = staff.role != UserRole.owner;
            state = state.copyWith(
              staffId: staff.staffId,
              staffName: staff.displayName,
              role: staff.role,
              assignedDoctorId: staff.assignedDoctorIds.isNotEmpty
                  ? staff.assignedDoctorIds.first
                  : null,
              isWorkstationLocked: isLocked,
              isAutoLocked: false,
              failedPinAttempts: 0,
              clearLockout: true,
            );
            try {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(_savedRoleKey, staff.role.wireValue);
              await prefs.setBool(_workstationLockedKey, isLocked);
            } catch (_) {}

            _logAuditEvent(
              db: db,
              action: 'workstation.unlock',
              entityType: 'workstation',
              entityId: state.deviceId,
              reason:
                  'Workstation unlocked by ${staff.displayName} (${staff.role.wireValue})',
            );
            return true;
          }
        }
      } catch (_) {}
    }

    // 3. Failed PIN entry: update attempts & apply lockout if reached threshold
    final newAttempts = state.failedPinAttempts + 1;
    final willLockout = newAttempts >= 5;
    final lockoutTime = willLockout
        ? DateTime.now().add(const Duration(seconds: 30))
        : null;

    state = state.copyWith(
      failedPinAttempts: newAttempts,
      lockoutUntil: lockoutTime,
    );

    if (willLockout) {
      _logAuditEvent(
        db: db,
        action: 'auth.pin_lockout',
        entityType: 'workstation',
        entityId: state.deviceId,
        result: AuditResult.denied,
        reason: '5 consecutive invalid PIN attempts. Workstation locked for 30s.',
      );
    } else {
      _logAuditEvent(
        db: db,
        action: 'auth.pin_failure',
        entityType: 'workstation',
        entityId: state.deviceId,
        result: AuditResult.failure,
        reason: 'Invalid PIN attempt ($newAttempts of 5)',
      );
    }

    return false;
  }

  void switchRole(UserRole newRole) {
    state = state.copyWith(
      role: newRole,
      isWorkstationLocked: newRole != UserRole.owner,
      isAutoLocked: false,
    );
    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(_savedRoleKey, newRole.wireValue);
        prefs.setBool(_workstationLockedKey, newRole != UserRole.owner);
      });
    } catch (_) {}
  }

  Future<void> restoreSavedRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_savedRoleKey);
      final isLocked = prefs.getBool(_workstationLockedKey) ?? false;
      final savedDocId = prefs.getString('apna_clinic_assigned_doctor_id');
      final savedDocName = prefs.getString('apna_clinic_assigned_doctor_name');
      if (saved != null && saved.isNotEmpty) {
        final role = UserRole.fromWire(saved);
        state = state.copyWith(
          role: role,
          assignedDoctorId: savedDocId,
          staffId: savedDocId ?? state.staffId,
          staffName: savedDocName ?? state.staffName,
          isWorkstationLocked: isLocked && role != UserRole.owner,
        );
      }
    } catch (_) {}
  }

  void setClinic(String clinicId, String staffId, String staffName, [String? doctorId]) {
    state = state.copyWith(
      clinicId: clinicId,
      staffId: staffId,
      staffName: staffName,
      assignedDoctorId: doctorId,
    );
  }

  void _logAuditEvent({
    required LocalDatabase? db,
    required String action,
    required String entityType,
    required String entityId,
    required String reason,
    AuditResult result = AuditResult.success,
  }) {
    if (db == null) return;
    try {
      final now = DateTime.now().toUtc();
      final event = AuditEvent(
        auditEventId: 'audit_auth_${DateTime.now().microsecondsSinceEpoch}',
        clinicId: state.clinicId,
        actorId: state.staffId,
        actorRole: state.role.wireValue,
        deviceId: state.deviceId,
        action: action,
        entityType: entityType,
        entityId: entityId,
        occurredAt: now,
        correlationId: 'sec_${DateTime.now().millisecondsSinceEpoch}',
        result: result,
        reasonOptional: reason,
      );
      db.upsert('Audit_Events', event.auditEventId, event.toMap());
    } catch (_) {}
  }

  void setGoogleAuth({required bool isAuthenticated, String? email}) {
    state = state.copyWith(
      isGoogleAuthenticated: isAuthenticated,
      googleUserEmail: email,
      authStatus: isAuthenticated
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
      clearAuthError: true,
    );
  }

  void setGoogleAuthSuccess({
    required String email,
    required String displayName,
    String? photoUrl,
  }) {
    state = state.copyWith(
      isGoogleAuthenticated: true,
      googleUserEmail: email,
      googleUserDisplayName: displayName,
      googleUserPhotoUrl: photoUrl,
      authStatus: AuthStatus.authenticated,
      clearAuthError: true,
    );
  }

  void setGoogleAuthOffline({
    required String email,
    required String displayName,
    String? photoUrl,
  }) {
    state = state.copyWith(
      isGoogleAuthenticated: true,
      googleUserEmail: email,
      googleUserDisplayName: displayName,
      googleUserPhotoUrl: photoUrl,
      authStatus: AuthStatus.authenticated,
      clearAuthError: true,
    );
  }

  void setGoogleAuthCancelled() {
    state = state.copyWith(
      authStatus: AuthStatus.cancelled,
      authError: 'Sign-in was cancelled.',
      authErrorCode: 'CANCELLED',
    );
  }

  void setGoogleAuthFailure(String error, [String? errorCode]) {
    state = state.copyWith(
      authStatus: AuthStatus.error,
      authError: error,
      authErrorCode: errorCode ?? 'AUTH_FAILURE',
    );
  }

  void clearGoogleAuth() {
    state = state.copyWith(
      isGoogleAuthenticated: false,
      clearGoogleUser: true,
      authStatus: AuthStatus.unauthenticated,
      clearAuthError: true,
    );
  }
}

final sessionProvider = StateNotifierProvider<SessionNotifier, SessionState>((
  ref,
) {
  return SessionNotifier();
});

/// Sync Health & Connectivity Status State
enum AppSyncStatus { online, syncing, offline, syncError, backupRequired }

class SyncHealthState {
  final AppSyncStatus status;
  final int pendingOutboxCount;
  final DateTime? lastSyncTime;
  final DateTime? lastVerifiedBackupTime;
  final String? errorMessage;

  const SyncHealthState({
    this.status = AppSyncStatus.online,
    this.pendingOutboxCount = 0,
    this.lastSyncTime,
    this.lastVerifiedBackupTime,
    this.errorMessage,
  });

  SyncHealthState copyWith({
    AppSyncStatus? status,
    int? pendingOutboxCount,
    DateTime? lastSyncTime,
    DateTime? lastVerifiedBackupTime,
    String? errorMessage,
  }) {
    return SyncHealthState(
      status: status ?? this.status,
      pendingOutboxCount: pendingOutboxCount ?? this.pendingOutboxCount,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastVerifiedBackupTime:
          lastVerifiedBackupTime ?? this.lastVerifiedBackupTime,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class SyncHealthNotifier extends StateNotifier<SyncHealthState> {
  final SyncRepository _syncRepo;

  SyncHealthNotifier(this._syncRepo) : super(const SyncHealthState());

  Future<void> refresh(String clinicId) async {
    try {
      final count = await _syncRepo.countPendingOutboxEvents(clinicId);
      final lastManifest = await _syncRepo.getLastSyncManifest(clinicId);

      state = state.copyWith(
        pendingOutboxCount: count,
        lastSyncTime: lastManifest?.confirmedAt ?? lastManifest?.uploadedAt,
        status: count > 0 ? AppSyncStatus.syncing : AppSyncStatus.online,
      );
    } catch (_) {
      state = state.copyWith(status: AppSyncStatus.offline);
    }
  }

  void setStatus(AppSyncStatus newStatus, [String? error]) {
    state = state.copyWith(status: newStatus, errorMessage: error);
  }

  void markBackupVerified(DateTime timestamp) {
    state = state.copyWith(lastVerifiedBackupTime: timestamp);
  }
}

final syncHealthProvider =
    StateNotifierProvider<SyncHealthNotifier, SyncHealthState>((ref) {
      final syncRepo = ref.watch(syncRepositoryProvider);
      return SyncHealthNotifier(syncRepo);
    });

/// Module 10: Subscription Service Provider
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return SubscriptionService(db);
});

/// Module 10: Reactive Subscription State Notifier
class SubscriptionNotifier extends StateNotifier<AsyncValue<ClinicSubscription>> {
  final SubscriptionService _service;
  final String _clinicId;

  SubscriptionNotifier(this._service, this._clinicId)
      : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      final sub = await _service.getSubscription(_clinicId);
      state = AsyncValue.data(sub);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> renewAnnual({
    required String actorId,
    String? paymentReference,
  }) async {
    state = const AsyncValue.loading();
    try {
      final sub = await _service.renewAnnualSubscription(
        clinicId: _clinicId,
        actorId: actorId,
        paymentReference: paymentReference,
      );
      state = AsyncValue.data(sub);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> activateOfflineKey({
    required String licenseKey,
    required String actorId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final sub = await _service.activateOfflineLicenseKey(
        clinicId: _clinicId,
        licenseKeyString: licenseKey,
        actorId: actorId,
      );
      state = AsyncValue.data(sub);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, AsyncValue<ClinicSubscription>>((ref) {
  final service = ref.watch(subscriptionServiceProvider);
  final session = ref.watch(sessionProvider);
  return SubscriptionNotifier(service, session.clinicId);
});

