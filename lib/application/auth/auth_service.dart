// Apna Clinic - Authentication Application Service
// Primary source of truth: Phase 3 Architecture Plan (Section 4 & 5)
// Orchestrates OAuth authentication, encrypted TokenVault lifecycle,
// session state updates, and graceful offline fallback.

import 'dart:async';

import '../../core/errors/failures.dart';
import '../../core/logging/app_logger.dart';
import '../../core/permissions/roles.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/i_clinic_repository.dart';
import '../../infrastructure/google/oauth/google_oauth_provider.dart';
import '../../infrastructure/google/oauth/i_google_oauth_provider.dart';
import '../../infrastructure/google/oauth/token_vault.dart';
import '../providers.dart';

class AuthService {
  final IGoogleOAuthProvider oauthProvider;
  final TokenVault tokenVault;
  final SessionNotifier sessionNotifier;
  final IClinicRepository? clinicRepository;

  AuthService({
    required this.oauthProvider,
    required this.tokenVault,
    required this.sessionNotifier,
    this.clinicRepository,
  });

  /// Returns the current OAuth session state from the provider
  GoogleAuthSession get currentSession => oauthProvider.currentSession;

  /// Reactive stream of session updates
  Stream<GoogleAuthSession> get sessionStream => oauthProvider.sessionStream;

  /// Initiates interactive Google sign-in
  Future<GoogleAuthResult> signIn({String? clinicId}) async {
    final activeClinicId = clinicId ?? sessionNotifier.currentClinicId;

    try {
      AppLogger.info('Starting Google Sign-In for clinic: $activeClinicId');
      final result = await oauthProvider.signIn();

      if (result.isSuccess && result.user != null) {
        final user = result.user!;
        final tokens = result.tokens!;

        // 1. Securely persist refresh token in encrypted vault if present
        if (tokens.refreshToken != null && tokens.refreshToken!.isNotEmpty) {
          await tokenVault.saveRefreshToken(
            activeClinicId,
            tokens.refreshToken!,
          );
        }

        // 2. Persist access token in vault
        if (tokens.accessToken.isNotEmpty) {
          await tokenVault.saveAccessToken(
            activeClinicId,
            tokens.accessToken,
            tokens.expiresAt,
          );
        }

        // 3. Persist cached user profile for offline session display
        await tokenVault.saveCachedUser(activeClinicId, user);
        await tokenVault.saveLastAuthTime(activeClinicId, DateTime.now().toUtc());

        // 4. Update application session state with automated staff role enforcement
        await _applyStaffRoleForEmail(activeClinicId, user);

        AppLogger.info('Google Sign-In successful for ${user.email}');
        return result;
      } else if (result.isCancelled) {
        AppLogger.info('Google Sign-In cancelled by user.');
        sessionNotifier.setGoogleAuthCancelled();
        return result;
      } else if (result.isRedirecting) {
        AppLogger.info('Google Sign-In redirecting browser window.');
        return result;
      } else {
        final err = result.errorMessage ?? 'Google authentication failed.';
        AppLogger.warning('Google Sign-In failed: $err (${result.errorCode})');
        sessionNotifier.setGoogleAuthFailure(err, result.errorCode);
        return result;
      }
    } catch (e) {
      final err = 'Unexpected authentication error: $e';
      AppLogger.error(err);
      sessionNotifier.setGoogleAuthFailure(err, 'UNEXPECTED_ERROR');
      return GoogleAuthResult.failure(err, errorCode: 'UNEXPECTED_ERROR');
    }
  }

  /// Signs out user, revokes tokens, and clears local encrypted vault
  Future<void> signOut({String? clinicId}) async {
    final activeClinicId = clinicId ?? sessionNotifier.currentClinicId;
    try {
      AppLogger.info('Signing out Google session for clinic: $activeClinicId');
      await oauthProvider.signOut();
      await tokenVault.clear(activeClinicId);
      sessionNotifier.clearGoogleAuth();
      AppLogger.info('Session successfully cleared.');
    } catch (e) {
      AppLogger.error('Error during sign-out: $e');
      sessionNotifier.clearGoogleAuth();
    }
  }

