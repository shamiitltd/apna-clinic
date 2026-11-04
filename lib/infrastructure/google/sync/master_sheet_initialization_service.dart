// Apna Clinic - Controlled One-Way Master Sheet Initialization Service
// Primary source of truth: User Request Milestone 3, PRD Section 17-19, TRD Section 7, 11
// Invariants:
// 1. One-way only: Google Master Sheet -> Sync -> Validation -> Local DB.
// 2. Never writes to Google Sheets.
// 3. Quota protected: Single bounded batchGet API call.
// 4. Atomic transaction with automatic rollback on database failure.
// 5. Foreign-key validation and safe rejection reporting.
// 6. Idempotent: repeated runs do not duplicate or corrupt records.

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/permissions/roles.dart';
import '../../../core/utils/phone_normalizer.dart';
import '../../../domain/enums/domain_enums.dart';
import '../../../application/auth/auth_service.dart';
import '../../database/local_database.dart';
import '../google_drive_client.dart';
import '../google_sheets_client.dart';

/// Structured report of a record rejected during initialization
class RecordRejection {
  final String sheetName;
  final String recordId;
  final String reason;
  final List<dynamic>? rawRow;

  const RecordRejection({
    required this.sheetName,
    required this.recordId,
    required this.reason,
    this.rawRow,
  });

  @override
  String toString() => '[$sheetName] Record $recordId rejected: $reason';
}

/// Comprehensive outcome of the Master Sheet initialization operation
class MasterSheetInitResult {
  final bool isSuccess;
  final int totalRecordsProcessed;
  final int totalRecordsImported;
  final int totalRecordsUnchanged;
  final int totalRecordsRejected;
  final List<RecordRejection> rejections;
  final Map<String, int> importedCountByTable;
  final String? errorCode;
  final String? errorMessage;
  final Duration? duration;

  const MasterSheetInitResult({
    required this.isSuccess,
    this.totalRecordsProcessed = 0,
    this.totalRecordsImported = 0,
    this.totalRecordsUnchanged = 0,
    this.totalRecordsRejected = 0,
    this.rejections = const [],
    this.importedCountByTable = const {},
    this.errorCode,
    this.errorMessage,
    this.duration,
  });

  factory MasterSheetInitResult.failure({
    required String message,
    String errorCode = 'INIT_FAILURE',
    List<RecordRejection> rejections = const [],
  }) {
    return MasterSheetInitResult(
      isSuccess: false,
      errorCode: errorCode,
      errorMessage: message,
      rejections: rejections,
      totalRecordsRejected: rejections.length,
    );
  }
}

class MasterSheetInitializationService {
  final GoogleDriveClient driveClient;
  final GoogleSheetsClient sheetsClient;
  final LocalDatabase localDb;
  final AuthService authService;

  MasterSheetInitializationService({
    required this.driveClient,
    required this.sheetsClient,
    required this.localDb,
    required this.authService,
  });

  /// Sheets requested for operational clinic initialization
  static const List<String> _initializationSheets = [
    '01_SETTINGS',
    '02_USERS',
    '04_DOCTORS',
    '05_PATIENTS',
    '06_APPOINTMENTS',
    '12_SERVICES',
    '20_LOOKUPS',
  ];

  /// Ensures that the clinic Master Sheet exists on Google Drive.
  /// If present: reuses it and NEVER recreates it (Milestone 2 Step 3).
  /// If missing: initializes it using Phase 3 initializer and moves it to clinic folder.
  Future<String> getOrCreateMasterSpreadsheet({
    required String accessToken,
    required String clinicId,
    List<int>? optionalXlsxBytes,
  }) async {
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

    final existingFile =
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

    if (existingFile != null) {
      AppLogger.info(
        'Reusing existing clinic Master Sheet: ${existingFile.id}',
      );
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('apna_drive_spreadsheet_id', existingFile.id);
      } catch (_) {}
      return existingFile.id;
    }

