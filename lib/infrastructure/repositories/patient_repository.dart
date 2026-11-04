// Apna Clinic - Concrete Patient Repository
// Implementation of IPatientRepository backed by LocalDatabase

import 'dart:convert';

import '../../domain/entities/entities.dart';
import '../../domain/enums/domain_enums.dart';
import '../../domain/repositories/i_patient_repository.dart';
import '../../core/utils/phone_normalizer.dart';
import '../database/local_database.dart';

class PatientRepository implements IPatientRepository {
  final LocalDatabase _db;

  PatientRepository(this._db);

  @override
  Future<Patient?> getPatientById(String clinicId, String patientId) async {
    final record = _db.get('Patients', patientId);
    if (record != null && record['deleted_at'] == null) {
      return Patient.fromMap(record);
    }
    final matches = _db.query(
      'Patients',
      where: (r) => r['patient_id'] == patientId && r['deleted_at'] == null,
    );
    if (matches.isNotEmpty) {
      return Patient.fromMap(matches.first);
    }
    return null;
  }

  @override
  Future<List<Patient>> searchPatients(
    String clinicId,
    String query, {
    int limit = 50,
  }) async {
    final rawResults = _db.searchPatients(
      clinicId: clinicId,
      query: query,
      limit: limit,
    );
    return rawResults.map((r) => Patient.fromMap(r)).toList();
  }

  @override
  Future<List<Patient>> findPossibleDuplicates(
    String clinicId, {
    String? phone,
    String? fullName,
    DateTime? dob,
  }) async {
    final cleanPhone = PhoneNormalizer.normalize(phone);
    final cleanName = fullName?.trim().toLowerCase();
    final dobStr = dob?.toIso8601String().split('T').first;

    final candidates = <String, Patient>{};

    final all = _db.query(
      'Patients',
      where: (r) => r['clinic_id'] == clinicId && r['deleted_at'] == null,
    );

    for (final r in all) {
      final p = Patient.fromMap(r);
      bool isMatch = false;

      // Match 1: Same normalized phone
      if (cleanPhone != null && cleanPhone.isNotEmpty) {
        if (p.normalizedPhone == cleanPhone) {
          isMatch = true;
        }
      }

      // Match 2: Exact same name and DOB
      if (cleanName != null && cleanName.isNotEmpty && dobStr != null) {
        final pDobStr = p.dateOfBirth?.toIso8601String().split('T').first;
        if (p.fullName.toLowerCase().trim() == cleanName && pDobStr == dobStr) {
          isMatch = true;
        }
      }

      if (isMatch) {
        candidates[p.patientId] = p;
      }
    }

    return candidates.values.toList();
  }

  @override
  Future<String> generateNextPatientNumber(String clinicId) async {
    final year = DateTime.now().year;
    final prefix = 'P-$year-';

    final all = _db.query('Patients', where: (r) => r['clinic_id'] == clinicId);

    int maxSeq = 0;
    for (final r in all) {
      final numStr = r['patient_number'] as String? ?? '';
      if (numStr.startsWith(prefix)) {
        final seqPart = numStr.substring(prefix.length);
        final seq = int.tryParse(seqPart);
        if (seq != null && seq > maxSeq) {
          maxSeq = seq;
        }
      }
    }

    final nextSeq = (maxSeq + 1).toString().padLeft(4, '0');
    return '$prefix$nextSeq';
  }

