// Apna Clinic - Mock Google Integration Clients
// Primary source of truth: User Request Step 9 & Phase 3 Architecture Plan
// Provides deterministic test doubles for Google Drive & Google Sheets integration without live credentials.

import 'dart:typed_data';

import '../../core/errors/failures.dart';
import '../../domain/entities/master_sheet_schema.dart';
import 'google_drive_client.dart';
import 'google_sheets_client.dart';

class MockGoogleDriveClient extends GoogleDriveClient {
  bool simulateOffline = false;
  bool simulateAuthExpired = false;
  bool simulatePermissionDenied = false;
  bool simulateFileNotFound = false;
  bool simulateRateLimit = false;
  bool simulateServiceUnavailable = false;

  final Map<String, String> _folders = {}; // name -> id
  final Map<String, DriveFileMetadata> _files = {}; // id -> metadata

  MockGoogleDriveClient() : super() {
    _resetDefaults();
  }

  void _resetDefaults() {
    _folders['ApnaClinic'] = 'folder_apna_clinic_root';
    _folders['clinic_primary_demo'] = 'folder_clinic_demo';
    _folders['Backups'] = 'folder_backups';
    _folders['Encrypted'] = 'folder_encrypted';

    const defaultSheetId = 'sheet_master_template_001';
    _files[defaultSheetId] = const DriveFileMetadata(
      id: defaultSheetId,
      name: 'APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL',
      mimeType: 'application/vnd.google-apps.spreadsheet',
      parents: ['folder_clinic_demo'],
      permissions: GoogleDriveFilePermissions(
        canEdit: true,
        canRead: true,
        canDelete: false,
        canShare: false,
      ),
    );
  }

  void _checkSimulatedErrors(String action) {
    if (simulateOffline) {
      throw const NetworkFailure(
        'Cannot connect to Google Drive. Offline mode active.',
      );
    }
    if (simulateAuthExpired) {
      throw const AuthorizationFailure(
        'Google OAuth token expired or invalid.',
      );
    }
    if (simulatePermissionDenied) {
      throw const AuthorizationFailure(
        'Google Drive access denied. Insufficient OAuth scope or permissions.',
      );
    }
    if (simulateRateLimit) {
      throw const QuotaExceededFailure(
        'Google Drive API rate limit exceeded. Please back off.',
      );
    }
    if (simulateServiceUnavailable) {
      throw const NetworkFailure(
        'Google Drive service is temporarily unavailable (503).',
      );
    }
  }

  @override
  Future<GoogleDriveAccountInfo> verifyAccountAccess({
    required String accessToken,
  }) async {
    _checkSimulatedErrors('verifyAccountAccess');
    if (accessToken.trim().isEmpty) {
      throw const AuthorizationFailure('Google OAuth access token is missing.');
    }
    return const GoogleDriveAccountInfo(
      emailAddress: 'doctor.sharma@apnaclinic.in',
      displayName: 'Dr. Rajesh Sharma',
      permissionId: 'perm_owner_001',
    );
  }

