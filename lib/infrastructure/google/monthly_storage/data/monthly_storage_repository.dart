// Apna Clinic - Monthly Storage Repository
// Primary source of truth: Feature PRD Section 7 & Feature TRD Section 6, 7, 8

import 'dart:async';
import 'package:uuid/uuid.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../domain/entities/master_sheet_schema.dart';
import '../../../database/local_database.dart';
import '../../google_drive_client.dart';
import '../../google_sheets_client.dart';
import '../../sync/master_sheet_mapper.dart';
import '../domain/month_resolver.dart';
import '../models/month_registry_entry.dart';
import '../models/monthly_storage_response.dart';
import '../models/patient_history_index_entry.dart';
import '../models/sync_batch.dart';
import 'apps_script_client.dart';

class MonthlyStorageRepository {
  final LocalDatabase localDb;
  final GoogleDriveClient driveClient;
  final GoogleSheetsClient sheetsClient;
  final IAppsScriptClient appsScriptClient;

  MonthlyStorageRepository({
    required this.localDb,
    required this.driveClient,
    required this.sheetsClient,
    required this.appsScriptClient,
  });

  /// 1. Resolve Monthly Workbook: Checks Google Drive file first, then provisions if missing
  Future<MonthRegistryEntry> resolveOrCreateMonthlyWorkbook({
    required String clinicId,
    required String yearMonth,
    required String clinicDriveFolderId,
    required String masterSpreadsheetId,
    String? accessToken,
    String createdBy = 'system_sync',
  }) async {
    final compositeKey = '$clinicId:$yearMonth';
    final workbookTitle = MonthResolver.generateMonthlyWorkbookName(clinicId, yearMonth);
    final nowIso = DateTime.now().toUtc().toIso8601String();

    String spreadsheetId = '';

    // A. Check if the actual workbook exists on Google Drive (matches user's Drive file directly)
    if (accessToken != null && accessToken.isNotEmpty && clinicDriveFolderId.isNotEmpty) {
      try {
        final sanitizedMonth = yearMonth.replaceAll('-', '_');
        var existingFile = await driveClient.locateMasterSheetFile(
          accessToken: accessToken,
          parentFolderId: clinicDriveFolderId,
          fileName: workbookTitle,
        );
        if (existingFile == null || existingFile.id.isEmpty) {
          existingFile = await driveClient.locateMasterSheetFile(
            accessToken: accessToken,
            parentFolderId: clinicDriveFolderId,
            fileName: 'Transactions_$sanitizedMonth',
          );
        }
        if (existingFile != null && existingFile.id.isNotEmpty) {
          spreadsheetId = existingFile.id;
          AppLogger.info('Found existing monthly workbook on Drive: $spreadsheetId ($workbookTitle)');
        }
      } catch (e) {
        AppLogger.warning('Locating monthly file on Drive note: $e');
      }
    }

    // B. Check remote master sheet 'Spreadsheet_Registry' if masterSpreadsheetId provided
    if (spreadsheetId.isEmpty &&
        accessToken != null &&
        accessToken.isNotEmpty &&
        masterSpreadsheetId.isNotEmpty) {
      try {
        final batchRows = await sheetsClient.batchReadSheetRows(
          accessToken: accessToken,
          spreadsheetId: masterSpreadsheetId,
          sheetNames: ['Spreadsheet_Registry'],
        );
        final remoteRows = batchRows['Spreadsheet_Registry'] ?? [];
        for (final row in remoteRows) {
          if (row.length >= 3) {
            final rClinic = row[0].toString();
            final rYm = row[1].toString();
            final rId = row[2].toString();
            final isClinicMatch = rClinic == clinicId ||
                (rClinic.contains('primary') && clinicId.contains('primary'));
            if (isClinicMatch && rYm == yearMonth && rId.isNotEmpty) {
              spreadsheetId = rId;
              break;
            }
          }
        }
      } catch (e) {
        AppLogger.warning('Registry lookup on remote sheet encountered note: $e');
      }
    }

    // C. Check local database table 'Spreadsheet_Registry'
    if (spreadsheetId.isEmpty) {
      final localRecord = localDb.get('Spreadsheet_Registry', compositeKey);
      if (localRecord != null && localRecord['spreadsheet_id'] != null) {
        final storedId = localRecord['spreadsheet_id'].toString();
        if (storedId.isNotEmpty && !storedId.startsWith('sheet_monthly_')) {
          spreadsheetId = storedId;
        }
      }
    }

    // D. Provision new monthly workbook if not found (TRD Section 6.2)
    MonthRegistryEntry entry;
    if (spreadsheetId.isEmpty) {
      entry = await provisionMonthlyWorkbook(
        clinicId: clinicId,
        yearMonth: yearMonth,
        clinicDriveFolderId: clinicDriveFolderId,
        masterSpreadsheetId: masterSpreadsheetId,
        accessToken: accessToken,
        createdBy: createdBy,
      );
      spreadsheetId = entry.spreadsheetId;
    } else {
      entry = MonthRegistryEntry(
        clinicId: clinicId,
        yearMonth: yearMonth,
        spreadsheetId: spreadsheetId,
        status: 'ACTIVE',
        schemaVersion: '1.0.0',
        createdAt: nowIso,
        createdBy: createdBy,
        lastVerifiedAt: nowIso,
      );
    }

    // Save in local database
    await localDb.upsert('Spreadsheet_Registry', compositeKey, entry.toMap());

    // E. Auto-heal: Ensure all 5 tabs and canonical 20/15/15/11/15 headers exist on the monthly sheet
    if (accessToken != null && accessToken.isNotEmpty && spreadsheetId.isNotEmpty && !spreadsheetId.startsWith('sheet_monthly_')) {
      try {
        await sheetsClient.ensureSheetsWithHeaders(
          accessToken: accessToken,
          spreadsheetId: spreadsheetId,
          sheetsWithHeaders: {
            'Appointments': MasterSheetSchema.canonicalHeaders['06_APPOINTMENTS']!,
            'Visits': MasterSheetSchema.canonicalHeaders['09_CONSULTATIONS']!,
            'Billing': MasterSheetSchema.canonicalHeaders['10_BILLING']!,
            'Payments': MasterSheetSchema.canonicalHeaders['11_PAYMENTS']!,
            'Queue_Events': MasterSheetSchema.canonicalHeaders['08_QUEUE']!,
          },
        );
      } catch (e) {
        AppLogger.warning('Auto-healing monthly sheet headers note: $e');
      }
    }

    // F. Ensure remote Master Sheet 'Spreadsheet_Registry' has this month registered with correct ID
    if (accessToken != null && accessToken.isNotEmpty && masterSpreadsheetId.isNotEmpty && !spreadsheetId.startsWith('sheet_monthly_')) {
      await _ensureRemoteRegistryUpdated(
        accessToken: accessToken,
        masterSpreadsheetId: masterSpreadsheetId,
        entry: entry,
      );
    }

    return entry;
  }

