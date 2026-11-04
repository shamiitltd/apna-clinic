// Apna Clinic - OAuth Callback & Direct Token Flow Tests
// Verifies callback data parsing, JWT decoding, encrypted token vault,
// session state transitions, and logout reset.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

import 'package:apna_clinic/application/auth/auth_service.dart';
import 'package:apna_clinic/application/providers.dart';
import 'package:apna_clinic/domain/entities/auth_session.dart';
import 'package:apna_clinic/infrastructure/database/storage_adapter.dart';
import 'package:apna_clinic/infrastructure/google/oauth/google_oauth_provider.dart';
import 'package:apna_clinic/infrastructure/google/oauth/i_google_oauth_provider.dart';
import 'package:apna_clinic/infrastructure/google/oauth/oauth_browser_helper.dart';
import 'package:apna_clinic/infrastructure/google/oauth/token_vault.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OAuth Callback Flow & Session State Unit Tests', () {
    test('1. JWT Payload decoding extracts user profile fields correctly', () {
      final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'RS256', 'typ': 'JWT'}))).replaceAll('=', '');
      final payloadData = {
        'sub': '10987654321',
        'email': 'dr.akash@apnaclinic.in',
        'email_verified': true,
        'name': 'Dr. Akash Dash',
        'picture': 'https://lh3.googleusercontent.com/photo.jpg',
      };
      final payload = base64Url.encode(utf8.encode(jsonEncode(payloadData))).replaceAll('=', '');
      const dummySignature = 'dummy_sig';
      final jwt = '$header.$payload.$dummySignature';

      final decoded = GoogleOAuthProvider.parseJwtPayload(jwt);
      expect(decoded, isNotNull);
      expect(decoded!['email'], equals('dr.akash@apnaclinic.in'));
      expect(decoded['name'], equals('Dr. Akash Dash'));
      expect(decoded['sub'], equals('10987654321'));
      expect(decoded['picture'], equals('https://lh3.googleusercontent.com/photo.jpg'));
    });

    test('2. TokenVault stores encrypted access token and retrieves before expiration', () async {
      final storage = MemoryStorageAdapter();
      final vault = TokenVault(storage);
      const clinicId = 'clinic_test_vault';
      const token = 'ya29.test_access_token_12345';
      final futureExp = DateTime.now().toUtc().add(const Duration(hours: 1));

      await vault.saveAccessToken(clinicId, token, futureExp);

      final retrieved = await vault.getAccessToken(clinicId);
      expect(retrieved, equals(token));
    });

    test('3. TokenVault returns null when cached access token has expired', () async {
      final storage = MemoryStorageAdapter();
      final vault = TokenVault(storage);
      const clinicId = 'clinic_test_expired';
      const token = 'ya29.expired_token';
      final pastExp = DateTime.now().toUtc().subtract(const Duration(minutes: 5));

      await vault.saveAccessToken(clinicId, token, pastExp);

      final retrieved = await vault.getAccessToken(clinicId);
      expect(retrieved, isNull);
    });

    test('4. TokenVault clear() wipes cached access token, refresh token, and user profile', () async {
      final storage = MemoryStorageAdapter();
      final vault = TokenVault(storage);
      const clinicId = 'clinic_test_clear';

      await vault.saveAccessToken(clinicId, 'ya29.xyz', DateTime.now().toUtc().add(const Duration(hours: 1)));
      await vault.saveRefreshToken(clinicId, 'refresh_123');
      await vault.saveCachedUser(clinicId, const GoogleUser(id: '1', email: 'test@clinic.in', displayName: 'Test'));

      expect(await vault.getAccessToken(clinicId), isNotNull);
      expect(await vault.getRefreshToken(clinicId), isNotNull);
      expect(await vault.getCachedUser(clinicId), isNotNull);

      await vault.clear(clinicId);

      expect(await vault.getAccessToken(clinicId), isNull);
      expect(await vault.getRefreshToken(clinicId), isNull);
      expect(await vault.getCachedUser(clinicId), isNull);
    });

    test('5. AuthService restores session from TokenVault and transitions sessionNotifier', () async {
      final storage = MemoryStorageAdapter();
      final vault = TokenVault(storage);
      final notifier = SessionNotifier();
      const clinicId = 'clinic_primary_demo';

      // Seed vault with user profile and valid access token
      const user = GoogleUser(
        id: 'user_123',
        email: 'doctor@apnaclinic.in',
        displayName: 'Doctor Sharma',
      );
      await vault.saveCachedUser(clinicId, user);
      await vault.saveAccessToken(clinicId, 'ya29.active_token', DateTime.now().toUtc().add(const Duration(hours: 1)));

      final authProvider = GoogleOAuthProvider(
        clientId: 'mock_client_id.apps.googleusercontent.com',
        redirectUri: 'http://localhost:8080',
      );

      final service = AuthService(
        oauthProvider: authProvider,
        tokenVault: vault,
        sessionNotifier: notifier,
      );

      expect(notifier.currentSessionState.isGoogleAuthenticated, isFalse);

      final restored = await service.restoreSession(clinicId: clinicId);
      expect(restored, isNotNull);
      expect(restored!.isSuccess, isTrue);
      expect(restored.user?.email, equals('doctor@apnaclinic.in'));

      // Verify SessionNotifier state
      expect(notifier.currentSessionState.isGoogleAuthenticated, isTrue);
      expect(notifier.currentSessionState.googleUserEmail, equals('doctor@apnaclinic.in'));
      expect(notifier.currentSessionState.googleUserDisplayName, equals('Doctor Sharma'));
      expect(notifier.currentSessionState.authStatus, equals(AuthStatus.authenticated));
    });

    test('6. AuthService signOut clears vault and resets sessionNotifier', () async {
      final storage = MemoryStorageAdapter();
      final vault = TokenVault(storage);
      final notifier = SessionNotifier();
      const clinicId = 'clinic_primary_demo';

      notifier.setGoogleAuthSuccess(
        email: 'doctor@apnaclinic.in',
        displayName: 'Doctor Sharma',
      );
      expect(notifier.currentSessionState.isGoogleAuthenticated, isTrue);

      final authProvider = GoogleOAuthProvider(
        clientId: 'mock_client_id.apps.googleusercontent.com',
        redirectUri: 'http://localhost:8080',
      );

      final service = AuthService(
        oauthProvider: authProvider,
        tokenVault: vault,
        sessionNotifier: notifier,
      );

      await service.signOut(clinicId: clinicId);

      expect(notifier.currentSessionState.isGoogleAuthenticated, isFalse);
      expect(notifier.currentSessionState.googleUserEmail, isNull);
      expect(notifier.currentSessionState.googleUserDisplayName, isNull);
      expect(notifier.currentSessionState.authStatus, equals(AuthStatus.unauthenticated));
    });

    test('7. OAuthCallbackData properties check', () {
      const dataEmpty = OAuthCallbackData();
      expect(dataEmpty.isEmpty, isTrue);
      expect(dataEmpty.hasToken, isFalse);
      expect(dataEmpty.hasCode, isFalse);
      expect(dataEmpty.hasError, isFalse);

      const dataToken = OAuthCallbackData(
        accessToken: 'ya29.test',
        idToken: 'jwt.id.token',
        expiresIn: 3600,
        state: 'auth_state',
      );
      expect(dataToken.isEmpty, isFalse);
      expect(dataToken.hasToken, isTrue);
      expect(dataToken.hasCode, isFalse);
      expect(dataToken.hasError, isFalse);
      expect(dataToken.accessToken, equals('ya29.test'));
      expect(dataToken.expiresIn, equals(3600));

      const dataError = OAuthCallbackData(
        error: 'access_denied',
        errorDescription: 'User cancelled',
      );
      expect(dataError.hasError, isTrue);
      expect(dataError.error, equals('access_denied'));
    });

    test('8. GoogleAuthResult correctly detects isRedirecting without error flagging', () {
      const redirectingResult = GoogleAuthResult.failure(
        'Redirecting to Google Sign-In...',
        errorCode: 'REDIRECTING',
      );
      expect(redirectingResult.isRedirecting, isTrue);
      expect(redirectingResult.isSuccess, isFalse);
      expect(redirectingResult.isCancelled, isFalse);
    });
  });
}
