// Apna Clinic - Patient History Cross-Month Router
// Primary source of truth: Feature PRD Section 9 & Feature TRD Section 8

import '../../../database/local_database.dart';
import '../data/monthly_storage_repository.dart';
import '../models/patient_history_index_entry.dart';
import 'month_resolver.dart';

class PatientTimelineItem {
  final String id;
  final String type; // 'visit', 'appointment', 'invoice', 'payment'
  final String date; // ISO-8601 string
  final String yearMonth;
  final String title;
  final String subtitle;
  final String status;
  final Map<String, dynamic> rawData;

  const PatientTimelineItem({
    required this.id,
    required this.type,
    required this.date,
    required this.yearMonth,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.rawData,
  });
}

class PatientMonthlyHistoryResult {
  final String patientId;
  final List<String> recordedMonths;
  final List<PatientHistoryIndexEntry> indexEntries;
  final List<PatientTimelineItem> timeline;
  final bool isPartial;
  final String? errorMessage;

  const PatientMonthlyHistoryResult({
    required this.patientId,
    required this.recordedMonths,
    required this.indexEntries,
    required this.timeline,
    this.isPartial = false,
    this.errorMessage,
  });
}

class PatientHistoryRouter {
  final LocalDatabase localDb;
  final MonthlyStorageRepository repository;

  PatientHistoryRouter({
    required this.localDb,
    required this.repository,
  });

  /// Retrieves a patient's administrative timeline across all months without scanning every workbook
  Future<PatientMonthlyHistoryResult> getPatientHistory({
    required String clinicId,
    required String patientId,
  }) async {
    final timeline = <PatientTimelineItem>[];

    // 1. Query Patient_History_Index to resolve which months hold data
    final indexEntries = await repository.getPatientHistoryIndex(
      clinicId: clinicId,
      patientId: patientId,
    );

    final recordedMonths = indexEntries.map((e) => e.yearMonth).toSet().toList()
      ..sort((a, b) => b.compareTo(a)); // Descending

    // 2. Load Local Data from LocalDatabase
    // A. Visits
    final allVisits = localDb.query('Visits');
    for (final v in allVisits) {
      if (v['patient_id'] == patientId && (v['clinic_id'] == null || v['clinic_id'] == clinicId)) {
        final date = v['visit_date']?.toString() ?? v['checkin_at']?.toString() ?? '';
        final ym = MonthResolver.resolveMonthFromString(date);
        timeline.add(PatientTimelineItem(
          id: v['visit_id']?.toString() ?? '',
          type: 'visit',
          date: date,
          yearMonth: ym,
          title: 'Visit #${v['token_number'] ?? ""}',
          subtitle: 'Doctor: ${v['doctor_name'] ?? v['doctor_id'] ?? "General"} • Status: ${v['queue_status'] ?? ""}',
          status: v['queue_status']?.toString() ?? 'COMPLETED',
          rawData: v,
        ));
      }
    }

    // B. Appointments
    final allAppointments = localDb.query('Appointments');
    for (final a in allAppointments) {
      if (a['patient_id'] == patientId && (a['clinic_id'] == null || a['clinic_id'] == clinicId)) {
        final date = a['appointment_date']?.toString() ?? a['scheduled_start_at']?.toString() ?? '';
        final ym = MonthResolver.resolveMonthFromString(date);
        timeline.add(PatientTimelineItem(
          id: a['appointment_id']?.toString() ?? '',
          type: 'appointment',
          date: date,
          yearMonth: ym,
          title: 'Appointment: ${a['slot_start_time'] ?? ""}',
          subtitle: 'Type: ${a['appointment_type'] ?? "Regular"} • Status: ${a['status'] ?? ""}',
          status: a['status']?.toString() ?? 'SCHEDULED',
          rawData: a,
        ));
      }
    }

    // C. Invoices
    final allInvoices = localDb.query('Invoices');
    for (final inv in allInvoices) {
      if (inv['patient_id'] == patientId && (inv['clinic_id'] == null || inv['clinic_id'] == clinicId)) {
        final date = inv['invoice_date']?.toString() ?? inv['issued_at']?.toString() ?? '';
        final ym = MonthResolver.resolveMonthFromString(date);
        timeline.add(PatientTimelineItem(
          id: inv['invoice_id']?.toString() ?? '',
          type: 'invoice',
          date: date,
          yearMonth: ym,
          title: 'Invoice #${inv['invoice_number'] ?? ""}',
          subtitle: 'Amount: ₹${((inv['total_amount'] as num? ?? 0) / 100).toStringAsFixed(2)} • Status: ${inv['payment_status'] ?? ""}',
          status: inv['payment_status']?.toString() ?? 'PAID',
          rawData: inv,
        ));
      }
    }

    // 3. Deduplicate by ID
    final seenIds = <String>{};
    final uniqueTimeline = <PatientTimelineItem>[];
    for (final item in timeline) {
      if (item.id.isNotEmpty && !seenIds.contains(item.id)) {
        seenIds.add(item.id);
        uniqueTimeline.add(item);
      }
    }

    // 4. Sort chronologically descending (newest first)
    uniqueTimeline.sort((a, b) => b.date.compareTo(a.date));

    // Also include months discovered from local records
    for (final item in uniqueTimeline) {
      if (!recordedMonths.contains(item.yearMonth)) {
        recordedMonths.add(item.yearMonth);
      }
    }
    recordedMonths.sort((a, b) => b.compareTo(a));

    return PatientMonthlyHistoryResult(
      patientId: patientId,
      recordedMonths: recordedMonths,
      indexEntries: indexEntries,
      timeline: uniqueTimeline,
      isPartial: false,
    );
  }
}

