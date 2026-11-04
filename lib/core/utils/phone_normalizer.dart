import 'dart:convert';

import 'package:crypto/crypto.dart';

class PhoneNormalizer {
  /// Normalizes an Indian phone number to 10 digits
  /// Example: "+91 98765-43210" -> "9876543210"
  static String? normalize(String? rawPhone) {
    if (rawPhone == null || rawPhone.trim().isEmpty) return null;

    final digitsOnly = rawPhone.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.length == 10) {
      return digitsOnly;
    } else if (digitsOnly.length == 12 && digitsOnly.startsWith('91')) {
      return digitsOnly.substring(2);
    } else if (digitsOnly.length == 11 && digitsOnly.startsWith('0')) {
      return digitsOnly.substring(1);
    }

    return digitsOnly;
  }

  /// Masks phone numbers for shared displays (e.g. "******3210")
  static String mask(String? phone) {
    final normalized = normalize(phone);
    if (normalized == null || normalized.length < 4) return '******';
    final visiblePart = normalized.substring(normalized.length - 4);
    return '******$visiblePart';
  }

  /// Alias for mask for explicit readability
  static String maskForDisplay(String? phone) => mask(phone);

  /// Generates SHA-256 hash of normalized phone for privacy-preserving deduplication
  static String? hash(String? phone) {
    final normalized = normalize(phone);
    if (normalized == null) return null;
    final bytes = utf8.encode(normalized);
    return sha256.convert(bytes).toString();
  }
}
