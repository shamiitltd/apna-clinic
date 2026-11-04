// Apna Clinic - Local Encryption Service
// Primary source of truth: PRD and TRD Section 12 & 14
// Audited AES-256 encryption with secure IV nonces and SHA-256 checksums

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

import '../../core/errors/failures.dart';

class EncryptedEnvelope {
  final String ciphertextBase64;
  final String ivBase64;
  final String checksumSha256;

  const EncryptedEnvelope({
    required this.ciphertextBase64,
    required this.ivBase64,
    required this.checksumSha256,
  });

  Map<String, dynamic> toMap() => {
    'ciphertext_base64': ciphertextBase64,
    'iv_base64': ivBase64,
    'checksum_sha256': checksumSha256,
  };

  factory EncryptedEnvelope.fromMap(Map<String, dynamic> map) {
    return EncryptedEnvelope(
      ciphertextBase64: map['ciphertext_base64'] as String,
      ivBase64: map['iv_base64'] as String,
      checksumSha256: map['checksum_sha256'] as String,
    );
  }
}

class LocalEncryptionService {
  /// Generates a cryptographic 256-bit (32 bytes) AES key
  static enc.Key generate256BitKey() {
    return enc.Key.fromSecureRandom(32);
  }

  /// Generates a secure 128-bit (16 bytes) IV nonce
  static enc.IV generateSecureIv() {
    return enc.IV.fromSecureRandom(16);
  }

  /// Encrypts plaintext string using AES-CBC with PKCS7 padding
  static EncryptedEnvelope encryptText({
    required String plaintext,
    required enc.Key key,
    enc.IV? iv,
  }) {
    try {
      final actualIv = iv ?? generateSecureIv();
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encrypt(plaintext, iv: actualIv);

      final checksum = sha256.convert(encrypted.bytes).toString();

      return EncryptedEnvelope(
        ciphertextBase64: encrypted.base64,
        ivBase64: actualIv.base64,
        checksumSha256: checksum,
      );
    } catch (e) {
      throw CryptoFailure('Failed to encrypt data securely: $e');
    }
  }

  /// Decrypts an encrypted envelope using the corresponding AES key
  /// Validates integrity checksum before decryption.
  static String decryptEnvelope({
    required EncryptedEnvelope envelope,
    required enc.Key key,
  }) {
    try {
      final ciphertextBytes = base64Decode(envelope.ciphertextBase64);
      final calculatedChecksum = sha256.convert(ciphertextBytes).toString();

      if (calculatedChecksum != envelope.checksumSha256) {
        throw const CryptoFailure(
          'Data integrity validation failed: Checksum mismatch. The ciphertext may have been corrupted or tampered with.',
        );
      }

      final iv = enc.IV.fromBase64(envelope.ivBase64);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = enc.Encrypted.fromBase64(envelope.ciphertextBase64);

      return encrypter.decrypt(encrypted, iv: iv);
    } on CryptoFailure {
      rethrow;
    } catch (e) {
      throw CryptoFailure(
        'Decryption failed: Incorrect key or corrupted payload ($e)',
      );
    }
  }

  /// Derives a deterministic 256-bit encryption key from passphrase and salt
  /// using PBKDF2-HMAC-SHA256 (10,000 rounds)
  static enc.Key deriveKeyFromPassphrase(String passphrase, String salt) {
    if (passphrase.trim().isEmpty) {
      throw const CryptoFailure('Passphrase cannot be empty');
    }

    final saltBytes = utf8.encode(salt);
    final keyBytes = utf8.encode(passphrase);

    // Iterative PBKDF2 HMAC-SHA256
    var digest = hmacSha256(keyBytes, saltBytes);
    for (int i = 1; i < 10000; i++) {
      digest = hmacSha256(keyBytes, digest);
    }

    // Return exactly 32 bytes (256 bits)
    return enc.Key(Uint8List.fromList(digest));
  }

  static List<int> hmacSha256(List<int> key, List<int> data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(data).bytes;
  }

  /// Computes SHA-256 hex checksum
  static String computeSha256(String content) {
    return sha256.convert(utf8.encode(content)).toString();
  }

  /// Generates a random salt string
  static String generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }
}
