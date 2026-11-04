// Apna Clinic - Authentication Domain Entities
// Primary source of truth: Phase 3 Architecture Plan (Section 5)
// Encapsulates Google User identity, OAuth Token metadata, and Session State.

import 'dart:convert';

/// Authentication state machine status
enum AuthStatus {
  unauthenticated,
  authenticating,
  authenticated,
  cancelled,
  error,
}

/// Google authenticated user profile
class GoogleUser {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;

  const GoogleUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'photo_url': photoUrl,
    };
  }

  factory GoogleUser.fromMap(Map<String, dynamic> map) {
    return GoogleUser(
      id: map['id'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: map['display_name'] as String? ?? '',
      photoUrl: map['photo_url'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory GoogleUser.fromJson(String source) =>
      GoogleUser.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  String toString() => 'GoogleUser(id: $id, email: $email, displayName: $displayName)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GoogleUser &&
        other.id == id &&
        other.email == email &&
        other.displayName == displayName &&
        other.photoUrl == photoUrl;
  }

  @override
  int get hashCode => Object.hash(id, email, displayName, photoUrl);
}

/// OAuth token metadata with expiry and granted scopes.
/// SECURITY INVARIANT: Access and refresh tokens are strictly excluded
/// from plaintext serialization and logs.
class AuthTokens {
  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;
  final List<String> scopes;

  const AuthTokens({
    required this.accessToken,
    this.refreshToken,
    required this.expiresAt,
    this.scopes = const [],
  });

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  Duration get timeUntilExpiry => expiresAt.difference(DateTime.now().toUtc());

  /// Returns true if the token expires within the given buffer duration
  bool willExpireWithin(Duration buffer) =>
      DateTime.now().toUtc().add(buffer).isAfter(expiresAt);

  @override
  String toString() =>
      'AuthTokens(expiresAt: $expiresAt, isExpired: $isExpired, scopes: $scopes)';
}

/// Immutable Google authenticated session representation
class GoogleAuthSession {
  final AuthStatus status;
  final GoogleUser? user;
  final AuthTokens? tokens;
  final String? errorMessage;
  final String? errorCode;
  final DateTime? lastAuthenticatedAt;

  const GoogleAuthSession({
    this.status = AuthStatus.unauthenticated,
    this.user,
    this.tokens,
    this.errorMessage,
    this.errorCode,
    this.lastAuthenticatedAt,
  });

  static const unauthenticated = GoogleAuthSession(
    status: AuthStatus.unauthenticated,
  );

  bool get isAuthenticated =>
      status == AuthStatus.authenticated &&
      user != null &&
      tokens != null &&
      !tokens!.isExpired;

  bool get isAuthenticating => status == AuthStatus.authenticating;

  GoogleAuthSession copyWith({
    AuthStatus? status,
    GoogleUser? user,
    AuthTokens? tokens,
    String? errorMessage,
    String? errorCode,
    DateTime? lastAuthenticatedAt,
    bool clearError = false,
  }) {
    return GoogleAuthSession(
      status: status ?? this.status,
      user: user ?? this.user,
      tokens: tokens ?? this.tokens,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      lastAuthenticatedAt: lastAuthenticatedAt ?? this.lastAuthenticatedAt,
    );
  }

  @override
  String toString() =>
      'GoogleAuthSession(status: $status, user: ${user?.email}, isAuthenticated: $isAuthenticated)';
}
