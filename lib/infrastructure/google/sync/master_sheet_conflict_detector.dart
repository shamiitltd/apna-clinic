// Apna Clinic - Controlled Two-Way Conflict & Change Detector
// Phase 3 — Milestone 4
// Primary source of truth: Milestone 4 User Request, PRD Section 38-41, TRD Section 11
// Invariants:
// 1. Two-way detection does NOT mean allowing Google Sheets to overwrite local data.
// 2. The LOCAL DATABASE remains the operational source of truth.
// 3. Clinical Data Rule: For sensitive entities (PATIENTS, CONSULTATIONS, MEDICAL_RECORDS,
//    PRESCRIPTIONS, BILLING, PAYMENTS), NEVER automatically overwrite local data.
//    Mark divergences as CONFLICT and record for controlled review.
// 4. Exhaustive classification: SYNCED, LOCAL_ONLY, REMOTE_ONLY, LOCAL_MODIFIED,
//    REMOTE_MODIFIED, CONFLICT, REMOTE_DELETED, LOCAL_DELETED, SCHEMA_MISMATCH,
//    AUTH_REQUIRED, SYNC_ERROR.

import 'dart:math';

import '../../../application/auth/auth_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../core/logging/app_logger.dart';
import '../../../domain/entities/entities.dart';
import '../../database/local_database.dart';
import '../../repositories/sync_repository.dart';
import '../google_drive_client.dart';
import '../google_sheets_client.dart';
import 'master_sheet_mapper.dart';

class MasterSheetConflictDetector {
  final GoogleDriveClient driveClient;
  final GoogleSheetsClient sheetsClient;
  final LocalDatabase localDb;
  final SyncRepository syncRepository;
  final AuthService authService;

  MasterSheetConflictDetector({
    required this.driveClient,
    required this.sheetsClient,
    required this.localDb,
    required this.syncRepository,
    required this.authService,
  });

  /// Check whether an entity type / sheet corresponds to sensitive clinical data
  static bool isSensitiveClinicalEntity(String sheetName) {
    final s = sheetName.toUpperCase();
    return s.contains('05_PATIENTS') ||
        s.contains('PATIENTS') ||
        s.contains('09_CONSULTATIONS') ||
        s.contains('CONSULTATIONS') ||
        s.contains('10_BILLING') ||
        s.contains('BILLING') ||
        s.contains('INVOICES') ||
        s.contains('11_PAYMENTS') ||
        s.contains('PAYMENTS') ||
        s.contains('13_MEDICAL_RECORDS') ||
        s.contains('14_PRESCRIPTIONS');
  }

  /// Maps a canonical sheet name to local table name
  static String resolveLocalTableName(String sheetName) {
    switch (sheetName) {
      case '01_SETTINGS':
        return 'Clinic_Config';
      case '02_USERS':
      case '03_ROLES':
        return 'Staff';
      case '04_DOCTORS':
      case '07_DOCTOR_SCHEDULES':
        return 'Doctors';
      case '05_PATIENTS':
        return 'Patients';
      case '06_APPOINTMENTS':
        return 'Appointments';
      case '08_QUEUE':
        return 'Queue_Events';
      case '09_CONSULTATIONS':
      case '13_MEDICAL_RECORDS':
      case '14_PRESCRIPTIONS':
        return 'Visits';
      case '10_BILLING':
        return 'Invoices';
      case '11_PAYMENTS':
        return 'Payments';
      case '12_SERVICES':
        return 'Fee_Catalog';
      case '15_FOLLOW_UPS':
        return 'Followups';
      case '16_ROOMS':
        return 'Clinic_Config';
      case '17_AUDIT_LOG':
      case '18_NOTIFICATIONS':
        return 'Audit_Events';
      case '19_REPORTING':
        return 'Daily_Summary';
      case '20_LOOKUPS':
        return 'Lookup_Config';
      default:
        return 'Patients';
    }
  }