  @override
  Future<void> savePatient(
    Patient patient, {
    ConsentEvent? consentEvent,
  }) async {
    // Exact duplicate guard: check if active patient with same normalized phone AND same full name exists
    final cleanPhone = PhoneNormalizer.normalize(patient.phoneOptional);
    final cleanName = patient.fullName.trim().toLowerCase();

    if (cleanPhone != null && cleanPhone.isNotEmpty && cleanName.isNotEmpty) {
      final duplicates = _db.query(
        'Patients',
        where: (r) {
          if (r['deleted_at'] != null) return false;
          if (r['patient_id'] == patient.patientId) return false;
          final existingPhone =
              PhoneNormalizer.normalize(r['phone_optional'] as String?);
          final existingName =
              (r['full_name'] as String? ?? '').trim().toLowerCase();
          return existingPhone == cleanPhone && existingName == cleanName;
        },
      );
      if (duplicates.isNotEmpty) {
        final existingNumber =
            duplicates.first['patient_number'] ?? 'Existing ID';
        throw StateError(
          'Duplicate patient blocked: A patient named "${patient.fullName}" with phone number "${patient.phoneOptional}" already exists ($existingNumber).',
        );
      }
    }

    await _db.transaction((tx) async {
      await _db.upsert('Patients', patient.patientId, patient.toMap(), tx: tx);

      if (consentEvent != null) {
        await _db.upsert(
          'Consent_Log',
          consentEvent.consentEventId,
          consentEvent.toMap(),
          tx: tx,
        );
      }

      // Stage for sync outbox
      final outboxEvent = SyncOutboxEvent(
        outboxEventId:
            'outbox_patient_${patient.patientId}_${DateTime.now().millisecondsSinceEpoch}',
        clinicId: patient.clinicId,
        entityType: 'Patients',
        entityId: patient.patientId,
        operation: OutboxOperation.insert,
        payloadJson: patient.toMap().toString(),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: 'patient_${patient.patientId}',
      );
      await _db.upsert(
        'sync_outbox',
        outboxEvent.outboxEventId,
        outboxEvent.toMap(),
        tx: tx,
      );
    });
  }

  @override
  Future<int> countPatients(String clinicId) async {
    final all = _db.query(
      'Patients',
      where: (r) => r['clinic_id'] == clinicId && r['deleted_at'] == null,
    );
    return all.length;
  }

  @override
  Future<void> saveReasonForVisitSecret(ReasonForVisitSecret secret) async {
    await _db.upsert('reason_for_visit_secrets', secret.refId, secret.toMap());
  }

  @override
  Future<ReasonForVisitSecret?> getReasonForVisitSecret(
    String clinicId,
    String refId,
  ) async {
    final record = _db.get('reason_for_visit_secrets', refId);
    if (record == null || record['clinic_id'] != clinicId) return null;
    return ReasonForVisitSecret.fromMap(record);
  }

  @override
  Future<void> updatePatient(
    Patient patient, {
    required String actorId,
    required String actorRole,
    required List<String> changedFields,
  }) async {
    final cleanPhone = PhoneNormalizer.normalize(patient.phoneOptional);
    final cleanName = patient.fullName.trim().toLowerCase();

    // Verify duplicate uniqueness if phone or name is being modified
    if (cleanPhone != null && cleanPhone.isNotEmpty && cleanName.isNotEmpty) {
      final duplicates = _db.query(
        'Patients',
        where: (r) {
          if (r['deleted_at'] != null) return false;
          if (r['patient_id'] == patient.patientId) return false;
          final existingPhone =
              PhoneNormalizer.normalize(r['phone_optional'] as String?);
          final existingName =
              (r['full_name'] as String? ?? '').trim().toLowerCase();
          return existingPhone == cleanPhone && existingName == cleanName;
        },
      );
      if (duplicates.isNotEmpty) {
        final existingNumber =
            duplicates.first['patient_number'] ?? 'Existing ID';
        throw StateError(
          'Duplicate patient blocked: Another patient named "${patient.fullName}" with phone number "${patient.phoneOptional}" already exists ($existingNumber).',
        );
      }
    }

    final updated = patient.copyWith(updatedAt: DateTime.now().toUtc());

    await _db.transaction((tx) async {
      await _db.upsert('Patients', updated.patientId, updated.toMap(), tx: tx);

      // Record immutable audit event
      final auditEvent = AuditEvent(
        auditEventId: 'audit_patient_edit_${DateTime.now().millisecondsSinceEpoch}_${patient.patientId}',
        clinicId: patient.clinicId,
        actorId: actorId,
        actorRole: actorRole,
        deviceId: 'primary_workstation',
        action: 'patient.edit',
        entityType: 'patient',
        entityId: patient.patientId,
        fieldNamesJson: jsonEncode(changedFields),
        occurredAt: DateTime.now().toUtc(),
        correlationId: patient.patientId,
        result: AuditResult.success,
        reasonOptional: 'Patient profile updated: ${changedFields.join(", ")}',
      );
      await _db.upsert(
        'Audit_Events',
        auditEvent.auditEventId,
        auditEvent.toMap(),
        tx: tx,
      );

      // Stage for cloud sync outbox
      final outboxEvent = SyncOutboxEvent(
        outboxEventId:
            'outbox_patient_edit_${patient.patientId}_${DateTime.now().millisecondsSinceEpoch}',
        clinicId: patient.clinicId,
        entityType: 'Patients',
        entityId: patient.patientId,
        operation: OutboxOperation.update,
        payloadJson: updated.toMap().toString(),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: 'patient_edit_${patient.patientId}_${DateTime.now().millisecondsSinceEpoch}',
      );
      await _db.upsert(
        'sync_outbox',
        outboxEvent.outboxEventId,
        outboxEvent.toMap(),
        tx: tx,
      );
    });
  }

