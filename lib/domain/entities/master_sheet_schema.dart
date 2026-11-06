// Apna Clinic - Canonical Master Sheet Schema Specification (Phase 2 Frozen Baseline)
// Primary source of truth: APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL.xlsx & TRD Section 7
// IMMUTABLE CONTRACT: 20 worksheets with canonical column names and order.

class MasterSheetSchema {
  MasterSheetSchema._();

  /// Canonical 20 worksheet names in exact template order
  static const List<String> canonicalSheetNames = [
    '01_SETTINGS',
    '02_USERS',
    '03_ROLES',
    '04_DOCTORS',
    '05_PATIENTS',
    '06_APPOINTMENTS',
    '07_DOCTOR_SCHEDULES',
    '08_QUEUE',
    '09_CONSULTATIONS',
    '10_BILLING',
    '11_PAYMENTS',
    '12_SERVICES',
    '13_MEDICAL_RECORDS',
    '14_PRESCRIPTIONS',
    '15_FOLLOW_UPS',
    '16_ROOMS',
    '17_AUDIT_LOG',
    '18_NOTIFICATIONS',
    '19_REPORTING',
    '20_LOOKUPS',
    // Monthly Storage Master Extensions (Feature TRD Section 5.2)
    'Spreadsheet_Registry',
    'Patient_History_Index',
  ];

  /// Canonical Monthly Transaction Tab Names (Feature TRD Section 5.3)
  static const List<String> monthlyTransactionTabNames = [
    'Appointments',
    'Visits',
    'Billing',
    'Payments',
    'Queue_Events',
  ];

  /// Map of Monthly Transaction Tab Name to canonical header columns (Feature TRD Section 5.1 & 5.3)
  static Map<String, List<String>> get monthlyTransactionHeaders => {
    'Appointments': canonicalHeaders['06_APPOINTMENTS']!,
    'Visits': canonicalHeaders['09_CONSULTATIONS']!,
    'Billing': canonicalHeaders['10_BILLING']!,
    'Payments': canonicalHeaders['11_PAYMENTS']!,
    'Queue_Events': canonicalHeaders['08_QUEUE']!,
  };

  /// Canonical headers for Monthly Storage Extensions (TRD Section 5.2)
  static const List<String> spreadsheetRegistryHeaders = [
    'clinic_id',
    'year_month',
    'spreadsheet_id',
    'status',
    'schema_version',
    'created_at',
    'created_by',
    'last_verified_at',
  ];

  static const List<String> patientHistoryIndexHeaders = [
    'clinic_id',
    'patient_id',
    'year_month',
    'record_type',
    'first_record_at',
    'last_record_at',
    'record_count',
    'last_updated_at',
  ];

