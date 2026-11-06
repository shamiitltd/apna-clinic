// Apna Clinic - Monthly Storage Feature Test Suite
// Validates PRD Section 6, 7, 8, 9, 10, 14 & TRD Section 5, 6, 7, 8, 9, 10, 12, 17:
// 1. Timezone-aware MonthResolver (Asia/Kolkata IST UTC+05:30)
// 2. Monthly Workbook Registry & Provisioning
// 3. Patient History Index updates and aggregation
// 4. Outbox partitioning by month & transaction entity
// 5. Cross-month Patient History Router timeline queries
// 6. Reconciliation Service index repairs
// 7. Additive Feature Flag toggle & fallback behavior

import 'dart:io';
import 'package:apna_clinic/core/config/app_config.dart';
import 'package:apna_clinic/domain/entities/master_sheet_schema.dart';
import 'package:apna_clinic/infrastructure/database/local_database.dart';
import 'package:apna_clinic/infrastructure/google/mock_google_integration.dart';
import 'package:apna_clinic/infrastructure/google/sync/master_sheet_mapper.dart';
import 'package:apna_clinic/infrastructure/google/monthly_storage/data/apps_script_client.dart';
import 'package:apna_clinic/infrastructure/google/monthly_storage/data/monthly_storage_repository.dart';
import 'package:apna_clinic/infrastructure/google/monthly_storage/domain/month_resolver.dart';
import 'package:apna_clinic/infrastructure/google/monthly_storage/domain/monthly_sync_coordinator.dart';
import 'package:apna_clinic/infrastructure/google/monthly_storage/domain/patient_history_router.dart';
import 'package:apna_clinic/infrastructure/google/monthly_storage/domain/reconciliation_service.dart';