  /// Ensures that Master Sheet 'Spreadsheet_Registry' contains the active monthly entry
  Future<void> _ensureRemoteRegistryUpdated({
    required String accessToken,
    required String masterSpreadsheetId,
    required MonthRegistryEntry entry,
  }) async {
    if (accessToken.isEmpty || masterSpreadsheetId.isEmpty) return;

    try {
      await sheetsClient.ensureSheetsWithHeaders(
        accessToken: accessToken,
        spreadsheetId: masterSpreadsheetId,
        sheetsWithHeaders: {
          'Spreadsheet_Registry': MasterSheetSchema.spreadsheetRegistryHeaders,
          'Patient_History_Index': MasterSheetSchema.patientHistoryIndexHeaders,
        },
      );

      final batchRows = await sheetsClient.batchReadSheetRows(
        accessToken: accessToken,
        spreadsheetId: masterSpreadsheetId,
        sheetNames: ['Spreadsheet_Registry'],
      );
      final existingRows = batchRows['Spreadsheet_Registry'] ?? [];

      int matchRowIndex = -1;
      bool idMatches = false;

      for (int i = 0; i < existingRows.length; i++) {
        final row = existingRows[i];
        if (row.length >= 3) {
          final rowClinicId = row[0].toString();
          final rowYm = row[1].toString();
          final rowSsId = row[2].toString();

          final isClinicMatch = rowClinicId == entry.clinicId ||
              (rowClinicId.contains('primary') && entry.clinicId.contains('primary'));
          final isSameSheet = (rowSsId == entry.spreadsheetId);
          final isMonthMatch = (isClinicMatch && rowYm == entry.yearMonth);

          if (isSameSheet || isMonthMatch) {
            matchRowIndex = i + 2; // Row number in sheet (1-based, +1 for header)
            idMatches = (rowSsId == entry.spreadsheetId && rowYm == entry.yearMonth && isClinicMatch);
            break;
          }
        }
      }

      if (matchRowIndex != -1 && !idMatches) {
        // Exists with wrong / outdated spreadsheetId: update in-place
        AppLogger.info('Updating remote Spreadsheet_Registry row $matchRowIndex with correct spreadsheetId: ${entry.spreadsheetId}');
        await sheetsClient.batchUpdateRows(
          accessToken: accessToken,
          spreadsheetId: masterSpreadsheetId,
          updates: [
            SheetValueUpdate(
              range: 'Spreadsheet_Registry!A$matchRowIndex',
              values: [entry.toRow()],
            ),
          ],
        );
      } else if (matchRowIndex == -1) {
        // Not present in remote Master Sheet: write to next available row near top
        final targetRow = 2 + existingRows.where((r) => r.isNotEmpty && r[0].toString().trim().isNotEmpty).length;
        AppLogger.info('Writing ${entry.yearMonth} (${entry.spreadsheetId}) to remote Spreadsheet_Registry at row $targetRow');
        await sheetsClient.batchUpdateRows(
          accessToken: accessToken,
          spreadsheetId: masterSpreadsheetId,
          updates: [
            SheetValueUpdate(
              range: 'Spreadsheet_Registry!A$targetRow',
              values: [entry.toRow()],
            ),
          ],
        );
      }
    } catch (e) {
      AppLogger.warning('Ensuring remote Spreadsheet_Registry sync note: $e');
    }
  }