  /// Canonical headers per worksheet in exact column sequence
  static const Map<String, List<String>> canonicalHeaders = {
    '01_SETTINGS': [
      'setting_id',
      'setting_category',
      'setting_key',
      'setting_value',
      'data_type',
      'description',
      'is_system',
      'updated_at',
    ],
    '02_USERS': [
      'user_id',
      'username',
      'display_name',
      'role_id',
      'phone',
      'email',
      'status',
      'assigned_doctor_ids',
      'created_at',
      'updated_at',
    ],
    '03_ROLES': [
      'role_id',
      'role_code',
      'role_name',
      'description',
      'permissions_summary',
      'status',
      'created_at',
      'updated_at',
    ],
    '04_DOCTORS': [
      'doctor_id',
      'doctor_code',
      'doctor_name',
      'specialization',
      'qualification',
      'registration_number',
      'phone',
      'email',
      'room_id',
      'consultation_fee',
      'consultation_duration_minutes',
      'status',
      'joining_date',
      'created_at',
      'updated_at',
    ],
    '05_PATIENTS': [
      'patient_id',
      'patient_code',
      'first_name',
      'middle_name',
      'last_name',
      'full_name',
      'date_of_birth',
      'age',
      'gender',
      'phone',
      'alternate_phone',
      'email',
      'address',
      'city',
      'state',
      'pincode',
      'emergency_contact_name',
      'emergency_contact_phone',
      'blood_group',
      'registration_date',
      'patient_status',
      'consent_status',
      'consent_version',
      'created_at',
      'updated_at',
      'created_by',
      'updated_by',
    ],
    '06_APPOINTMENTS': [
      'appointment_id',
      'appointment_code',
      'patient_id',
      'doctor_id',
      'appointment_date',
      'start_time',
      'end_time',
      'appointment_type',
      'booking_source',
      'status',
      'token_number',
      'room_id',
      'notes',
      'cancel_reason',
      'reminder_consent',
      'reminder_status',
      'created_at',
      'updated_at',
      'created_by',
      'updated_by',
    ],
    '07_DOCTOR_SCHEDULES': [
      'schedule_id',
      'doctor_id',
      'day_of_week',
      'start_time',
      'end_time',
      'slot_duration',
      'break_start',
      'break_end',
      'room_id',
      'maximum_patients',
      'status',
      'effective_from',
      'effective_to',
      'created_at',
      'updated_at',
    ],
    '08_QUEUE': [
      'queue_id',
      'appointment_id',
      'patient_id',
      'doctor_id',
      'token_number',
      'queue_date',
      'check_in_time',
      'called_time',
      'consultation_start_time',
      'consultation_end_time',
      'queue_status',
      'priority',
      'room_id',
      'created_at',
      'updated_at',
    ],
    '09_CONSULTATIONS': [
      'consultation_id',
      'appointment_id',
      'patient_id',
      'doctor_id',
      'chief_complaint',
      'clinical_summary',
      'diagnosis',
      'advice',
      'follow_up_required',
      'follow_up_date',
      'consultation_status',
      'started_at',
      'completed_at',
      'created_at',
      'updated_at',
    ],
    '10_BILLING': [
      'invoice_id',
      'invoice_number',
      'patient_id',
      'appointment_id',
      'invoice_date',
      'subtotal',
      'discount',
      'tax',
      'total_amount',
      'paid_amount',
      'due_amount',
      'payment_status',
      'notes',
      'created_at',
      'updated_at',
    ],
    '11_PAYMENTS': [
      'payment_id',
      'invoice_id',
      'patient_id',
      'payment_date',
      'amount',
      'payment_method',
      'transaction_reference',
      'payment_status',
      'received_by',
      'notes',
      'created_at',
    ],
    '12_SERVICES': [
      'service_id',
      'service_code',
      'service_name',
      'category',
      'description',
      'default_fee',
      'tax_rate',
      'status',
      'created_at',
      'updated_at',
    ],
    '13_MEDICAL_RECORDS': [
      'record_id',
      'patient_id',
      'consultation_id',
      'record_type',
      'title',
      'description',
      'document_url',
      'record_date',
      'created_by',
      'created_at',
      'updated_at',
    ],
    '14_PRESCRIPTIONS': [
      'prescription_id',
      'consultation_id',
      'patient_id',
      'medicine_name',
      'dosage',
      'frequency',
      'duration',
      'route',
      'instructions',
      'quantity',
      'created_at',
    ],
    '15_FOLLOW_UPS': [
      'followup_id',
      'patient_id',
      'consultation_id',
      'doctor_id',
      'due_date',
      'status',
      'reminder_consent',
      'reminder_sent_at',
      'converted_appointment_id',
      'notes',
      'created_at',
      'updated_at',
    ],
    '16_ROOMS': [
      'room_id',
      'room_code',
      'room_name',
      'room_type',
      'floor',
      'status',
      'assigned_doctor_id',
      'notes',
      'created_at',
      'updated_at',
    ],
    '17_AUDIT_LOG': [
      'audit_id',
      'timestamp',
      'user_id',
      'user_role',
      'action',
      'entity_type',
      'entity_id',
      'old_value',
      'new_value',
      'source',
      'remarks',
    ],
    '18_NOTIFICATIONS': [
      'notification_id',
      'patient_id',
      'notification_type',
      'recipient_contact',
      'scheduled_at',
      'sent_at',
      'channel',
      'template_name',
      'status',
      'delivery_status',
      'remarks',
      'created_at',
    ],
    '19_REPORTING': [
      'kpi_metric_id',
      'metric_name',
      'metric_value_formula',
      'category',
      'notes',
    ],
    '20_LOOKUPS': [
      'lookup_id',
      'category',
      'code',
      'display_name',
      'sort_order',
      'is_active',
      'description',
    ],
    'Spreadsheet_Registry': spreadsheetRegistryHeaders,
    'Patient_History_Index': patientHistoryIndexHeaders,
  };

