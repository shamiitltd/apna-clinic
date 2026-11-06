// Apna Clinic - Deterministic Timezone-Aware Month Resolver
// Primary source of truth: Feature PRD Section 7.2 & Feature TRD Section 6.1

class MonthResolver {
  static const String defaultClinicTimezone = 'Asia/Kolkata';

  /// Resolves standard YYYY-MM month key from a DateTime object,
  /// converted to the clinic's timezone (IST UTC+05:30 by default per PRD M01).
  static String resolveMonthFromDate(
    DateTime date, {
    String timezone = defaultClinicTimezone,
  }) {
    final istDate = toClinicTime(date, timezone: timezone);
    final year = istDate.year.toString().padLeft(4, '0');
    final month = istDate.month.toString().padLeft(2, '0');
    return '$year-$month';
  }

  /// Convenience alias for resolveMonthFromDate
  static String resolveMonthKey(
    DateTime date, {
    String timezone = defaultClinicTimezone,
  }) => resolveMonthFromDate(date, timezone: timezone);

  /// Resolves standard YYYY-MM month key from an ISO date or date-time string.
  /// If the string is date-only (e.g. '2026-11-04'), extracts the prefix directly.
  static String resolveMonthFromString(
    String dateString, {
    String timezone = defaultClinicTimezone,
  }) {
    if (dateString.isEmpty) {
      return resolveMonthFromDate(DateTime.now().toUtc(), timezone: timezone);
    }

    final trimmed = dateString.trim();

    // If it is a timestamp with time component (contains 'T'), parse and convert to clinic timezone
    if (trimmed.contains('T')) {
      try {
        final parsed = DateTime.parse(trimmed);
        return resolveMonthFromDate(parsed, timezone: timezone);
      } catch (_) {}
    }

    // Quick regex for date-only YYYY-MM or YYYY-MM-DD
    final dateMatch = RegExp(r'^(\d{4})-(\d{2})').firstMatch(trimmed);
    if (dateMatch != null) {
      return '${dateMatch.group(1)}-${dateMatch.group(2)}';
    }

    try {
      final parsed = DateTime.parse(trimmed);
      return resolveMonthFromDate(parsed, timezone: timezone);
    } catch (_) {
      return resolveMonthFromDate(DateTime.now().toUtc(), timezone: timezone);
    }
  }

  /// Resolves target month for a specific entity record using its business date field
  /// per TRD Section 6.1 (late-entered or backdated records route to their business date).
  static String resolveMonthFromEntity(
    String entityType,
    Map<String, dynamic> record, {
    String timezone = defaultClinicTimezone,
  }) {
    String? candidateDate;

    switch (entityType.toLowerCase()) {
      case 'visits':
      case '09_consultations':
      case 'consultations':
        candidateDate = record['visit_date']?.toString() ??
            record['checkin_at']?.toString() ??
            record['created_at']?.toString();
        break;

      case 'appointments':
      case '06_appointments':
        candidateDate = record['appointment_date']?.toString() ??
            record['scheduled_start_at']?.toString() ??
            record['created_at']?.toString();
        break;

      case 'invoices':
      case 'billing':
      case '10_billing':
        candidateDate = record['invoice_date']?.toString() ??
            record['issued_at']?.toString() ??
            record['created_at']?.toString();
        break;

      case 'payments':
      case '11_payments':
        candidateDate = record['payment_date']?.toString() ??
            record['paid_at']?.toString() ??
            record['created_at']?.toString();
        break;

      case 'expenses':
        candidateDate = record['expense_date']?.toString() ??
            record['created_at']?.toString();
        break;

      case 'refunds':
        candidateDate = record['refunded_at']?.toString() ??
            record['created_at']?.toString();
        break;

      case 'queue_events':
      case '08_queue':
        candidateDate = record['occurred_at']?.toString() ??
            record['changed_at']?.toString() ??
            record['created_at']?.toString();
        break;

      default:
        candidateDate = record['business_date']?.toString() ??
            record['created_at']?.toString();
    }

    if (candidateDate != null && candidateDate.isNotEmpty) {
      return resolveMonthFromString(candidateDate, timezone: timezone);
    }

    return resolveMonthFromDate(DateTime.now().toUtc(), timezone: timezone);
  }

  /// Converts a UTC DateTime to clinic local time (Indian Standard Time UTC+05:30)
  static DateTime toClinicTime(
    DateTime utcDate, {
    String timezone = defaultClinicTimezone,
  }) {
    // For Asia/Kolkata (Indian Standard Time), fixed offset is +5 hours 30 minutes without DST.
    if (timezone == 'Asia/Kolkata' || timezone == 'IST') {
      return utcDate.toUtc().add(const Duration(hours: 5, minutes: 30));
    }
    // Fall back to device local representation for other explicit zones
    return utcDate.toLocal();
  }

  /// Formats YYYY-MM into human-friendly label (e.g. '2026-11' -> 'November 2026')
  static String formatMonthLabel(String yearMonth) {
    if (!yearMonth.contains('-')) return yearMonth;
    final parts = yearMonth.split('-');
    if (parts.length < 2) return yearMonth;

    final year = parts[0];
    final monthNum = int.tryParse(parts[1]) ?? 1;

    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];

    final monthName = (monthNum >= 1 && monthNum <= 12)
        ? monthNames[monthNum - 1]
        : 'Month $monthNum';

    return '$monthName $year';
  }

  /// Generates canonical monthly workbook title
  /// e.g. ApnaClinic_clinic_primary_Transactions_2026_11
  static String generateMonthlyWorkbookName(String clinicId, String yearMonth) {
    final sanitizedMonth = yearMonth.replaceAll('-', '_');
    return 'ApnaClinic_${clinicId}_Transactions_$sanitizedMonth';
  }
}

