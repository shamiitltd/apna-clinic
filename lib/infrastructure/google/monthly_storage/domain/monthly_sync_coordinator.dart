// Apna Clinic - Monthly Sync Coordinator
// Primary source of truth: Feature PRD Section 10 & Feature TRD Section 7, 10

import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../database/local_database.dart';
import '../data/monthly_storage_repository.dart';
import '../models/sync_batch.dart';
import 'month_resolver.dart';

class MonthlySyncSummary {
  final int totalBatches;
  final int totalOperations;
  final int successfulOperations;
  final int failedOperations;
  final List<String> affectedMonths;
  final bool isSuccess;
  final String? errorMessage;

  const MonthlySyncSummary({
    required this.totalBatches,
    required this.totalOperations,
    required this.successfulOperations,
    required this.failedOperations,
    required this.affectedMonths,
    required this.isSuccess,
    this.errorMessage,
  });

  factory MonthlySyncSummary.empty() {
    return const MonthlySyncSummary(
      totalBatches: 0,
      totalOperations: 0,
      successfulOperations: 0,
      failedOperations: 0,
      affectedMonths: [],
      isSuccess: true,
    );
  }
}

class MonthlySyncCoordinator {
  final LocalDatabase localDb;
  final MonthlyStorageRepository repository;

  MonthlySyncCoordinator({
    required this.localDb,
    required this.repository,
  });

  /// Check whether an entity type qualifies for monthly transaction storage
  /// (Appointments, Visits, Invoices, Payments, Queue_Events)
  static bool isMonthlyTransactionEntity(String entityType) {
    switch (entityType.toLowerCase()) {
      case 'appointments':
      case '06_appointments':
      case 'visits':
      case 'consultations':
      case '09_consultations':
      case 'invoices':
      case 'billing':
      case '10_billing':
      case 'payments':
      case '11_payments':
      case 'queue_events':
      case '08_queue':
        return true;
      default:
        return false;
    }
  }

