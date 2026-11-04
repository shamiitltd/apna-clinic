// Apna Clinic - Mock Google OAuth Provider
// Primary source of truth: Phase 3 Architecture Plan & Milestone 1 Testing Matrix
// Used in tests, offline local workstation mode, and demo simulation.
// Simulates success, cancellation, network failure, token refresh, and invalid sessions.

import 'dart:async';

import '../../../domain/entities/auth_session.dart';
import 'i_google_oauth_provider.dart';

class MockGoogleOAuthProvider implements IGoogleOAuthProvider {
  final StreamController<GoogleAuthSession> _sessionController =
      StreamController<GoogleAuthSession>.broadcast();

  GoogleAuthSession _currentSession = GoogleAuthSession.unauthenticated;

  // Simulation flags for comprehensive test coverage
  bool simulateCancellation = false;
  bool simulateNetworkError = false;
  bool simulateServiceUnavailable = false;
  bool simulateInvalidGrant = false;
  bool simulateExpiredToken = false;
  Duration simulatedDelay = Duration.zero;

  // Configured default test user
  GoogleUser defaultUser = const GoogleUser(
    id: 'google_user_demo_101',
    email: 'doctor.sharma@apnaclinic.in',
    displayName: 'Dr. Rajesh Sharma',
    photoUrl: 'https://lh3.googleusercontent.com/a/default-avatar',
  );

  @override
  bool get isConfigured => true;

  @override
  Stream<GoogleAuthSession> get sessionStream => _sessionController.stream;

  @override
  GoogleAuthSession get currentSession => _currentSession;

  void _updateSession(GoogleAuthSession session) {
    _currentSession = session;
    _sessionController.add(session);
  }

  @override
  Future<GoogleAuthResult> signIn() async {
    if (simulatedDelay > Duration.zero) {
      await Future<void>.delayed(simulatedDelay);
    }

    // 1. Check network error simulation (No Internet)
    if (simulateNetworkError) {
      const res = GoogleAuthResult.failure(
        'Unable to connect to Google OAuth servers. Offline mode active.',
        errorCode: 'NETWORK_ERROR',
      );
      _updateSession(
        GoogleAuthSession(
          status: AuthStatus.error,
          errorMessage: res.errorMessage,
          errorCode: res.errorCode,
        ),
      );
      return res;
    }

    // 2. Check service unavailable simulation (Google 503)
    if (simulateServiceUnavailable) {
      const res = GoogleAuthResult.failure(
        'Google Accounts service is temporarily unavailable (503).',
        errorCode: 'SERVICE_UNAVAILABLE',
      );
      _updateSession(
        GoogleAuthSession(
          status: AuthStatus.error,
          errorMessage: res.errorMessage,
          errorCode: res.errorCode,
        ),
      );
      return res;
    }

    // 3. Check user cancellation simulation
    if (simulateCancellation) {
      const res = GoogleAuthResult.cancelled();
      _updateSession(
        GoogleAuthSession(
          status: AuthStatus.cancelled,
          errorMessage: res.errorMessage,
          errorCode: res.errorCode,
        ),
      );
      return res;
    }

    // 4. Default Success Simulation
    final tokens = AuthTokens(
      accessToken: 'mock_access_token_${DateTime.now().millisecondsSinceEpoch}',
      refreshToken:
          'mock_refresh_token_${DateTime.now().millisecondsSinceEpoch}',
      expiresAt: simulateExpiredToken
          ? DateTime.now().toUtc().subtract(const Duration(minutes: 5))
          : DateTime.now().toUtc().add(const Duration(hours: 1)),
      scopes: const ['openid', 'email', 'profile'],
    );

    final res = GoogleAuthResult.success(user: defaultUser, tokens: tokens);

    _updateSession(
      GoogleAuthSession(
        status: AuthStatus.authenticated,
        user: defaultUser,
        tokens: tokens,
        lastAuthenticatedAt: DateTime.now().toUtc(),
      ),
    );

    return res;
  }

  @override
  Future<void> signOut() async {
    if (simulatedDelay > Duration.zero) {
      await Future<void>.delayed(simulatedDelay);
    }

    _updateSession(GoogleAuthSession.unauthenticated);
  }

  @override
  Future<GoogleAuthResult?> handleRedirectCallback() async {
    return null;
  }

  @override
  Future<GoogleAuthResult?> restoreSession() async {
    if (simulateNetworkError) {
      return const GoogleAuthResult.failure(
        'Cannot reach Google servers to validate session.',
        errorCode: 'NETWORK_ERROR',
      );
    }

    if (simulateInvalidGrant) {
      _updateSession(GoogleAuthSession.unauthenticated);
      return const GoogleAuthResult.failure(
        'Refresh token has been revoked or expired.',
        errorCode: 'INVALID_GRANT',
      );
    }

    if (_currentSession.isAuthenticated) {
      return GoogleAuthResult.success(
        user: _currentSession.user!,
        tokens: _currentSession.tokens!,
      );
    }

    return null;
  }

  @override
  Future<AuthTokens?> refreshTokens(String refreshToken) async {
    if (simulateNetworkError || simulateServiceUnavailable) {
      return null;
    }

    if (simulateInvalidGrant || refreshToken.isEmpty) {
      _updateSession(GoogleAuthSession.unauthenticated);
      return null;
    }

    final freshTokens = AuthTokens(
      accessToken:
          'mock_refreshed_access_token_${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: refreshToken,
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      scopes: const ['openid', 'email', 'profile'],
    );

    if (_currentSession.user != null) {
      _updateSession(
        _currentSession.copyWith(
          tokens: freshTokens,
          status: AuthStatus.authenticated,
          clearError: true,
        ),
      );
    }

    return freshTokens;
  }

  /// Helper for tests to directly inject a session
  void injectSession(GoogleAuthSession session) {
    _updateSession(session);
  }

  @override
  void dispose() {
    _sessionController.close();
  }
}