  /// Canonical initial lookup records for 20_LOOKUPS
  static const List<List<dynamic>> defaultLookups = [
    ['LKP-001', 'GENDER', 'MALE', 'Male', 1, true, 'Biological Male'],
    ['LKP-002', 'GENDER', 'FEMALE', 'Female', 2, true, 'Biological Female'],
    ['LKP-003', 'GENDER', 'OTHER', 'Other', 3, true, 'Other / Non-binary'],
    ['LKP-010', 'APPOINTMENT_STATUS', 'SCHEDULED', 'Scheduled', 1, true, 'Upcoming appointment'],
    ['LKP-011', 'APPOINTMENT_STATUS', 'COMPLETED', 'Completed', 2, true, 'Completed appointment'],
    ['LKP-012', 'APPOINTMENT_STATUS', 'CANCELLED', 'Cancelled', 3, true, 'Cancelled appointment'],
    ['LKP-013', 'APPOINTMENT_STATUS', 'NO_SHOW', 'No Show', 4, true, 'Patient did not arrive'],
    ['LKP-020', 'QUEUE_STATUS', 'WAITING', 'Waiting', 1, true, 'In waiting room'],
    ['LKP-021', 'QUEUE_STATUS', 'IN_CONSULTATION', 'In Consultation', 2, true, 'With doctor'],
    ['LKP-022', 'QUEUE_STATUS', 'COMPLETED', 'Completed', 3, true, 'Visit complete'],
    ['LKP-030', 'PAYMENT_STATUS', 'PAID', 'Paid', 1, true, 'Fully paid'],
    ['LKP-031', 'PAYMENT_STATUS', 'PENDING', 'Pending', 2, true, 'Payment due'],
    ['LKP-040', 'PAYMENT_METHOD', 'CASH', 'Cash', 1, true, 'Cash payment'],
    ['LKP-041', 'PAYMENT_METHOD', 'UPI', 'UPI', 2, true, 'UPI digital payment'],
    ['LKP-042', 'PAYMENT_METHOD', 'CARD', 'Card', 3, true, 'Debit/Credit card'],
    ['LKP-050', 'USER_ROLE', 'ADMIN', 'Admin', 1, true, 'Clinic Administrator'],
    ['LKP-051', 'USER_ROLE', 'DOCTOR', 'Doctor', 2, true, 'Medical Doctor'],
    ['LKP-052', 'USER_ROLE', 'RECEPTIONIST', 'Receptionist', 3, true, 'Front Desk Staff'],
  ];

