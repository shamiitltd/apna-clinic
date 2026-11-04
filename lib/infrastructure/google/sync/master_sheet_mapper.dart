// Apna Clinic - Strongly Typed Master Sheet Mapper
// Phase 3 — Milestone 3
// Primary source of truth: APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL.xlsx, TRD Section 7 & 11
// Invariants:
// 1. Exact canonical 20-sheet column headers and order preserved 100%.
// 2. Deterministic, pure mappings from local domain models/maps to remote spreadsheet rows.
// 3. Currency represented in Rupees with 2 decimal places (from minor units paise).
// 4. Dates represented in standard ISO-8601 strings (YYYY-MM-DD or YYYY-MM-DDTHH:MM:SSZ).
// 5. Zero clinical diagnostic or prescription sensitive data leakage in raw logs.

import '../../../domain/entities/master_sheet_schema.dart';

class MasterSheetMapper {
  MasterSheetMapper._();

  /// Maps local entity table names to canonical Master Sheet tab names
  static String resolveSheetName(String entityType) {
    switch (entityType.toLowerCase()) {
      case 'clinic_config':
      case 'settings':
      case '01_settings':
        return '01_SETTINGS';
      case 'staff':
      case 'users':
      case '02_users':
        return '02_USERS';
      case 'roles':
      case '03_roles':
        return '03_ROLES';
      case 'doctors':
      case '04_doctors':
        return '04_DOCTORS';
      case 'patients':
      case '05_patients':
        return '05_PATIENTS';
      case 'appointments':
      case '06_appointments':
        return '06_APPOINTMENTS';
      case 'doctor_schedules':
      case 'schedules':
      case '07_doctor_schedules':
        return '07_DOCTOR_SCHEDULES';
      case 'queue_events':
      case 'queue':
      case '08_queue':
        return '08_QUEUE';
      case 'visits':
      case 'consultations':
      case '09_consultations':
        return '09_CONSULTATIONS';
      case 'invoices':
      case 'billing':
      case '10_billing':
        return '10_BILLING';
      case 'payments':
      case '11_payments':
        return '11_PAYMENTS';
      case 'fee_catalog':
      case 'services':
      case '12_services':
        return '12_SERVICES';
      case 'medical_records':
      case '13_medical_records':
        return '13_MEDICAL_RECORDS';
      case 'prescriptions':
      case '14_prescriptions':
        return '14_PRESCRIPTIONS';
      case 'followups':
      case 'follow_ups':
      case '15_follow_ups':
        return '15_FOLLOW_UPS';
      case 'rooms':
      case '16_rooms':
        return '16_ROOMS';
      case 'audit_events':
      case 'audit_log':
      case '17_audit_log':
        return '17_AUDIT_LOG';
      case 'notifications':
      case '18_notifications':
        return '18_NOTIFICATIONS';
      case 'reporting':
      case 'daily_summary':
      case '19_reporting':
        return '19_REPORTING';
      case 'lookup_config':
      case 'lookups':
      case '20_lookups':
        return '20_LOOKUPS';
      default:
        return entityType;
    }
  }

  /// Maps an entity map to a remote row matching the exact canonical header sequence
  static List<dynamic> mapToRow(String sheetName, Map<String, dynamic> record) {
    switch (sheetName) {
      case '01_SETTINGS':
        return _mapSettings(record);
      case '02_USERS':
        return _mapUsers(record);
      case '03_ROLES':
        return _mapRoles(record);
      case '04_DOCTORS':
        return _mapDoctors(record);
      case '05_PATIENTS':
        return _mapPatients(record);
      case '06_APPOINTMENTS':
        return _mapAppointments(record);
      case '07_DOCTOR_SCHEDULES':
        return _mapDoctorSchedules(record);
      case '08_QUEUE':
        return _mapQueue(record);
      case '09_CONSULTATIONS':
        return _mapConsultations(record);
      case '10_BILLING':
        return _mapBilling(record);
      case '11_PAYMENTS':
        return _mapPayments(record);
      case '12_SERVICES':
        return _mapServices(record);
      case '13_MEDICAL_RECORDS':
        return _mapMedicalRecords(record);
      case '14_PRESCRIPTIONS':
        return _mapPrescriptions(record);
      case '15_FOLLOW_UPS':
        return _mapFollowUps(record);
      case '16_ROOMS':
        return _mapRooms(record);
      case '17_AUDIT_LOG':
        return _mapAuditLog(record);
      case '18_NOTIFICATIONS':
        return _mapNotifications(record);
      case '19_REPORTING':
        return _mapReporting(record);
      case '20_LOOKUPS':
        return _mapLookups(record);
      default:
        // Fallback: order by canonical headers if sheet exists
        final headers = MasterSheetSchema.canonicalHeaders[sheetName] ?? [];
        return headers.map((h) => record[h]?.toString() ?? '').toList();
    }
  }

