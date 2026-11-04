// PhoneNormalizer Unit Tests - Testing Indian Phone Normalization, Masking, and SHA-256 Hashing
// Requirements: Section 21, 22, 23

import 'package:flutter_test/flutter_test.dart';
import 'package:apna_clinic/core/utils/phone_normalizer.dart';

void main() {
  group('PhoneNormalizer Tests', () {
    test('Normalizes standard 10 digit Indian numbers', () {
      expect(PhoneNormalizer.normalize('9876543210'), equals('9876543210'));
      expect(PhoneNormalizer.normalize(' 9876543210 '), equals('9876543210'));
      expect(PhoneNormalizer.normalize('98765-43210'), equals('9876543210'));
    });

    test('Normalizes +91 and 91 prefixed numbers', () {
      expect(
        PhoneNormalizer.normalize('+91 98765 43210'),
        equals('9876543210'),
      );
      expect(PhoneNormalizer.normalize('919876543210'), equals('9876543210'));
      expect(
        PhoneNormalizer.normalize('+91-98765-43210'),
        equals('9876543210'),
      );
    });

    test('Normalizes 0 prefixed numbers', () {
      expect(PhoneNormalizer.normalize('09876543210'), equals('9876543210'));
      expect(PhoneNormalizer.normalize('0 98765 43210'), equals('9876543210'));
    });

    test('Returns null for empty or invalid inputs', () {
      expect(PhoneNormalizer.normalize(null), isNull);
      expect(PhoneNormalizer.normalize(''), isNull);
      expect(PhoneNormalizer.normalize('   '), isNull);
    });

    test('Masks phone number for shared screens (privacy preservation)', () {
      expect(PhoneNormalizer.mask('9876543210'), equals('******3210'));
      expect(PhoneNormalizer.mask('+91 98765 43210'), equals('******3210'));
      expect(PhoneNormalizer.mask(null), equals('******'));
      expect(PhoneNormalizer.mask('123'), equals('******'));
    });

    test('Generates deterministic SHA-256 hash for deduplication indexing', () {
      final hash1 = PhoneNormalizer.hash('9876543210');
      final hash2 = PhoneNormalizer.hash('+91 98765-43210');
      final hash3 = PhoneNormalizer.hash('09876543210');

      expect(hash1, isNotNull);
      expect(hash1, equals(hash2));
      expect(hash2, equals(hash3));

      final diffHash = PhoneNormalizer.hash('9123456789');
      expect(hash1, isNot(equals(diffHash)));
    });
  });
}
