// Apna Clinic - Google Apps Script HTTP & Mock Client
// Primary source of truth: Feature TRD Section 9 & Section 14

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

import '../../../../core/config/app_config.dart';
import '../../../../core/logging/app_logger.dart';
import '../models/monthly_storage_response.dart';

abstract class IAppsScriptClient {
  Future<MonthlyStorageResponse> executeAction(
    MonthlyStorageRequest request, {
    String? accessToken,
    int maxRetries = 3,
  });
}

class AppsScriptClient implements IAppsScriptClient {
  final http.Client _httpClient;
  final String? _customEndpointUrl;

  AppsScriptClient({
    http.Client? httpClient,
    String? customEndpointUrl,
  })  : _httpClient = httpClient ?? http.Client(),
        _customEndpointUrl = customEndpointUrl;

  String get endpointUrl =>
      _customEndpointUrl ?? AppConfig.current.appsScriptWebAppUrl;

  @override
  Future<MonthlyStorageResponse> executeAction(
    MonthlyStorageRequest request, {
    String? accessToken,
    int maxRetries = 3,
  }) async {
    final url = endpointUrl;
    if (url.isEmpty) {
      // In development or when Apps Script URL is unconfigured, return client fallback response
      AppLogger.info(
        'AppsScriptClient: No endpoint URL configured. Handling locally for action: ${request.action}',
      );
      return MonthlyStorageResponse(
        requestId: request.requestId,
        ok: true,
        data: {
          'handledBy': 'client_fallback',
          'action': request.action,
          'clinicId': request.clinicId,
        },
        meta: {
          'serverTime': DateTime.now().toUtc().toIso8601String(),
        },
      );
    }

    final headers = {
      'Content-Type': 'application/json',
      if (accessToken != null && accessToken.isNotEmpty)
        'Authorization': 'Bearer $accessToken',
    };

    final bodyJson = jsonEncode(request.toMap());

    int attempt = 0;
    while (attempt < maxRetries) {
      attempt++;
      try {
        final response = await _httpClient
            .post(
              Uri.parse(url),
              headers: headers,
              body: bodyJson,
            )
            .timeout(const Duration(seconds: 25));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          return MonthlyStorageResponse.fromMap(decoded);
        }

        // Retryable status codes (429 Rate Limit, 500, 502, 503 Server Errors)
        if (response.statusCode == 429 ||
            (response.statusCode >= 500 && response.statusCode <= 504)) {
          if (attempt >= maxRetries) {
            return MonthlyStorageResponse.failure(
              requestId: request.requestId,
              errorCode: 'QUOTA_LIMIT',
              errorMessage:
                  'Apps Script server returned HTTP ${response.statusCode} after $maxRetries attempts.',
            );
          }
          final backoffMs =
              (pow(2, attempt) * 200).toInt() + Random().nextInt(150);
          await Future.delayed(Duration(milliseconds: backoffMs));
          continue;
        }

        return MonthlyStorageResponse.failure(
          requestId: request.requestId,
          errorCode: 'HTTP_${response.statusCode}',
          errorMessage: 'HTTP ${response.statusCode}: ${response.body}',
        );
      } catch (e) {
        if (attempt >= maxRetries) {
          return MonthlyStorageResponse.failure(
            requestId: request.requestId,
            errorCode: 'NETWORK_ERROR',
            errorMessage: 'Failed to communicate with Apps Script: $e',
          );
        }
        final backoffMs = (pow(2, attempt) * 200).toInt() + Random().nextInt(100);
        await Future.delayed(Duration(milliseconds: backoffMs));
      }
    }

    return MonthlyStorageResponse.failure(
      requestId: request.requestId,
      errorCode: 'TEMPORARY_FAILURE',
      errorMessage: 'Execution timed out after $maxRetries retries.',
    );
  }
}

