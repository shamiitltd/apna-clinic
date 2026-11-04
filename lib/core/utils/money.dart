/// Production integer-minor-unit (paise) representation of money.
///
/// CRITICAL ARCHITECTURAL RULE:
/// NEVER use floating point numbers for currency calculations.
/// ₹250.50 is represented internally as 25050 paise.
class Money implements Comparable<Money> {
  final int paise;

  const Money(this.paise);

  static const Money zero = Money(0);

  factory Money.fromRupees(num rupees) {
    return Money((rupees * 100).round());
  }

  factory Money.fromPaise(int paise) {
    return Money(paise);
  }

  int get minorUnits => paise;
  bool get isZero => paise == 0;
  bool get isNegative => paise < 0;
  String get formatted => format();

  double get inRupees => paise / 100.0;

  Money operator +(Money other) => Money(paise + other.paise);

  Money operator -(Money other) => Money(paise - other.paise);

  Money operator -() => Money(-paise);

  Money operator *(num multiplier) => Money((paise * multiplier).round());

  bool operator <(Money other) => paise < other.paise;
  bool operator <=(Money other) => paise <= other.paise;
  bool operator >(Money other) => paise > other.paise;
  bool operator >=(Money other) => paise >= other.paise;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money &&
          runtimeType == other.runtimeType &&
          paise == other.paise;

  @override
  int get hashCode => paise.hashCode;

  @override
  int compareTo(Money other) => paise.compareTo(other.paise);

  /// Calculate discount amount in paise
  Money calculateDiscount(double percentage) {
    if (percentage <= 0) return Money.zero;
    return Money((paise * (percentage / 100)).round());
  }

  /// Calculate tax amount in paise
  Money calculateTax(double percentage) {
    if (percentage <= 0) return Money.zero;
    return Money((paise * (percentage / 100)).round());
  }

  /// Apply a percentage discount and round to nearest paise
  Money applyDiscountPercentage(double percentage) {
    if (percentage <= 0) return this;
    if (percentage >= 100) return Money.zero;
    final discountAmountPaise = (paise * (percentage / 100)).round();
    return Money(paise - discountAmountPaise);
  }

  /// Apply a percentage tax and return the tax amount in paise
  Money calculateTaxAmount(double taxPercentage) {
    if (taxPercentage <= 0) return Money.zero;
    final taxPaise = (paise * (taxPercentage / 100)).round();
    return Money(taxPaise);
  }

  /// Format as Indian Currency (e.g., ₹250.50, ₹1,250.00)
  String format({bool includeSymbol = true}) {
    final isNegative = paise < 0;
    final absPaise = paise.abs();
    final rupeesPart = absPaise ~/ 100;
    final paisePart = absPaise % 100;

    final formattedRupees = _formatIndianNumber(rupeesPart);
    final paiseStr = paisePart.toString().padLeft(2, '0');
    final formatted = '$formattedRupees.$paiseStr';

    final sign = isNegative ? '-' : '';
    final symbol = includeSymbol ? '₹' : '';
    return '$sign$symbol$formatted';
  }

  static String _formatIndianNumber(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;

    final lastThree = s.substring(s.length - 3);
    var remaining = s.substring(0, s.length - 3);
    final result = <String>[];

    while (remaining.length > 2) {
      result.insert(0, remaining.substring(remaining.length - 2));
      remaining = remaining.substring(0, remaining.length - 2);
    }
    if (remaining.isNotEmpty) {
      result.insert(0, remaining);
    }
    result.add(lastThree);
    return result.join(',');
  }

  @override
  String toString() => format();
}
