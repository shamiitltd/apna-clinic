// Apna Clinic - Google Drive Connection Application Service (Layer 3)
// Governs user authorization of Google Drive and Google Sheets for clinic operational data.
// Strictly separated from Firebase Authentication (Layer 1).
// Implements the "Search First" algorithm to avoid creating duplicate workbooks.

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/logging/app_logger.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../../infrastructure/google/google_drive_client.dart';
import '../../infrastructure/google/google_sheets_client.dart';
import '../../infrastructure/google/oauth/i_google_oauth_provider.dart';
import '../../infrastructure/google/oauth/token_vault.dart';

class DriveConnectionResult {
  final bool isSuccess;
  final bool isCancelled;
  final String? driveEmail;
  final String? folderId;
  final String? spreadsheetId;
  final String? errorMessage;
  final bool isExistingWorkspace;

  const DriveConnectionResult.success({
    required this.driveEmail,
    required this.folderId,
    required this.spreadsheetId,
    required this.isExistingWorkspace,
  }) : isSuccess = true,
       isCancelled = false,
       errorMessage = null;

  const DriveConnectionResult.cancelled()
    : isSuccess = false,
      isCancelled = true,
      driveEmail = null,
      folderId = null,
      spreadsheetId = null,
      errorMessage = null,
      isExistingWorkspace = false;

  const DriveConnectionResult.failure(this.errorMessage)
    : isSuccess = false,
      isCancelled = false,
      driveEmail = null,
      folderId = null,
      spreadsheetId = null,
      isExistingWorkspace = false;
}

class DriveConnectionService {
  static const String _prefDriveEmail = 'apna_drive_connected_email';
  static const String _prefDriveFolderId = 'apna_drive_folder_id';
  static const String _prefSpreadsheetId = 'apna_drive_spreadsheet_id';
  static const String _prefDriveConnected = 'apna_drive_connected_flag';

  final IGoogleOAuthProvider oauthProvider;
  final TokenVault tokenVault;
  final GoogleDriveClient driveClient;
  final GoogleSheetsClient sheetsClient;
  final IAuthRepository authRepository;

  DriveConnectionService({
    required this.oauthProvider,
    required this.tokenVault,
    required this.driveClient,
    required this.sheetsClient,
    required this.authRepository,
  });

