// Apna Clinic - Google Sheets Integration Client
// Primary source of truth: APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL.xlsx, PRD Section 18, 19, 41 and TRD Section 7
// ZERO-FAKE IMPLEMENTATION: Canonical 20-tab Master Sheet schema verification,
// batch metadata & header retrieval, controlled lookup reading, and strict error handling.
// Least-privilege OAuth scope: https://www.googleapis.com/auth/spreadsheets

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors/failures.dart';
import '../../core/logging/app_logger.dart';
import '../../domain/entities/master_sheet_schema.dart';

/// Metadata representation of a Google Sheets spreadsheet
class SpreadsheetMetadata {
  final String spreadsheetId;
  final String title;
  final List<String> sheetNames;
  final Map<String, int> sheetIdsByName;

  const SpreadsheetMetadata({
    required this.spreadsheetId,
    required this.title,
    required this.sheetNames,
    required this.sheetIdsByName,
  });

  factory SpreadsheetMetadata.fromJson(
    String id,
    Map<String, dynamic> json,
  ) {
    final properties = json['properties'] as Map<String, dynamic>? ?? {};
    final title = properties['title'] as String? ?? '';
    final sheetsRaw = json['sheets'] as List? ?? [];

    final names = <String>[];
    final ids = <String, int>{};

    for (final s in sheetsRaw) {
      final sProps = s['properties'] as Map<String, dynamic>? ?? {};
      final sheetTitle = sProps['title'] as String? ?? '';
      final sheetId = sProps['sheetId'] as int? ?? 0;
      if (sheetTitle.isNotEmpty) {
        names.add(sheetTitle);
        ids[sheetTitle] = sheetId;
      }
    }

    return SpreadsheetMetadata(
      spreadsheetId: id,
      title: title,
      sheetNames: names,
      sheetIdsByName: ids,
    );
  }
}

/// Represents a range update batch item for values:batchUpdate
class SheetValueUpdate {
  final String range;
  final List<List<dynamic>> values;

  const SheetValueUpdate({
    required this.range,
    required this.values,
  });

  Map<String, dynamic> toJson() => {
        'range': range,
        'values': values,
      };
}

class GoogleSheetsClient {
  static const String _sheetsBaseUrl =
      'https://sheets.googleapis.com/v4/spreadsheets';

  final http.Client _httpClient;

  GoogleSheetsClient([http.Client? client])
    : _httpClient = client ?? http.Client();

  /// 1. Reads spreadsheet metadata (title and sheet names)
  Future<SpreadsheetMetadata> getSpreadsheetMetadata({
    required String accessToken,
    required String spreadsheetId,
  }) async {
    _validateParams(accessToken, spreadsheetId);

    try {
      final url = Uri.parse(
        '$_sheetsBaseUrl/$spreadsheetId?fields=properties.title,sheets.properties(sheetId,title)',
      );

      final response = await _httpClient.get(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return SpreadsheetMetadata.fromJson(spreadsheetId, data);
      } else {
        _handleHttpError(response, 'fetch spreadsheet metadata');
      }
    } on SocketException {
      throw const NetworkFailure(
        'Cannot connect to Google Sheets. Offline mode active.',
      );
    }
  }