  /// 01_SETTINGS
  /// Canonical: [setting_id, setting_category, setting_key, setting_value, data_type, description, is_system, updated_at]
  static List<dynamic> _mapSettings(Map<String, dynamic> r) {
    final key = (r['setting_key'] ?? r['key'] ?? '').toString();
    final id = r['setting_id'] ?? (key.isNotEmpty ? 'SET-$key' : 'SET-001');
    return [
      id,
      r['setting_category'] ?? r['category'] ?? 'CLINIC',
      key,
      r['setting_value'] ?? r['value'] ?? '',
      r['data_type'] ?? 'STRING',
      r['description'] ?? '',
      (r['is_system'] == true || r['is_system']?.toString().toUpperCase() == 'TRUE') ? 'TRUE' : 'FALSE',
      r['updated_at'] ?? r['created_at'] ?? '',
    ];
  }

  /// 02_USERS
  /// Canonical: [user_id, username, display_name, role_id, phone, email, status, assigned_doctor_ids, created_at, updated_at]
  static List<dynamic> _mapUsers(Map<String, dynamic> r) {
    return [
      r['user_id'] ?? r['staff_id'] ?? '',
      r['username'] ?? '',
      r['display_name'] ?? r['full_name'] ?? '',
      r['role_id'] ?? r['role'] ?? '',
      r['phone'] ?? '',
      r['email'] ?? '',
      r['status'] ?? ((r['active'] == false || r['active'] == 0) ? 'INACTIVE' : 'ACTIVE'),
      r['assigned_doctor_ids'] ?? '',
      r['created_at'] ?? '',
      r['updated_at'] ?? '',
    ];
  }

  /// 03_ROLES
  /// Canonical: [role_id, role_code, role_name, description, permissions_summary, status, created_at, updated_at]
  static List<dynamic> _mapRoles(Map<String, dynamic> r) {
    return [
      r['role_id'] ?? '',
      r['role_code'] ?? '',
      r['role_name'] ?? '',
      r['description'] ?? '',
      r['permissions_summary'] ?? '',
      r['status'] ?? 'ACTIVE',
      r['created_at'] ?? '',
      r['updated_at'] ?? '',
    ];
  }

  /// 04_DOCTORS
  /// Canonical: [doctor_id, doctor_code, doctor_name, specialization, qualification, registration_number, phone, email, room_id, consultation_fee, consultation_duration_minutes, status, joining_date, created_at, updated_at]
  static List<dynamic> _mapDoctors(Map<String, dynamic> r) {
    final fee = r['default_fee'] != null
        ? ((r['default_fee'] as num) / 100).toStringAsFixed(2)
        : (r['consultation_fee']?.toString() ?? '500.00');

    return [
      r['doctor_id'] ?? '',
      r['doctor_code'] ?? r['doctor_id'] ?? '',
      r['display_name'] ?? r['doctor_name'] ?? r['name'] ?? '',
      r['specialty_label'] ?? r['specialization'] ?? 'General Medicine',
      r['qualification_text'] ?? r['qualification'] ?? '',
      r['registration_number'] ?? '',
      r['contact_phone'] ?? r['phone'] ?? '',
      r['email'] ?? '',
      r['room_label'] ?? r['room_id'] ?? 'ROOM-01',
      fee,
      r['consultation_duration_minutes']?.toString() ?? '15',
      (r['active'] == 0 || r['active'] == false) ? 'INACTIVE' : 'ACTIVE',
      r['joining_date'] ?? '',
      r['created_at'] ?? '',
      r['updated_at'] ?? '',
    ];
  }