void main() async {
  int passed = 0;
  int failed = 0;

  void assertTest(String description, bool condition, [String? errorDetail]) {
    if (condition) {
      stdout.writeln('  [PASS] $description');
      passed++;
    } else {
      stderr.writeln(
        '  [FAIL] $description ${errorDetail != null ? "--> $errorDetail" : ""}',
      );
      failed++;
    }
  }

  stdout.writeln('========================================================');
  stdout.writeln('RUNNING APNA CLINIC MONTHLY STORAGE FEATURE TEST SUITE');
  stdout.writeln('========================================================\n');

  final db = LocalDatabase();
  await db.initialize();

  final driveClient = MockGoogleDriveClient();
  final sheetsClient = MockGoogleSheetsClient();
  final appsScriptClient = AppsScriptClient();

  final repository = MonthlyStorageRepository(
    localDb: db,
    driveClient: driveClient,
    sheetsClient: sheetsClient,
    appsScriptClient: appsScriptClient,
  );

  const testClinicId = 'clinic_monthly_test';
  const testFolderId = 'folder_monthly_test';
  const testMasterSheetId = 'master_sheet_monthly_test';

  // 1. Timezone-Aware MonthResolver respects Asia/Kolkata (IST UTC+05:30)
  stdout.writeln('--- 1. TIMEZONE-AWARE MONTH RESOLVER (Asia/Kolkata IST) ---');
  final dtOctober = DateTime.parse('2026-10-31T18:29:59Z');
  assertTest(
    'Oct 31 18:29:59 UTC resolves to 2026-10 (23:59:59 IST)',
    MonthResolver.resolveMonthKey(dtOctober) == '2026-10',
  );

  final dtNovember = DateTime.parse('2026-10-31T18:30:00Z');
  assertTest(
    'Oct 31 18:30:00 UTC resolves to 2026-11 (00:00:00 IST Midnight boundary)',
    MonthResolver.resolveMonthKey(dtNovember) == '2026-11',
  );

  assertTest(
    'String ISO-8601 parsing correctly resolves month',
    MonthResolver.resolveMonthFromString('2026-10-31T18:30:00Z') == '2026-11',
  );
  assertTest(
    'Date-only format YYYY-MM-DD resolves cleanly',
    MonthResolver.resolveMonthFromString('2026-11-15') == '2026-11',
  );

  final wbName = MonthResolver.generateMonthlyWorkbookName('clinic_demo', '2026-11');
  assertTest(
    'Workbook title generation matches convention ApnaClinic_<clinic>_Transactions_YYYY_MM',
    wbName == 'ApnaClinic_clinic_demo_Transactions_2026_11',
  );

  // 2. Monthly Workbook Registry and Provisioning works idempotently
  stdout.writeln('\n--- 2. MONTHLY WORKBOOK REGISTRY & PROVISIONING ---');
  final entry1 = await repository.resolveOrCreateMonthlyWorkbook(
    clinicId: testClinicId,
    yearMonth: '2026-11',
    clinicDriveFolderId: testFolderId,
    masterSpreadsheetId: testMasterSheetId,
  );

  assertTest('Provisioned entry has correct clinicId', entry1.clinicId == testClinicId);
  assertTest('Provisioned entry has correct yearMonth', entry1.yearMonth == '2026-11');
  assertTest('Provisioned entry status is ACTIVE', entry1.status == 'ACTIVE');
  assertTest('Provisioned entry has valid spreadsheetId', entry1.spreadsheetId.isNotEmpty);

  final stored = db.get('Spreadsheet_Registry', '$testClinicId:2026-11');
  assertTest('Stored entry exists in local Spreadsheet_Registry table', stored != null);
  assertTest('Stored entry spreadsheetId matches', stored?['spreadsheet_id'] == entry1.spreadsheetId);

  // Resolve again - must return identical entry without re-provisioning
  final entry2 = await repository.resolveOrCreateMonthlyWorkbook(
    clinicId: testClinicId,
    yearMonth: '2026-11',
    clinicDriveFolderId: testFolderId,
    masterSpreadsheetId: testMasterSheetId,
  );
  assertTest('Idempotent resolve returns identical spreadsheetId', entry2.spreadsheetId == entry1.spreadsheetId);

  // 3. Patient History Index correctly tracks counts and timestamp bounds
  stdout.writeln('\n--- 3. PATIENT HISTORY INDEX UPDATES & AGGREGATION ---');
  const patientId = 'pat_history_001';

  // Event 1: Nov 02, 2026
  await repository.updatePatientHistoryIndex(
    clinicId: testClinicId,
    patientId: patientId,
    yearMonth: '2026-11',
    recordType: 'visits',
    recordTimestamp: '2026-11-02T10:00:00Z',
  );

  var entries = await repository.getPatientHistoryIndex(
    clinicId: testClinicId,
    patientId: patientId,
  );
  assertTest('Initial index entry created', entries.length == 1);
  assertTest('Initial recordCount is 1', entries.first.recordCount == 1);
  assertTest('Initial bounds match event timestamp', entries.first.firstRecordAt == '2026-11-02T10:00:00Z');

  // Event 2: Nov 15, 2026 (Later date)
  await repository.updatePatientHistoryIndex(
    clinicId: testClinicId,
    patientId: patientId,
    yearMonth: '2026-11',
    recordType: 'visits',
    recordTimestamp: '2026-11-15T14:30:00Z',
  );

  entries = await repository.getPatientHistoryIndex(
    clinicId: testClinicId,
    patientId: patientId,
  );
  assertTest('Updated index recordCount increments to 2', entries.first.recordCount == 2);
  assertTest('First record bound remains Nov 02', entries.first.firstRecordAt == '2026-11-02T10:00:00Z');
  assertTest('Last record bound expands to Nov 15', entries.first.lastRecordAt == '2026-11-15T14:30:00Z');

  // Event 3: Different month (October 2026)
  await repository.updatePatientHistoryIndex(
    clinicId: testClinicId,
    patientId: patientId,
    yearMonth: '2026-10',
    recordType: 'appointments',
    recordTimestamp: '2026-10-12T09:00:00Z',
  );

  entries = await repository.getPatientHistoryIndex(
    clinicId: testClinicId,
    patientId: patientId,
  );
  assertTest('Patient has 2 distinct monthly index entries', entries.length == 2);
  assertTest('Index entries sorted newest month first (2026-11 then 2026-10)', entries.first.yearMonth == '2026-11' && entries.last.yearMonth == '2026-10');

  // 4. MonthlySyncCoordinator filters transaction entities and routes multi-month batches
  stdout.writeln('\n--- 4. OUTBOX PARTITIONING & MONTHLY SYNC COORDINATOR ---');
  final coordinator = MonthlySyncCoordinator(localDb: db, repository: repository);

  assertTest('Appointments qualifies for monthly storage', MonthlySyncCoordinator.isMonthlyTransactionEntity('Appointments'));
  assertTest('Visits qualifies for monthly storage', MonthlySyncCoordinator.isMonthlyTransactionEntity('Visits'));
  assertTest('Billing qualifies for monthly storage', MonthlySyncCoordinator.isMonthlyTransactionEntity('Billing'));
  assertTest('Payments qualifies for monthly storage', MonthlySyncCoordinator.isMonthlyTransactionEntity('Payments'));
  assertTest('Queue_Events qualifies for monthly storage', MonthlySyncCoordinator.isMonthlyTransactionEntity('Queue_Events'));
  assertTest('Patients is Master data (not monthly)', !MonthlySyncCoordinator.isMonthlyTransactionEntity('Patients'));
  assertTest('Users is Master data (not monthly)', !MonthlySyncCoordinator.isMonthlyTransactionEntity('Users'));
  assertTest('Settings is Master data (not monthly)', !MonthlySyncCoordinator.isMonthlyTransactionEntity('Settings'));

  // Seed outbox with events spanning 2 months and 1 master entity
  await db.upsert('sync_outbox', 'event_1', {
    'event_id': 'event_1',
    'clinic_id': testClinicId,
    'entity_type': 'Visits',
    'entity_id': 'visit_nov_1',
    'business_date': '2026-11-05T10:00:00Z',
    'status': 'pending',
    'payload': {
      'visit_id': 'visit_nov_1',
      'patient_id': 'pat_101',
      'visit_date': '2026-11-05T10:00:00Z',
    },
  });

  await db.upsert('sync_outbox', 'event_2', {
    'event_id': 'event_2',
    'clinic_id': testClinicId,
    'entity_type': 'Visits',
    'entity_id': 'visit_oct_1',
    'business_date': '2026-10-20T11:00:00Z',
    'status': 'pending',
    'payload': {
      'visit_id': 'visit_oct_1',
      'patient_id': 'pat_101',
      'visit_date': '2026-10-20T11:00:00Z',
    },
  });

  await db.upsert('sync_outbox', 'event_3', {
    'event_id': 'event_3',
    'clinic_id': testClinicId,
    'entity_type': 'Patients', // Master entity: should NOT be touched by monthly coordinator
    'entity_id': 'pat_101',
    'business_date': '2026-11-01T08:00:00Z',
    'status': 'pending',
    'payload': {'patient_id': 'pat_101', 'full_name': 'Ramesh Kumar'},
  });

  final summary = await coordinator.syncPendingMonthlyRecords(
    clinicId: testClinicId,
    clinicDriveFolderId: testFolderId,
    masterSpreadsheetId: testMasterSheetId,
  );

  assertTest('Monthly sync coordinator succeeds', summary.isSuccess);
  assertTest('Total batches created equals 2 (one per month)', summary.totalBatches == 2);
  assertTest('Total operations synced equals 2', summary.totalOperations == 2);
  assertTest('Affected months contains 2026-11 and 2026-10', summary.affectedMonths.contains('2026-11') && summary.affectedMonths.contains('2026-10'));

  final masterEvent = db.get('sync_outbox', 'event_3');
  assertTest('Master entity remains pending for baseline sync engine', masterEvent?['status'] == 'pending');

  final monthlyEvent1 = db.get('sync_outbox', 'event_1');
  assertTest('Monthly transaction event marked synced', monthlyEvent1?['status'] == 'synced');

  // 5. Cross-month PatientHistoryRouter builds unified timeline
  stdout.writeln('\n--- 5. CROSS-MONTH PATIENT HISTORY ROUTER ---');
  final router = PatientHistoryRouter(localDb: db, repository: repository);
  const patTimelineId = 'pat_timeline_99';

  await db.upsert('Visits', 'v_nov', {
    'visit_id': 'v_nov',
    'clinic_id': testClinicId,
    'patient_id': patTimelineId,
    'visit_date': '2026-11-10T11:00:00Z',
    'token_number': '14',
    'doctor_name': 'Dr. Sharma',
    'queue_status': 'COMPLETED',
  });

  await db.upsert('Appointments', 'a_oct', {
    'appointment_id': 'a_oct',
    'clinic_id': testClinicId,
    'patient_id': patTimelineId,
    'appointment_date': '2026-10-15T09:30:00Z',
    'doctor_name': 'Dr. Sharma',
    'status': 'CONFIRMED',
  });

  await repository.updatePatientHistoryIndex(
    clinicId: testClinicId,
    patientId: patTimelineId,
    yearMonth: '2026-11',
    recordType: 'visits',
    recordTimestamp: '2026-11-10T11:00:00Z',
  );

  await repository.updatePatientHistoryIndex(
    clinicId: testClinicId,
    patientId: patTimelineId,
    yearMonth: '2026-10',
    recordType: 'appointments',
    recordTimestamp: '2026-10-15T09:30:00Z',
  );

  final historyResult = await router.getPatientHistory(
    clinicId: testClinicId,
    patientId: patTimelineId,
  );

  assertTest('Patient history returns correct patient ID', historyResult.patientId == patTimelineId);
  assertTest('Patient recordedMonths contains both months in descending order', historyResult.recordedMonths.length == 2 && historyResult.recordedMonths[0] == '2026-11' && historyResult.recordedMonths[1] == '2026-10');
  assertTest('Timeline contains 2 chronological items', historyResult.timeline.length == 2);
  assertTest('First timeline item is November Visit', historyResult.timeline[0].yearMonth == '2026-11' && historyResult.timeline[0].type == 'visit');
  assertTest('Second timeline item is October Appointment', historyResult.timeline[1].yearMonth == '2026-10' && historyResult.timeline[1].type == 'appointment');

  // 6. ReconciliationService repairs missing index entries
  stdout.writeln('\n--- 6. RECONCILIATION SERVICE (Self-Healing Index) ---');
  final reconciliationService = MonthlyStorageReconciliationService(
    localDb: db,
    repository: repository,
  );

  const patReconcileId = 'pat_reconcile_1';

  // Insert a visit without index entry
  await db.upsert('Visits', 'v_unindexed', {
    'visit_id': 'v_unindexed',
    'clinic_id': testClinicId,
    'patient_id': patReconcileId,
    'visit_date': '2026-11-04T12:00:00Z',
  });

  var unindexedList = await repository.getPatientHistoryIndex(
    clinicId: testClinicId,
    patientId: patReconcileId,
  );
  assertTest('Index is initially empty before reconciliation', unindexedList.isEmpty);

  final report = await reconciliationService.reconcilePatientHistoryIndex(
    testClinicId,
  );
  assertTest('Reconciliation report succeeded', report.isClean);
  assertTest('Reconciliation reconciled entries > 0', report.indexEntriesReconciled > 0);

  var reconciledList = await repository.getPatientHistoryIndex(
    clinicId: testClinicId,
    patientId: patReconcileId,
  );
  assertTest('Index populated after reconciliation', reconciledList.isNotEmpty);
  assertTest('Reconciled entry has correct month 2026-11', reconciledList.first.yearMonth == '2026-11');
  assertTest('Reconciled entry has correct recordType', reconciledList.first.recordType == 'visit');

  // 7. Additive Feature Flag toggle allows seamless fallback
  stdout.writeln('\n--- 7. FEATURE FLAG TOGGLE & FALLBACK ---');
  final config = AppConfig.current;
  assertTest('Default config has enableMonthlyStorageRouting defined', config.enableMonthlyStorageRouting == false || config.enableMonthlyStorageRouting == true);

  final customConfig = config.copyWith(enableMonthlyStorageRouting: true);
  assertTest('copyWith enables monthly storage routing cleanly', customConfig.enableMonthlyStorageRouting == true);

  // 8. End-to-End Monthly Transaction Routing via MonthlySyncCoordinator
  stdout.writeln('\n--- 8. END-TO-END MONTHLY PROVISIONING & OUTBOX ROUTING ---');
  AppConfig.current = customConfig;

  const e2eEventId = 'e2e_visit_outbox_001';
  await db.upsert('sync_outbox', e2eEventId, {
    'outbox_event_id': e2eEventId,
    'clinic_id': testClinicId,
    'entity_type': 'Visits',
    'entity_id': 'visit_e2e_1',
    'operation': 'insert',
    'payload_json': '{"visit_id":"visit_e2e_1","patient_id":"pat_e2e","visit_date":"2026-11-05T12:00:00Z","token_number":"99"}',
    'created_at': DateTime.now().toUtc().toIso8601String(),
    'status': 'pending',
  });

  final e2eSummary = await coordinator.syncPendingMonthlyRecords(
    clinicId: testClinicId,
    clinicDriveFolderId: testFolderId,
    masterSpreadsheetId: testMasterSheetId,
    accessToken: 'mock_token_e2e',
  );

  assertTest('Monthly transaction routing succeeded', e2eSummary.isSuccess);
  assertTest('Monthly transaction batch processed', e2eSummary.successfulOperations > 0);

  final e2eOutboxRecord = db.get('sync_outbox', e2eEventId);
  assertTest('Transaction outbox record marked synced by monthly coordinator', e2eOutboxRecord?['status'] == 'synced');

  final registryEntry = db.get('Spreadsheet_Registry', '$testClinicId:2026-11');
  assertTest('Monthly workbook registered in Spreadsheet_Registry', registryEntry != null);
  assertTest('Registered monthly workbook has valid spreadsheet ID', (registryEntry?['spreadsheet_id'] as String? ?? '').isNotEmpty);

  // 9. Exact Canonical Headers & Row Mapping Parity (Feature TRD Section 5.1 & 5.3)
  stdout.writeln('\n--- 9. CANONICAL HEADERS & TRANSACTION ROW PARITY ---');
  final apptHeaders = MasterSheetSchema.canonicalHeaders['06_APPOINTMENTS']!;
  final visitHeaders = MasterSheetSchema.canonicalHeaders['09_CONSULTATIONS']!;
  final billHeaders = MasterSheetSchema.canonicalHeaders['10_BILLING']!;
  final payHeaders = MasterSheetSchema.canonicalHeaders['11_PAYMENTS']!;
  final queueHeaders = MasterSheetSchema.canonicalHeaders['08_QUEUE']!;

  assertTest('Appointments canonical headers has 20 columns', apptHeaders.length == 20);
  assertTest('Visits (Consultations) canonical headers has 15 columns', visitHeaders.length == 15);
  assertTest('Billing canonical headers has 15 columns', billHeaders.length == 15);
  assertTest('Payments canonical headers has 11 columns', payHeaders.length == 11);
  assertTest('Queue_Events canonical headers has 15 columns', queueHeaders.length == 15);

  // Test Appointment row mapping from Appointment.toMap()
  final sampleApptMap = {
    'appointment_id': 'apt_test_001',
    'clinic_id': testClinicId,
    'patient_id': 'pat_test_001',
    'doctor_id': 'doc_test_001',
    'scheduled_start_at': '2026-11-05T09:30:00.000Z',
    'scheduled_end_at': '2026-11-05T09:45:00.000Z',
    'appointment_type': 'new_consultation',
    'booking_source': 'reception',
    'status': 'scheduled',
    'created_by_staff_id': 'staff_01',
    'created_at': '2026-11-05T08:00:00.000Z',
    'updated_at': '2026-11-05T08:00:00.000Z',
  };
  final apptRow = MasterSheetMapper.mapToRow('06_APPOINTMENTS', sampleApptMap);
  assertTest('Appointment mapped row has exact 20 columns', apptRow.length == 20);
  assertTest('Appointment mapped row has extracted appointment_date 2026-11-05', apptRow[4] == '2026-11-05');
  assertTest('Appointment mapped row has extracted start_time 09:30', apptRow[5] == '09:30');
  assertTest('Appointment mapped row has extracted end_time 09:45', apptRow[6] == '09:45');
  assertTest('Appointment mapped row has uppercase status SCHEDULED', apptRow[9] == 'SCHEDULED');

  // Test Appointment outbox routing in MonthlySyncCoordinator
  const apptEventId = 'evt_outbox_appt_test';
  await db.upsert('sync_outbox', apptEventId, {
    'outbox_event_id': apptEventId,
    'clinic_id': testClinicId,
    'entity_type': 'Appointments',
    'entity_id': 'apt_test_001',
    'operation': 'insert',
    'payload_json': '{"appointment_id":"apt_test_001","patient_id":"pat_test_001","doctor_id":"doc_test_001","scheduled_start_at":"2026-11-05T09:30:00Z","scheduled_end_at":"2026-11-05T09:45:00Z","status":"scheduled"}',
    'created_at': DateTime.now().toUtc().toIso8601String(),
    'status': 'pending',
  });

  final apptSyncSummary = await coordinator.syncPendingMonthlyRecords(
    clinicId: testClinicId,
    clinicDriveFolderId: testFolderId,
    masterSpreadsheetId: testMasterSheetId,
    accessToken: 'mock_token_appt',
  );
  assertTest('Appointment monthly routing succeeded', apptSyncSummary.isSuccess);
  final apptOutbox = db.get('sync_outbox', apptEventId);
  assertTest('Appointment outbox marked synced', apptOutbox?['status'] == 'synced');
  assertTest('Appointment target year_month is 2026-11', apptOutbox?['target_year_month'] == '2026-11');

  // Restore config
  AppConfig.current = config;

  stdout.writeln('\n========================================================');
  stdout.writeln('TEST RESULTS: $passed PASSED, $failed FAILED');
  stdout.writeln('========================================================');

  if (failed > 0) {
    exit(1);
  } else {
    exit(0);
  }
}
