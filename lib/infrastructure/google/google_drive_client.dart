// Apna Clinic - Google Drive Integration Client
// Primary source of truth: PRD Section 17, 42, 43 and TRD Section 5, 13
// Manages folder hierarchy: ApnaClinic/{clinic_id}/Backups/Encrypted/ and Master Sheet location
// Least-privilege OAuth scope: https://www.googleapis.com/auth/drive.file

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/logging/app_logger.dart';

/// Information about the authenticated Google account retrieved from Drive
class GoogleDriveAccountInfo {
  final String emailAddress;
  final String displayName;
  final String? permissionId;
  final String? photoLink;

  const GoogleDriveAccountInfo({
    required this.emailAddress,
    required this.displayName,
    this.permissionId,
    this.photoLink,
  });

  factory GoogleDriveAccountInfo.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? {};
    return GoogleDriveAccountInfo(
      emailAddress: user['emailAddress'] as String? ?? '',
      displayName: user['displayName'] as String? ?? '',
      permissionId: user['permissionId'] as String?,
      photoLink: user['photoLink'] as String?,
    );
  }
}

/// Permissions capabilities for a specific Drive file or folder
class GoogleDriveFilePermissions {
  final bool canEdit;
  final bool canRead;
  final bool canDelete;
  final bool canShare;

  const GoogleDriveFilePermissions({
    required this.canEdit,
    required this.canRead,
    this.canDelete = false,
    this.canShare = false,
  });

  factory GoogleDriveFilePermissions.fromCapabilities(
    Map<String, dynamic> capabilities,
  ) {
    return GoogleDriveFilePermissions(
      canEdit: capabilities['canEdit'] as bool? ?? false,
      canRead: capabilities['canRead'] as bool? ?? true,
      canDelete: capabilities['canDelete'] as bool? ?? false,
      canShare: capabilities['canShare'] as bool? ?? false,
    );
  }
}

/// Metadata representation of a file or folder on Google Drive
class DriveFileMetadata {
  final String id;
  final String name;
  final String mimeType;
  final List<String> parents;
  final GoogleDriveFilePermissions? permissions;

  const DriveFileMetadata({
    required this.id,
    required this.name,
    required this.mimeType,
    this.parents = const [],
    this.permissions,
  });

  factory DriveFileMetadata.fromJson(Map<String, dynamic> json) {
    final parentsRaw = json['parents'] as List?;
    final parents = parentsRaw != null
        ? parentsRaw.map((p) => p.toString()).toList()
        : <String>[];
    final capabilitiesRaw = json['capabilities'] as Map<String, dynamic>?;

    return DriveFileMetadata(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      mimeType: json['mimeType'] as String? ?? '',
      parents: parents,
      permissions: capabilitiesRaw != null
          ? GoogleDriveFilePermissions.fromCapabilities(capabilitiesRaw)
          : null,
    );
  }
}

class GoogleDriveClient {
  static const String _driveFilesUrl =
      'https://www.googleapis.com/drive/v3/files';
  static const String _driveAboutUrl =
      'https://www.googleapis.com/drive/v3/about?fields=user';
  static const String _driveUploadUrl =
      'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart';

  final http.Client _httpClient;

  GoogleDriveClient([http.Client? client])
    : _httpClient = client ?? http.Client();

  /// 1. Verify Google Account Access via Drive API
  Future<GoogleDriveAccountInfo> verifyAccountAccess({
    required String accessToken,
  }) async {
    _validateToken(accessToken);

    try {
      final response = await _httpClient.get(
        Uri.parse(_driveAboutUrl),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return GoogleDriveAccountInfo.fromJson(data);
      } else {
        _handleHttpError(response, 'verify Google Drive account access');
      }
    } on SocketException {
      throw const NetworkFailure(
        'Cannot connect to Google Drive. Offline mode active.',
      );
    }
  }

