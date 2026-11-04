// Apna Clinic - Module 13: Multi-Doctor & Multi-Device Live Collaboration Repository
// Primary Source of Truth: PRD Section 5 (M13), Section 7.3, TRD Section 2, Section 8, ADR-003, ADR-011.

import 'dart:convert';
import '../../core/errors/failures.dart';
import '../../core/permissions/roles.dart';
import '../../domain/entities/audit_event.dart';
import '../../domain/entities/device_state.dart';
import '../../domain/entities/sync_models.dart';
import '../../domain/enums/domain_enums.dart';
import '../../domain/repositories/i_device_collaboration_repository.dart';
import '../../domain/services/authorization_service.dart';
import '../database/local_database.dart';

class DeviceCollaborationRepository implements IDeviceCollaborationRepository {
  final LocalDatabase _db;
  String? _cachedLocalDeviceId;

  DeviceCollaborationRepository(this._db, {String? initialDeviceId}) {
    _cachedLocalDeviceId = initialDeviceId;
  }

  @override
  Future<DeviceRegistration> getLocalDevice(
    String clinicId, {
    String? defaultName,
    DeviceRole? defaultRole,
  }) async {
    // 1. Establish persistent device ID
    if (_cachedLocalDeviceId == null || _cachedLocalDeviceId!.isEmpty) {
      final stateRecord = _db.get('browser_device_state', 'local_device');
      if (stateRecord != null && stateRecord['device_id'] != null) {
        _cachedLocalDeviceId = stateRecord['device_id'] as String;
      } else {
        _cachedLocalDeviceId =
            'dev_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecondsSinceEpoch % 100000).toString().padLeft(5, '0')}';
        await _db.upsert('browser_device_state', 'local_device', {
          'device_id': _cachedLocalDeviceId,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    }

    // 2. Fetch or create device registration
    final existing = _db.get('Devices', _cachedLocalDeviceId!);
    final now = DateTime.now().toUtc();

    if (existing != null) {
      final device = DeviceRegistration.fromMap(existing).copyWith(
        lastHeartbeatAt: now,
      );
      await _db.upsert('Devices', device.deviceId, device.toMap());
      return device;
    }

    final newDevice = DeviceRegistration(
      deviceId: _cachedLocalDeviceId!,
      clinicId: clinicId,
      deviceName: defaultName ?? 'Primary Reception Desk',
      deviceRole: defaultRole ?? DeviceRole.primaryReception,
      platformInfo: 'Flutter Web / Workstation',
      appVersion: '1.0.0',
      registeredAt: now,
      lastHeartbeatAt: now,
    );

    await registerDevice(newDevice);
    return newDevice;
  }

  @override
  Future<void> registerDevice(DeviceRegistration device) async {
    await _db.transaction((tx) async {
      await _db.upsert('Devices', device.deviceId, device.toMap(), tx: tx);

      final outboxEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_dev_${device.deviceId}',
        clinicId: device.clinicId,
        entityType: 'Devices',
        entityId: device.deviceId,
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode(device.toMap()),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: 'dev_${device.deviceId}',
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
  Future<void> updateDeviceName({
    required String clinicId,
    required String deviceId,
    required String newName,
  }) async {
    final existing = _db.get('Devices', deviceId);
    if (existing == null) {
      throw const DatabaseFailure('Device not found for name update.');
    }

    final updated = DeviceRegistration.fromMap(existing).copyWith(
      deviceName: newName.trim(),
      lastHeartbeatAt: DateTime.now().toUtc(),
    );

    await registerDevice(updated);
  }

  @override
  Future<List<DeviceRegistration>> getConnectedDevices(String clinicId) async {
    final records = _db.query(
      'Devices',
      where: (r) => r['clinic_id'] == clinicId,
    );

    final devices = records.map((r) => DeviceRegistration.fromMap(r)).toList();
    // Sort: Primary reception first, then active/recent heartbeats
    devices.sort((a, b) {
      if (a.deviceRole == DeviceRole.primaryReception &&
          b.deviceRole != DeviceRole.primaryReception) {
        return -1;
      }
      if (b.deviceRole == DeviceRole.primaryReception &&
          a.deviceRole != DeviceRole.primaryReception) {
        return 1;
      }
      return b.lastHeartbeatAt.compareTo(a.lastHeartbeatAt);
    });
    return devices;
  }

  @override
  Future<DeviceLease?> getActiveWriteLease(String clinicId) async {
    final leases = _db.query(
      'Device_Leases',
      where: (r) => r['clinic_id'] == clinicId,
    );

    for (final map in leases) {
      final lease = DeviceLease.fromMap(map);
      if (lease.status == DeviceLeaseStatus.active) {
        if (lease.isExpired) {
          // Auto-mark expired
          final expiredLease = lease.copyWith(status: DeviceLeaseStatus.expired);
          await _db.upsert('Device_Leases', lease.leaseId, expiredLease.toMap());
        } else {
          return lease;
        }
      }
    }
    return null;
  }

  @override
  Future<bool> isCurrentDeviceAuthoritativeWriter(String clinicId) async {
    final localDevice = await getLocalDevice(clinicId);
    final activeLease = await getActiveWriteLease(clinicId);

    // If no active lease exists, or if the current device is the lease holder, it has authority
    if (activeLease == null) {
      return true; // Single-device unassigned mode
    }
    return activeLease.holderDeviceId == localDevice.deviceId;
  }

  @override
  Future<DeviceLease> acquireWriteLease({
    required String clinicId,
    required String staffId,
    required UserRole role,
    int durationSeconds = 300,
  }) async {
    // RBAC validation
    if (!AuthorizationService.hasPermission(
      role: role,
      permission: AppPermission.manageDeviceLease,
    )) {
      throw AuthorizationFailure(
        'Role ${role.name.toUpperCase()} is not authorized to acquire write lease.',
      );
    }

    final localDevice = await getLocalDevice(clinicId);
    final currentLease = await getActiveWriteLease(clinicId);

    // Check if another device holds an active, unexpired lease
    if (currentLease != null &&
        currentLease.holderDeviceId != localDevice.deviceId &&
        currentLease.isActive) {
      throw DeviceLeaseFailure(
        'Workstation "${currentLease.holderDeviceId}" holds the active write lease until ${currentLease.expiresAt.toIso8601String()}. Please release or transfer before acquiring.',
      );
    }

    final now = DateTime.now().toUtc();
    final newLease = DeviceLease(
      leaseId: 'lease_${now.millisecondsSinceEpoch}_${localDevice.deviceId}',
      clinicId: clinicId,
      holderDeviceId: localDevice.deviceId,
      holderStaffId: staffId,
      holderRole: role,
      acquiredAt: now,
      expiresAt: now.add(Duration(seconds: durationSeconds)),
      durationSeconds: durationSeconds,
      status: DeviceLeaseStatus.active,
    );

    await _db.transaction((tx) async {
      // Mark any prior lease as released
      if (currentLease != null) {
        await _db.upsert(
          'Device_Leases',
          currentLease.leaseId,
          currentLease.copyWith(status: DeviceLeaseStatus.released).toMap(),
          tx: tx,
        );
      }

      await _db.upsert('Device_Leases', newLease.leaseId, newLease.toMap(), tx: tx);

      final outboxEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_lease_${newLease.leaseId}',
        clinicId: clinicId,
        entityType: 'Device_Leases',
        entityId: newLease.leaseId,
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode(newLease.toMap()),
        createdAt: now,
        idempotencyKey: 'lease_${newLease.leaseId}',
      );
      await _db.upsert(
        'sync_outbox',
        outboxEvent.outboxEventId,
        outboxEvent.toMap(),
        tx: tx,
      );

      final audit = AuditEvent(
        auditEventId: 'audit_lease_acq_${now.millisecondsSinceEpoch}',
        clinicId: clinicId,
        actorId: staffId,
        actorRole: role.wireValue,
        deviceId: localDevice.deviceId,
        action: 'device_lease.acquire',
        entityType: 'device_lease',
        entityId: newLease.leaseId,
        occurredAt: now,
        result: AuditResult.success,
        correlationId: localDevice.deviceId,
      );
      await _db.upsert('Audit_Events', audit.auditEventId, audit.toMap(), tx: tx);
    });

    return newLease;
  }

  @override
  Future<DeviceLease> renewWriteLease({
    required String clinicId,
    required String staffId,
  }) async {
    final localDevice = await getLocalDevice(clinicId);
    final activeLease = await getActiveWriteLease(clinicId);

    if (activeLease == null || activeLease.holderDeviceId != localDevice.deviceId) {
      throw const DeviceLeaseFailure('No active write lease held by this workstation to renew.');
    }

    final now = DateTime.now().toUtc();
    final renewed = activeLease.copyWith(
      expiresAt: now.add(Duration(seconds: activeLease.durationSeconds)),
    );

    await _db.upsert('Device_Leases', renewed.leaseId, renewed.toMap());
    return renewed;
  }

  @override
  Future<void> releaseWriteLease({
    required String clinicId,
    required String staffId,
  }) async {
    final localDevice = await getLocalDevice(clinicId);
    final activeLease = await getActiveWriteLease(clinicId);

    if (activeLease == null) return;

    if (activeLease.holderDeviceId != localDevice.deviceId) {
      throw const DeviceLeaseFailure('Cannot release a write lease held by another workstation.');
    }

    final now = DateTime.now().toUtc();
    final released = activeLease.copyWith(status: DeviceLeaseStatus.released);

    await _db.transaction((tx) async {
      await _db.upsert('Device_Leases', released.leaseId, released.toMap(), tx: tx);

      final audit = AuditEvent(
        auditEventId: 'audit_lease_rel_${now.millisecondsSinceEpoch}',
        clinicId: clinicId,
        actorId: staffId,
        actorRole: activeLease.holderRole.wireValue,
        deviceId: localDevice.deviceId,
        action: 'device_lease.release',
        entityType: 'device_lease',
        entityId: released.leaseId,
        occurredAt: now,
        result: AuditResult.success,
        correlationId: localDevice.deviceId,
      );
      await _db.upsert('Audit_Events', audit.auditEventId, audit.toMap(), tx: tx);
    });
  }

  @override
  Future<DeviceLease> forceTransferLease({
    required String clinicId,
    required String staffId,
    required String targetDeviceId,
    required String reason,
  }) async {
    // Only Owner is authorized to forcibly revoke/transfer active leases
    final localDevice = await getLocalDevice(clinicId);
    final now = DateTime.now().toUtc();

    final activeLease = await getActiveWriteLease(clinicId);

    final newLease = DeviceLease(
      leaseId: 'lease_${now.millisecondsSinceEpoch}_$targetDeviceId',
      clinicId: clinicId,
      holderDeviceId: targetDeviceId,
      holderStaffId: staffId,
      holderRole: UserRole.owner,
      acquiredAt: now,
      expiresAt: now.add(const Duration(seconds: 300)),
      durationSeconds: 300,
      status: DeviceLeaseStatus.active,
    );

    await _db.transaction((tx) async {
      if (activeLease != null) {
        final revoked = activeLease.copyWith(status: DeviceLeaseStatus.forceRevoked);
        await _db.upsert('Device_Leases', revoked.leaseId, revoked.toMap(), tx: tx);
      }

      await _db.upsert('Device_Leases', newLease.leaseId, newLease.toMap(), tx: tx);

      final audit = AuditEvent(
        auditEventId: 'audit_lease_transfer_${now.millisecondsSinceEpoch}',
        clinicId: clinicId,
        actorId: staffId,
        actorRole: 'owner',
        deviceId: localDevice.deviceId,
        action: 'device_lease.force_transfer',
        entityType: 'device_lease',
        entityId: newLease.leaseId,
        occurredAt: now,
        result: AuditResult.success,
        correlationId: targetDeviceId,
        reasonOptional: reason,
      );
      await _db.upsert('Audit_Events', audit.auditEventId, audit.toMap(), tx: tx);
    });

    return newLease;
  }

  @override
  Future<void> sendHeartbeat(String clinicId) async {
    final localDevice = await getLocalDevice(clinicId);
    final now = DateTime.now().toUtc();

    final updated = localDevice.copyWith(lastHeartbeatAt: now);
    await _db.upsert('Devices', updated.deviceId, updated.toMap());

    // Auto-renew lease if this device holds it
    final lease = await getActiveWriteLease(clinicId);
    if (lease != null && lease.holderDeviceId == localDevice.deviceId && lease.isActive) {
      await renewWriteLease(clinicId: clinicId, staffId: lease.holderStaffId);
    }
  }

  @override
  Future<List<CollaborationConflict>> getConflicts(
    String clinicId, {
    bool unresolvedOnly = true,
  }) async {
    final records = _db.query(
      'Device_Conflicts',
      where: (r) => r['clinic_id'] == clinicId,
    );

    var conflicts = records.map((r) => CollaborationConflict.fromMap(r)).toList();
    if (unresolvedOnly) {
      conflicts = conflicts.where((c) => !c.isResolved).toList();
    }
    conflicts.sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
    return conflicts;
  }

  @override
  Future<void> recordConflict(CollaborationConflict conflict) async {
    await _db.transaction((tx) async {
      await _db.upsert(
        'Device_Conflicts',
        conflict.conflictId,
        conflict.toMap(),
        tx: tx,
      );

      final outboxEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_conflict_${conflict.conflictId}',
        clinicId: conflict.clinicId,
        entityType: 'Device_Conflicts',
        entityId: conflict.conflictId,
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode(conflict.toMap()),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: 'conflict_${conflict.conflictId}',
      );
      await _db.upsert(
        'sync_outbox',
        outboxEvent.outboxEventId,
        outboxEvent.toMap(),
        tx: tx,
      );

      final audit = AuditEvent(
        auditEventId: 'audit_conflict_det_${DateTime.now().millisecondsSinceEpoch}',
        clinicId: conflict.clinicId,
        actorId: 'system_coordinator',
        actorRole: 'system',
        deviceId: conflict.localDeviceId,
        action: 'collaboration.conflict_detected',
        entityType: 'collaboration_conflict',
        entityId: conflict.conflictId,
        occurredAt: DateTime.now().toUtc(),
        result: AuditResult.success,
        correlationId: conflict.entityId,
        reasonOptional: '${conflict.conflictType}: ${conflict.localSummary}',
      );
      await _db.upsert('Audit_Events', audit.auditEventId, audit.toMap(), tx: tx);
    });
  }

  @override
  Future<void> resolveConflict({
    required String conflictId,
    required String clinicId,
    required String staffId,
    required String resolutionStatus,
    String? notes,
  }) async {
    final existing = _db.get('Device_Conflicts', conflictId);
    if (existing == null) {
      throw const DatabaseFailure('Conflict record not found.');
    }

    final now = DateTime.now().toUtc();
    final conflict = CollaborationConflict.fromMap(existing).copyWith(
      resolutionStatus: resolutionStatus,
      resolvedAt: now,
      resolvedByStaffId: staffId,
      resolutionNotes: notes,
    );

    await _db.transaction((tx) async {
      await _db.upsert('Device_Conflicts', conflict.conflictId, conflict.toMap(), tx: tx);

      final audit = AuditEvent(
        auditEventId: 'audit_conflict_res_${now.millisecondsSinceEpoch}',
        clinicId: clinicId,
        actorId: staffId,
        actorRole: 'staff',
        deviceId: conflict.localDeviceId,
        action: 'collaboration.conflict_resolved',
        entityType: 'collaboration_conflict',
        entityId: conflict.conflictId,
        occurredAt: now,
        result: AuditResult.success,
        correlationId: conflict.entityId,
        reasonOptional: 'Resolution: $resolutionStatus. Notes: ${notes ?? "N/A"}',
      );
      await _db.upsert('Audit_Events', audit.auditEventId, audit.toMap(), tx: tx);
    });
  }

  @override
  Future<int> getNextAuthoritativeSequence(String clinicId, String streamKey) async {
    final key = '${clinicId}_$streamKey';
    final existing = _db.get('sequence_counters', key);
    final currentSeq = (existing?['sequence'] as int?) ?? 0;
    final nextSeq = currentSeq + 1;

    await _db.upsert('sequence_counters', key, {
      'clinic_id': clinicId,
      'stream_key': streamKey,
      'sequence': nextSeq,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    return nextSeq;
  }
}