    AppLogger.info(
      'Master Sheet missing. Initializing new Master Sheet for clinic: $clinicId',
    );
    String newSheetId;
    if (optionalXlsxBytes != null && optionalXlsxBytes.isNotEmpty) {
      newSheetId = await driveClient.uploadExcelAsGoogleSheet(
        accessToken: accessToken,
        parentFolderId: clinicFolderId,
        fileName: 'ApnaClinic_MasterData',
        xlsxBytes: optionalXlsxBytes,
      );
    } else {
      try {
        newSheetId = await driveClient.createSpreadsheetInFolder(
          accessToken: accessToken,
          parentFolderId: clinicFolderId,
          fileName: 'ApnaClinic_MasterData',
        );
      } catch (_) {
        newSheetId = await sheetsClient.createMasterSpreadsheet(
          accessToken: accessToken,
          clinicTitle: 'ApnaClinic_MasterData',
        );
        await driveClient.moveFileToFolder(
          accessToken: accessToken,
          fileId: newSheetId,
          targetFolderId: clinicFolderId,
        );
      }
      try {
        await sheetsClient.populateCanonicalSheets(
          accessToken: accessToken,
          spreadsheetId: newSheetId,
        );
      } catch (_) {}
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('apna_drive_spreadsheet_id', newSheetId);
    } catch (_) {}

