// Money Unit Tests - Testing deterministic integer paise arithmetic
// Requirements: Section 9 - Money Representation

import 'package:flutter_test/flutter_test.dart';
import 'package:apna_clinic/core/utils/money.dart';

void main() {
  group('Money Value Object Tests', () {
    test('Zero money represents 0 paise', () {
      const zero = Money.zero;
      expect(zero.minorUnits, equals(0));
      expect(zero.inRupees, equals(0.0));
      expect(zero.isZero, isTrue);
      expect(zero.formatted, equals('₹0.00'));
    });

    test('fromRupees converts correctly without floating point errors', () {
      final m1 = Money.fromRupees(1.0);
      expect(m1.minorUnits, equals(100));

      final m99_99 = Money.fromRupees(99.99);
      expect(m99_99.minorUnits, equals(9999));

      final m100 = Money.fromRupees(100.0);
      expect(m100.minorUnits, equals(10000));

      final m250_50 = Money.fromRupees(250.50);
      expect(m250_50.minorUnits, equals(25050));
    });

    test('Addition, Subtraction and Negation are deterministic', () {
      final a = Money.fromPaise(50000); // ₹500
      final b = Money.fromPaise(25050); // ₹250.50

      final sum = a + b;
      expect(sum.minorUnits, equals(75050));
      expect(sum.inRupees, equals(750.50));

      final diff = a - b;
      expect(diff.minorUnits, equals(24950));
      expect(diff.inRupees, equals(249.50));

      final neg = -a;
      expect(neg.minorUnits, equals(-50000));
      expect(neg.isNegative, isTrue);
    });

    test(
      'Discount calculation calculates minor units with deterministic rounding',
      () {
        final bill = Money.fromRupees(500.0); // 50000 paise
        // 10% discount
        final discount = bill.calculateDiscount(10.0);
        expect(discount.minorUnits, equals(5000)); // ₹50

        final net = bill - discount;
        expect(net.minorUnits, equals(45000)); // ₹450
      },
    );

    test('Tax calculation calculates minor units correctly', () {
      final bill = Money.fromRupees(1000.0); // 100000 paise
      // 18% GST
      final tax = bill.calculateTax(18.0);
      expect(tax.minorUnits, equals(18000)); // ₹180

      final total = bill + tax;
      expect(total.minorUnits, equals(118000)); // ₹1180
    });

    test('Invoice multi-payment and partial payment reconciliation', () {
      final invoiceTotal = Money.fromRupees(1500.0); // 150000 paise
      final payment1 = Money.fromRupees(500.0); // Cash 500
      final payment2 = Money.fromRupees(750.0); // UPI 750

      final totalPaid = payment1 + payment2;
      expect(totalPaid.minorUnits, equals(125000));

      final outstanding = invoiceTotal - totalPaid;
      expect(outstanding.minorUnits, equals(25000)); // ₹250 outstanding
      expect(outstanding.inRupees, equals(250.0));

      // Final payment
      final payment3 = Money.fromRupees(250.0);
      final finalPaid = totalPaid + payment3;
      final finalOutstanding = invoiceTotal - finalPaid;
      expect(finalOutstanding.minorUnits, equals(0));
      expect(finalOutstanding.isZero, isTrue);
    });

    test('Refund and reversal calculations', () {
      final originalPayment = Money.fromRupees(500.0);
      final refundAmount = Money.fromRupees(200.0);

      final netRetained = originalPayment - refundAmount;
      expect(netRetained.minorUnits, equals(30000));
      expect(netRetained.inRupees, equals(300.0));
    });

    test('Indian currency formatting with commas (Lakhs / Crores)', () {
      final small = Money.fromRupees(500.0);
      expect(small.formatted, equals('₹500.00'));

      final thousand = Money.fromRupees(1234.50);
      expect(thousand.formatted, equals('₹1,234.50'));

      final lakh = Money.fromRupees(123456.78);
      expect(lakh.formatted, equals('₹1,23,456.78'));

      final crore = Money.fromRupees(12345678.90);
      expect(crore.formatted, equals('₹1,23,45,678.90'));
    });
  });
}