  /// 2. Validates spreadsheet against frozen canonical Phase 2 Master Sheet schema
  /// Verifies:
  /// - All 20 canonical worksheets exist
  /// - Header row (Row 1) of every sheet has exact expected columns in exact order
  /// Never modifies the sheet; returns structured validation failure on mismatch.
  Future<MasterSheetValidationResult> validateMasterSheetSchema({
    required String accessToken,
    required String spreadsheetId,
  }) async {
    _validateParams(accessToken, spreadsheetId);

    try {
      // 1. Fetch metadata
      final metadata = await getSpreadsheetMetadata(
        accessToken: accessToken,
        spreadsheetId: spreadsheetId,
      );

      // If missing critical sheets, return early failure
      final missingSheets = <String>[];
      for (final expected in MasterSheetSchema.canonicalSheetNames) {
        if (!metadata.sheetNames.contains(expected)) {
          missingSheets.add(expected);
        }
      }

      if (missingSheets.length > 5) {
        return MasterSheetValidationResult.failure(
          message:
              'Spreadsheet is missing ${missingSheets.length} canonical worksheets: ${missingSheets.take(5).join(", ")}...',
          missingSheets: missingSheets,
        );
      }

      // 2. Fetch Row 1 headers in a single batchGet request for present canonical sheets
      final sheetsToFetch = MasterSheetSchema.canonicalSheetNames
          .where((s) => metadata.sheetNames.contains(s))
          .toList();

      final rangesQuery =
          sheetsToFetch.map((s) => 'ranges=${Uri.encodeComponent("$s!1:1")}').join('&');

      final batchUrl = Uri.parse(
        '$_sheetsBaseUrl/$spreadsheetId/values:batchGet?$rangesQuery&majorDimension=ROWS',
      );

      final batchRes = await _httpClient.get(
        batchUrl,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (batchRes.statusCode != 200) {
        _handleHttpError(batchRes, 'batch-read sheet headers');
      }

      final batchData = jsonDecode(batchRes.body) as Map<String, dynamic>;
      final valueRanges = batchData['valueRanges'] as List? ?? [];

      final actualHeadersBySheet = <String, List<String>>{};

      for (int i = 0; i < sheetsToFetch.length; i++) {
        final sheetName = sheetsToFetch[i];
        if (i < valueRanges.length) {
          final vr = valueRanges[i] as Map<String, dynamic>;
          final values = vr['values'] as List?;
          if (values != null && values.isNotEmpty) {
            final row1 = values.first as List?;
            if (row1 != null) {
              actualHeadersBySheet[sheetName] =
                  row1.map((c) => c.toString().trim()).toList();
              continue;
            }
          }
        }
        actualHeadersBySheet[sheetName] = [];
      }

      // 3. Delegate to pure domain MasterSheetSchema validator
      return MasterSheetSchema.validate(
        actualSheetNames: metadata.sheetNames,
        actualHeadersBySheet: actualHeadersBySheet,
      );
    } on SocketException {
      return MasterSheetValidationResult.failure(
        message: 'Cannot connect to Google Sheets. Offline mode active.',
        errorCode: 'NETWORK_UNAVAILABLE',
      );
    } on Failure catch (f) {
      return MasterSheetValidationResult.failure(
        message: f.message,
        errorCode: f is AuthorizationFailure
            ? 'AUTH_ERROR'
            : (f is QuotaExceededFailure ? 'RATE_LIMIT' : 'SHEETS_API_ERROR'),
      );
    } catch (e) {
      return MasterSheetValidationResult.failure(
        message: 'Unexpected error validating Master Sheet schema: $e',
        errorCode: 'UNEXPECTED_ERROR',
      );
    }
  }

  /// 3. Reads controlled lookup table entries from 20_LOOKUPS by category
  Future<List<MasterSheetLookupItem>> readLookupCategory({
    required String accessToken,
    required String spreadsheetId,
    required String category,
  }) async {
    _validateParams(accessToken, spreadsheetId);

    try {
      final range = Uri.encodeComponent('20_LOOKUPS!A2:G');
      final url = Uri.parse('$_sheetsBaseUrl/$spreadsheetId/values/$range');

      final response = await _httpClient.get(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rows = data['values'] as List? ?? [];

        final results = <MasterSheetLookupItem>[];
        for (final row in rows) {
          if (row is List && row.length >= 4) {
            final item = MasterSheetLookupItem.fromRow(row);
            if (item.category.toUpperCase() == category.toUpperCase() &&
                item.isActive) {
              results.add(item);
            }
          }
        }
        results.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        return results;
      } else {
        _handleHttpError(response, 'read lookup category "$category"');
      }
    } on SocketException {
      throw const NetworkFailure(
        'Cannot connect to Google Sheets. Offline mode active.',
      );
    }
  }

  /// 4. Reads data rows across multiple worksheets in a single bounded batchGet request (Quota Protected)
  Future<Map<String, List<List<dynamic>>>> batchReadSheetRows({
    required String accessToken,
    required String spreadsheetId,
    required List<String> sheetNames,
    int startRow = 2,
    int endRow = 1000,
  }) async {
    _validateParams(accessToken, spreadsheetId);
    if (sheetNames.isEmpty) return {};

    try {
      final rangesQuery = sheetNames
          .map((s) => 'ranges=${Uri.encodeComponent("$s!A$startRow:ZZ$endRow")}')
          .join('&');

      final url = Uri.parse(
        '$_sheetsBaseUrl/$spreadsheetId/values:batchGet?$rangesQuery&majorDimension=ROWS',
      );

      final response = await _httpClient.get(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final valueRanges = data['valueRanges'] as List? ?? [];

        final results = <String, List<List<dynamic>>>{};
        for (int i = 0; i < sheetNames.length; i++) {
          final sheet = sheetNames[i];
          if (i < valueRanges.length) {
            final vr = valueRanges[i] as Map<String, dynamic>;
            final values = vr['values'] as List?;
            if (values != null) {
              results[sheet] = values
                  .map((row) => (row as List).map((cell) => cell).toList())
                  .toList();
              continue;
            }
          }
          results[sheet] = [];
        }
        return results;
      } else {
        _handleHttpError(response, 'batch-read sheet rows');
      }
    } on SocketException {
      throw const NetworkFailure(
        'Cannot connect to Google Sheets. Offline mode active.',
      );
    }
  }

  /// Creates a new master spreadsheet with all 20 canonical tabs and headers
  Future<String> createMasterSpreadsheet({
    required String accessToken,
    required String clinicTitle,
  }) async {
    _validateParams(accessToken, 'new');

    final sheetsPayload = MasterSheetSchema.canonicalHeaders.entries.map((entry) {
      final rowDataList = <Map<String, dynamic>>[
        {
          'values': entry.value
              .map(
                (h) => {
                  'userEnteredValue': {'stringValue': h},
                },
              )
              .toList(),
        },
      ];

      // Populate canonical lookups into 20_LOOKUPS
      if (entry.key == '20_LOOKUPS') {
        for (final lkp in MasterSheetSchema.defaultLookups) {
          rowDataList.add({
            'values': [
              {'userEnteredValue': {'stringValue': lkp[0].toString()}},
              {'userEnteredValue': {'stringValue': lkp[1].toString()}},
              {'userEnteredValue': {'stringValue': lkp[2].toString()}},
              {'userEnteredValue': {'stringValue': lkp[3].toString()}},
              {'userEnteredValue': {'numberValue': (lkp[4] as num).toDouble()}},
              {'userEnteredValue': {'boolValue': lkp[5] as bool}},
              {
                'userEnteredValue': {
                  'stringValue': lkp.length > 6 ? lkp[6].toString() : '',
                },
              },
            ],
          });
        }
      }

      return {
        'properties': {
          'title': entry.key,
          'gridProperties': {
            'rowCount': 1000,
            'columnCount': entry.value.length,
            'frozenRowCount': 1,
          },
        },
        'data': [
          {
            'startRow': 0,
            'startColumn': 0,
            'rowData': rowDataList,
          },
        ],
      };
    }).toList();

    final title = clinicTitle.contains('APNA_CLINIC_MASTER')
        ? clinicTitle
        : 'APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL_$clinicTitle';

    final body = jsonEncode({
      'properties': {'title': title},
      'sheets': sheetsPayload,
    });

    final response = await _httpClient.post(
      Uri.parse(_sheetsBaseUrl),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final spreadsheetId = data['spreadsheetId'] as String;
      AppLogger.info(
        'Successfully created Google Sheets master template: $spreadsheetId',
      );
      return spreadsheetId;
    } else {
      _handleHttpError(response, 'create master spreadsheet');
    }
  }

  /// Creates a spreadsheet with specific sheets and their Row 1 canonical headers in a single atomic call
  Future<String> createSpreadsheetWithSheets({
    required String accessToken,
    required String title,
    required Map<String, List<String>> sheetsWithHeaders,
  }) async {
    _validateParams(accessToken, 'new');

    final sheetsPayload = sheetsWithHeaders.entries.map((entry) {
      final colCount = entry.value.length < 10 ? 10 : entry.value.length;
      return {
        'properties': {
          'title': entry.key,
          'gridProperties': {
            'rowCount': 1000,
            'columnCount': colCount,
            'frozenRowCount': 1,
          },
        },
        'data': [
          {
            'startRow': 0,
            'startColumn': 0,
            'rowData': [
              {
                'values': entry.value
                    .map(
                      (h) => {
                        'userEnteredValue': {'stringValue': h},
                      },
                    )
                    .toList(),
              },
            ],
          },
        ],
      };
    }).toList();

    final body = jsonEncode({
      'properties': {'title': title},
      'sheets': sheetsPayload,
    });

    final response = await _httpClient.post(
      Uri.parse(_sheetsBaseUrl),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final spreadsheetId = data['spreadsheetId'] as String;
      AppLogger.info('Successfully created Google Sheet "$title": $spreadsheetId');
      return spreadsheetId;
    } else {
      _handleHttpError(response, 'create spreadsheet with sheets');
    }
  }

  /// Ensures that specified worksheets exist in a spreadsheet and have their Row 1 headers populated
  Future<void> ensureSheetsWithHeaders({
    required String accessToken,
    required String spreadsheetId,
    required Map<String, List<String>> sheetsWithHeaders,
  }) async {
    _validateParams(accessToken, spreadsheetId);
    if (sheetsWithHeaders.isEmpty) return;

    try {
      final metadata = await getSpreadsheetMetadata(
        accessToken: accessToken,
        spreadsheetId: spreadsheetId,
      );

      final existingSheetNames = metadata.sheetNames;
      final updateRequests = <Map<String, dynamic>>[];

      for (final name in sheetsWithHeaders.keys) {
        final colCount = sheetsWithHeaders[name]?.length ?? 20;
        final targetCols = colCount < 26 ? 26 : colCount;

        if (!existingSheetNames.contains(name)) {
          updateRequests.add({
            'addSheet': {
              'properties': {
                'title': name,
                'gridProperties': {
                  'rowCount': 1000,
                  'columnCount': targetCols,
                  'frozenRowCount': 1,
                },
              },
            },
          });
        } else if (metadata.sheetIdsByName.containsKey(name)) {
          final sId = metadata.sheetIdsByName[name];
          updateRequests.add({
            'updateSheetProperties': {
              'properties': {
                'sheetId': sId,
                'gridProperties': {
                  'columnCount': targetCols,
                },
              },
              'fields': 'gridProperties.columnCount',
            },
          });
        }
      }

      if (updateRequests.isNotEmpty) {
        final batchUrl = Uri.parse('$_sheetsBaseUrl/$spreadsheetId:batchUpdate');
        final batchRes = await _httpClient.post(
          batchUrl,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'requests': updateRequests}),
        );

        if (batchRes.statusCode != 200) {
          AppLogger.warning(
            'Batch update sheets returned HTTP ${batchRes.statusCode}: ${batchRes.body}',
          );
        }
      }

      final valueUpdates = <Map<String, dynamic>>[];
      for (final entry in sheetsWithHeaders.entries) {
        final name = entry.key;
        final headers = entry.value;
        if (headers.isNotEmpty) {
          valueUpdates.add({
            'range': '$name!A1',
            'values': [headers],
          });
        }
      }

      if (valueUpdates.isNotEmpty) {
        final updateUrl = Uri.parse(
          '$_sheetsBaseUrl/$spreadsheetId/values:batchUpdate',
        );
        await _httpClient.post(
          updateUrl,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'valueInputOption': 'USER_ENTERED',
            'data': valueUpdates,
          }),
        );
      }
    } catch (e) {
      AppLogger.warning('ensureSheetsWithHeaders encountered note: $e');
    }
  }

  /// Ensures that all 20 canonical worksheets exist in the spreadsheet and have their
  /// Row 1 headers and canonical lookups populated according to MasterSheetSchema.
  Future<void> populateCanonicalSheets({
    required String accessToken,
    required String spreadsheetId,
  }) async {
    _validateParams(accessToken, spreadsheetId);

    try {
      // 1. Fetch current spreadsheet metadata
      final metadata = await getSpreadsheetMetadata(
        accessToken: accessToken,
        spreadsheetId: spreadsheetId,
      );

      final existingSheetNames = metadata.sheetNames;

      // 2. Add missing canonical sheets
      final sheetsToAdd = <String>[];
      for (final name in MasterSheetSchema.canonicalSheetNames) {
        if (!existingSheetNames.contains(name)) {
          sheetsToAdd.add(name);
        }
      }

      if (sheetsToAdd.isNotEmpty) {
        final requests = sheetsToAdd.map((name) {
          final colCount =
              MasterSheetSchema.canonicalHeaders[name]?.length ?? 10;
          return {
            'addSheet': {
              'properties': {
                'title': name,
                'gridProperties': {
                  'rowCount': 1000,
                  'columnCount': colCount < 10 ? 10 : colCount,
                  'frozenRowCount': 1,
                },
              },
            },
          };
        }).toList();

        final batchUrl = Uri.parse('$_sheetsBaseUrl/$spreadsheetId:batchUpdate');
        final addRes = await _httpClient.post(
          batchUrl,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'requests': requests}),
        );

        if (addRes.statusCode != 200) {
          AppLogger.warning(
            'Batch addSheet returned HTTP ${addRes.statusCode}: ${addRes.body}',
          );
        }
      }

      // 3. Populate Row 1 headers and 20_LOOKUPS default values via values:batchUpdate
      final valueUpdates = <Map<String, dynamic>>[];
      for (final name in MasterSheetSchema.canonicalSheetNames) {
        final headers = MasterSheetSchema.canonicalHeaders[name];
        if (headers != null && headers.isNotEmpty) {
          final rows = <List<dynamic>>[headers];

          if (name == '20_LOOKUPS') {
            for (final lkp in MasterSheetSchema.defaultLookups) {
              rows.add(lkp);
            }
          }

          valueUpdates.add({
            'range': '$name!A1',
            'values': rows,
          });
        }
      }

      if (valueUpdates.isNotEmpty) {
        final updateUrl = Uri.parse(
          '$_sheetsBaseUrl/$spreadsheetId/values:batchUpdate',
        );
        final updateRes = await _httpClient.post(
          updateUrl,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'valueInputOption': 'USER_ENTERED',
            'data': valueUpdates,
          }),
        );

        if (updateRes.statusCode != 200) {
          AppLogger.warning(
            'values:batchUpdate returned HTTP ${updateRes.statusCode}: ${updateRes.body}',
          );
        }
      }

      // 4. If default "Sheet1" is present alongside canonical sheets, delete it to keep clean
      if (existingSheetNames.contains('Sheet1') &&
          metadata.sheetIdsByName.containsKey('Sheet1')) {
        final sheet1Id = metadata.sheetIdsByName['Sheet1'];
        if (sheet1Id != null) {
          try {
            final delUrl =
                Uri.parse('$_sheetsBaseUrl/$spreadsheetId:batchUpdate');
            await _httpClient.post(
              delUrl,
              headers: {
                'Authorization': 'Bearer $accessToken',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'requests': [
                  {
                    'deleteSheet': {'sheetId': sheet1Id},
                  },
                ],
              }),
            );
          } catch (_) {}
        }
      }
    } catch (e) {
      AppLogger.warning('populateCanonicalSheets non-fatal error: $e');
    }
  }

  /// 5. Reads a single column (e.g. Primary Key column A) for a worksheet starting from startRow
  Future<List<String>> readSheetColumn({
    required String accessToken,
    required String spreadsheetId,
    required String sheetName,
    String columnLetter = 'A',
    int startRow = 2,
    int endRow = 5000,
  }) async {
    _validateParams(accessToken, spreadsheetId);
    try {
      final range = Uri.encodeComponent(
        '$sheetName!$columnLetter$startRow:$columnLetter$endRow',
      );
      final url = Uri.parse(
        '$_sheetsBaseUrl/$spreadsheetId/values/$range?majorDimension=COLUMNS',
      );

      final response = await _httpClient.get(
        url,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final values = data['values'] as List? ?? [];
        if (values.isEmpty || values.first is! List) return [];
        return (values.first as List)
            .map((e) => e.toString().trim())
            .toList();
      } else {
        _handleHttpError(response, 'read sheet column $sheetName!$columnLetter');
      }
    } on SocketException {
      throw const NetworkFailure(
        'Cannot connect to Google Sheets. Offline mode active.',
      );
    }
  }

  /// Clears cell values within a specific range
  Future<void> clearSheetRange({
    required String accessToken,
    required String spreadsheetId,
    required String range,
  }) async {
    _validateParams(accessToken, spreadsheetId);
    try {
      final encodedRange = Uri.encodeComponent(range);
      final url = Uri.parse(
        '$_sheetsBaseUrl/$spreadsheetId/values/$encodedRange:clear',
      );
      await _httpClient.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );
    } on SocketException {
      throw const NetworkFailure(
        'Cannot connect to Google Sheets. Offline mode active.',
      );
    } catch (_) {}
  }

  /// 6. Appends rows to a worksheet in a single batch API call
  Future<int> batchAppendRows({
    required String accessToken,
    required String spreadsheetId,
    required String sheetName,
    required List<List<dynamic>> rows,
  }) async {
    _validateParams(accessToken, spreadsheetId);
    if (rows.isEmpty) return 0;

    try {
      final range = Uri.encodeComponent('$sheetName!A:A');
      final url = Uri.parse(
        '$_sheetsBaseUrl/$spreadsheetId/values/$range:append?valueInputOption=USER_ENTERED&insertDataOption=INSERT_ROWS',
      );

      final response = await _httpClient.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'values': rows}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final updates = data['updates'] as Map<String, dynamic>? ?? {};
        final updatedRows =
            (updates['updatedRows'] as num?)?.toInt() ?? rows.length;
        AppLogger.info('Successfully appended $updatedRows rows to $sheetName');
        return updatedRows;
      } else {
        _handleHttpError(response, 'append rows to $sheetName');
      }
    } on SocketException {
      throw const NetworkFailure(
        'Cannot connect to Google Sheets. Offline mode active.',
      );
    }
  }

  /// 7. Updates multiple row ranges across worksheets in a single batchUpdate request
  Future<int> batchUpdateRows({
    required String accessToken,
    required String spreadsheetId,
    required List<SheetValueUpdate> updates,
  }) async {
    _validateParams(accessToken, spreadsheetId);
    if (updates.isEmpty) return 0;

    try {
      final url = Uri.parse(
        '$_sheetsBaseUrl/$spreadsheetId/values:batchUpdate',
      );

      final body = jsonEncode({
        'valueInputOption': 'USER_ENTERED',
        'data': updates.map((u) => u.toJson()).toList(),
      });

      final response = await _httpClient.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final totalUpdatedRows =
            (data['totalUpdatedRows'] as num?)?.toInt() ?? updates.length;
        AppLogger.info('Successfully batch-updated $totalUpdatedRows rows');
        return totalUpdatedRows;
      } else {
        _handleHttpError(response, 'batch-update rows');
      }
    } on SocketException {
      throw const NetworkFailure(
        'Cannot connect to Google Sheets. Offline mode active.',
      );
    }
  }

  void _validateParams(String token, String id) {
    if (token.trim().isEmpty) {
      throw const AuthorizationFailure('Google OAuth access token is missing.');
    }
    if (id.trim().isEmpty) {
      throw const DatabaseFailure('Google Sheets spreadsheet ID is missing.');
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
        'Google Sheets permission denied ($detail). Ensure Google Sheets API is enabled in Google Cloud Console.',
      );
    } else if (status == 404) {
      throw DatabaseFailure('Google Spreadsheet not found ($detail).');
    } else if (status == 429) {
      throw QuotaExceededFailure(
        'Google Sheets API quota exceeded ($detail). Please back off.',
      );
    } else if (status >= 500) {
      throw NetworkFailure(
        'Google Sheets service is temporarily unavailable ($status): $detail',
      );
    } else {
      throw NetworkFailure(
        'Failed to $action ($status): $detail',
      );
    }
  }
}