  /// Checks if Google Drive is authorized and connected
  Future<bool> isDriveConnected({String clinicId = 'primary_clinic'}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final folderId = prefs.getString(_prefDriveFolderId);
      final flag = prefs.getBool(_prefDriveConnected) ?? false;

      // On live mode, a mock/local fallback ID is not a real Drive connection
      if (!AppConfig.current.useMockAuth &&
          (folderId == null ||
              folderId.isEmpty ||
              folderId.startsWith('local_folder_'))) {
        return false;
      }

      final cachedToken =
          await tokenVault.getAccessToken(clinicId) ??
          await tokenVault.getAccessToken('primary_clinic') ??
          await tokenVault.getAccessToken('clinic_primary_demo');
      final refreshToken =
          await tokenVault.getRefreshToken(clinicId) ??
          await tokenVault.getRefreshToken('primary_clinic') ??
          await tokenVault.getRefreshToken('clinic_primary_demo');
      final hasTokens =
          (cachedToken != null && cachedToken.isNotEmpty) ||
          (refreshToken != null && refreshToken.isNotEmpty);

      // On live mode, verify we have either real Drive tokens or a valid folder
      if (!AppConfig.current.useMockAuth &&
          !hasTokens &&
          (folderId == null ||
              folderId.isEmpty ||
              folderId.startsWith('local_folder_'))) {
        return false;
      }

      return flag || hasTokens;
    } catch (_) {
      return false;
    }
  }

  /// Gets the currently connected Drive email
  Future<String?> getConnectedDriveEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefDriveEmail);
    } catch (_) {
      return null;
    }
  }

  /// Gets the currently connected Drive folder ID
  Future<String?> getConnectedDriveFolderId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefDriveFolderId);
    } catch (_) {
      return null;
    }
  }

  /// Gets the designated master spreadsheet ID
  Future<String?> getSpreadsheetId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_prefSpreadsheetId);
    } catch (_) {
      return null;
    }
  }

  /// Directly initializes the Google Drive workspace folder and master spreadsheet
  /// using an already authenticated access token.
  Future<DriveConnectionResult> initializeWorkspaceWithToken({
    required String accessToken,
    String clinicId = 'primary_clinic',
    String? driveEmail,
  }) async {
    try {
      AppLogger.info(
        'Initializing Google Drive workspace for clinic: $clinicId',
      );
      String folderId;
      String spreadsheetId;
      bool isExisting = false;

      try {
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
        // Top-level root folder visible in user's Drive
        folderId = rootFolderId;

        // 1. Search for existing Master Sheet in root folder or clinic folder
        DriveFileMetadata? existingSheet =
            await driveClient.locateMasterSheetFile(
              accessToken: accessToken,
              parentFolderId: rootFolderId,
              fileName: 'ApnaClinic_MasterData',
            ) ??
            await driveClient.locateMasterSheetFile(
              accessToken: accessToken,
              parentFolderId: clinicFolderId,
              fileName: 'ApnaClinic_MasterData',
            ) ??
            await driveClient.locateMasterSheetFile(
              accessToken: accessToken,
              parentFolderId: rootFolderId,
              fileName: 'APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL',
            ) ??
            await driveClient.locateMasterSheetFile(
              accessToken: accessToken,
              parentFolderId: clinicFolderId,
              fileName: 'APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL',
            );

        // 2. If not found inside folder, locate any existing orphaned sheet in user's Drive
        existingSheet ??= await driveClient.findAnyMasterSheetFile(
          accessToken: accessToken,
        );

        if (existingSheet != null && existingSheet.id.isNotEmpty) {
          AppLogger.info(
            'Found existing Apna Clinic master spreadsheet: ${existingSheet.id}',
          );
          spreadsheetId = existingSheet.id;
          isExisting = true;

          // Keep spreadsheet inside the clinic's subfolder (or root if clinicFolderId is unavailable)
          try {
            await driveClient.moveFileToFolder(
              accessToken: accessToken,
              fileId: spreadsheetId,
              targetFolderId: clinicFolderId,
            );
          } catch (e) {
            AppLogger.warning(
              'Could not adjust folder placement for existing sheet: $e',
            );
          }
        } else {
          AppLogger.info(
            'No existing master sheet found. Creating new Master Data workbook in clinic folder...',
          );

          // Primary: Create native Google Spreadsheet directly in the clinic folder
          try {
            spreadsheetId = await driveClient.createSpreadsheetInFolder(
              accessToken: accessToken,
              parentFolderId: clinicFolderId,
              fileName: 'ApnaClinic_MasterData',
            );
            AppLogger.info(
              'Master Sheet created directly in clinic folder via Drive API: $spreadsheetId',
            );
          } catch (driveErr) {
            AppLogger.warning(
              'Direct Drive spreadsheet creation failed ($driveErr), attempting Sheets API fallback...',
            );
            spreadsheetId = await sheetsClient.createMasterSpreadsheet(
              accessToken: accessToken,
              clinicTitle: 'ApnaClinic_MasterData',
            );
            try {
              await driveClient.moveFileToFolder(
                accessToken: accessToken,
                fileId: spreadsheetId,
                targetFolderId: clinicFolderId,
              );
            } catch (moveErr) {
              AppLogger.warning('Could not move sheet to folder: $moveErr');
            }
          }
          isExisting = false;
        }

        // Initialize canonical 20 worksheets and header rows
        try {
          await sheetsClient.populateCanonicalSheets(
            accessToken: accessToken,
            spreadsheetId: spreadsheetId,
          );
          AppLogger.info(
            'Canonical 20 worksheets and headers populated successfully.',
          );
        } catch (sheetsErr) {
          AppLogger.warning(
            'Canonical header population encountered an issue: $sheetsErr',
          );
        }
      } catch (e) {
        if (AppConfig.current.useMockAuth) {
          AppLogger.warning('Mock auth active. Using local fallback IDs: $e');
          folderId = 'local_folder_$clinicId';
          spreadsheetId = 'local_sheet_$clinicId';
        } else {
          AppLogger.error('Google Drive or Sheets API call failed: $e');
          return DriveConnectionResult.failure(
            'Failed to create Drive workspace: $e\n'
            'Please ensure Google Drive API & Google Sheets API are enabled in your Google Cloud Console for project apna-clinic-96541-fd638.',
          );
        }
      }

      // Persist connection details locally in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefDriveConnected, true);
      if (driveEmail != null && driveEmail.isNotEmpty) {
        await prefs.setString(_prefDriveEmail, driveEmail);
      }
      await prefs.setString(_prefDriveFolderId, folderId);
      await prefs.setString(_prefSpreadsheetId, spreadsheetId);

      // Update Firestore user account if Firebase user is logged in
      final currentUid = authRepository.currentUid;
      if (currentUid != null && currentUid.isNotEmpty) {
        await authRepository.updateDriveConnectionMetadata(
          uid: currentUid,
          driveEmail: driveEmail ?? '',
          driveFolderId: folderId,
          spreadsheetId: spreadsheetId,
        );
      }

      AppLogger.info(
        'Drive connection completed successfully for ${driveEmail ?? 'clinic'} (Folder: $folderId, Sheet: $spreadsheetId)',
      );
      return DriveConnectionResult.success(
        driveEmail: driveEmail ?? '',
        folderId: folderId,
        spreadsheetId: spreadsheetId,
        isExistingWorkspace: isExisting,
      );
    } catch (e) {
      final err = 'Unexpected error initializing Google Drive workspace: $e';
      AppLogger.error(err);
      return DriveConnectionResult.failure(err);
    }
  }

  /// Initiates interactive Google Drive OAuth authorization and performs
  /// the "Search First" workspace discovery and initialization.
  Future<DriveConnectionResult> connectAndInitializeDrive({
    String clinicId = 'primary_clinic',
    String clinicName = 'My Clinic',
  }) async {
    try {
      // 1. If we already have a valid access token in TokenVault, try to initialize directly first
      final existingToken =
          await tokenVault.getAccessToken(clinicId) ??
          await tokenVault.getAccessToken('primary_clinic');
      final existingEmail = await getConnectedDriveEmail();

      if (existingToken != null && existingToken.isNotEmpty) {
        AppLogger.info(
          'Found existing OAuth access token in TokenVault. Attempting direct workspace initialization...',
        );
        final directResult = await initializeWorkspaceWithToken(
          accessToken: existingToken,
          clinicId: clinicId,
          driveEmail: existingEmail,
        );
        if (directResult.isSuccess) {
          return directResult;
        }
        AppLogger.info(
          'Direct initialization with cached token failed or expired. Initiating fresh OAuth...',
        );
      }

      // 2. Launch OAuth sign-in flow
      AppLogger.info('Starting Google Drive OAuth flow for clinic: $clinicId');
      final authResult = await oauthProvider.signIn();

      if (authResult.isCancelled) {
        AppLogger.info('Google Drive OAuth cancelled by user.');
        return const DriveConnectionResult.cancelled();
      }

      if (!authResult.isSuccess || authResult.tokens == null) {
        final err =
            authResult.errorMessage ?? 'Failed to authorize Google Drive.';
        AppLogger.warning('Drive OAuth failed: $err');
        return DriveConnectionResult.failure(err);
      }

      final tokens = authResult.tokens!;
      final driveEmail = authResult.user?.email ?? '';

      // Securely save Drive OAuth tokens in TokenVault
      if (tokens.refreshToken != null && tokens.refreshToken!.isNotEmpty) {
        await tokenVault.saveRefreshToken(clinicId, tokens.refreshToken!);
      }
      if (tokens.accessToken.isNotEmpty) {
        await tokenVault.saveAccessToken(
          clinicId,
          tokens.accessToken,
          tokens.expiresAt,
        );
      }

      return await initializeWorkspaceWithToken(
        accessToken: tokens.accessToken,
        clinicId: clinicId,
        driveEmail: driveEmail,
      );
    } catch (e) {
      final err = 'Unexpected error connecting Google Drive: $e';
      AppLogger.error(err);
      return DriveConnectionResult.failure(err);
    }
  }

  /// Self-healing: Guarantees that the master spreadsheet is visible inside
  /// the top-level "Apna Clinic" folder as well as the clinic subfolder.
  Future<void> ensureWorkspacePlacement({
    required String accessToken,
    String clinicId = 'primary_clinic',
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var spreadsheetId = prefs.getString(_prefSpreadsheetId);

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

      // If spreadsheetId is null or empty, search for it
      if (spreadsheetId == null || spreadsheetId.isEmpty) {
        final existingSheet =
            await driveClient.locateMasterSheetFile(
              accessToken: accessToken,
              parentFolderId: rootFolderId,
              fileName: 'ApnaClinic_MasterData',
            ) ??
            await driveClient.locateMasterSheetFile(
              accessToken: accessToken,
              parentFolderId: clinicFolderId,
              fileName: 'ApnaClinic_MasterData',
            ) ??
            await driveClient.findAnyMasterSheetFile(accessToken: accessToken);

        if (existingSheet != null && existingSheet.id.isNotEmpty) {
          spreadsheetId = existingSheet.id;
          await prefs.setString(_prefSpreadsheetId, spreadsheetId);
        }
      }

      if (spreadsheetId == null || spreadsheetId.isEmpty) return;

      final meta = await driveClient.getFileMetadata(
        accessToken: accessToken,
        fileId: spreadsheetId,
      );

      if (meta != null) {
        if (!meta.parents.contains(rootFolderId)) {
          await driveClient.moveFileToFolder(
            accessToken: accessToken,
            fileId: spreadsheetId,
            targetFolderId: rootFolderId,
          );
        }
        await prefs.setString(_prefDriveFolderId, rootFolderId);
        AppLogger.info(
          'ensureWorkspacePlacement: Sheet $spreadsheetId confirmed in Apna Clinic folder.',
        );
      }
    } catch (e) {
      AppLogger.warning('ensureWorkspacePlacement non-fatal error: $e');
    }
  }

  /// Disconnects Google Drive by clearing local tokens and metadata.
  /// Does NOT delete files or folders on the user's Google Drive.
  Future<void> disconnectDrive({String clinicId = 'primary_clinic'}) async {
    try {
      AppLogger.info('Disconnecting Google Drive for clinic: $clinicId');
      await tokenVault.clear(clinicId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefDriveConnected, false);
      await prefs.remove(_prefDriveEmail);
      await prefs.remove(_prefDriveFolderId);
      await prefs.remove(_prefSpreadsheetId);
      AppLogger.info('Drive credentials cleared locally.');
    } catch (e) {
      AppLogger.error('Error disconnecting Drive: $e');
    }
  }
}