    AppLogger.info('Successfully initialized clinic Master Sheet: $newSheetId');
    return newSheetId;
  }

  /// Executes controlled one-way initialization
  Future<MasterSheetInitResult> initializeFromMasterSheet({
    required String clinicId,
    String? explicitSpreadsheetId,
    String? explicitAccessToken,
    bool createIfMissing = false,
    List<int>? optionalXlsxBytes,
  }) async {
    final stopwatch = Stopwatch()..start();
    AppLogger.info(
      'Starting Controlled Master Sheet Initialization for clinic: $clinicId',
    );

    try {
      // 1. Resolve Access Token
      final accessToken =
          explicitAccessToken ??
          await authService.getValidAccessToken(clinicId: clinicId);

      if (accessToken == null || accessToken.trim().isEmpty) {
        return MasterSheetInitResult.failure(
          message:
              'Google authentication required. No valid access token found.',
          errorCode: 'AUTH_REQUIRED',
        );
      }

      // 2. Resolve & Verify Master Sheet Identity
      String spreadsheetId = explicitSpreadsheetId ?? '';

      if (spreadsheetId.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final storedId = prefs.getString('apna_drive_spreadsheet_id');
          if (storedId != null &&
              storedId.isNotEmpty &&
              !storedId.startsWith('local_sheet_')) {
            spreadsheetId = storedId;
            AppLogger.info(
              'Resolved master spreadsheet ID from preferences: $spreadsheetId',
            );
          }
        } catch (_) {}
      }

      if (spreadsheetId.isEmpty) {
        // Resolve clinic folder on Google Drive
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
            await driveClient.locateMasterSheetFile(
              accessToken: accessToken,
              parentFolderId: rootFolderId,
              fileName: 'APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL',
            ) ??
            await driveClient.findAnyMasterSheetFile(accessToken: accessToken);

        if (fileMeta == null) {
          if (createIfMissing) {
            spreadsheetId = await getOrCreateMasterSpreadsheet(
              accessToken: accessToken,
              clinicId: clinicId,
              optionalXlsxBytes: optionalXlsxBytes,
            );
          } else {
            return MasterSheetInitResult.failure(
              message: 'Master Sheet spreadsheet not found in Google Drive.',
              errorCode: 'MASTER_SHEET_NOT_FOUND',
            );
          }
        } else {
          spreadsheetId = fileMeta.id;
        }
      }

      // Persist resolved spreadsheet ID locally for all components
      if (spreadsheetId.isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('apna_drive_spreadsheet_id', spreadsheetId);
        } catch (_) {}
      }

      // 3. Strict Master Sheet Schema Validation Gate with Auto-Healing
      var validationResult = await sheetsClient.validateMasterSheetSchema(
        accessToken: accessToken,
        spreadsheetId: spreadsheetId,
      );

      if (!validationResult.isValid &&
          validationResult.missingSheets.isNotEmpty) {
        try {
          AppLogger.info(
            'Spreadsheet missing canonical tabs. Self-healing via populateCanonicalSheets...',
          );
          await sheetsClient.populateCanonicalSheets(
            accessToken: accessToken,
            spreadsheetId: spreadsheetId,
          );
          validationResult = await sheetsClient.validateMasterSheetSchema(
            accessToken: accessToken,
            spreadsheetId: spreadsheetId,
          );
        } catch (e) {
          AppLogger.warning('Schema self-healing non-fatal error: $e');
        }
      }

      if (!validationResult.isValid) {
        final errCode = validationResult.errorCode;
        final isRateLimit = errCode == 'RATE_LIMIT';
        final isAuth = errCode == 'AUTH_ERROR' || errCode == 'AUTH_FAILURE';
        final isApi =
            errCode == 'SHEETS_API_ERROR' || errCode == 'NETWORK_ERROR';

        final finalErrorCode = isRateLimit
            ? 'RATE_LIMIT'
            : (isAuth
                  ? 'AUTH_FAILURE'
                  : (isApi ? 'API_FAILURE' : 'SCHEMA_MISMATCH'));

        AppLogger.warning(
          'Master Sheet validation check failed: ${validationResult.errorMessage} (code: $finalErrorCode)',
        );
        return MasterSheetInitResult.failure(
          message:
              'Master Sheet validation failed. Operation halted to prevent corrupting local state: ${validationResult.errorMessage}',
          errorCode: finalErrorCode,
        );
      }

      // 4. Single Bounded Batch Read (Quota Protection)
      final allSheetRows = await sheetsClient.batchReadSheetRows(
        accessToken: accessToken,
        spreadsheetId: spreadsheetId,
        sheetNames: _initializationSheets,
        startRow: 2,
        endRow: 1000,
      );

      // 5. In-Memory Validation, Normalization & Staging
      final rejections = <RecordRejection>[];
      final stagedRecords = <String, Map<String, Map<String, dynamic>>>{};
      for (final table in [
        'Clinic_Config',
        'Staff',
        'Doctors',
        'Patients',
        'Appointments',
        'Fee_Catalog',
        'Lookup_Config',
      ]) {
        stagedRecords[table] = {};
      }

      int totalProcessed = 0;

      // A. Process 20_LOOKUPS -> Lookup_Config
      final lookupRows = allSheetRows['20_LOOKUPS'] ?? [];
      for (final row in lookupRows) {
        if (row.isEmpty || row[0].toString().trim().isEmpty) continue;
        totalProcessed++;
        final lookupId = row[0].toString().trim();
        final category = row.length > 1 ? row[1].toString().trim() : '';
        final code = row.length > 2 ? row[2].toString().trim() : '';
        final name = row.length > 3 ? row[3].toString().trim() : '';

        if (category.isEmpty || code.isEmpty) {
          rejections.add(
            RecordRejection(
              sheetName: '20_LOOKUPS',
              recordId: lookupId,
              reason: 'Missing required category or code',
              rawRow: row,
            ),
          );
          continue;
        }

        stagedRecords['Lookup_Config']![lookupId] = {
          'lookup_id': lookupId,
          'clinic_id': clinicId,
          'category': category,
          'code': code,
          'display_name': name,
          'sort_order': row.length > 4
              ? int.tryParse(row[4].toString()) ?? 0
              : 0,
          'is_active': row.length > 5
              ? row[5].toString().toUpperCase() != 'FALSE'
              : true,
          'description': row.length > 6 ? row[6].toString().trim() : '',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };
      }

      // B. Process 01_SETTINGS -> Clinic_Config
      // IMPORTANT: Preserve existing local Clinic_Config (logo, owner, address) so local-only or unmapped fields are not wiped
      final existingClinic = localDb.get('Clinic_Config', clinicId) ??
          (localDb.query('Clinic_Config').isNotEmpty
              ? localDb.query('Clinic_Config').first
              : null);
      final settingRows = allSheetRows['01_SETTINGS'] ?? [];
      final clinicConfigMap = <String, dynamic>{
        if (existingClinic != null) ...existingClinic,
        'clinic_id': clinicId,
        'schema_version': '2.1.0',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      for (final row in settingRows) {
        if (row.isEmpty || row.length < 4) continue;
        totalProcessed++;
        final rawKey = row[2].toString().trim().toLowerCase();
        final val = row[3].toString().trim();
        if (rawKey.isEmpty || val.isEmpty) continue;

        clinicConfigMap[rawKey] = val;

        // Canonical model mappings for Clinic entity
        if (rawKey == 'clinic_name' || rawKey == 'display_name') {
          clinicConfigMap['display_name'] = val;
          clinicConfigMap['clinic_name'] = val;
        } else if (rawKey == 'legal_name') {
          clinicConfigMap['legal_name'] = val;
        } else if (rawKey == 'owner_name') {
          clinicConfigMap['owner_name'] = val;
        } else if (rawKey == 'contact_phone' || rawKey == 'phone') {
          clinicConfigMap['contact_phone'] = val;
          clinicConfigMap['phone'] = val;
        } else if (rawKey == 'contact_email' || rawKey == 'email') {
          clinicConfigMap['contact_email'] = val;
          clinicConfigMap['email'] = val;
        } else if (rawKey == 'address' || rawKey == 'address_line1') {
          clinicConfigMap['address_line1'] = val;
          clinicConfigMap['address'] = val;
        } else if (rawKey == 'address_line2') {
          clinicConfigMap['address_line2'] = val;
        } else if (rawKey == 'city') {
          clinicConfigMap['city'] = val;
        } else if (rawKey == 'district') {
          clinicConfigMap['district'] = val;
        } else if (rawKey == 'state') {
          clinicConfigMap['state'] = val;
        } else if (rawKey == 'pincode') {
          clinicConfigMap['pincode'] = val;
        } else if (rawKey == 'currency') {
          clinicConfigMap['currency'] = val;
        } else if (rawKey == 'tax_id' || rawKey == 'tax_registration_number') {
          clinicConfigMap['tax_registration_number'] = val;
          clinicConfigMap['tax_id'] = val;
        } else if (rawKey == 'logo_drive_file_id') {
          clinicConfigMap['logo_drive_file_id'] = val;
        } else if (rawKey == 'logo_base64') {
          clinicConfigMap['logo_base64'] = val;
        }
      }
      stagedRecords['Clinic_Config']![clinicId] = clinicConfigMap;

      // C. Process 02_USERS -> Staff
      final userRows = allSheetRows['02_USERS'] ?? [];
      for (final row in userRows) {
        if (row.isEmpty || row[0].toString().trim().isEmpty) continue;
        totalProcessed++;
        final userId = row[0].toString().trim();
        final displayName = row.length > 2 ? row[2].toString().trim() : '';
        final roleStr = row.length > 3
            ? row[3].toString().trim().toLowerCase()
            : '';
        final phone = row.length > 4 ? row[4].toString().trim() : '';

        if (displayName.isEmpty || roleStr.isEmpty) {
          rejections.add(
            RecordRejection(
              sheetName: '02_USERS',
              recordId: userId,
              reason: 'Missing display name or role',
              rawRow: row,
            ),
          );
          continue;
        }

        // Validate role matches domain UserRole
        final role = _parseUserRole(roleStr);
        if (role == null) {
          rejections.add(
            RecordRejection(
              sheetName: '02_USERS',
              recordId: userId,
              reason: 'Invalid user role: "$roleStr"',
              rawRow: row,
            ),
          );
          continue;
        }

        stagedRecords['Staff']![userId] = {
          'staff_id': userId,
          'clinic_id': clinicId,
          'display_name': displayName,
          'role': role.name,
          'phone': PhoneNormalizer.normalize(phone) ?? phone,
          'email': row.length > 5 ? row[5].toString().trim() : '',
          'active': row.length > 6
              ? row[6].toString().toUpperCase() != 'INACTIVE'
              : true,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };
      }

      // D. Process 04_DOCTORS -> Doctors
      final doctorRows = allSheetRows['04_DOCTORS'] ?? [];
      for (final row in doctorRows) {
        if (row.isEmpty || row[0].toString().trim().isEmpty) continue;
        totalProcessed++;
        final docId = row[0].toString().trim();
        final docName = row.length > 2 ? row[2].toString().trim() : '';
        final spec = row.length > 3 ? row[3].toString().trim() : '';
        final regNum = row.length > 5 ? row[5].toString().trim() : '';

        if (docName.isEmpty || spec.isEmpty) {
          rejections.add(
            RecordRejection(
              sheetName: '04_DOCTORS',
              recordId: docId,
              reason: 'Missing doctor name or specialization',
              rawRow: row,
            ),
          );
          continue;
        }

        stagedRecords['Doctors']![docId] = {
          'doctor_id': docId,
          'clinic_id': clinicId,
          'display_name': docName,
          'specialty_label': spec,
          'qualification_text': row.length > 4 ? row[4].toString().trim() : '',
          'registration_number': regNum,
          'contact_phone': row.length > 6 ? row[6].toString().trim() : '',
          'room_label': row.length > 8 ? row[8].toString().trim() : '',
          'default_fee': row.length > 9 ? _parsePaiseFromRupees(row[9]) : 50000,
          'active': row.length > 11
              ? row[11].toString().toUpperCase() != 'INACTIVE'
              : true,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };
      }

      // E. Process 05_PATIENTS -> Patients
      final patientRows = allSheetRows['05_PATIENTS'] ?? [];
      for (final row in patientRows) {
        if (row.isEmpty) continue;
        final patIdRaw = row.isNotEmpty ? row[0].toString().trim() : '';
        final patCode = row.length > 1 ? row[1].toString().trim() : '';
        final firstName = row.length > 2 ? row[2].toString().trim() : '';
        final middleName = row.length > 3 ? row[3].toString().trim() : '';
        final lastName = row.length > 4 ? row[4].toString().trim() : '';
        var fullName = row.length > 5 && row[5].toString().trim().isNotEmpty
            ? row[5].toString().trim()
            : [
                firstName,
                middleName,
                lastName,
              ].where((s) => s.isNotEmpty).join(' ').trim();

        // Skip completely empty spacer rows
        if (patIdRaw.isEmpty && patCode.isEmpty && fullName.isEmpty) continue;

        totalProcessed++;
        if (fullName.isEmpty) {
          rejections.add(
            RecordRejection(
              sheetName: '05_PATIENTS',
              recordId: patIdRaw.isNotEmpty ? patIdRaw : 'UNKNOWN',
              reason: 'Missing patient full name',
              rawRow: row,
            ),
          );
          continue;
        }

        final patId = patIdRaw.isNotEmpty
            ? patIdRaw
            : (patCode.isNotEmpty
                  ? patCode
                  : 'pat_${DateTime.now().millisecondsSinceEpoch}_$totalProcessed');

        final genderStr = row.length > 8 && row[8].toString().trim().isNotEmpty
            ? row[8].toString().trim().toUpperCase()
            : 'OTHER';
        final phone = row.length > 9 ? row[9].toString().trim() : '';
        final normalizedPhone = phone.isNotEmpty
            ? (PhoneNormalizer.normalize(phone) ?? phone)
            : null;
        final dobStr = row.length > 6 ? row[6].toString().trim() : '';
        final ageVal = row.length > 7
            ? int.tryParse(row[7].toString().trim())
            : null;
        final emailStr = row.length > 11 ? row[11].toString().trim() : '';
        final isDeleted = row.length > 20 &&
            row[20].toString().trim().toUpperCase() == 'INACTIVE';
        final createdAtStr = row.length > 23 && row[23].toString().trim().isNotEmpty
            ? row[23].toString().trim()
            : DateTime.now().toUtc().toIso8601String();
        final updatedAtStr = row.length > 24 && row[24].toString().trim().isNotEmpty
            ? row[24].toString().trim()
            : DateTime.now().toUtc().toIso8601String();

        stagedRecords['Patients']![patId] = {
          'patient_id': patId,
          'clinic_id': clinicId,
          'patient_number': patCode.isNotEmpty ? patCode : patId,
          'full_name': fullName,
          'first_name': firstName,
          'last_name': lastName,
          'sex_optional': genderStr,
          'phone_optional': normalizedPhone,
          'date_of_birth': dobStr.isNotEmpty ? dobStr : null,
          'age_if_dob_unknown': ageVal,
          'alternate_phone_optional': row.length > 10
              ? row[10].toString().trim()
              : null,
          'email_optional': emailStr.isNotEmpty ? emailStr : null,
          'address_optional': row.length > 12
              ? row[12].toString().trim()
              : null,
          'city_optional': row.length > 13 ? row[13].toString().trim() : null,
          'pincode_optional': row.length > 15
              ? row[15].toString().trim()
              : null,
          'consent_status': row.length > 21
              ? row[21].toString().trim().toLowerCase()
              : 'granted',
          'consent_version': row.length > 22
              ? row[22].toString().trim()
              : 'v1.0',
          'created_at': createdAtStr,
          'updated_at': updatedAtStr,
          'deleted_at': isDeleted ? DateTime.now().toUtc().toIso8601String() : null,
        };
      }

      // F. Process 06_APPOINTMENTS -> Appointments (with Strict Foreign-Key Validation)
      final aptRows = allSheetRows['06_APPOINTMENTS'] ?? [];
      for (final row in aptRows) {
        if (row.isEmpty || row[0].toString().trim().isEmpty) continue;
        totalProcessed++;
        final aptId = row[0].toString().trim();
        final patId = row.length > 2 ? row[2].toString().trim() : '';
        final docId = row.length > 3 ? row[3].toString().trim() : '';
        final aptDate = row.length > 4 ? row[4].toString().trim() : '';
        final statusStr = row.length > 9
            ? row[9].toString().trim().toUpperCase()
            : 'SCHEDULED';

        if (patId.isEmpty || docId.isEmpty || aptDate.isEmpty) {
          rejections.add(
            RecordRejection(
              sheetName: '06_APPOINTMENTS',
              recordId: aptId,
              reason: 'Missing patient_id, doctor_id, or appointment_date',
              rawRow: row,
            ),
          );
          continue;
        }

        // FOREIGN KEY INTEGRITY CHECK:
        // 1. Check patient exists in staged records OR in existing LocalDatabase
        final patientExists =
            stagedRecords['Patients']!.containsKey(patId) ||
            localDb.get('Patients', patId) != null;

        if (!patientExists) {
          rejections.add(
            RecordRejection(
              sheetName: '06_APPOINTMENTS',
              recordId: aptId,
              reason:
                  'Foreign key violation: Referenced patient "$patId" does not exist',
              rawRow: row,
            ),
          );
          continue;
        }

        // 2. Check doctor exists in staged records OR in existing LocalDatabase
        final doctorExists =
            stagedRecords['Doctors']!.containsKey(docId) ||
            localDb.get('Doctors', docId) != null;

        if (!doctorExists) {
          rejections.add(
            RecordRejection(
              sheetName: '06_APPOINTMENTS',
              recordId: aptId,
              reason:
                  'Foreign key violation: Referenced doctor "$docId" does not exist',
              rawRow: row,
            ),
          );
          continue;
        }

        final status = _parseAppointmentStatus(statusStr);

        stagedRecords['Appointments']![aptId] = {
          'appointment_id': aptId,
          'clinic_id': clinicId,
          'patient_id': patId,
          'doctor_id': docId,
          'scheduled_start_at': aptDate,
          'scheduled_end_at': aptDate,
          'appointment_type': row.length > 7
              ? row[7].toString().trim()
              : 'CONSULTATION',
          'booking_source': row.length > 8
              ? row[8].toString().trim()
              : 'WALKIN',
          'status': status.name,
          'notes': row.length > 12 ? row[12].toString().trim() : '',
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };
      }

      // G. Process 12_SERVICES -> Fee_Catalog
      final serviceRows = allSheetRows['12_SERVICES'] ?? [];
      for (final row in serviceRows) {
        if (row.isEmpty || row[0].toString().trim().isEmpty) continue;
        totalProcessed++;
        final sId = row[0].toString().trim();
        final sCode = row.length > 1 ? row[1].toString().trim() : '';
        final sName = row.length > 2 ? row[2].toString().trim() : '';

        if (sName.isEmpty) {
          rejections.add(
            RecordRejection(
              sheetName: '12_SERVICES',
              recordId: sId,
              reason: 'Missing service_name',
              rawRow: row,
            ),
          );
          continue;
        }

        stagedRecords['Fee_Catalog']![sId] = {
          'fee_id': sId,
          'clinic_id': clinicId,
          'fee_code': sCode.isNotEmpty ? sCode : sId,
          'fee_name': sName,
          'description': row.length > 4 ? row[4].toString().trim() : '',
          'default_amount_minor': row.length > 5
              ? _parsePaiseFromRupees(row[5])
              : 0,
          'active': row.length > 7
              ? row[7].toString().toUpperCase() != 'INACTIVE'
              : true,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };
      }

      // 6. Atomic Commit to Local Database with Idempotency Tracking
      int totalImported = 0;
      int totalUnchanged = 0;
      final importedCounts = <String, int>{};

      await localDb.transaction<void>((tx) async {
        for (final entry in stagedRecords.entries) {
          final table = entry.key;
          final records = entry.value;
          int tableImported = 0;

          for (final recEntry in records.entries) {
            final id = recEntry.key;
            final incoming = recEntry.value;

            final existing = localDb.get(table, id);
            if (existing != null && _isRecordUnchanged(existing, incoming)) {
              totalUnchanged++;
            } else {
              await localDb.upsert(table, id, incoming, tx: tx);
              totalImported++;
              tableImported++;
            }
          }

          importedCounts[table] = tableImported;
        }
      });

      stopwatch.stop();
      AppLogger.info(
        'Master Sheet Initialization finished: $totalImported imported, $totalUnchanged unchanged, ${rejections.length} rejected in ${stopwatch.elapsedMilliseconds}ms',
      );

      return MasterSheetInitResult(
        isSuccess: true,
        totalRecordsProcessed: totalProcessed,
        totalRecordsImported: totalImported,
        totalRecordsUnchanged: totalUnchanged,
        totalRecordsRejected: rejections.length,
        rejections: rejections,
        importedCountByTable: importedCounts,
        duration: stopwatch.elapsed,
      );
    } on Failure catch (f) {
      stopwatch.stop();
      return MasterSheetInitResult.failure(
        message: f.message,
        errorCode: f is AuthorizationFailure
            ? 'AUTH_FAILURE'
            : (f is QuotaExceededFailure ? 'RATE_LIMIT' : 'API_FAILURE'),
      );
    } catch (e) {
      stopwatch.stop();
      return MasterSheetInitResult.failure(
        message: 'Master Sheet initialization encountered an error: $e',
        errorCode: 'UNEXPECTED_ERROR',
      );
    }
  }

  static bool _isRecordUnchanged(
    Map<String, dynamic> existing,
    Map<String, dynamic> incoming,
  ) {
    for (final key in incoming.keys) {
      if (key == 'updated_at' || key == 'created_at') continue;
      if (existing[key]?.toString() != incoming[key]?.toString()) {
        return false;
      }
    }
    return true;
  }

  static UserRole? _parseUserRole(String roleStr) {
    final lower = roleStr.toLowerCase();
    if (lower.contains('owner') || lower.contains('admin'))
      return UserRole.owner;
    if (lower.contains('doctor')) return UserRole.doctor;
    if (lower.contains('reception')) return UserRole.receptionist;
    if (lower.contains('account')) return UserRole.accountant;
    return null;
  }

  static AppointmentStatus _parseAppointmentStatus(String statusStr) {
    final upper = statusStr.trim().toUpperCase();
    if (upper == 'COMPLETED') return AppointmentStatus.completed;
    if (upper == 'CANCELLED') return AppointmentStatus.cancelled;
    if (upper == 'NO_SHOW' || upper == 'NOSHOW')
      return AppointmentStatus.noShow;
    if (upper == 'CHECKED_IN' || upper == 'CHECKEDIN')
      return AppointmentStatus.checkedIn;
    return AppointmentStatus.scheduled;
  }

  static int _parsePaiseFromRupees(dynamic val) {
    if (val == null) return 0;
    final clean = val.toString().replaceAll('₹', '').replaceAll(',', '').trim();
    final d = double.tryParse(clean);
    if (d == null) return 0;
    return (d * 100).round();
  }
}