  /// 2. Provision New Monthly Workbook with versioned canonical transaction sheets
  Future<MonthRegistryEntry> provisionMonthlyWorkbook({
    required String clinicId,
    required String yearMonth,
    required String clinicDriveFolderId,
    required String masterSpreadsheetId,
    String? accessToken,
    String createdBy = 'system_sync',
  }) async {
    final compositeKey = '$clinicId:$yearMonth';
    final workbookTitle = MonthResolver.generateMonthlyWorkbookName(clinicId, yearMonth);
    final nowIso = DateTime.now().toUtc().toIso8601String();

    AppLogger.info('Provisioning Monthly Workbook: $workbookTitle for $yearMonth');

    String spreadsheetId = '';

    if (accessToken != null && accessToken.isNotEmpty) {
      try {
        final transactionTabs = {
          'Appointments': _getCanonicalHeadersForTab('Appointments'),
          'Visits': _getCanonicalHeadersForTab('Visits'),
          'Billing': _getCanonicalHeadersForTab('Billing'),
          'Payments': _getCanonicalHeadersForTab('Payments'),
          'Queue_Events': _getCanonicalHeadersForTab('Queue_Events'),
        };

        // Check if workbook file already exists in clinic Drive folder
        if (clinicDriveFolderId.isNotEmpty) {
          try {
            final sanitizedMonth = yearMonth.replaceAll('-', '_');
            var existingFile = await driveClient.locateMasterSheetFile(
              accessToken: accessToken,
              parentFolderId: clinicDriveFolderId,
              fileName: workbookTitle,
            );
            if (existingFile == null || existingFile.id.isEmpty) {
              existingFile = await driveClient.locateMasterSheetFile(
                accessToken: accessToken,
                parentFolderId: clinicDriveFolderId,
                fileName: 'Transactions_$sanitizedMonth',
              );
            }
            if (existingFile != null && existingFile.id.isNotEmpty) {
              spreadsheetId = existingFile.id;
              AppLogger.info('Found existing monthly workbook on Drive: $spreadsheetId ($workbookTitle)');
            }
          } catch (_) {}
        }

        // Create spreadsheet with all canonical transaction sheets atomically
        if (spreadsheetId.isEmpty) {
          AppLogger.info('Creating new monthly workbook: $workbookTitle');
          spreadsheetId = await sheetsClient.createSpreadsheetWithSheets(
            accessToken: accessToken,
            title: workbookTitle,
            sheetsWithHeaders: transactionTabs,
          );

          if (clinicDriveFolderId.isNotEmpty) {
            try {
              await driveClient.moveFileToFolder(
                accessToken: accessToken,
                fileId: spreadsheetId,
                targetFolderId: clinicDriveFolderId,
              );
            } catch (e) {
              AppLogger.warning('Could not move monthly sheet into folder $clinicDriveFolderId: $e');
            }
          }
        }

        // Ensure sheets exist in case existing spreadsheet was missing any
        try {
          await sheetsClient.ensureSheetsWithHeaders(
            accessToken: accessToken,
            spreadsheetId: spreadsheetId,
            sheetsWithHeaders: transactionTabs,
          );
        } catch (_) {}

        // Register in Master Sheet 'Spreadsheet_Registry' tab
        if (masterSpreadsheetId.isNotEmpty && spreadsheetId.isNotEmpty) {
          try {
            final provisionedEntry = MonthRegistryEntry(
              clinicId: clinicId,
              yearMonth: yearMonth,
              spreadsheetId: spreadsheetId,
              status: 'ACTIVE',
              schemaVersion: '1.0.0',
              createdAt: nowIso,
              createdBy: createdBy,
              lastVerifiedAt: nowIso,
            );
            await _ensureRemoteRegistryUpdated(
              accessToken: accessToken,
              masterSpreadsheetId: masterSpreadsheetId,
              entry: provisionedEntry,
            );
          } catch (e) {
            AppLogger.warning('Registering monthly sheet in Spreadsheet_Registry: $e');
          }
        }
      } catch (e) {
        AppLogger.error('Failed to provision remote workbook: $e');
        spreadsheetId = 'sheet_monthly_${clinicId}_${yearMonth.replaceAll('-', '_')}';
      }
    } else {
      // Mock / Offline deterministic spreadsheet ID
      spreadsheetId = 'sheet_monthly_${clinicId}_${yearMonth.replaceAll('-', '_')}';
    }

    final entry = MonthRegistryEntry(
      clinicId: clinicId,
      yearMonth: yearMonth,
      spreadsheetId: spreadsheetId,
      status: 'ACTIVE',
      schemaVersion: '1.0.0',
      createdAt: nowIso,
      createdBy: createdBy,
      lastVerifiedAt: nowIso,
    );

    // Save in local database
    await localDb.upsert('Spreadsheet_Registry', compositeKey, entry.toMap());

    return entry;
  }