  /// 05_PATIENTS
  /// Canonical: [patient_id, patient_code, first_name, middle_name, last_name, full_name, date_of_birth, age, gender, phone, alternate_phone, email, address, city, state, pincode, emergency_contact_name, emergency_contact_phone, blood_group, registration_date, patient_status, consent_status, consent_version, created_at, updated_at, created_by, updated_by]
  static List<dynamic> _mapPatients(Map<String, dynamic> r) {
    final fullName = r['full_name'] ?? '';
    final names = fullName.toString().trim().split(RegExp(r'\s+'));
    final firstName = r['first_name'] ?? (names.isNotEmpty ? names.first : '');
    final lastName = r['last_name'] ?? (names.length > 1 ? names.last : '');
    final middleName = r['middle_name'] ?? (names.length > 2 ? names.sublist(1, names.length - 1).join(' ') : '');

    return [
      r['patient_id'] ?? '',
      r['patient_code'] ?? r['patient_number'] ?? '',
      firstName,
      middleName,
      lastName,
      fullName,
      r['date_of_birth'] ?? '',
      r['age']?.toString() ?? r['age_if_dob_unknown']?.toString() ?? '',
      r['gender'] ?? r['sex_optional'] ?? '',
      r['phone'] ?? r['phone_optional'] ?? '',
      r['alternate_phone'] ?? r['alternate_phone_optional'] ?? '',
      r['email'] ?? r['email_optional'] ?? '',
      r['address'] ?? r['address_optional'] ?? '',
      r['city'] ?? r['city_optional'] ?? '',
      r['state'] ?? r['state_optional'] ?? '',
      r['pincode'] ?? r['pincode_optional'] ?? '',
      r['emergency_contact_name'] ?? '',
      r['emergency_contact_phone'] ?? '',
      r['blood_group'] ?? '',
      r['registration_date'] ?? (r['created_at']?.toString().split('T').first ?? ''),
      r['patient_status'] ?? (r['deleted_at'] != null ? 'INACTIVE' : 'ACTIVE'),
      r['consent_status'] ?? 'granted',
      r['consent_version'] ?? 'v1.0',
      r['created_at'] ?? '',
      r['updated_at'] ?? '',
      r['created_by'] ?? 'SYSTEM',
      r['updated_by'] ?? 'SYSTEM',
    ];
  }

  /// 06_APPOINTMENTS
  /// Canonical: [appointment_id, appointment_code, patient_id, doctor_id, appointment_date, start_time, end_time, appointment_type, booking_source, status, token_number, room_id, notes, cancel_reason, reminder_consent, reminder_status, created_at, updated_at, created_by, updated_by]
  static List<dynamic> _mapAppointments(Map<String, dynamic> r) {
    return [
      r['appointment_id'] ?? '',
      r['appointment_code'] ?? r['appointment_id'] ?? '',
      r['patient_id'] ?? '',
      r['doctor_id'] ?? '',
      r['appointment_date'] ?? (r['scheduled_start']?.toString().split('T').first ?? ''),
      r['start_time'] ?? '',
      r['end_time'] ?? '',
      r['appointment_type'] ?? 'CONSULTATION',
      r['booking_source'] ?? 'WALKIN',
      r['status']?.toString().toUpperCase() ?? 'SCHEDULED',
      r['token_number']?.toString() ?? '',
      r['room_id'] ?? 'ROOM-01',
      r['notes'] ?? '',
      r['cancel_reason'] ?? '',
      r['reminder_consent']?.toString().toUpperCase() ?? 'TRUE',
      r['reminder_status'] ?? 'PENDING',
      r['created_at'] ?? '',
      r['updated_at'] ?? '',
      r['created_by'] ?? 'SYSTEM',
      r['updated_by'] ?? 'SYSTEM',
    ];
  }

