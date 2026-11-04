// Apna Clinic - Secure OAuth Token Vault
// Primary source of truth: Phase 3 Architecture Plan (Section 5 & 11)
// Stores encrypted credentials and cached user profiles using AES-256.

import 'dart:convert';

import 'package:encrypt/encrypt.dart' as enc;

import '../../../core/logging/app_logger.dart';
import '../../../domain/entities/auth_session.dart';
import '../../database/storage_adapter.dart';
import '../../security/local_encryption_service.dart';

class TokenVault {
  static const String _storagePrefix = 'apna_clinic_oauth_vault_';
  static const String _defaultVaultSalt = 'ApnaClinicOAuthTokenVaultSalt2026';

  final IStorageAdapter _storage;

  TokenVault([IStorageAdapter? storageAdapter])
    : _storage = storageAdapter ?? MemoryStorageAdapter();

  /// Derives a deterministic clinic-scoped AES-256 key for vault encryption
  enc.Key _deriveVaultKey(String clinicId) {
    return LocalEncryptionService.deriveKeyFromPassphrase(
      clinicId,
      _defaultVaultSalt,
    );
  }

  /// Securely encrypts and persists a refresh token
  Future<void> saveRefreshToken(String clinicId, String refreshToken) async {
    try {
      final key = _deriveVaultKey(clinicId);
      final envelope = LocalEncryptionService.encryptText(
        plaintext: refreshToken,
        key: key,
      );
      final serializedEnvelope = jsonEncode(envelope.toMap());
      await _storage.write(
        '${_storagePrefix}refresh_token_$clinicId',
        serializedEnvelope,
      );
    } catch (e) {
      AppLogger.error('Failed to securely store refresh token in vault: $e');
    }
  }

  /// Retrieves and decrypts the refresh token for a clinic
  Future<String?> getRefreshToken(String clinicId) async {
    try {
      final rawEnvelope = await _storage.read(
        '${_storagePrefix}refresh_token_$clinicId',
      );
      if (rawEnvelope == null || rawEnvelope.isEmpty) return null;

      final envelopeMap = jsonDecode(rawEnvelope) as Map<String, dynamic>;
      final envelope = EncryptedEnvelope.fromMap(envelopeMap);
      final key = _deriveVaultKey(clinicId);

      return LocalEncryptionService.decryptEnvelope(
        envelope: envelope,
        key: key,
      );
    } catch (e) {
      AppLogger.warning('Failed to decrypt stored refresh token: $e');
      return null;
    }
  }

  /// Securely encrypts and persists an access token with expiration
  Future<void> saveAccessToken(
    String clinicId,
    String accessToken,
    DateTime expiresAt,
  ) async {
    try {
      final key = _deriveVaultKey(clinicId);
      final envelope = LocalEncryptionService.encryptText(
        plaintext: accessToken,
        key: key,
      );
      final serializedEnvelope = jsonEncode(envelope.toMap());
      await _storage.write(
        '${_storagePrefix}access_token_$clinicId',
        serializedEnvelope,
      );
      await _storage.write(
        '${_storagePrefix}access_token_exp_$clinicId',
        expiresAt.toUtc().toIso8601String(),
      );
    } catch (e) {
      AppLogger.error('Failed to securely store access token in vault: $e');
    }
  }

  /// Retrieves and decrypts the access token if not expired
  Future<String?> getAccessToken(String clinicId) async {
    try {
      final expStr = await _storage.read(
        '${_storagePrefix}access_token_exp_$clinicId',
      );
      if (expStr != null) {
        final exp = DateTime.tryParse(expStr);
        if (exp != null && DateTime.now().toUtc().isAfter(exp)) {
          return null; // Token expired
        }
      }

      final rawEnvelope = await _storage.read(
        '${_storagePrefix}access_token_$clinicId',
      );
      if (rawEnvelope == null || rawEnvelope.isEmpty) return null;

      final envelopeMap = jsonDecode(rawEnvelope) as Map<String, dynamic>;
      final envelope = EncryptedEnvelope.fromMap(envelopeMap);
      final key = _deriveVaultKey(clinicId);

      return LocalEncryptionService.decryptEnvelope(
        envelope: envelope,
        key: key,
      );
    } catch (e) {
      AppLogger.warning('Failed to decrypt stored access token: $e');
      return null;
    }
  }

  /// Persists cached Google user demographic details for offline session display
  Future<void> saveCachedUser(String clinicId, GoogleUser user) async {
    try {
      await _storage.write(
        '${_storagePrefix}user_profile_$clinicId',
        user.toJson(),
      );
    } catch (e) {
      AppLogger.error('Failed to save cached user profile: $e');
    }
  }

  /// Retrieves cached Google user demographic details
  Future<GoogleUser?> getCachedUser(String clinicId) async {
    try {
      final raw = await _storage.read('${_storagePrefix}user_profile_$clinicId');
      if (raw == null || raw.isEmpty) return null;
      return GoogleUser.fromJson(raw);
    } catch (e) {
      AppLogger.warning('Failed to parse cached user profile: $e');
      return null;
    }
  }

  /// Saves the last authenticated timestamp
  Future<void> saveLastAuthTime(String clinicId, DateTime timestamp) async {
    await _storage.write(
      '${_storagePrefix}last_auth_$clinicId',
      timestamp.toUtc().toIso8601String(),
    );
  }

  /// Retrieves the last authenticated timestamp
  Future<DateTime?> getLastAuthTime(String clinicId) async {
    final raw = await _storage.read('${_storagePrefix}last_auth_$clinicId');
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  /// Clears all encrypted credentials and user cache for a clinic
  Future<void> clear(String clinicId) async {
    await _storage.remove('${_storagePrefix}refresh_token_$clinicId');
    await _storage.remove('${_storagePrefix}access_token_$clinicId');
    await _storage.remove('${_storagePrefix}access_token_exp_$clinicId');
    await _storage.remove('${_storagePrefix}user_profile_$clinicId');
    await _storage.remove('${_storagePrefix}last_auth_$clinicId');
  }
}