  /// 3. Updates Patient History Index in local DB and Master Sheet
  Future<void> updatePatientHistoryIndex({
    required String clinicId,
    required String patientId,
    required String yearMonth,
    required String recordType,
    required String recordTimestamp,
    String? masterSpreadsheetId,
    String? accessToken,
  }) async {
    final compositeKey = '$clinicId:$patientId:$yearMonth:$recordType';
    final existing = localDb.get('Patient_History_Index', compositeKey);

    PatientHistoryIndexEntry updated;
    if (existing != null) {
      final current = PatientHistoryIndexEntry.fromMap(existing);
      final count = current.recordCount + 1;
      final first = current.firstRecordAt.compareTo(recordTimestamp) < 0
          ? current.firstRecordAt
          : recordTimestamp;
      final last = current.lastRecordAt.compareTo(recordTimestamp) > 0
          ? current.lastRecordAt
          : recordTimestamp;

      updated = current.copyWith(
        recordCount: count,
        firstRecordAt: first,
        lastRecordAt: last,
        lastUpdatedAt: DateTime.now().toUtc().toIso8601String(),
      );
    } else {
      updated = PatientHistoryIndexEntry(
        clinicId: clinicId,
        patientId: patientId,
        yearMonth: yearMonth,
        recordType: recordType,
        firstRecordAt: recordTimestamp,
        lastRecordAt: recordTimestamp,
        recordCount: 1,
        lastUpdatedAt: DateTime.now().toUtc().toIso8601String(),
      );
    }

    // Save in local database
    await localDb.upsert('Patient_History_Index', compositeKey, updated.toMap());

    // Sync to Master Sheet 'Patient_History_Index' tab if connected
    if (accessToken != null &&
        accessToken.isNotEmpty &&
        masterSpreadsheetId != null &&
        masterSpreadsheetId.isNotEmpty) {
      try {
        await sheetsClient.ensureSheetsWithHeaders(
          accessToken: accessToken,
          spreadsheetId: masterSpreadsheetId,
          sheetsWithHeaders: {
            'Patient_History_Index': [
              'clinic_id',
              'patient_id',
              'year_month',
              'record_type',
              'first_record_at',
              'last_record_at',
              'record_count',
              'last_updated_at',
            ],
          },
        );
        await sheetsClient.batchAppendRows(
          accessToken: accessToken,
          spreadsheetId: masterSpreadsheetId,
          sheetName: 'Patient_History_Index',
          rows: [updated.toRow()],
        );
      } catch (_) {}
    }
  }