  /// 07_DOCTOR_SCHEDULES
  /// Canonical: [schedule_id, doctor_id, day_of_week, start_time, end_time, slot_duration, break_start, break_end, room_id, maximum_patients, status, effective_from, effective_to, created_at, updated_at]
  static List<dynamic> _mapDoctorSchedules(Map<String, dynamic> r) {
    return [
      r['schedule_id'] ?? '',
      r['doctor_id'] ?? '',
      r['day_of_week'] ?? 'MONDAY',
      r['start_time'] ?? '09:00',
      r['end_time'] ?? '17:00',
      r['slot_duration']?.toString() ?? '15',
      r['break_start'] ?? '13:00',
      r['break_end'] ?? '14:00',
      r['room_id'] ?? 'ROOM-01',
      r['maximum_patients']?.toString() ?? '30',
      r['status'] ?? 'ACTIVE',
      r['effective_from'] ?? '',
      r['effective_to'] ?? '',
      r['created_at'] ?? '',
      r['updated_at'] ?? '',
    ];
  }

  /// 08_QUEUE
  /// Canonical: [queue_id, appointment_id, patient_id, doctor_id, token_number, queue_date, check_in_time, called_time, consultation_start_time, consultation_end_time, queue_status, priority, room_id, created_at, updated_at]
  static List<dynamic> _mapQueue(Map<String, dynamic> r) {
    return [
      r['queue_id'] ?? r['visit_id'] ?? '',
      r['appointment_id'] ?? r['appointment_id_optional'] ?? '',
      r['patient_id'] ?? '',
      r['doctor_id'] ?? '',
      r['token_number']?.toString() ?? '1',
      r['queue_date'] ?? r['visit_date_local'] ?? '',
      r['check_in_time'] ?? r['checkin_at'] ?? '',
      r['called_time'] ?? '',
      r['consultation_start_time'] ?? r['consultation_started_at'] ?? '',
      r['consultation_end_time'] ?? r['consultation_completed_at'] ?? '',
      r['queue_status']?.toString().toUpperCase() ?? 'WAITING',
      r['priority'] ?? 'NORMAL',
      r['room_id'] ?? 'ROOM-01',
      r['created_at'] ?? '',
      r['updated_at'] ?? '',
    ];
  }

  /// 09_CONSULTATIONS
  /// Canonical: [consultation_id, appointment_id, patient_id, doctor_id, chief_complaint, clinical_summary, diagnosis, advice, follow_up_required, follow_up_date, consultation_status, started_at, completed_at, created_at, updated_at]
  static List<dynamic> _mapConsultations(Map<String, dynamic> r) {
    return [
      r['consultation_id'] ?? r['visit_id'] ?? '',
      r['appointment_id'] ?? r['appointment_id_optional'] ?? '',
      r['patient_id'] ?? '',
      r['doctor_id'] ?? '',
      r['chief_complaint'] ?? '',
      r['clinical_summary'] ?? '',
      r['diagnosis'] ?? '',
      r['advice'] ?? '',
      (r['follow_up_required'] == true || r['followup_due_date_optional'] != null) ? 'TRUE' : 'FALSE',
      r['follow_up_date'] ?? r['followup_due_date_optional'] ?? '',
      r['consultation_status'] ?? 'COMPLETED',
      r['started_at'] ?? r['consultation_started_at'] ?? '',
      r['completed_at'] ?? r['consultation_completed_at'] ?? '',
      r['created_at'] ?? '',
      r['updated_at'] ?? '',
    ];
  }

  /// 10_BILLING
  /// Canonical: [invoice_id, invoice_number, patient_id, appointment_id, invoice_date, subtotal, discount, tax, total_amount, paid_amount, due_amount, payment_status, notes, created_at, updated_at]
  static List<dynamic> _mapBilling(Map<String, dynamic> r) {
    String paiseToRupees(dynamic minor) {
      if (minor == null) return '0.00';
      if (minor is num) return (minor / 100).toStringAsFixed(2);
      final d = double.tryParse(minor.toString());
      return d != null ? (d / 100).toStringAsFixed(2) : '0.00';
    }

    return [
      r['invoice_id'] ?? '',
      r['invoice_number'] ?? '',
      r['patient_id'] ?? '',
      r['appointment_id'] ?? r['visit_id'] ?? '',
      r['invoice_date'] ?? r['issue_date_local'] ?? '',
      paiseToRupees(r['subtotal_minor']),
      paiseToRupees(r['discount_minor']),
      paiseToRupees(r['tax_minor']),
      paiseToRupees(r['total_minor']),
      paiseToRupees(r['paid_minor']),
      paiseToRupees(r['balance_minor']),
      r['payment_status'] ?? r['status']?.toString().toUpperCase() ?? 'PAID',
      r['notes'] ?? r['notes_nonclinical'] ?? '',
      r['created_at'] ?? '',
      r['updated_at'] ?? '',
    ];
  }