  /// Groups pending outbox records into monthly batches and routes them to monthly workbooks
  Future<MonthlySyncSummary> syncPendingMonthlyRecords({
    required String clinicId,
    required String clinicDriveFolderId,
    required String masterSpreadsheetId,
    String? accessToken,
    String deviceId = 'primary_device',
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();

    // 1. Ensure local appointments are staged if remote monthly tab needs them
    final localAppts = localDb.query('Appointments');
    for (final appt in localAppts) {
      final apptId = (appt['appointment_id'] ?? '').toString();
      if (apptId.isNotEmpty) {
        final outboxId = 'outbox_appointments_$apptId';
        final existing = localDb.get('sync_outbox', outboxId);
        if (existing == null || existing['status'] != 'pending') {
          await localDb.upsert('sync_outbox', outboxId, {
            if (existing != null) ...existing,
            'outbox_event_id': outboxId,
            'clinic_id': clinicId,
            'entity_type': 'Appointments',
            'entity_id': apptId,
            'operation': 'insert',
            'payload_json': jsonEncode(appt),
            'status': 'pending',
            'created_at': existing?['created_at'] ?? nowIso,
            'idempotency_key': 'Appointments_$apptId',
          });
        }
      }
    }

    // 2. Ensure local visits and initial queue events are staged
    final localVisits = localDb.query('Visits');
    for (final v in localVisits) {
      final vId = (v['visit_id'] ?? '').toString();
      if (vId.isNotEmpty) {
        final outboxId = 'outbox_visit_$vId';
        final existing = localDb.get('sync_outbox', outboxId);
        if (existing == null || existing['status'] != 'pending') {
          await localDb.upsert('sync_outbox', outboxId, {
            if (existing != null) ...existing,
            'outbox_event_id': outboxId,
            'clinic_id': clinicId,
            'entity_type': 'Visits',
            'entity_id': vId,
            'operation': 'insert',
            'payload_json': jsonEncode(v),
            'status': 'pending',
            'created_at': existing?['created_at'] ?? nowIso,
            'idempotency_key': 'Visits_$vId',
          });
        }

        final qevtId = 'qevt_${vId}_1';
        final outboxQId = 'outbox_qevt_$qevtId';
        final existingQ = localDb.get('sync_outbox', outboxQId);
        if (existingQ == null || existingQ['status'] != 'pending') {
          await localDb.upsert('sync_outbox', outboxQId, {
            if (existingQ != null) ...existingQ,
            'outbox_event_id': outboxQId,
            'clinic_id': clinicId,
            'entity_type': 'Queue_Events',
            'entity_id': qevtId,
            'operation': 'insert',
            'payload_json': jsonEncode({
              'queue_event_id': qevtId,
              'queue_id': qevtId,
              'clinic_id': clinicId,
              'visit_id': vId,
              'doctor_id': v['doctor_id'] ?? 'doc_primary_01',
              'patient_id': v['patient_id'] ?? '',
              'from_status': 'REGISTERED',
              'to_status': v['queue_status'] ?? 'WAITING',
              'changed_at': v['created_at'] ?? nowIso,
              'changed_by_staff_id': 'staff_admin_01',
            }),
            'status': 'pending',
            'created_at': existingQ?['created_at'] ?? nowIso,
            'idempotency_key': 'Queue_Events_$qevtId',
          });
        }
      }
    }

    // 3. Ensure local invoices and payments are staged
    final localInvoices = localDb.query('Invoices');
    for (final inv in localInvoices) {
      final invId = (inv['invoice_id'] ?? '').toString();
      if (invId.isNotEmpty) {
        final outboxId = 'outbox_inv_$invId';
        final existing = localDb.get('sync_outbox', outboxId);
        if (existing == null || existing['status'] != 'pending') {
          await localDb.upsert('sync_outbox', outboxId, {
            if (existing != null) ...existing,
            'outbox_event_id': outboxId,
            'clinic_id': clinicId,
            'entity_type': 'Billing',
            'entity_id': invId,
            'operation': 'insert',
            'payload_json': jsonEncode(inv),
            'status': 'pending',
            'created_at': existing?['created_at'] ?? nowIso,
            'idempotency_key': 'Billing_$invId',
          });
        }
      }
    }

    final localPayments = localDb.query('Payments');
    for (final p in localPayments) {
      final pId = (p['payment_id'] ?? '').toString();
      if (pId.isNotEmpty) {
        final outboxId = 'outbox_pay_$pId';
        final existing = localDb.get('sync_outbox', outboxId);
        if (existing == null || existing['status'] != 'pending') {
          await localDb.upsert('sync_outbox', outboxId, {
            if (existing != null) ...existing,
            'outbox_event_id': outboxId,
            'clinic_id': clinicId,
            'entity_type': 'Payments',
            'entity_id': pId,
            'operation': 'insert',
            'payload_json': jsonEncode(p),
            'status': 'pending',
            'created_at': existing?['created_at'] ?? nowIso,
            'idempotency_key': 'Payments_$pId',
          });
        }
      }
    }

    final pendingOutbox = localDb.query('sync_outbox');
    if (pendingOutbox.isEmpty) {
      return MonthlySyncSummary.empty();
    }

    // Filter to monthly transaction entities that are not yet synced
    final eligibleRecords = pendingOutbox.where((r) {
      final recordClinicId = r['clinic_id']?.toString() ?? '';
      if (clinicId.isNotEmpty && recordClinicId.isNotEmpty) {
        final cleanA = clinicId.replaceFirst('clinic_', '').replaceAll('_demo', '');
        final cleanB = recordClinicId.replaceFirst('clinic_', '').replaceAll('_demo', '');
        final isBothPrimary = clinicId.contains('primary') && recordClinicId.contains('primary');
        if (clinicId != recordClinicId && cleanA != cleanB && !isBothPrimary) {
          return false;
        }
      }
      final entityType = r['entity_type']?.toString() ?? '';
      final status = r['status']?.toString() ?? 'pending';
      return isMonthlyTransactionEntity(entityType) && (status == 'pending' || status == 'failed');
    }).toList();

    if (eligibleRecords.isEmpty) {
      return MonthlySyncSummary.empty();
    }

    AppLogger.info(
      'MonthlySyncCoordinator: Found ${eligibleRecords.length} pending transaction records to route monthly.',
    );

    // Group operations by resolved YYYY-MM
    final opsByMonth = <String, List<MonthlySyncOperation>>{};

    for (final r in eligibleRecords) {
      final entityType = r['entity_type']?.toString() ?? '';
      final entityId = r['entity_id']?.toString() ?? '';
      final action = r['action']?.toString() ?? r['operation']?.toString() ?? 'upsert';

      Map<String, dynamic> payload = {};
      if (r['payload'] is Map) {
        payload = Map<String, dynamic>.from(r['payload'] as Map);
      } else if (r['payload_json'] != null && r['payload_json'].toString().isNotEmpty) {
        try {
          payload = Map<String, dynamic>.from(jsonDecode(r['payload_json'].toString()) as Map);
        } catch (_) {}
      }

      final ym = MonthResolver.resolveMonthFromEntity(entityType, payload);

      // Enrich Queue_Events payload with parent Visit details so all 15 columns are fully populated
      if (entityType.toLowerCase() == 'queue_events' || entityType.toLowerCase() == '08_queue') {
        final visitId = (payload['visit_id'] ?? entityId).toString();
        var visit = localDb.get('Visits', visitId);
        if (visit == null) {
          visit = localDb.query('Visits', where: (v) => v['visit_id'] == visitId).firstOrNull ?? {};
        }
        final doctorId = payload['doctor_id'] ?? visit['doctor_id'] ?? 'doc_primary_01';
        final patientId = payload['patient_id'] ?? visit['patient_id'] ?? '';
        final appointmentId = payload['appointment_id'] ?? visit['appointment_id'] ?? '';
        final tokenNumber = payload['token_number'] ?? visit['token_number'] ?? '1';
        final queueDate = payload['queue_date'] ?? visit['visit_date_local'] ?? visit['visit_date'] ?? DateTime.now().toIso8601String().split('T').first;
        final checkInTime = payload['check_in_time'] ?? visit['checkin_at'] ?? '';
        final calledTime = payload['called_time'] ?? visit['called_at'] ?? '';
        final consultationStart = payload['consultation_start_time'] ?? visit['consultation_started_at'] ?? '';
        final consultationEnd = payload['consultation_end_time'] ?? visit['consultation_completed_at'] ?? '';
        final queueStatus = payload['to_status'] ?? payload['queue_status'] ?? visit['queue_status'] ?? 'WAITING';
        final priority = payload['priority'] ?? visit['priority'] ?? 'NORMAL';
        final roomId = payload['room_id'] ?? visit['room_id'] ?? 'ROOM-01';
        final createdAt = payload['changed_at'] ?? payload['created_at'] ?? visit['created_at'] ?? DateTime.now().toUtc().toIso8601String();
        final updatedAt = payload['changed_at'] ?? payload['updated_at'] ?? visit['updated_at'] ?? createdAt;

        final rawQId = payload['queue_event_id'] ?? payload['queue_id'] ?? entityId;
        final cleanQId = (rawQId.toString().startsWith('qevt_'))
            ? rawQId.toString()
            : 'qevt_${visitId}_1';

        payload = {
          ...payload,
          'queue_id': cleanQId,
          'queue_event_id': cleanQId,
          'visit_id': visitId,
          'doctor_id': doctorId,
          'patient_id': patientId,
          'appointment_id': appointmentId,
          'token_number': tokenNumber,
          'queue_date': queueDate,
          'check_in_time': checkInTime,
          'called_time': calledTime,
          'consultation_start_time': consultationStart,
          'consultation_end_time': consultationEnd,
          'queue_status': queueStatus,
          'priority': priority,
          'room_id': roomId,
          'created_at': createdAt,
          'updated_at': updatedAt,
        };
      }
      final businessDate = payload['visit_date'] ??
          payload['visit_date_local'] ??
          payload['appointment_date'] ??
          payload['scheduled_start_at'] ??
          payload['scheduled_start'] ??
          payload['invoice_date'] ??
          payload['issue_date_local'] ??
          payload['payment_date'] ??
          payload['paid_at'] ??
          payload['created_at'] ??
          r['created_at'] ??
          DateTime.now().toIso8601String();

      final opId = r['outbox_event_id']?.toString() ?? r['event_id']?.toString() ?? const Uuid().v4();

      final op = MonthlySyncOperation(
        operationId: opId,
        idempotencyKey: 'op_${entityType}_${entityId}_$ym',
        entityType: entityType,
        entityId: entityId,
        action: action,
        businessDate: businessDate.toString(),
        yearMonth: ym,
        patientId: payload['patient_id']?.toString(),
        payload: payload,
      );

      opsByMonth.putIfAbsent(ym, () => []).add(op);
    }

    int totalOps = 0;
    int successOps = 0;
    int failOps = 0;
    final affectedMonths = opsByMonth.keys.toList();

    for (final entry in opsByMonth.entries) {
      final ym = entry.key;
      final ops = entry.value;
      totalOps += ops.length;

      final batch = MonthlySyncBatch(
        batchId: 'batch_${clinicId}_${ym.replaceAll('-', '_')}_${DateTime.now().millisecondsSinceEpoch}',
        clinicId: clinicId,
        deviceId: deviceId,
        yearMonth: ym,
        operations: ops,
        createdAt: DateTime.now().toUtc(),
      );

      final resp = await repository.syncBatch(
        batch: batch,
        masterSpreadsheetId: masterSpreadsheetId,
        clinicDriveFolderId: clinicDriveFolderId,
        accessToken: accessToken,
      );

      if (resp.ok) {
        successOps += ops.length;
        // Mark local outbox records as completed
        for (final op in ops) {
          final outboxRow = eligibleRecords.firstWhere(
            (r) => (r['outbox_event_id'] == op.operationId ||
                r['event_id'] == op.operationId ||
                r['entity_id'] == op.entityId),
            orElse: () => {},
          );
          if (outboxRow.isNotEmpty) {
            final id = outboxRow['outbox_event_id']?.toString() ??
                outboxRow['event_id']?.toString() ??
                outboxRow['entity_id']?.toString();
            if (id != null) {
              await localDb.upsert('sync_outbox', id, {
                ...outboxRow,
                'status': 'synced',
                'synced_at': DateTime.now().toUtc().toIso8601String(),
                'target_year_month': ym,
              });
            }
          }
        }
      } else {
        failOps += ops.length;
        AppLogger.warning('Monthly batch for $ym returned error: ${resp.errorMessage}');
      }
    }

    return MonthlySyncSummary(
      totalBatches: opsByMonth.length,
      totalOperations: totalOps,
      successfulOperations: successOps,
      failedOperations: failOps,
      affectedMonths: affectedMonths,
      isSuccess: failOps == 0,
      errorMessage: failOps > 0 ? '$failOps monthly operations failed.' : null,
    );
  }
}