  /// Checks for and processes any pending OAuth authorization code or tokens from redirect callback
  Future<GoogleAuthResult?> handleRedirectCallback({String? clinicId}) async {
    final activeClinicId = clinicId ?? sessionNotifier.currentClinicId;
    try {
      final result = await oauthProvider.handleRedirectCallback();
      if (result != null && result.isSuccess && result.user != null) {
        final user = result.user!;
        final tokens = result.tokens;

        if (tokens?.refreshToken != null && tokens!.refreshToken!.isNotEmpty) {
          await tokenVault.saveRefreshToken(activeClinicId, tokens.refreshToken!);
        }
        if (tokens != null && tokens.accessToken.isNotEmpty) {
          await tokenVault.saveAccessToken(
            activeClinicId,
            tokens.accessToken,
            tokens.expiresAt,
          );
        }
        await tokenVault.saveCachedUser(activeClinicId, user);
        await tokenVault.saveLastAuthTime(activeClinicId, DateTime.now().toUtc());

        await _applyStaffRoleForEmail(activeClinicId, user);

        AppLogger.info('Successfully handled OAuth callback for ${user.email}');
        return result;
      }
      return result;
    } catch (e) {
      AppLogger.error('Failed to handle OAuth callback: $e');
      return null;
    }
  }

  /// Attempts to silently restore session from encrypted vault on app launch
  Future<GoogleAuthResult?> restoreSession({String? clinicId}) async {
    final activeClinicId = clinicId ?? sessionNotifier.currentClinicId;

    try {
      final cachedUser = await tokenVault.getCachedUser(activeClinicId);
      final refreshToken = await tokenVault.getRefreshToken(activeClinicId);
      final cachedAccessToken = await tokenVault.getAccessToken(activeClinicId);

      if (cachedUser == null && refreshToken == null && cachedAccessToken == null) {
        return null;
      }

      // 1. If we have a valid, unexpired cached access token and cached user
      if (cachedAccessToken != null && cachedAccessToken.isNotEmpty && cachedUser != null) {
        final tokens = AuthTokens(
          accessToken: cachedAccessToken,
          refreshToken: refreshToken,
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        );

        if (oauthProvider is GoogleOAuthProvider) {
          (oauthProvider as GoogleOAuthProvider).setSession(
            GoogleAuthSession(
              status: AuthStatus.authenticated,
              user: cachedUser,
              tokens: tokens,
              lastAuthenticatedAt: DateTime.now().toUtc(),
            ),
          );
        }

        await _applyStaffRoleForEmail(activeClinicId, cachedUser);

        return GoogleAuthResult.success(user: cachedUser, tokens: tokens);
      }

      // 2. If we have a refresh token, attempt silent refresh
      if (refreshToken != null && refreshToken.isNotEmpty) {
        final newTokens = await oauthProvider.refreshTokens(refreshToken);
        if (newTokens != null && cachedUser != null) {
          await tokenVault.saveAccessToken(
            activeClinicId,
            newTokens.accessToken,
            newTokens.expiresAt,
          );
          await _applyStaffRoleForEmail(activeClinicId, cachedUser);
          return GoogleAuthResult.success(user: cachedUser, tokens: newTokens);
        }
      }

      // 3. If offline / tokens cannot be refreshed, preserve cached identity for UI
      if (cachedUser != null) {
        sessionNotifier.setGoogleAuthOffline(
          email: cachedUser.email,
          displayName: cachedUser.displayName,
          photoUrl: cachedUser.photoUrl,
        );
        return GoogleAuthResult.success(
          user: cachedUser,
          tokens: AuthTokens(
            accessToken: '',
            refreshToken: refreshToken,
            expiresAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          ),
        );
      }
    } catch (e) {
      AppLogger.warning('Failed to restore session from vault: $e');
    }

    return null;
  }