  /// 4. Query all months and record types for a patient
  Future<List<PatientHistoryIndexEntry>> getPatientHistoryIndex({
    required String clinicId,
    required String patientId,
  }) async {
    final allRecords = localDb.query('Patient_History_Index');
    final patientEntries = allRecords
        .where((r) => r['clinic_id'] == clinicId && r['patient_id'] == patientId)
        .map((r) => PatientHistoryIndexEntry.fromMap(r))
        .toList();

    // Sort chronologically descending (newest month first)
    patientEntries.sort((a, b) => b.yearMonth.compareTo(a.yearMonth));
    return patientEntries;
  }

  /// 5. Writes a monthly sync batch directly to monthly workbook
  Future<MonthlyStorageResponse> syncBatch({
    required MonthlySyncBatch batch,
    required String masterSpreadsheetId,
    required String clinicDriveFolderId,
    String? accessToken,
  }) async {
    final requestId = const Uuid().v4();

    // Check if Apps Script endpoint is available
    if (appsScriptClient is AppsScriptClient &&
        (appsScriptClient as AppsScriptClient).endpointUrl.isNotEmpty) {
      final request = MonthlyStorageRequest(
        action: 'monthlyStorage.syncBatch',
        requestId: requestId,
        clinicId: batch.clinicId,
        idempotencyKey: batch.batchId,
        payload: batch.toMap(),
      );
      return await appsScriptClient.executeAction(request, accessToken: accessToken);
    }

    // Direct / Local Client Execution (authoritative fallback)
    try {
      final monthEntry = await resolveOrCreateMonthlyWorkbook(
        clinicId: batch.clinicId,
        yearMonth: batch.yearMonth,
        clinicDriveFolderId: clinicDriveFolderId,
        masterSpreadsheetId: masterSpreadsheetId,
        accessToken: accessToken,
      );

      final results = <MonthlyOperationResult>[];

      // Canonical 5 monthly transaction tabs
      const canonicalTabs = ['Appointments', 'Visits', 'Billing', 'Payments', 'Queue_Events'];

      // Group operations by destination tab
      final opsByTab = <String, List<MonthlySyncOperation>>{};
      for (final op in batch.operations) {
        final tabName = _resolveDestinationTab(op.entityType);
        opsByTab.putIfAbsent(tabName, () => []).add(op);
      }

      // Ensure all 5 canonical tabs are checked during sync
      for (final tab in canonicalTabs) {
        opsByTab.putIfAbsent(tab, () => []);
      }

      for (final entry in opsByTab.entries) {
        final tabName = entry.key;
        var ops = List<MonthlySyncOperation>.from(entry.value);

        // Fetch remote existing primary keys from Column A for idempotency
        List<String> remoteExistingIds = [];
        if (accessToken != null && accessToken.isNotEmpty) {
          try {
            remoteExistingIds = await sheetsClient.readSheetColumn(
              accessToken: accessToken,
              spreadsheetId: monthEntry.spreadsheetId,
              sheetName: tabName,
              startRow: 2,
              endRow: 100,
            );
          } catch (_) {}
        }

        final nonEmptyTopIds = remoteExistingIds.where((id) => id.trim().isNotEmpty).toList();

        // Self-heal blank Appointments tab: If rows 2 to 10 are empty, wipe ghost rows at row 1001 and rewrite from local database
        if (tabName == 'Appointments' && nonEmptyTopIds.isEmpty && accessToken != null && accessToken.isNotEmpty) {
          AppLogger.info('Detected empty top rows in Appointments tab. Clearing range and staging local appointments.');
          try {
            await sheetsClient.clearSheetRange(
              accessToken: accessToken,
              spreadsheetId: monthEntry.spreadsheetId,
              range: 'Appointments!A2:T2000',
            );
            remoteExistingIds.clear();
          } catch (e) {
            AppLogger.warning('Could not clear Appointments rows: $e');
          }

          if (ops.isEmpty) {
            final localAppts = localDb.query('Appointments');
            for (final a in localAppts) {
              final aId = (a['appointment_id'] ?? '').toString();
              if (aId.isNotEmpty) {
                ops.add(MonthlySyncOperation(
                  operationId: 'op_appt_$aId',
                  idempotencyKey: 'op_Appointments_${aId}_${batch.yearMonth}',
                  entityType: 'Appointments',
                  entityId: aId,
                  action: 'insert',
                  businessDate: a['scheduled_start_at']?.toString() ?? a['appointment_date']?.toString() ?? DateTime.now().toIso8601String(),
                  yearMonth: batch.yearMonth,
                  patientId: a['patient_id']?.toString(),
                  payload: a,
                ));
              }
            }
          }
        }

        // Self-heal corrupted or duplicate Queue_Events rows in remote sheet
        if (tabName == 'Queue_Events' && accessToken != null && accessToken.isNotEmpty) {
          final hasDuplicates = nonEmptyTopIds.toSet().length < nonEmptyTopIds.length;
          final hasMalformedIds = nonEmptyTopIds.any((id) => !id.startsWith('qevt_'));
          final isTopEmpty = nonEmptyTopIds.isEmpty;

          if (hasDuplicates || hasMalformedIds || isTopEmpty) {
            AppLogger.info('Self-healing Queue_Events tab (duplicates=$hasDuplicates, malformed=$hasMalformedIds, empty=$isTopEmpty). Rewriting clean rows.');
            try {
              await sheetsClient.clearSheetRange(
                accessToken: accessToken,
                spreadsheetId: monthEntry.spreadsheetId,
                range: 'Queue_Events!A2:O2000',
              );
              remoteExistingIds.clear();
            } catch (e) {
              AppLogger.warning('Could not clear dirty Queue_Events rows: $e');
            }

            if (ops.isEmpty || hasMalformedIds || hasDuplicates) {
              ops.clear();
              final localVisits = localDb.query('Visits');
              for (final v in localVisits) {
                final vId = (v['visit_id'] ?? '').toString();
                if (vId.isNotEmpty) {
                  final qevtId = 'qevt_${vId}_1';
                  ops.add(MonthlySyncOperation(
                    operationId: 'op_qevt_$qevtId',
                    idempotencyKey: 'op_Queue_Events_${qevtId}_${batch.yearMonth}',
                    entityType: 'Queue_Events',
                    entityId: qevtId,
                    action: 'insert',
                    businessDate: v['visit_date_local']?.toString() ?? v['created_at']?.toString() ?? DateTime.now().toIso8601String(),
                    yearMonth: batch.yearMonth,
                    patientId: v['patient_id']?.toString(),
                    payload: {
                      'queue_id': qevtId,
                      'queue_event_id': qevtId,
                      'clinic_id': batch.clinicId,
                      'visit_id': vId,
                      'doctor_id': v['doctor_id'] ?? 'doc_primary_01',
                      'patient_id': v['patient_id'] ?? '',
                      'appointment_id': v['appointment_id'] ?? '',
                      'token_number': v['token_number'] ?? '1',
                      'queue_date': v['visit_date_local'] ?? v['created_at']?.toString().split('T').first ?? DateTime.now().toIso8601String().split('T').first,
                      'check_in_time': v['checkin_at'] ?? v['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
                      'called_time': v['called_at'] ?? '',
                      'consultation_start_time': v['consultation_started_at'] ?? '',
                      'consultation_end_time': v['consultation_completed_at'] ?? '',
                      'queue_status': v['queue_status'] ?? 'WAITING',
                      'priority': v['priority'] ?? 'NORMAL',
                      'room_id': v['room_id'] ?? 'ROOM-01',
                      'created_at': v['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
                      'updated_at': v['updated_at'] ?? v['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
                    },
                  ));
                }
              }
            }
          }
        }

        // Self-heal Visits if top is empty
        if (tabName == 'Visits' && nonEmptyTopIds.isEmpty && ops.isEmpty) {
          final localVisits = localDb.query('Visits');
          for (final v in localVisits) {
            final vId = (v['visit_id'] ?? '').toString();
            if (vId.isNotEmpty) {
              ops.add(MonthlySyncOperation(
                operationId: 'op_visit_$vId',
                idempotencyKey: 'op_Visits_${vId}_${batch.yearMonth}',
                entityType: 'Visits',
                entityId: vId,
                action: 'insert',
                businessDate: v['visit_date_local']?.toString() ?? DateTime.now().toIso8601String(),
                yearMonth: batch.yearMonth,
                patientId: v['patient_id']?.toString(),
                payload: v,
              ));
            }
          }
        }

        // Self-heal Billing if top is empty
        if (tabName == 'Billing' && nonEmptyTopIds.isEmpty && ops.isEmpty) {
          final localInvoices = localDb.query('Invoices');
          for (final inv in localInvoices) {
            final invId = (inv['invoice_id'] ?? '').toString();
            if (invId.isNotEmpty) {
              ops.add(MonthlySyncOperation(
                operationId: 'op_inv_$invId',
                idempotencyKey: 'op_Billing_${invId}_${batch.yearMonth}',
                entityType: 'Billing',
                entityId: invId,
                action: 'insert',
                businessDate: inv['issue_date_local']?.toString() ?? DateTime.now().toIso8601String(),
                yearMonth: batch.yearMonth,
                patientId: inv['patient_id']?.toString(),
                payload: inv,
              ));
            }
          }
        }

        // Self-heal Payments if top is empty
        if (tabName == 'Payments' && nonEmptyTopIds.isEmpty && ops.isEmpty) {
          final localPayments = localDb.query('Payments');
          for (final p in localPayments) {
            final pId = (p['payment_id'] ?? '').toString();
            if (pId.isNotEmpty) {
              ops.add(MonthlySyncOperation(
                operationId: 'op_pay_$pId',
                idempotencyKey: 'op_Payments_${pId}_${batch.yearMonth}',
                entityType: 'Payments',
                entityId: pId,
                action: 'insert',
                businessDate: p['paid_at']?.toString() ?? DateTime.now().toIso8601String(),
                yearMonth: batch.yearMonth,
                payload: p,
              ));
            }
          }
        }

        final rowsToWrite = <List<dynamic>>[];
        for (final op in ops) {
          // Update Patient History Index if patientId is present
          if (op.patientId != null && op.patientId!.isNotEmpty) {
            await updatePatientHistoryIndex(
              clinicId: batch.clinicId,
              patientId: op.patientId!,
              yearMonth: batch.yearMonth,
              recordType: op.entityType.toLowerCase(),
              recordTimestamp: op.businessDate,
              masterSpreadsheetId: masterSpreadsheetId,
              accessToken: accessToken,
            );
          }

          final cleanQId = op.payload['queue_id'] ?? op.payload['queue_event_id'] ?? op.entityId;
          final isAlreadyPresent = remoteExistingIds.contains(op.entityId) ||
              remoteExistingIds.contains(cleanQId.toString());

          if (isAlreadyPresent) {
            // Already present in remote monthly sheet, skip appending to ensure idempotency
            results.add(MonthlyOperationResult(
              operationId: op.operationId,
              entityId: op.entityId,
              success: true,
              status: 'COMMITTED',
              targetSpreadsheetId: monthEntry.spreadsheetId,
              targetSheetName: tabName,
            ));
            continue;
          }

          final row = MasterSheetMapper.mapToRow(
            MasterSheetMapper.resolveSheetName(op.entityType),
            op.payload,
          );
          rowsToWrite.add(row);

          results.add(MonthlyOperationResult(
            operationId: op.operationId,
            entityId: op.entityId,
            success: true,
            status: 'COMMITTED',
            targetSpreadsheetId: monthEntry.spreadsheetId,
            targetSheetName: tabName,
          ));
        }

        if (accessToken != null && accessToken.isNotEmpty && rowsToWrite.isNotEmpty) {
          try {
            final targetStartRow = 2 + remoteExistingIds.where((id) => id.trim().isNotEmpty).length;
            AppLogger.info('Writing ${rowsToWrite.length} rows to $tabName starting at Row $targetStartRow');
            await sheetsClient.batchUpdateRows(
              accessToken: accessToken,
              spreadsheetId: monthEntry.spreadsheetId,
              updates: [
                SheetValueUpdate(
                  range: '$tabName!A$targetStartRow',
                  values: rowsToWrite,
                ),
              ],
            );
          } catch (e) {
            AppLogger.warning('Direct batch update to $tabName failed, falling back to batchAppendRows: $e');
            try {
              await sheetsClient.batchAppendRows(
                accessToken: accessToken,
                spreadsheetId: monthEntry.spreadsheetId,
                sheetName: tabName,
                rows: rowsToWrite,
              );
            } catch (appendErr) {
              AppLogger.warning('Direct monthly append to $tabName note: $appendErr');
              for (final op in ops) {
                results.removeWhere((r) => r.operationId == op.operationId);
                results.add(MonthlyOperationResult(
                  operationId: op.operationId,
                  entityId: op.entityId,
                  success: false,
                  status: 'FAILED',
                  errorMessage: 'Failed to write to $tabName: $appendErr',
                  targetSpreadsheetId: monthEntry.spreadsheetId,
                  targetSheetName: tabName,
                ));
              }
            }
          }
        }
      }

      final hasFailures = results.any((r) => !r.success);
      return MonthlyStorageResponse(
        requestId: requestId,
        ok: !hasFailures,
        errorCode: hasFailures ? 'APPEND_FAILED' : null,
        errorMessage: hasFailures ? 'One or more tabs failed to append rows.' : null,
        data: {
          'batchId': batch.batchId,
          'yearMonth': batch.yearMonth,
          'spreadsheetId': monthEntry.spreadsheetId,
          'results': results.map((r) => r.toMap()).toList(),
        },
      );
    } catch (e) {
      return MonthlyStorageResponse.failure(
        requestId: requestId,
        errorCode: 'SYNC_ERROR',
        errorMessage: 'Failed to sync monthly batch: $e',
      );
    }
  }

  static String _resolveDestinationTab(String entityType) {
    switch (entityType.toLowerCase()) {
      case 'appointments':
      case '06_appointments':
        return 'Appointments';
      case 'visits':
      case 'consultations':
      case '09_consultations':
        return 'Visits';
      case 'invoices':
      case 'billing':
      case '10_billing':
        return 'Billing';
      case 'payments':
      case '11_payments':
        return 'Payments';
      case 'queue_events':
      case '08_queue':
        return 'Queue_Events';
      default:
        return entityType;
    }
  }

  static List<String> _getCanonicalHeadersForTab(String tabName) {
    switch (tabName) {
      case 'Appointments':
        return MasterSheetSchema.canonicalHeaders['06_APPOINTMENTS']!;
      case 'Visits':
        return MasterSheetSchema.canonicalHeaders['09_CONSULTATIONS']!;
      case 'Billing':
        return MasterSheetSchema.canonicalHeaders['10_BILLING']!;
      case 'Payments':
        return MasterSheetSchema.canonicalHeaders['11_PAYMENTS']!;
      case 'Queue_Events':
        return MasterSheetSchema.canonicalHeaders['08_QUEUE']!;
      default:
        return MasterSheetSchema.canonicalHeaders[tabName] ?? [];
    }
  }
}