  /// 11_PAYMENTS
  /// Canonical: [payment_id, invoice_id, patient_id, payment_date, amount, payment_method, transaction_reference, payment_status, received_by, notes, created_at]
  static List<dynamic> _mapPayments(Map<String, dynamic> r) {
    String paiseToRupees(dynamic minor) {
      if (minor == null) return '0.00';
      if (minor is num) return (minor / 100).toStringAsFixed(2);
      final d = double.tryParse(minor.toString());
      return d != null ? (d / 100).toStringAsFixed(2) : '0.00';
    }

    return [
      r['payment_id'] ?? '',
      r['invoice_id'] ?? '',
      r['patient_id'] ?? '',
      r['payment_date'] ?? (r['received_at']?.toString().split('T').first ?? ''),
      paiseToRupees(r['amount_minor']),
      r['payment_method'] ?? r['method']?.toString().toUpperCase() ?? 'CASH',
      r['transaction_reference'] ?? r['cash_upi_card_reference_optional'] ?? '',
      r['payment_status'] ?? r['status']?.toString().toUpperCase() ?? 'COMPLETED',
      r['received_by'] ?? r['received_by_staff_id'] ?? '',
      r['notes'] ?? '',
      r['created_at'] ?? '',
    ];
  }

  /// 12_SERVICES
  /// Canonical: [service_id, service_code, service_name, category, description, default_fee, tax_rate, status, created_at, updated_at]
  static List<dynamic> _mapServices(Map<String, dynamic> r) {
    final fee = r['default_amount_minor'] != null
        ? ((r['default_amount_minor'] as num) / 100).toStringAsFixed(2)
        : (r['default_fee']?.toString() ?? '500.00');

    return [
      r['service_id'] ?? r['fee_id'] ?? '',
      r['service_code'] ?? r['fee_code'] ?? r['fee_id'] ?? '',
      r['service_name'] ?? r['fee_name'] ?? '',
      r['category'] ?? 'CONSULTATION',
      r['description'] ?? '',
      fee,
      r['tax_rate']?.toString() ?? '0.0',
      (r['active'] == false || r['active'] == 0) ? 'INACTIVE' : 'ACTIVE',
      r['created_at'] ?? '',
      r['updated_at'] ?? '',
    ];
  }

  /// 13_MEDICAL_RECORDS
  /// Canonical: [record_id, patient_id, consultation_id, record_type, title, description, document_url, record_date, created_by, created_at, updated_at]
  static List<dynamic> _mapMedicalRecords(Map<String, dynamic> r) {
    return [
      r['record_id'] ?? '',
      r['patient_id'] ?? '',
      r['consultation_id'] ?? '',
      r['record_type'] ?? 'LAB_REPORT',
      r['title'] ?? '',
      r['description'] ?? '',
      r['document_url'] ?? '',
      r['record_date'] ?? '',
      r['created_by'] ?? '',
      r['created_at'] ?? '',
      r['updated_at'] ?? '',
    ];
  }

  /// 14_PRESCRIPTIONS
  /// Canonical: [prescription_id, consultation_id, patient_id, medicine_name, dosage, frequency, duration, route, instructions, quantity, created_at]
  static List<dynamic> _mapPrescriptions(Map<String, dynamic> r) {
    return [
      r['prescription_id'] ?? '',
      r['consultation_id'] ?? '',
      r['patient_id'] ?? '',
      r['medicine_name'] ?? '',
      r['dosage'] ?? '',
      r['frequency'] ?? '',
      r['duration'] ?? '',
      r['route'] ?? 'ORAL',
      r['instructions'] ?? '',
      r['quantity']?.toString() ?? '1',
      r['created_at'] ?? '',
    ];
  }

