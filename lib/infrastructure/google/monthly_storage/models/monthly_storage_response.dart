// Apna Clinic - Monthly Storage Request/Response Contract Models
// Primary source of truth: Feature TRD Section 9

class MonthlyOperationResult {
  final String operationId;
  final String entityId;
  final bool success;
  final String? status;
  final String? errorCode;
  final String? errorMessage;
  final String? targetSpreadsheetId;
  final String? targetSheetName;

  const MonthlyOperationResult({
    required this.operationId,
    required this.entityId,
    required this.success,
    this.status,
    this.errorCode,
    this.errorMessage,
    this.targetSpreadsheetId,
    this.targetSheetName,
  });

  Map<String, dynamic> toMap() {
    return {
      'operationId': operationId,
      'entityId': entityId,
      'success': success,
      'status': status,
      'errorCode': errorCode,
      'errorMessage': errorMessage,
      'targetSpreadsheetId': targetSpreadsheetId,
      'targetSheetName': targetSheetName,
    };
  }

  factory MonthlyOperationResult.fromMap(Map<String, dynamic> map) {
    return MonthlyOperationResult(
      operationId: map['operationId']?.toString() ?? '',
      entityId: map['entityId']?.toString() ?? '',
      success: map['success'] == true,
      status: map['status']?.toString(),
      errorCode: map['errorCode']?.toString(),
      errorMessage: map['errorMessage']?.toString(),
      targetSpreadsheetId: map['targetSpreadsheetId']?.toString(),
      targetSheetName: map['targetSheetName']?.toString(),
    );
  }
}

class MonthlyStorageRequest {
  final String apiVersion;
  final String action;
  final String requestId;
  final String clinicId;
  final String idempotencyKey;
  final Map<String, dynamic> payload;

  const MonthlyStorageRequest({
    this.apiVersion = 'v1',
    required this.action,
    required this.requestId,
    required this.clinicId,
    required this.idempotencyKey,
    required this.payload,
  });

  Map<String, dynamic> toMap() {
    return {
      'apiVersion': apiVersion,
      'action': action,
      'requestId': requestId,
      'clinicId': clinicId,
      'idempotencyKey': idempotencyKey,
      'payload': payload,
    };
  }
}

class MonthlyStorageResponse {
  final String apiVersion;
  final String requestId;
  final bool ok;
  final Map<String, dynamic>? data;
  final String? errorCode;
  final String? errorMessage;
  final Map<String, dynamic>? meta;

  const MonthlyStorageResponse({
    this.apiVersion = 'v1',
    required this.requestId,
    required this.ok,
    this.data,
    this.errorCode,
    this.errorMessage,
    this.meta,
  });

  Map<String, dynamic> toMap() {
    return {
      'apiVersion': apiVersion,
      'requestId': requestId,
      'ok': ok,
      'data': data,
      'error': errorCode != null
          ? {
              'code': errorCode,
              'message': errorMessage,
            }
          : null,
      'meta': meta,
    };
  }

  factory MonthlyStorageResponse.fromMap(Map<String, dynamic> map) {
    String? errCode;
    String? errMsg;
    if (map['error'] is Map) {
      final err = map['error'] as Map;
      errCode = err['code']?.toString();
      errMsg = err['message']?.toString();
    } else if (map['error'] != null) {
      errMsg = map['error'].toString();
    }

    return MonthlyStorageResponse(
      apiVersion: map['apiVersion']?.toString() ?? 'v1',
      requestId: map['requestId']?.toString() ?? '',
      ok: map['ok'] == true,
      data: map['data'] != null ? Map<String, dynamic>.from(map['data'] as Map) : null,
      errorCode: errCode,
      errorMessage: errMsg,
      meta: map['meta'] != null ? Map<String, dynamic>.from(map['meta'] as Map) : null,
    );
  }

  factory MonthlyStorageResponse.failure({
    required String requestId,
    required String errorCode,
    required String errorMessage,
  }) {
    return MonthlyStorageResponse(
      requestId: requestId,
      ok: false,
      errorCode: errorCode,
      errorMessage: errorMessage,
      meta: {
        'serverTime': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }
}