  @override
  Future<void> deletePatient(
    String clinicId,
    String patientId, {
    required String actorId,
    required String actorRole,
    String? reason,
  }) async {
    final existing = await getPatientById(clinicId, patientId);
    if (existing == null) {
      throw StateError('Patient not found or already deleted: $patientId');
    }

    final deleted = existing.copyWith(
      deletedAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

    await _db.transaction((tx) async {
      await _db.upsert('Patients', deleted.patientId, deleted.toMap(), tx: tx);

      // Record immutable audit event
      final auditEvent = AuditEvent(
        auditEventId: 'audit_patient_delete_${DateTime.now().millisecondsSinceEpoch}_$patientId',
        clinicId: clinicId,
        actorId: actorId,
        actorRole: actorRole,
        deviceId: 'primary_workstation',
        action: 'patient.delete',
        entityType: 'patient',
        entityId: patientId,
        fieldNamesJson: jsonEncode(['deleted_at']),
        occurredAt: DateTime.now().toUtc(),
        correlationId: patientId,
        result: AuditResult.success,
        reasonOptional: reason ?? 'Patient soft-deleted by $actorRole ($actorId)',
      );
      await _db.upsert(
        'Audit_Events',
        auditEvent.auditEventId,
        auditEvent.toMap(),
        tx: tx,
      );

      // Stage for cloud sync outbox
      final outboxEvent = SyncOutboxEvent(
        outboxEventId:
            'outbox_patient_del_${patientId}_${DateTime.now().millisecondsSinceEpoch}',
        clinicId: clinicId,
        entityType: 'Patients',
        entityId: patientId,
        operation: OutboxOperation.delete,
        payloadJson: deleted.toMap().toString(),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: 'patient_del_${patientId}_${DateTime.now().millisecondsSinceEpoch}',
      );
      await _db.upsert(
        'sync_outbox',
        outboxEvent.outboxEventId,
        outboxEvent.toMap(),
        tx: tx,
      );
    });
  }

  @override
  Future<List<AuditEvent>> getPatientAuditHistory(
    String clinicId,
    String patientId,
  ) async {
    final records = _db.query(
      'Audit_Events',
      where: (r) =>
          r['clinic_id'] == clinicId &&
          (r['entity_id'] == patientId ||
              r['reason_optional']?.toString().contains(patientId) == true),
    );

    final events = records.map((r) => AuditEvent.fromMap(r)).toList();
    events.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return events;
  }
}