  /// Extracts the Primary Key field name for local records
  static String getLocalPkField(String localTable) {
    switch (localTable) {
      case 'Clinic_Config':
        return 'setting_id';
      case 'Staff':
        return 'staff_id';
      case 'Doctors':
        return 'doctor_id';
      case 'Patients':
        return 'patient_id';
      case 'Appointments':
        return 'appointment_id';
      case 'Visits':
        return 'visit_id';
      case 'Queue_Events':
        return 'queue_event_id';
      case 'Invoices':
        return 'invoice_id';
      case 'Payments':
        return 'payment_id';
      case 'Fee_Catalog':
        return 'service_id';
      case 'Followups':
        return 'followup_id';
      case 'Audit_Events':
        return 'audit_event_id';
      case 'Daily_Summary':
        return 'summary_id';
      case 'Lookup_Config':
        return 'lookup_id';
      default:
        return 'id';
    }
  }

  /// Safe, non-destructive two-way change and conflict detection pass for a given worksheet.
  /// Does NOT write changes to local clinical tables.
  Future<ChangeDetectionResult> detectChanges({
    required String clinicId,
    required String sheetName,
    String? explicitSpreadsheetId,
    String? explicitAccessToken,
    Map<String, String>? simulatedLastSyncedChecksums,
  }) async {
    final inspectedAt = DateTime.now().toUtc();
    final canonicalSheet = MasterSheetMapper.resolveSheetName(sheetName);

    try {
      // 1. Authenticate & Verify Token
      final accessToken =
          explicitAccessToken ??
          await authService.getValidAccessToken(clinicId: clinicId);

      if (accessToken == null || accessToken.trim().isEmpty) {
        return ChangeDetectionResult.failure(
          clinicId: clinicId,
          targetWorksheet: canonicalSheet,
          errorCode: 'AUTH_REQUIRED',
          errorMessage: 'Valid Google OAuth access token is required for change detection.',
        );
      }

      // 2. Resolve Master Sheet Spreadsheet ID
      String spreadsheetId = explicitSpreadsheetId ?? '';
      if (spreadsheetId.isEmpty) {
        final rootFolderId = await driveClient.getOrCreateFolder(
          accessToken: accessToken,
          folderName: AppConstants.driveRootFolder,
        );
        final cleanClinicFolder = clinicId.startsWith('clinic_')
            ? clinicId
            : 'clinic_$clinicId';
        final clinicFolderId = await driveClient.getOrCreateFolder(
          accessToken: accessToken,
          folderName: cleanClinicFolder,
          parentFolderId: rootFolderId,
        );
        final fileMeta =
            await driveClient.locateMasterSheetFile(
              accessToken: accessToken,
              parentFolderId: clinicFolderId,
              fileName: 'ApnaClinic_MasterData',
            ) ??
            await driveClient.locateMasterSheetFile(
              accessToken: accessToken,
              parentFolderId: rootFolderId,
              fileName: 'ApnaClinic_MasterData',
            ) ??
            await driveClient.locateMasterSheetFile(
              accessToken: accessToken,
              parentFolderId: clinicFolderId,
              fileName: 'APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL',
            ) ??
            await driveClient.findAnyMasterSheetFile(accessToken: accessToken);
        if (fileMeta == null) {
          return ChangeDetectionResult.failure(
            clinicId: clinicId,
            targetWorksheet: canonicalSheet,
            errorCode: 'MASTER_SHEET_NOT_FOUND',
            errorMessage: 'Master Sheet template not located on Google Drive.',
          );
        }
        spreadsheetId = fileMeta.id;
      }

      // 3. Pre-Flight Canonical Schema Validation Gate
      final validationResult = await sheetsClient.validateMasterSheetSchema(
        accessToken: accessToken,
        spreadsheetId: spreadsheetId,
      );

      if (!validationResult.isValid) {
        final errCode = validationResult.errorCode;
        if (errCode == 'AUTH_ERROR' || errCode == 'AUTH_FAILURE') {
          return ChangeDetectionResult.failure(
            clinicId: clinicId,
            targetWorksheet: canonicalSheet,
            errorCode: 'AUTH_REQUIRED',
            errorMessage:
                validationResult.errorMessage ??
                'Google authentication required.',
          );
        }
        if (errCode == 'NETWORK_ERROR' ||
            errCode == 'RATE_LIMIT' ||
            errCode == 'SHEETS_API_ERROR') {
          return ChangeDetectionResult.failure(
            clinicId: clinicId,
            targetWorksheet: canonicalSheet,
            errorCode: 'SYNC_ERROR',
            errorMessage:
                validationResult.errorMessage ?? 'Network or rate limit error.',
          );
        }
        return ChangeDetectionResult.failure(
          clinicId: clinicId,
          targetWorksheet: canonicalSheet,
          errorCode: 'SCHEMA_MISMATCH',
          errorMessage:
              validationResult.errorMessage ??
              'Canonical schema mismatch detected.',
        );
      }

      // 4. Batch Read Remote Rows for Target Worksheet
      final remoteRowsMap = await sheetsClient.batchReadSheetRows(
        accessToken: accessToken,
        spreadsheetId: spreadsheetId,
        sheetNames: [canonicalSheet],
        startRow: 2,
        endRow: 1000,
      );

      final remoteRows = remoteRowsMap[canonicalSheet] ?? [];

      // 5. Read Local Records
      final localTable = resolveLocalTableName(canonicalSheet);
      final pkField = getLocalPkField(localTable);

      final localRecords = localDb.query(
        localTable,
        where: (r) => (r['clinic_id'] == null || r['clinic_id'] == clinicId),
      );

      // Build maps indexed by entity ID
      final localById = <String, Map<String, dynamic>>{};
      for (final r in localRecords) {
        final id = (r[pkField] ?? r['id'])?.toString().trim();
        if (id != null && id.isNotEmpty) {
          localById[id] = r;
        }
      }

      final remoteById = <String, List<dynamic>>{};
      for (int i = 0; i < remoteRows.length; i++) {
        final row = remoteRows[i];
        if (row.isNotEmpty) {
          final id = row[0].toString().trim();
          if (id.isNotEmpty) {
            remoteById[id] = row;
          }
        }
      }

      // 6. Retrieve Last Synced State
      final knownSyncedChecksums = simulatedLastSyncedChecksums ?? {};

      // 7. Calculate Deterministic Checksums and Classify
      final allEntityIds = <String>{
        ...localById.keys,
        ...remoteById.keys,
        ...knownSyncedChecksums.keys,
      };
      final classifiedItems = <ClassifiedChangeItem>[];

      for (final id in allEntityIds) {
        final localRec = localById[id];
        final remoteRow = remoteById[id];
        final lastSyncedChecksum = knownSyncedChecksums[id];

        final hasLocal = localRec != null;
        final hasRemote = remoteRow != null;
        final hadPriorSync =
            lastSyncedChecksum != null && lastSyncedChecksum.isNotEmpty;

        // Calculate checksums
        String localChecksum = '';
        if (hasLocal) {
          // Canonicalize local record into row columns to ensure exact parity with sheet data
          final canonicalLocalRow = MasterSheetMapper.mapToRow(
            canonicalSheet,
            localRec,
          );
          localChecksum = ChecksumCalculator.fromRow(canonicalLocalRow);
        }

        String remoteChecksum = '';
        if (hasRemote) {
          remoteChecksum = ChecksumCalculator.fromRow(remoteRow);
        }

        final localVerRef =
            localRec?['updated_at']?.toString() ??
            localRec?['created_at']?.toString();
        final remoteVerRef = hasRemote
            ? 'row_${remoteRows.indexOf(remoteRow) + 2}'
            : null;

        ConflictClassification classification;

        if (hasLocal && !hasRemote) {
          if (hadPriorSync) {
            // Existed in sync before, now missing remotely
            classification = ConflictClassification.remoteDeleted;
          } else {
            // Brand new local record not yet synced
            classification = ConflictClassification.localOnly;
          }
        } else if (!hasLocal && hasRemote) {
          if (hadPriorSync) {
            // Existed in sync before, now deleted locally
            classification = ConflictClassification.localDeleted;
          } else {
            // Record exists remotely but not locally
            classification = ConflictClassification.remoteOnly;
          }
        } else if (hasLocal && hasRemote) {
          if (localChecksum == remoteChecksum) {
            classification = ConflictClassification.synced;
          } else {
            // Data differs between local and remote
            if (hadPriorSync) {
              final localChanged = localChecksum != lastSyncedChecksum;
              final remoteChanged = remoteChecksum != lastSyncedChecksum;

              if (localChanged && !remoteChanged) {
                classification = ConflictClassification.localModified;
              } else if (!localChanged && remoteChanged) {
                // Remote modified!
                // Critical Clinical Data Rule: sensitive clinical data must NEVER automatically overwrite!
                if (isSensitiveClinicalEntity(canonicalSheet)) {
                  classification = ConflictClassification.conflict;
                } else {
                  classification = ConflictClassification.remoteModified;
                }
              } else {
                // Both modified!
                classification = ConflictClassification.conflict;
              }
            } else {
              // No prior sync baseline recorded and checksums differ
              classification = ConflictClassification.conflict;
            }
          }
        } else {
          // Neither exists currently but was in prior sync
          classification = ConflictClassification.remoteDeleted;
        }

        // If conflict detected, record in sync_conflicts store
        if (classification == ConflictClassification.conflict) {
          final conflictId =
              'conf_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
          final conflictRecord = SyncConflictRecord(
            conflictId: conflictId,
            clinicId: clinicId,
            entityType: canonicalSheet,
            entityId: id,
            detectedAt: inspectedAt,
            localChecksum: localChecksum,
            remoteChecksum: remoteChecksum,
            lastSyncedChecksum: lastSyncedChecksum,
            conflictStatus: 'unresolved',
            localVersionReference: localVerRef,
            remoteVersionReference: remoteVerRef,
            resolutionStatus: 'pending',
            errorCode: 'TWO_WAY_CONFLICT',
          );
          await localDb.upsert(
            'sync_conflicts',
            conflictId,
            conflictRecord.toMap(),
          );
          AppLogger.warning(
            'Conflict recorded [ID: $id, Sheet: $canonicalSheet, Conflict: $conflictId]',
          );
        }

        classifiedItems.add(
          ClassifiedChangeItem(
            entityId: id,
            entityType: canonicalSheet,
            classification: classification,
            localChecksum: localChecksum,
            remoteChecksum: remoteChecksum,
            lastSyncedChecksum: lastSyncedChecksum,
            localVersionReference: localVerRef,
            remoteVersionReference: remoteVerRef,
          ),
        );
      }

      return ChangeDetectionResult(
        clinicId: clinicId,
        targetWorksheet: canonicalSheet,
        inspectedAt: inspectedAt,
        items: classifiedItems,
      );
    } on Failure catch (f) {
      final isAuth = f is AuthorizationFailure;
      final isNet = f is NetworkFailure;
      return ChangeDetectionResult.failure(
        clinicId: clinicId,
        targetWorksheet: canonicalSheet,
        errorCode: isAuth
            ? 'AUTH_REQUIRED'
            : (isNet ? 'NETWORK_FAILURE' : 'SYNC_ERROR'),
        errorMessage: f.message,
      );
    } catch (e) {
      return ChangeDetectionResult.failure(
        clinicId: clinicId,
        targetWorksheet: canonicalSheet,
        errorCode: 'SYNC_ERROR',
        errorMessage: e.toString(),
      );
    }
  }

  /// Retrieve all recorded conflicts from local database
  Future<List<SyncConflictRecord>> getRecordedConflicts(String clinicId) async {
    final records = localDb.query(
      'sync_conflicts',
      where: (r) => r['clinic_id'] == clinicId,
    );
    final list = records.map((r) => SyncConflictRecord.fromMap(r)).toList();
    list.sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
    return list;
  }
}