  /// Retrieves an active valid access token, auto-refreshing via vault if expired
  Future<String?> getValidAccessToken({
    String? clinicId,
    bool forceRefresh = false,
  }) async {
    final activeClinicId = clinicId ?? sessionNotifier.currentClinicId;
    final currentTokens = oauthProvider.currentSession.tokens;

    // 1. If active token exists and is not expired and forceRefresh is false, return it immediately
    if (!forceRefresh && currentTokens != null && !currentTokens.isExpired) {
      return currentTokens.accessToken;
    }

    // Candidate clinic IDs to search for stored tokens (handles aliases like primary_clinic / clinic_primary_demo)
    final candidateIds = [
      activeClinicId,
      if (activeClinicId != 'primary_clinic') 'primary_clinic',
      if (activeClinicId != 'clinic_primary_demo') 'clinic_primary_demo',
    ];

    // 2. Check vault for valid cached access token
    if (!forceRefresh) {
      for (final id in candidateIds) {
        final vaultToken = await tokenVault.getAccessToken(id);
        if (vaultToken != null && vaultToken.isNotEmpty) {
          return vaultToken;
        }
      }
    }

    // 3. If expired or forceRefresh, check vault for refresh token
    String? refreshToken = currentTokens?.refreshToken;
    String matchedClinicId = activeClinicId;

    if (refreshToken == null || refreshToken.isEmpty) {
      for (final id in candidateIds) {
        final token = await tokenVault.getRefreshToken(id);
        if (token != null && token.isNotEmpty) {
          refreshToken = token;
          matchedClinicId = id;
          break;
        }
      }
    }

    if (refreshToken != null && refreshToken.isNotEmpty) {
      final freshTokens = await oauthProvider.refreshTokens(refreshToken);
      if (freshTokens != null) {
        await tokenVault.saveAccessToken(
          matchedClinicId,
          freshTokens.accessToken,
          freshTokens.expiresAt,
        );
        if (matchedClinicId != activeClinicId) {
          await tokenVault.saveAccessToken(
            activeClinicId,
            freshTokens.accessToken,
            freshTokens.expiresAt,
          );
        }
        return freshTokens.accessToken;
      }
    }

    return null;
  }

  /// Automatically looks up the user's Google email in the clinic's staff roster.
  /// If matched, assigns their staff identity and locks the workstation to their role.
  Future<void> _applyStaffRoleForEmail(String clinicId, GoogleUser user) async {
    sessionNotifier.setGoogleAuthSuccess(
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoUrl,
    );

    if (clinicRepository == null) return;

    try {
      final cleanEmail = user.email.trim().toLowerCase();

      // 1. Check if email matches clinic contact/owner email
      final clinic = await clinicRepository!.getClinic(clinicId);
      if (clinic != null &&
          clinic.contactEmail.trim().toLowerCase() == cleanEmail) {
        sessionNotifier.setClinic(
          clinicId,
          'staff_owner',
          clinic.ownerName.isNotEmpty ? clinic.ownerName : user.displayName,
        );
        sessionNotifier.switchRole(UserRole.owner);
        AppLogger.info(
          'Clinic Owner logged in ($cleanEmail). Unrestricted access granted.',
        );
        return;
      }

      // 2. Query Staff table
      final staff = await clinicRepository!.getStaffByEmail(clinicId, cleanEmail);
      if (staff != null) {
        if (!staff.active) {
          AppLogger.warning(
            'Staff member ${staff.displayName} ($cleanEmail) is deactivated. Access revoked.',
          );
          throw const AuthorizationFailure(
            'Your staff account has been deactivated by the clinic owner. Please contact your clinic administrator.',
          );
        }
        sessionNotifier.setClinic(clinicId, staff.staffId, staff.displayName);
        await sessionNotifier.lockWorkstationToRole(staff.role);
        AppLogger.info(
          'Staff member ${staff.displayName} logged in. Role automatically enforced & locked: ${staff.role.wireValue}',
        );
        return;
      }

      // 3. Fallback: if no staff exist in clinic yet, grant owner access
      final allStaff = await clinicRepository!.getStaffMembers(clinicId);
      if (allStaff.isEmpty) {
        sessionNotifier.switchRole(UserRole.owner);
        return;
      }

      // 4. If staff exist, but this email is unrecognized: lock to receptionist by default
      await sessionNotifier.lockWorkstationToRole(UserRole.receptionist);
      AppLogger.warning(
        'User $cleanEmail not found in clinic Staff roster. Workstation locked to Receptionist.',
      );
    } catch (e) {
      AppLogger.error('Failed to enforce staff role on sign-in: $e');
    }
  }
}