  /// Validates a list of sheet names and their headers against the canonical specification
  static MasterSheetValidationResult validate({
    required List<String> actualSheetNames,
    required Map<String, List<String>> actualHeadersBySheet,
  }) {
    final missingSheets = <String>[];
    final unexpectedSheets = <String>[];
    final missingHeaders = <String, List<String>>{};
    final misplacedHeaders = <String, List<String>>{};

    // Check for missing sheets
    for (final expected in canonicalSheetNames) {
      if (!actualSheetNames.contains(expected)) {
        missingSheets.add(expected);
      }
    }

    // Check for unexpected extra sheets
    for (final actual in actualSheetNames) {
      if (!canonicalSheetNames.contains(actual)) {
        unexpectedSheets.add(actual);
      }
    }

    // Validate headers for present sheets
    for (final expectedSheet in canonicalSheetNames) {
      if (!actualSheetNames.contains(expectedSheet)) continue;

      final expectedCols = canonicalHeaders[expectedSheet] ?? [];
      final actualCols = actualHeadersBySheet[expectedSheet] ?? [];

      // Check missing columns
      final missingInSheet = <String>[];
      for (final expCol in expectedCols) {
        if (!actualCols.contains(expCol)) {
          missingInSheet.add(expCol);
        }
      }
      if (missingInSheet.isNotEmpty) {
        missingHeaders[expectedSheet] = missingInSheet;
      }

      // Check column ordering (must match exact sequence for canonical integrity)
      final misplacedInSheet = <String>[];
      final minLen = actualCols.length < expectedCols.length
          ? actualCols.length
          : expectedCols.length;
      for (int i = 0; i < minLen; i++) {
        if (actualCols[i] != expectedCols[i]) {
          misplacedInSheet.add(
            'Col $i expected "${expectedCols[i]}" but found "${actualCols[i]}"',
          );
        }
      }
      if (actualCols.length < expectedCols.length && missingInSheet.isEmpty) {
        misplacedInSheet.add(
          'Total column count (${actualCols.length}) less than expected (${expectedCols.length})',
        );
      }
      if (misplacedInSheet.isNotEmpty) {
        misplacedHeaders[expectedSheet] = misplacedInSheet;
      }
    }

    final isValid =
        missingSheets.isEmpty &&
        missingHeaders.isEmpty &&
        misplacedHeaders.isEmpty;

    String? errorSummary;
    if (!isValid) {
      final parts = <String>[];
      if (missingSheets.isNotEmpty) {
        parts.add('Missing worksheets: ${missingSheets.join(", ")}');
      }
      if (missingHeaders.isNotEmpty) {
        final details = missingHeaders.entries
            .map((e) => '${e.key}: [${e.value.join(", ")}]')
            .join('; ');
        parts.add('Missing columns in: $details');
      }
      if (misplacedHeaders.isNotEmpty) {
        final details = misplacedHeaders.entries
            .map((e) => '${e.key} (${e.value.first})')
            .join('; ');
        parts.add('Header sequence mismatch: $details');
      }
      errorSummary = parts.join(' | ');
    }

    return MasterSheetValidationResult(
      isValid: isValid,
      missingSheets: missingSheets,
      unexpectedSheets: unexpectedSheets,
      missingHeaders: missingHeaders,
      misplacedHeaders: misplacedHeaders,
      errorMessage: errorSummary,
    );
  }
}

/// Immutable validation result of the Master Sheet schema verification
class MasterSheetValidationResult {
  final bool isValid;
  final List<String> missingSheets;
  final List<String> unexpectedSheets;
  final Map<String, List<String>> missingHeaders;
  final Map<String, List<String>> misplacedHeaders;
  final String? errorCode;
  final String? errorMessage;

  const MasterSheetValidationResult({
    required this.isValid,
    this.missingSheets = const [],
    this.unexpectedSheets = const [],
    this.missingHeaders = const {},
    this.misplacedHeaders = const {},
    this.errorCode,
    this.errorMessage,
  });

  static const MasterSheetValidationResult success =
      MasterSheetValidationResult(isValid: true);

  factory MasterSheetValidationResult.failure({
    required String message,
    String errorCode = 'SCHEMA_MISMATCH',
    List<String> missingSheets = const [],
    Map<String, List<String>> missingHeaders = const {},
    Map<String, List<String>> misplacedHeaders = const {},
  }) {
    return MasterSheetValidationResult(
      isValid: false,
      errorCode: errorCode,
      errorMessage: message,
      missingSheets: missingSheets,
      missingHeaders: missingHeaders,
      misplacedHeaders: misplacedHeaders,
    );
  }
}

/// Controlled lookup row from 20_LOOKUPS
class MasterSheetLookupItem {
  final String lookupId;
  final String category;
  final String code;
  final String displayName;
  final int sortOrder;
  final bool isActive;
  final String description;

  const MasterSheetLookupItem({
    required this.lookupId,
    required this.category,
    required this.code,
    required this.displayName,
    this.sortOrder = 0,
    this.isActive = true,
    this.description = '',
  });

  factory MasterSheetLookupItem.fromRow(List<dynamic> row) {
    return MasterSheetLookupItem(
      lookupId: row.isNotEmpty ? row[0].toString() : '',
      category: row.length > 1 ? row[1].toString() : '',
      code: row.length > 2 ? row[2].toString() : '',
      displayName: row.length > 3 ? row[3].toString() : '',
      sortOrder: row.length > 4 ? int.tryParse(row[4].toString()) ?? 0 : 0,
      isActive: row.length > 5
          ? (row[5].toString().toUpperCase() == 'TRUE' ||
              row[5].toString() == '1' ||
              row[5].toString().toUpperCase() == 'ACTIVE')
          : true,
      description: row.length > 6 ? row[6].toString() : '',
    );
  }
}
