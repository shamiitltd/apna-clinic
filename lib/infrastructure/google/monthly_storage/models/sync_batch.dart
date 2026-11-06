// Apna Clinic - Monthly Sync Batch Model
// Primary source of truth: Feature TRD Section 7 & Section 9

class MonthlySyncOperation {
  final String operationId;
  final String idempotencyKey;
  final String entityType; // 'Appointments', 'Visits', 'Billing', 'Payments', etc.
  final String entityId;
  final String action; // 'upsert', 'delete', 'update'
  final String businessDate; // ISO-8601 string or date
  final String yearMonth; // Resolved YYYY-MM
  final String? patientId; // For index updating
  final Map<String, dynamic> payload;

  const MonthlySyncOperation({
    required this.operationId,
    required this.idempotencyKey,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.businessDate,
    required this.yearMonth,
    this.patientId,
    required this.payload,
  });

  Map<String, dynamic> toMap() {
    return {
      'operationId': operationId,
      'idempotencyKey': idempotencyKey,
      'entityType': entityType,
      'entityId': entityId,
      'action': action,
      'businessDate': businessDate,
      'yearMonth': yearMonth,
      'patientId': patientId,
      'payload': payload,
    };
  }

  factory MonthlySyncOperation.fromMap(Map<String, dynamic> map) {
    return MonthlySyncOperation(
      operationId: map['operationId']?.toString() ?? '',
      idempotencyKey: map['idempotencyKey']?.toString() ?? '',
      entityType: map['entityType']?.toString() ?? '',
      entityId: map['entityId']?.toString() ?? '',
      action: map['action']?.toString() ?? 'upsert',
      businessDate: map['businessDate']?.toString() ?? '',
      yearMonth: map['yearMonth']?.toString() ?? '',
      patientId: map['patientId']?.toString(),
      payload: Map<String, dynamic>.from(map['payload'] as Map? ?? {}),
    );
  }
}

class MonthlySyncBatch {
  final String batchId;
  final String clinicId;
  final String deviceId;
  final String yearMonth;
  final List<MonthlySyncOperation> operations;
  final DateTime createdAt;

  const MonthlySyncBatch({
    required this.batchId,
    required this.clinicId,
    required this.deviceId,
    required this.yearMonth,
    required this.operations,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'batchId': batchId,
      'clinicId': clinicId,
      'deviceId': deviceId,
      'yearMonth': yearMonth,
      'operations': operations.map((o) => o.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MonthlySyncBatch.fromMap(Map<String, dynamic> map) {
    final opsList = (map['operations'] as List? ?? [])
        .map((o) => MonthlySyncOperation.fromMap(Map<String, dynamic>.from(o as Map)))
        .toList();
    return MonthlySyncBatch(
      batchId: map['batchId']?.toString() ?? '',
      clinicId: map['clinicId']?.toString() ?? '',
      deviceId: map['deviceId']?.toString() ?? '',
      yearMonth: map['yearMonth']?.toString() ?? '',
      operations: opsList,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