  /// 2. Ensures a folder exists on Drive; creates it if absent.
  /// Deduplicates and consolidates duplicate root folders if multiple exist.
  Future<String> getOrCreateFolder({
    required String accessToken,
    required String folderName,
    String? parentFolderId,
  }) async {
    _validateToken(accessToken);

    try {
      final isRoot = parentFolderId == null || parentFolderId == 'root';
      final compactName = folderName.replaceAll(' ', '');

      // Root search finds either "Apna Clinic" or "ApnaClinic"
      final query = isRoot
          ? "mimeType = 'application/vnd.google-apps.folder' and (name = '${AppConstants.driveRootFolder}' or name = 'ApnaClinic' or name = 'Apna Clinic') and trashed = false"
          : "mimeType = 'application/vnd.google-apps.folder' and (name = '$folderName' or name = '$compactName') and '$parentFolderId' in parents and trashed = false";

      final searchUrl = Uri.parse(
        '$_driveFilesUrl?q=${Uri.encodeComponent(query)}&fields=files(id,name,parents,createdTime)&orderBy=createdTime asc',
      );
      final searchRes = await _httpClient.get(
        searchUrl,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (searchRes.statusCode == 200) {
        final data = jsonDecode(searchRes.body) as Map<String, dynamic>;
        final files =
            (data['files'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        if (files.isNotEmpty) {
          if (!isRoot || files.length == 1) {
            return files.first['id'] as String;
          }

          // Multiple root folders exist ("Apna Clinic" and "ApnaClinic")!
          // Consolidate into exactly ONE canonical root folder.
          AppLogger.info(
            'Found ${files.length} duplicate root folders on Drive. Consolidating into one canonical folder...',
          );

          Map<String, dynamic>? winnerFolder;
          final emptyDuplicates = <Map<String, dynamic>>[];

          for (final f in files) {
            final fId = f['id'] as String;
            try {
              final childQuery = "'$fId' in parents and trashed = false";
              final childRes = await _httpClient.get(
                Uri.parse(
                  '$_driveFilesUrl?q=${Uri.encodeComponent(childQuery)}&fields=files(id,name,mimeType)',
                ),
                headers: {'Authorization': 'Bearer $accessToken'},
              );
              if (childRes.statusCode == 200) {
                final childData =
                    jsonDecode(childRes.body) as Map<String, dynamic>;
                final children = (childData['files'] as List?) ?? [];
                if (children.isNotEmpty) {
                  winnerFolder ??= f; // Prioritize the folder that actually contains files/workspaces
                } else {
                  emptyDuplicates.add(f);
                }
              }
            } catch (_) {}
          }

          // Fallback to the first folder if none or all had children
          winnerFolder ??= files.first;
          final winnerId = winnerFolder['id'] as String;

          // Remove the selected winner from empty list if it was placed there
          emptyDuplicates.removeWhere((f) => f['id'] == winnerId);

          // Trash the empty duplicate folder(s) so only ONE folder exists in user's Drive!
          for (final dup in emptyDuplicates) {
            final dupId = dup['id'] as String;
            try {
              await _httpClient.patch(
                Uri.parse('$_driveFilesUrl/$dupId'),
                headers: {
                  'Authorization': 'Bearer $accessToken',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({'trashed': true}),
              );
              AppLogger.info(
                'Cleaned up duplicate empty Drive folder: $dupId ("${dup['name']}")',
              );
            } catch (e) {
              AppLogger.warning('Could not trash duplicate folder $dupId: $e');
            }
          }

          // Ensure the winner folder has the canonical title "Apna Clinic"
          if (winnerFolder['name'] != AppConstants.driveRootFolder) {
            try {
              await _httpClient.patch(
                Uri.parse('$_driveFilesUrl/$winnerId'),
                headers: {
                  'Authorization': 'Bearer $accessToken',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({'name': AppConstants.driveRootFolder}),
              );
            } catch (_) {}
          }

          return winnerId;
        }
      } else {
        _handleHttpError(searchRes, 'search for Drive folder "$folderName"');
      }

      // Folder not found — create it with canonical name
      final targetName = isRoot ? AppConstants.driveRootFolder : folderName;
      final createBody = jsonEncode({
        'name': targetName,
        'mimeType': 'application/vnd.google-apps.folder',
        if (parentFolderId != null) 'parents': [parentFolderId],
      });

      final createRes = await _httpClient.post(
        Uri.parse(_driveFilesUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: createBody,
      );

      if (createRes.statusCode == 200 || createRes.statusCode == 201) {
        final data = jsonDecode(createRes.body) as Map<String, dynamic>;
        return data['id'] as String;
      } else {
        _handleHttpError(createRes, 'create Drive folder "$targetName"');
      }
    } on SocketException {
      throw const NetworkFailure(
        'Cannot connect to Google Drive. Offline mode active.',
      );
    }
  }

  /// 3. Locates designated Master Sheet spreadsheet file inside parent folder
  Future<DriveFileMetadata?> locateMasterSheetFile({
    required String accessToken,
    required String parentFolderId,
    String fileName = 'APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL',
  }) async {
    _validateToken(accessToken);

    try {
      final query =
          "name contains '$fileName' and '$parentFolderId' in parents and trashed = false";

      final url = Uri.parse(
        '$_driveFilesUrl?q=${Uri.encodeComponent(query)}&fields=files(id,name,mimeType,parents,capabilities)',
      );

      final response = await _httpClient.get(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final files = data['files'] as List?;
        if (files != null && files.isNotEmpty) {
          return DriveFileMetadata.fromJson(
            files.first as Map<String, dynamic>,
          );
        }
        return null;
      } else {
        _handleHttpError(response, 'locate Master Sheet file');
      }
    } on SocketException {
      throw const NetworkFailure(
        'Cannot connect to Google Drive. Offline mode active.',
      );
    }
  }

  /// Locates any existing Apna Clinic Master Spreadsheet anywhere in the user's Google Drive.
  /// Useful when a spreadsheet was created prior to moving, or exists in root "My Drive".
  Future<DriveFileMetadata?> findAnyMasterSheetFile({
    required String accessToken,
    List<String> candidateNames = const [
      'ApnaClinic_MasterData',
      'APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL',
      'ApnaClinic_Master',
      'ApnaClinic',
      'Apna Clinic',
      'Apna_Clinic',
      'APNA_CLINIC',
      'APNA CLINIC',
      'MasterData',
      'Master Data',
      'MasterSheet',
    ],
  }) async {
    _validateToken(accessToken);
    try {
      final nameQueries = candidateNames
          .map((n) => "name contains '$n'")
          .join(' or ');
      final query =
          "mimeType = 'application/vnd.google-apps.spreadsheet' and ($nameQueries) and trashed = false";

      final url = Uri.parse(
        '$_driveFilesUrl?q=${Uri.encodeComponent(query)}&fields=files(id,name,mimeType,parents,capabilities)',
      );

      final response = await _httpClient.get(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final files = data['files'] as List?;
        if (files != null && files.isNotEmpty) {
          return DriveFileMetadata.fromJson(
            files.first as Map<String, dynamic>,
          );
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Retrieves metadata for a file, including parents and capabilities
  Future<DriveFileMetadata?> getFileMetadata({
    required String accessToken,
    required String fileId,
  }) async {
    _validateToken(accessToken);
    try {
      final url = Uri.parse(
        '$_driveFilesUrl/$fileId?fields=id,name,mimeType,parents,capabilities',
      );
      final response = await _httpClient.get(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return DriveFileMetadata.fromJson(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 4. Verifies permissions for a designated file
  Future<GoogleDriveFilePermissions> verifyFilePermissions({
    required String accessToken,
    required String fileId,
  }) async {
    _validateToken(accessToken);

    try {
      final url = Uri.parse('$_driveFilesUrl/$fileId?fields=capabilities');
      final response = await _httpClient.get(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final capabilities =
            data['capabilities'] as Map<String, dynamic>? ?? {};
        return GoogleDriveFilePermissions.fromCapabilities(capabilities);
      } else {
        _handleHttpError(response, 'verify file permissions');
      }
    } on SocketException {
      throw const NetworkFailure(
        'Cannot connect to Google Drive. Offline mode active.',
      );
    }
  }

  /// Sets up canonical clinic folder hierarchy: Apna Clinic/{clinic_id}/Backups/Encrypted/
  Future<String> initializeClinicBackupFolder({
    required String accessToken,
    required String clinicId,
  }) async {
    final rootId = await getOrCreateFolder(
      accessToken: accessToken,
      folderName: AppConstants.driveRootFolder,
    );

    final cleanClinicFolder = clinicId.startsWith('clinic_')
        ? clinicId
        : 'clinic_$clinicId';
    final clinicFolderId = await getOrCreateFolder(
      accessToken: accessToken,
      folderName: cleanClinicFolder,
      parentFolderId: rootId,
    );

    final backupsFolderId = await getOrCreateFolder(
      accessToken: accessToken,
      folderName: 'Backups',
      parentFolderId: clinicFolderId,
    );

    final encryptedFolderId = await getOrCreateFolder(
      accessToken: accessToken,
      folderName: 'Encrypted',
      parentFolderId: backupsFolderId,
    );

    AppLogger.info(
      'Clinic Drive backup folder initialized: $encryptedFolderId',
    );
    return encryptedFolderId;
  }

  /// Sets up canonical clinic branding folder hierarchy: Apna Clinic/{clinic_id}/Branding/
  Future<String> initializeClinicBrandingFolder({
    required String accessToken,
    required String clinicId,
  }) async {
    final rootId = await getOrCreateFolder(
      accessToken: accessToken,
      folderName: AppConstants.driveRootFolder,
    );

    final cleanClinicFolder = clinicId.startsWith('clinic_')
        ? clinicId
        : 'clinic_$clinicId';
    final clinicFolderId = await getOrCreateFolder(
      accessToken: accessToken,
      folderName: cleanClinicFolder,
      parentFolderId: rootId,
    );

    final brandingFolderId = await getOrCreateFolder(
      accessToken: accessToken,
      folderName: 'Branding',
      parentFolderId: clinicFolderId,
    );

    AppLogger.info(
      'Clinic Drive branding folder initialized: $brandingFolderId',
    );
    return brandingFolderId;
  }

  /// Uploads binary file (such as clinic logo image) to Drive
  Future<String> uploadBinaryFile({
    required String accessToken,
    required String parentFolderId,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    _validateToken(accessToken);
    const boundary = 'apna_clinic_multipart_boundary';
    final metadata = jsonEncode({
      'name': fileName,
      'parents': [parentFolderId],
      'mimeType': mimeType,
    });

    final metadataHeader =
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$metadata\r\n'
        '--$boundary\r\n'
        'Content-Type: $mimeType\r\n'
        'Content-Transfer-Encoding: base64\r\n\r\n';

    final base64Content = base64Encode(bytes);
    const footer = '\r\n--$boundary--';

    final body = metadataHeader + base64Content + footer;

    try {
      final response = await _httpClient.post(
        Uri.parse(_driveUploadUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'multipart/related; boundary=$boundary',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['id'] as String;
      } else {
        _handleHttpError(response, 'upload binary file to Drive');
      }
    } on SocketException {
      throw const NetworkFailure(
        'Cannot connect to Google Drive. Offline mode active.',
      );
    }
  }

  /// Uploads encrypted backup archive payload to Drive
  Future<String> uploadEncryptedBackup({
    required String accessToken,
    required String parentFolderId,
    required String fileName,
    required String encryptedPayloadJson,
  }) async {
    _validateToken(accessToken);
    const boundary = 'apna_clinic_multipart_boundary';
    final metadata = jsonEncode({
      'name': fileName,
      'parents': [parentFolderId],
      'mimeType': 'application/json',
    });

    final multipartBody =
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$metadata\r\n'
        '--$boundary\r\n'
        'Content-Type: application/json\r\n\r\n'
        '$encryptedPayloadJson\r\n'
        '--$boundary--';

    try {
      final response = await _httpClient.post(
        Uri.parse(_driveUploadUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'multipart/related; boundary=$boundary',
        },
        body: multipartBody,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['id'] as String;
      } else {
        _handleHttpError(response, 'upload encrypted backup to Drive');
      }
    } on SocketException {
      throw const NetworkFailure(
        'Cannot connect to Google Drive. Offline mode active.',
      );
    }
  }

  /// Downloads backup file content by Drive file ID
  Future<String> downloadBackupFile({
    required String accessToken,
    required String fileId,
  }) async {
    _validateToken(accessToken);
    try {
      final url = Uri.parse('$_driveFilesUrl/$fileId?alt=media');
      final response = await _httpClient.get(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        return response.body;
      } else {
        _handleHttpError(response, 'download backup file from Drive');
      }
    } on SocketException {
      throw const NetworkFailure(
        'Cannot connect to Google Drive. Offline mode active.',
      );
    }
  }

  /// 5. Creates a native Google Spreadsheet directly inside the target folder
  /// using Google Drive API v3. This eliminates post-creation moves and multiple parents issues.
  Future<String> createSpreadsheetInFolder({
    required String accessToken,
    required String parentFolderId,
    required String fileName,
  }) async {
    _validateToken(accessToken);
    try {
      final createBody = jsonEncode({
        'name': fileName,
        'mimeType': 'application/vnd.google-apps.spreadsheet',
        'parents': [parentFolderId],
      });

      final createRes = await _httpClient.post(
        Uri.parse(_driveFilesUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: createBody,
      );

      if (createRes.statusCode == 200 || createRes.statusCode == 201) {
        final data = jsonDecode(createRes.body) as Map<String, dynamic>;
        return data['id'] as String;
      } else {
        _handleHttpError(
          createRes,
          'create Google Spreadsheet in folder "$fileName"',
        );
      }
    } on SocketException {
      throw const NetworkFailure(
        'Cannot connect to Google Drive. Offline mode active.',
      );
    }
  }

  /// 5b. Moves a file into a target folder on Drive (Drive API v3 PATCH addParents/removeParents)
  Future<void> moveFileToFolder({
    required String accessToken,
    required String fileId,
    required String targetFolderId,
    String? removeParents,
  }) async {
    _validateToken(accessToken);
    try {
      String? parentsToRemove = removeParents;
      if (parentsToRemove == null || parentsToRemove.isEmpty) {
        final meta = await getFileMetadata(
          accessToken: accessToken,
          fileId: fileId,
        );
        if (meta != null && meta.parents.isNotEmpty) {
          if (meta.parents.contains(targetFolderId))
            return; // Already in target folder
          parentsToRemove = meta.parents.join(',');
        }
      }

      var query = 'addParents=$targetFolderId&fields=id,parents';
      if (parentsToRemove != null && parentsToRemove.isNotEmpty) {
        query += '&removeParents=$parentsToRemove';
      }
      final url = Uri.parse('$_driveFilesUrl/$fileId?$query');
      final response = await _httpClient.patch(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}),
      );

      if (response.statusCode != 200) {
        _handleHttpError(response, 'move file to Drive folder');
      }
    } on SocketException {
      throw const NetworkFailure(
        'Cannot connect to Google Drive. Offline mode active.',
      );
    }
  }

  /// 6. Uploads an Excel workbook (.xlsx) and converts it to a native Google Spreadsheet
  Future<String> uploadExcelAsGoogleSheet({
    required String accessToken,
    required String parentFolderId,
    required String fileName,
    required List<int> xlsxBytes,
  }) async {
    _validateToken(accessToken);
    const boundary = 'apna_clinic_multipart_boundary';
    final metadata = jsonEncode({
      'name': fileName,
      'parents': [parentFolderId],
      'mimeType': 'application/vnd.google-apps.spreadsheet',
    });

    final metadataHeader =
        '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$metadata\r\n'
        '--$boundary\r\n'
        'Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet\r\n\r\n';

    const footer = '\r\n--$boundary--';
    final bodyBytes = [
      ...utf8.encode(metadataHeader),
      ...xlsxBytes,
      ...utf8.encode(footer),
    ];

    try {
      final response = await _httpClient.post(
        Uri.parse(_driveUploadUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'multipart/related; boundary=$boundary',
        },
        body: bodyBytes,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['id'] as String;
      } else {
        _handleHttpError(response, 'upload Excel workbook to Google Drive');
      }
    } on SocketException {
      throw const NetworkFailure(
        'Cannot connect to Google Drive. Offline mode active.',
      );
    }
  }

  void _validateToken(String token) {
    if (token.trim().isEmpty) {
      throw const AuthorizationFailure('Google OAuth access token is missing.');
    }
  }

  Never _handleHttpError(http.Response response, String action) {
    final status = response.statusCode;
    String detail = response.body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final err = decoded['error'];
        if (err is Map<String, dynamic> && err['message'] != null) {
          detail = err['message'].toString();
        } else if (err is String) {
          detail = err;
        }
      }
    } catch (_) {}

    if (status == 401) {
      throw AuthorizationFailure(
        'Google OAuth token expired or invalid ($detail).',
      );
    } else if (status == 403) {
      throw AuthorizationFailure(
        'Google Drive access denied ($detail). Ensure Google Drive API is enabled in Google Cloud Console.',
      );
    } else if (status == 404) {
      throw DatabaseFailure('Google Drive resource not found ($detail).');
    } else if (status == 429) {
      throw QuotaExceededFailure(
        'Google Drive API rate limit exceeded ($detail). Please back off.',
      );
    } else if (status >= 500) {
      throw NetworkFailure(
        'Google Drive service is temporarily unavailable ($status): $detail',
      );
    } else {
      throw NetworkFailure('Failed to $action ($status): $detail');
    }
  }
}