  @override
  Future<String> getOrCreateFolder({
    required String accessToken,
    required String folderName,
    String? parentFolderId,
  }) async {
    _checkSimulatedErrors('getOrCreateFolder');
    if (accessToken.trim().isEmpty) {
      throw const AuthorizationFailure('Google OAuth access token is missing.');
    }
    final key = parentFolderId != null
        ? '$parentFolderId/$folderName'
        : folderName;
    return _folders.putIfAbsent(
      key,
      () =>
          'folder_mock_${folderName.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  @override
  Future<DriveFileMetadata?> locateMasterSheetFile({
    required String accessToken,
    required String parentFolderId,
    String fileName = 'APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL',
  }) async {
    _checkSimulatedErrors('locateMasterSheetFile');
    if (simulateFileNotFound) return null;

    for (final file in _files.values) {
      if (file.name.contains(fileName) &&
          file.parents.contains(parentFolderId)) {
        return file;
      }
    }
    // Return default file if parent matches
    if (_files.containsKey('sheet_master_template_001')) {
      return _files['sheet_master_template_001'];
    }
    return null;
  }

  @override
  Future<DriveFileMetadata?> findAnyMasterSheetFile({
    required String accessToken,
    List<String> candidateNames = const [
      'ApnaClinic_MasterData',
      'APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL',
      'ApnaClinic_Master',
      'ApnaClinic',
    ],
  }) async {
    _checkSimulatedErrors('findAnyMasterSheetFile');
    for (final f in _files.values) {
      if (f.mimeType == 'application/vnd.google-apps.spreadsheet') {
        for (final name in candidateNames) {
          if (f.name.contains(name)) return f;
        }
      }
    }
    if (_files.containsKey('sheet_master_template_001')) {
      return _files['sheet_master_template_001'];
    }
    return null;
  }

  @override
  Future<DriveFileMetadata?> getFileMetadata({
    required String accessToken,
    required String fileId,
  }) async {
    _checkSimulatedErrors('getFileMetadata');
    return _files[fileId];
  }

  @override
  Future<GoogleDriveFilePermissions> verifyFilePermissions({
    required String accessToken,
    required String fileId,
  }) async {
    _checkSimulatedErrors('verifyFilePermissions');
    if (simulateFileNotFound || !_files.containsKey(fileId)) {
      throw const DatabaseFailure('Google Drive resource not found.');
    }
    return _files[fileId]!.permissions ??
        const GoogleDriveFilePermissions(canEdit: true, canRead: true);
  }

  @override
  Future<String> createSpreadsheetInFolder({
    required String accessToken,
    required String parentFolderId,
    required String fileName,
  }) async {
    _checkSimulatedErrors('createSpreadsheetInFolder');
    final fileId = 'sheet_mock_${DateTime.now().millisecondsSinceEpoch}';
    _files[fileId] = DriveFileMetadata(
      id: fileId,
      name: fileName,
      mimeType: 'application/vnd.google-apps.spreadsheet',
      parents: [parentFolderId],
      permissions: const GoogleDriveFilePermissions(
        canEdit: true,
        canRead: true,
      ),
    );
    return fileId;
  }

  @override
  Future<void> moveFileToFolder({
    required String accessToken,
    required String fileId,
    required String targetFolderId,
    String? removeParents,
  }) async {
    _checkSimulatedErrors('moveFileToFolder');
    if (_files.containsKey(fileId)) {
      final file = _files[fileId]!;
      final newParents = List<String>.from(file.parents);
      if (removeParents != null) {
        newParents.remove(removeParents);
      }
      if (!newParents.contains(targetFolderId)) {
        newParents.add(targetFolderId);
      }
      _files[fileId] = DriveFileMetadata(
        id: file.id,
        name: file.name,
        mimeType: file.mimeType,
        parents: newParents,
        permissions: file.permissions,
      );
    }
  }

  @override
  Future<String> uploadExcelAsGoogleSheet({
    required String accessToken,
    required String parentFolderId,
    required String fileName,
    required List<int> xlsxBytes,
  }) async {
    _checkSimulatedErrors('uploadExcelAsGoogleSheet');
    final fileId = 'sheet_converted_${DateTime.now().millisecondsSinceEpoch}';
    _files[fileId] = DriveFileMetadata(
      id: fileId,
      name: fileName,
      mimeType: 'application/vnd.google-apps.spreadsheet',
      parents: [parentFolderId],
      permissions: const GoogleDriveFilePermissions(
        canEdit: true,
        canRead: true,
      ),
    );
    return fileId;
  }

  @override
  Future<String> initializeClinicBrandingFolder({
    required String accessToken,
    required String clinicId,
  }) async {
    _checkSimulatedErrors('initializeClinicBrandingFolder');
    return 'branding_folder_mock_$clinicId';
  }

  @override
  Future<String> uploadBinaryFile({
    required String accessToken,
    required String parentFolderId,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    _checkSimulatedErrors('uploadBinaryFile');
    final fileId = 'file_mock_${DateTime.now().millisecondsSinceEpoch}';
    _files[fileId] = DriveFileMetadata(
      id: fileId,
      name: fileName,
      mimeType: mimeType,
      parents: [parentFolderId],
      permissions: const GoogleDriveFilePermissions(
        canEdit: true,
        canRead: true,
      ),
    );
    return fileId;
  }
}

class MockGoogleSheetsClient extends GoogleSheetsClient {
  bool simulateOffline = false;
  bool simulateAuthExpired = false;
  bool simulatePermissionDenied = false;
  bool simulateSpreadsheetNotFound = false;
  bool simulateRateLimit = false;
  bool simulateRateLimitOnWrite = false;
  bool simulateServiceUnavailable = false;

  /// Schema tampering flags for validation testing
  bool simulateMissingSheet = false;
  bool simulateMissingColumn = false;
  bool simulateMisplacedColumn = false;

  MockGoogleSheetsClient() : super();

  void _checkSimulatedErrors(String action) {
    if (simulateOffline) {
      throw const NetworkFailure(
        'Cannot connect to Google Sheets. Offline mode active.',
      );
    }
    if (simulateAuthExpired) {
      throw const AuthorizationFailure(
        'Google OAuth token expired or invalid.',
      );
    }
    if (simulatePermissionDenied) {
      throw const AuthorizationFailure(
        'Google Sheets permission denied. Insufficient OAuth scope or access rights.',
      );
    }
    if (simulateSpreadsheetNotFound) {
      throw const DatabaseFailure('Google Spreadsheet not found.');
    }
    if (simulateRateLimit) {
      throw const QuotaExceededFailure(
        'Google Sheets API quota exceeded. Please back off.',
      );
    }
    if (simulateRateLimitOnWrite &&
        (action == 'batchAppendRows' || action == 'batchUpdateRows')) {
      throw const QuotaExceededFailure(
        'Google Sheets API quota exceeded on write. Please back off.',
      );
    }
    if (simulateServiceUnavailable) {
      throw const NetworkFailure(
        'Google Sheets service is temporarily unavailable (503).',
      );
    }
  }

  @override
  Future<SpreadsheetMetadata> getSpreadsheetMetadata({
    required String accessToken,
    required String spreadsheetId,
  }) async {
    _checkSimulatedErrors('getSpreadsheetMetadata');

    final sheets = List<String>.from(MasterSheetSchema.canonicalSheetNames);
    if (simulateMissingSheet) {
      sheets.remove('05_PATIENTS');
    }

    final ids = <String, int>{};
    for (int i = 0; i < sheets.length; i++) {
      ids[sheets[i]] = i;
    }

    return SpreadsheetMetadata(
      spreadsheetId: spreadsheetId,
      title: 'ApnaClinic_Master_Production_v1',
      sheetNames: sheets,
      sheetIdsByName: ids,
    );
  }

  @override
  Future<MasterSheetValidationResult> validateMasterSheetSchema({
    required String accessToken,
    required String spreadsheetId,
  }) async {
    try {
      _checkSimulatedErrors('validateMasterSheetSchema');

      final actualSheetNames = List<String>.from(
        MasterSheetSchema.canonicalSheetNames,
      );
      if (simulateMissingSheet) {
        actualSheetNames.remove('05_PATIENTS');
      }

      final actualHeaders = <String, List<String>>{};
      for (final sheet in MasterSheetSchema.canonicalSheetNames) {
        final original = MasterSheetSchema.canonicalHeaders[sheet]!;
        final cols = List<String>.from(original);

        if (sheet == '10_BILLING' && simulateMissingColumn) {
          cols.remove('total_amount');
        }

        if (sheet == '06_APPOINTMENTS' && simulateMisplacedColumn) {
          // Swap start_time and end_time
          final idxStart = cols.indexOf('start_time');
          final idxEnd = cols.indexOf('end_time');
          if (idxStart != -1 && idxEnd != -1) {
            cols[idxStart] = 'end_time';
            cols[idxEnd] = 'start_time';
          }
        }

        actualHeaders[sheet] = cols;
      }

      return MasterSheetSchema.validate(
        actualSheetNames: actualSheetNames,
        actualHeadersBySheet: actualHeaders,
      );
    } on Failure catch (f) {
      return MasterSheetValidationResult.failure(
        message: f.message,
        errorCode: f is AuthorizationFailure
            ? 'AUTH_ERROR'
            : (f is QuotaExceededFailure
                  ? 'RATE_LIMIT'
                  : (f is NetworkFailure
                        ? 'NETWORK_ERROR'
                        : 'SHEETS_API_ERROR')),
      );
    } catch (e) {
      return MasterSheetValidationResult.failure(
        message: e.toString(),
        errorCode: 'UNEXPECTED_ERROR',
      );
    }
  }

  @override
  Future<List<MasterSheetLookupItem>> readLookupCategory({
    required String accessToken,
    required String spreadsheetId,
    required String category,
  }) async {
    _checkSimulatedErrors('readLookupCategory');

    final allItems = [
      const MasterSheetLookupItem(
        lookupId: 'LK-001',
        category: 'GENDER',
        code: 'MALE',
        displayName: 'Male',
        sortOrder: 1,
        isActive: true,
      ),
      const MasterSheetLookupItem(
        lookupId: 'LK-002',
        category: 'GENDER',
        code: 'FEMALE',
        displayName: 'Female',
        sortOrder: 2,
        isActive: true,
      ),
      const MasterSheetLookupItem(
        lookupId: 'LK-003',
        category: 'GENDER',
        code: 'OTHER',
        displayName: 'Other',
        sortOrder: 3,
        isActive: true,
      ),
      const MasterSheetLookupItem(
        lookupId: 'LK-010',
        category: 'APPOINTMENT_STATUS',
        code: 'SCHEDULED',
        displayName: 'Scheduled',
        sortOrder: 1,
        isActive: true,
      ),
      const MasterSheetLookupItem(
        lookupId: 'LK-011',
        category: 'APPOINTMENT_STATUS',
        code: 'COMPLETED',
        displayName: 'Completed',
        sortOrder: 2,
        isActive: true,
      ),
    ];

    return allItems.where((i) => i.category == category).toList();
  }

  /// Data customization flags for testing
  bool simulateEmptySheet = false;
  bool simulateInvalidRecords = false;
  bool simulateForeignKeyViolation = false;
  Map<String, List<List<dynamic>>>? customSheetRows;

  // In-memory sheet row storage for write and idempotency verification
  final Map<String, List<List<dynamic>>> _sheetStore = {};

  List<List<dynamic>> getStoredRows(String sheetName) =>
      _getSheetRows(sheetName);

  List<List<dynamic>> _getSheetRows(String sheetName) {
    if (!_sheetStore.containsKey(sheetName)) {
      final defaultRows = _getDefaultRowsForSheet(sheetName);
      _sheetStore[sheetName] = [
        for (final r in defaultRows) List<dynamic>.from(r),
      ];
    }
    return _sheetStore[sheetName]!;
  }

  List<List<dynamic>> _getDefaultRowsForSheet(String sheetName) {
    final defaultData = <String, List<List<dynamic>>>{
      '01_SETTINGS': [
        [
          'SET-001',
          'CLINIC',
          'clinic_name',
          'Apna Clinic Demo',
          'STRING',
          'Legal Clinic Name',
          'TRUE',
          '2026-09-30',
        ],
        [
          'SET-002',
          'CLINIC',
          'contact_phone',
          '+919876543200',
          'STRING',
          'Clinic Phone',
          'TRUE',
          '2026-09-30',
        ],
      ],
      '02_USERS': [
        [
          'USR-001',
          'dr_rajesh',
          'Dr. Rajesh Sharma',
          'doctor',
          '9876543201',
          'rajesh@apnaclinic.in',
          'ACTIVE',
          'DOC-001',
        ],
        [
          'USR-002',
          'anita_rec',
          'Anita Desk',
          'receptionist',
          '9876543202',
          'anita@apnaclinic.in',
          'ACTIVE',
          '',
        ],
      ],
      '04_DOCTORS': [
        [
          'DOC-001',
          'D-01',
          'Dr. Rajesh Sharma',
          'General Medicine',
          'MBBS, MD',
          'MCI-2012-8890',
          '9876543201',
          'rajesh@apnaclinic.in',
          'ROOM-01',
          '500',
          '15',
          'ACTIVE',
        ],
      ],
      '05_PATIENTS': [
        [
          'PAT-000001',
          'P-2026-0001',
          'Ramesh',
          '',
          'Kumar',
          'Ramesh Kumar',
          '1985-05-15',
          '41',
          'MALE',
          '9876543210',
          '',
          'ramesh@example.com',
          '123 MG Road',
          'New Delhi',
          'Delhi',
          '110001',
          '',
          '',
          'O+',
          '2026-09-30',
          'ACTIVE',
          'GRANTED',
          'v1.0',
        ],
        [
          'PAT-000002',
          'P-2026-0002',
          'Sunita',
          '',
          'Sharma',
          'Sunita Sharma',
          '1992-08-20',
          '34',
          'FEMALE',
          '9876543211',
          '',
          '',
          '456 Ring Road',
          'New Delhi',
          'Delhi',
          '110002',
          '',
          '',
          'B+',
          '2026-09-30',
          'ACTIVE',
          'GRANTED',
          'v1.0',
        ],
      ],
      '06_APPOINTMENTS': [
        [
          'APT-000001',
          'APT-01',
          'PAT-000001',
          'DOC-001',
          '2026-09-30T10:00:00Z',
          '10:00',
          '10:15',
          'CONSULTATION',
          'WALKIN',
          'SCHEDULED',
          '1',
          'ROOM-01',
          'Fever checkup',
        ],
      ],
      '12_SERVICES': [
        [
          'SRV-001',
          'CONS-GEN',
          'General Consultation',
          'CONSULTATION',
          'Standard Consultation',
          '500',
          '0',
          'ACTIVE',
        ],
      ],
      '20_LOOKUPS': [
        ['LK-001', 'GENDER', 'MALE', 'Male', '1', 'TRUE'],
        ['LK-002', 'GENDER', 'FEMALE', 'Female', '2', 'TRUE'],
        ['LK-003', 'GENDER', 'OTHER', 'Other', '3', 'TRUE'],
      ],
    };

    if (simulateInvalidRecords) {
      defaultData['05_PATIENTS']?.add([
        'PAT-000003',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        'OTHER',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        'ACTIVE',
        'GRANTED',
        'v1.0',
      ]);
      defaultData['02_USERS']?.add([
        'USR-003',
        'bad_user',
        'Bad User',
        'INVALID_ROLE_CODE',
        '9876543299',
      ]);
    }

    if (simulateForeignKeyViolation) {
      defaultData['06_APPOINTMENTS']?.add([
        'APT-000002',
        'APT-02',
        'PAT-NON-EXISTENT',
        'DOC-001',
        '2026-09-30T11:00:00Z',
        '11:00',
        '11:15',
        'CONSULTATION',
        'WALKIN',
        'SCHEDULED',
      ]);
    }

    return defaultData[sheetName] ?? [];
  }

  @override
  Future<List<String>> readSheetColumn({
    required String accessToken,
    required String spreadsheetId,
    required String sheetName,
    String columnLetter = 'A',
    int startRow = 2,
    int endRow = 5000,
  }) async {
    _checkSimulatedErrors('readSheetColumn');
    final rows = _getSheetRows(sheetName);
    return rows.map((r) => r.isNotEmpty ? r[0].toString().trim() : '').toList();
  }

  @override
  Future<void> clearSheetRange({
    required String accessToken,
    required String spreadsheetId,
    required String range,
  }) async {
    _checkSimulatedErrors('clearSheetRange');
    final sheetName = range.contains('!') ? range.split('!').first : range;
    final list = _getSheetRows(sheetName);
    list.clear();
  }

  @override
  Future<int> batchAppendRows({
    required String accessToken,
    required String spreadsheetId,
    required String sheetName,
    required List<List<dynamic>> rows,
  }) async {
    _checkSimulatedErrors('batchAppendRows');
    final list = _getSheetRows(sheetName);
    list.addAll(rows);
    return rows.length;
  }

  @override
  Future<int> batchUpdateRows({
    required String accessToken,
    required String spreadsheetId,
    required List<SheetValueUpdate> updates,
  }) async {
    _checkSimulatedErrors('batchUpdateRows');
    for (final update in updates) {
      final parts = update.range.split('!');
      if (parts.length == 2) {
        final sheet = parts[0];
        final cellRange = parts[1];
        final rowMatch = RegExp(r'\d+').firstMatch(cellRange);
        if (rowMatch != null) {
          final rowNum = int.tryParse(rowMatch.group(0)!);
          if (rowNum != null && rowNum >= 2) {
            final rows = _getSheetRows(sheet);
            final targetIdx = rowNum - 2;
            if (targetIdx < rows.length && update.values.isNotEmpty) {
              rows[targetIdx] = List<dynamic>.from(update.values.first);
            }
          }
        }
      }
    }
    return updates.length;
  }

  @override
  Future<Map<String, List<List<dynamic>>>> batchReadSheetRows({
    required String accessToken,
    required String spreadsheetId,
    required List<String> sheetNames,
    int startRow = 2,
    int endRow = 1000,
  }) async {
    _checkSimulatedErrors('batchReadSheetRows');

    final custom = customSheetRows;
    if (custom != null) {
      return custom;
    }

    if (simulateEmptySheet) {
      return {for (final s in sheetNames) s: []};
    }

    return {for (final s in sheetNames) s: _getSheetRows(s)};
  }

  @override
  Future<String> createSpreadsheetWithSheets({
    required String accessToken,
    required String title,
    required Map<String, List<String>> sheetsWithHeaders,
  }) async {
    _checkSimulatedErrors('createSpreadsheetWithSheets');
    return 'sheet_mock_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<void> ensureSheetsWithHeaders({
    required String accessToken,
    required String spreadsheetId,
    required Map<String, List<String>> sheetsWithHeaders,
  }) async {
    _checkSimulatedErrors('ensureSheetsWithHeaders');
  }
}
