// Apna Clinic - Google OAuth Provider Interface
// Primary source of truth: Phase 3 Architecture Plan (Section 5)
// Defines the contract for OAuth 2.0 PKCE authentication with Google.

import 'dart:async';

import '../../../domain/entities/auth_session.dart';

/// Typed result object for OAuth operations
class GoogleAuthResult {
  final bool isSuccess;
  final bool isCancelled;
  final GoogleUser? user;
  final AuthTokens? tokens;
  final String? errorMessage;
  final String? errorCode;

  const GoogleAuthResult.success({
    required GoogleUser this.user,
    required AuthTokens this.tokens,
  }) : isSuccess = true,
       isCancelled = false,
       errorMessage = null,
       errorCode = null;

  const GoogleAuthResult.cancelled()
    : isSuccess = false,
      isCancelled = true,
      user = null,
      tokens = null,
      errorMessage = 'User cancelled the sign-in request.',
      errorCode = 'CANCELLED';

  const GoogleAuthResult.failure(
    String this.errorMessage, {
    this.errorCode = 'AUTH_ERROR',
  }) : isSuccess = false,
       isCancelled = false,
       user = null,
       tokens = null;

  bool get isRedirecting => errorCode == 'REDIRECTING';

  @override
  String toString() {
    if (isSuccess) return 'GoogleAuthResult.success(user: ${user?.email})';
    if (isCancelled) return 'GoogleAuthResult.cancelled()';
    return 'GoogleAuthResult.failure(code: $errorCode, message: $errorMessage)';
  }
}

/// Abstract OAuth Provider contract
abstract class IGoogleOAuthProvider {
  /// Initiates interactive Google OAuth sign-in flow
  Future<GoogleAuthResult> signIn();

  /// Revokes active tokens and signs out user
  Future<void> signOut();

  /// Attempts to restore previously persisted session (e.g. on application startup)
  Future<GoogleAuthResult?> restoreSession();

  /// Completes pending OAuth flow if an authorization code was returned via redirect
  Future<GoogleAuthResult?> handleRedirectCallback();

  /// Exchanges a refresh token for fresh access tokens
  Future<AuthTokens?> refreshTokens(String refreshToken);

  /// Returns true if client ID and OAuth parameters are configured
  bool get isConfigured;

  /// Reactive stream of authentication session changes
  Stream<GoogleAuthSession> get sessionStream;

  /// Current session snapshot
  GoogleAuthSession get currentSession;

  /// Disposes provider resources
  void dispose();
}