  /// 15_FOLLOW_UPS
  /// Canonical: [followup_id, patient_id, consultation_id, doctor_id, due_date, status, reminder_consent, reminder_sent_at, converted_appointment_id, notes, created_at, updated_at]
  static List<dynamic> _mapFollowUps(Map<String, dynamic> r) {
    return [
      r['followup_id'] ?? '',
      r['patient_id'] ?? '',
      r['consultation_id'] ?? '',
      r['doctor_id'] ?? '',
      r['due_date'] ?? '',
      r['status'] ?? 'SCHEDULED',
      r['reminder_consent']?.toString().toUpperCase() ?? 'TRUE',
      r['reminder_sent_at'] ?? '',
      r['converted_appointment_id'] ?? '',
      r['notes'] ?? '',
      r['created_at'] ?? '',
      r['updated_at'] ?? '',
    ];
  }

  /// 16_ROOMS
  /// Canonical: [room_id, room_code, room_name, room_type, floor, status, assigned_doctor_id, notes, created_at, updated_at]
  static List<dynamic> _mapRooms(Map<String, dynamic> r) {
    return [
      r['room_id'] ?? '',
      r['room_code'] ?? '',
      r['room_name'] ?? '',
      r['room_type'] ?? 'CONSULTATION',
      r['floor'] ?? '1',
      r['status'] ?? 'AVAILABLE',
      r['assigned_doctor_id'] ?? '',
      r['notes'] ?? '',
      r['created_at'] ?? '',
      r['updated_at'] ?? '',
    ];
  }

  /// 17_AUDIT_LOG
  /// Canonical: [audit_id, timestamp, user_id, user_role, action, entity_type, entity_id, old_value, new_value, source, remarks]
  static List<dynamic> _mapAuditLog(Map<String, dynamic> r) {
    return [
      r['audit_id'] ?? '',
      r['timestamp'] ?? DateTime.now().toUtc().toIso8601String(),
      r['user_id'] ?? '',
      r['user_role'] ?? '',
      r['action'] ?? '',
      r['entity_type'] ?? '',
      r['entity_id'] ?? '',
      r['old_value'] ?? '',
      r['new_value'] ?? '',
      r['source'] ?? 'APP',
      r['remarks'] ?? '',
    ];
  }

  /// 18_NOTIFICATIONS
  /// Canonical: [notification_id, patient_id, notification_type, recipient_contact, scheduled_at, sent_at, channel, template_name, status, delivery_status, remarks, created_at]
  static List<dynamic> _mapNotifications(Map<String, dynamic> r) {
    return [
      r['notification_id'] ?? '',
      r['patient_id'] ?? '',
      r['notification_type'] ?? 'APPOINTMENT_REMINDER',
      r['recipient_contact'] ?? '',
      r['scheduled_at'] ?? '',
      r['sent_at'] ?? '',
      r['channel'] ?? 'SMS',
      r['template_name'] ?? '',
      r['status'] ?? 'SENT',
      r['delivery_status'] ?? 'DELIVERED',
      r['remarks'] ?? '',
      r['created_at'] ?? '',
    ];
  }

  /// 19_REPORTING
  /// Canonical: [kpi_metric_id, metric_name, metric_value_formula, category, notes]
  static List<dynamic> _mapReporting(Map<String, dynamic> r) {
    return [
      r['kpi_metric_id'] ?? '',
      r['metric_name'] ?? '',
      r['metric_value_formula'] ?? '',
      r['category'] ?? '',
      r['notes'] ?? '',
    ];
  }

  /// 20_LOOKUPS
  /// Canonical: [lookup_id, category, code, display_name, sort_order, is_active, description]
  static List<dynamic> _mapLookups(Map<String, dynamic> r) {
    return [
      r['lookup_id'] ?? '',
      r['category'] ?? '',
      r['code'] ?? '',
      r['display_name'] ?? r['name'] ?? '',
      r['sort_order']?.toString() ?? '0',
      (r['is_active'] == false || r['is_active'] == 0) ? 'FALSE' : 'TRUE',
      r['description'] ?? '',
    ];
  }
}
