// Apna Clinic - Module 13: Multi-Doctor & Multi-Device Live Collaboration Tests
// Primary Source of Truth: PRD Section 5 (M13), Section 7.3, TRD Section 2, Section 8, ADR-003, ADR-011.

import 'package:flutter_test/flutter_test.dart';
import 'package:apna_clinic/core/errors/failures.dart';
import 'package:apna_clinic/core/permissions/roles.dart';
import 'package:apna_clinic/domain/entities/entities.dart';
import 'package:apna_clinic/domain/services/authorization_service.dart';
import 'package:apna_clinic/infrastructure/database/local_database.dart';
import 'package:apna_clinic/infrastructure/database/storage_adapter.dart';
import 'package:apna_clinic/infrastructure/repositories/device_collaboration_repository.dart';

class InMemoryStorageAdapter implements IStorageAdapter {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> remove(String key) async => _data.remove(key);

  @override
  Future<void> clear() async => _data.clear();
}

void main() {
  group('MODULE 13 — MULTI-DOCTOR & MULTI-DEVICE LIVE COLLABORATION (PRD M13)', () {
    late LocalDatabase db;
    late DeviceCollaborationRepository collabRepo1;
    late DeviceCollaborationRepository collabRepo2;

    const testClinicId = 'clinic_m13_test';
    const testOwnerStaffId = 'staff_owner_m13';
    const testReceptStaffId = 'staff_recept_m13';
    const testDoctorStaffId = 'staff_doc_m13';
    const device1Id = 'terminal_reception_alpha';
    const device2Id = 'terminal_doctor_cabin_1';

    setUp(() async {
      final storage = InMemoryStorageAdapter();
      db = LocalDatabase(storage);
      await db.initialize();

      collabRepo1 = DeviceCollaborationRepository(db, initialDeviceId: device1Id);
      collabRepo2 = DeviceCollaborationRepository(db, initialDeviceId: device2Id);
    });

    test('1. Workstation Registration & Persistent Identity: Initializes and registers terminal', () async {
      final localDev = await collabRepo1.getLocalDevice(
        testClinicId,
        defaultName: 'Main Reception Terminal',
        defaultRole: DeviceRole.primaryReception,
      );

      expect(localDev.deviceId, equals(device1Id));
      expect(localDev.clinicId, equals(testClinicId));
      expect(localDev.deviceName, equals('Main Reception Terminal'));
      expect(localDev.deviceRole, equals(DeviceRole.primaryReception));
      expect(localDev.isOnline, isTrue);

      final roster = await collabRepo1.getConnectedDevices(testClinicId);
      expect(roster.length, equals(1));
      expect(roster.first.deviceId, equals(device1Id));
    });

    test('2. Multi-Terminal Heartbeats & Online Status: Detects active vs offline stations', () async {
      await collabRepo1.getLocalDevice(testClinicId);
      await collabRepo2.getLocalDevice(
        testClinicId,
        defaultName: 'Dr. Sharma Cabin Desk',
        defaultRole: DeviceRole.doctorDesk,
      );

      // Heartbeat sent by terminal 1
      await collabRepo1.sendHeartbeat(testClinicId);

      final roster = await collabRepo1.getConnectedDevices(testClinicId);
      expect(roster.length, equals(2));

      final docStation = roster.firstWhere((d) => d.deviceId == device2Id);
      expect(docStation.isOnline, isTrue);

      // Simulate a stale device from 5 minutes ago
      final staleDevice = docStation.copyWith(
        deviceId: 'terminal_stale',
        lastHeartbeatAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
      );
      expect(staleDevice.isOnline, isFalse);
    });

    test('3. Single-Writer Lease Acquisition: Grants exclusive primary write authority (ADR-003)', () async {
      final lease = await collabRepo1.acquireWriteLease(
        clinicId: testClinicId,
        staffId: testReceptStaffId,
        role: UserRole.receptionist,
        durationSeconds: 300,
      );

      expect(lease.holderDeviceId, equals(device1Id));
      expect(lease.holderStaffId, equals(testReceptStaffId));
      expect(lease.status, equals(DeviceLeaseStatus.active));
      expect(lease.isActive, isTrue);
      expect(lease.isExpired, isFalse);

      final isWriter1 = await collabRepo1.isCurrentDeviceAuthoritativeWriter(testClinicId);
      final isWriter2 = await collabRepo2.isCurrentDeviceAuthoritativeWriter(testClinicId);

      expect(isWriter1, isTrue);
      expect(isWriter2, isFalse);
    });

    test('4. Concurrent Write Protection: Prevents second station from seizing active lease', () async {
      // Station 1 acquires active lease
      await collabRepo1.acquireWriteLease(
        clinicId: testClinicId,
        staffId: testReceptStaffId,
        role: UserRole.receptionist,
        durationSeconds: 300,
      );

      // Station 2 attempts to acquire lease while station 1 lease is unexpired
      expect(
        () async => await collabRepo2.acquireWriteLease(
          clinicId: testClinicId,
          staffId: testDoctorStaffId,
          role: UserRole.receptionist,
        ),
        throwsA(isA<DeviceLeaseFailure>()),
      );
    });

    test('5. Lease Auto-Expiration: Permits acquisition once prior lease expires', () async {
      // Insert an expired lease directly
      final expiredLease = DeviceLease(
        leaseId: 'lease_expired_test',
        clinicId: testClinicId,
        holderDeviceId: device1Id,
        holderStaffId: testReceptStaffId,
        holderRole: UserRole.receptionist,
        acquiredAt: DateTime.now().toUtc().subtract(const Duration(minutes: 10)),
        expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
        status: DeviceLeaseStatus.active,
      );
      await db.upsert('Device_Leases', expiredLease.leaseId, expiredLease.toMap());

      // Active lease check detects expiration
      final current = await collabRepo2.getActiveWriteLease(testClinicId);
      expect(current, isNull);

      // Station 2 can now acquire the lease cleanly
      final newLease = await collabRepo2.acquireWriteLease(
        clinicId: testClinicId,
        staffId: testOwnerStaffId,
        role: UserRole.owner,
      );
      expect(newLease.holderDeviceId, equals(device2Id));
      expect(newLease.isActive, isTrue);
    });

    test('6. Lease Renewal & Release: Supports heartbeat extension and clean relinquishment', () async {
      await collabRepo1.acquireWriteLease(
        clinicId: testClinicId,
        staffId: testReceptStaffId,
        role: UserRole.receptionist,
        durationSeconds: 100,
      );

      final renewed = await collabRepo1.renewWriteLease(
        clinicId: testClinicId,
        staffId: testReceptStaffId,
      );
      expect(renewed.isActive, isTrue);

      await collabRepo1.releaseWriteLease(
        clinicId: testClinicId,
        staffId: testReceptStaffId,
      );

      final active = await collabRepo1.getActiveWriteLease(testClinicId);
      expect(active, isNull);
    });

    test('7. Owner Force-Transfer: Emergency lease rotation with immutable audit event', () async {
      // Station 1 holds lease
      await collabRepo1.acquireWriteLease(
        clinicId: testClinicId,
        staffId: testReceptStaffId,
        role: UserRole.receptionist,
      );

      // Owner forcibly rotates lease to Station 2
      final transferred = await collabRepo1.forceTransferLease(
        clinicId: testClinicId,
        staffId: testOwnerStaffId,
        targetDeviceId: device2Id,
        reason: 'Workstation 1 hardware malfunction reported',
      );

      expect(transferred.holderDeviceId, equals(device2Id));
      expect(transferred.isActive, isTrue);

      final audits = await db.query('Audit_Events');
      final transferAudit = audits.firstWhere((a) => a['action'] == 'device_lease.force_transfer');
      expect(transferAudit['actor_id'], equals(testOwnerStaffId));
      expect(transferAudit['correlation_id'], equals(device2Id));
      expect(transferAudit['reason_optional'], contains('hardware malfunction'));
    });

    test('8. Monotonic Sequence Vector Ordering: Generates deterministic sequence counters', () async {
      final seq1 = await collabRepo1.getNextAuthoritativeSequence(testClinicId, 'queue_stream');
      final seq2 = await collabRepo1.getNextAuthoritativeSequence(testClinicId, 'queue_stream');
      final seq3 = await collabRepo2.getNextAuthoritativeSequence(testClinicId, 'queue_stream');

      expect(seq1, equals(1));
      expect(seq2, equals(2));
      expect(seq3, equals(3));
    });

    test('9. Collaboration Conflict Ledger & Resolution: Resolves conflicts with zero clinical leakage', () async {
      final conflict = CollaborationConflict(
        conflictId: 'conflict_test_01',
        clinicId: testClinicId,
        entityType: 'appointment',
        entityId: 'slot_1000_1015',
        localDeviceId: device1Id,
        remoteDeviceId: device2Id,
        conflictType: 'overlapping_slot',
        detectedAt: DateTime.now().toUtc(),
        localSummary: 'Dr. Sharma 10:00 AM slot booked by Reception Desk',
        remoteSummary: 'Dr. Sharma 10:00 AM slot requested by Doctor Mobile',
      );

      await collabRepo1.recordConflict(conflict);

      final unresolved = await collabRepo1.getConflicts(testClinicId, unresolvedOnly: true);
      expect(unresolved.length, equals(1));
      expect(unresolved.first.conflictId, equals('conflict_test_01'));
      expect(unresolved.first.isResolved, isFalse);

      // Resolve conflict
      await collabRepo1.resolveConflict(
        conflictId: 'conflict_test_01',
        clinicId: testClinicId,
        staffId: testOwnerStaffId,
        resolutionStatus: 'resolved_keep_local',
        notes: 'Reception desk slot booked first; doctor notified',
      );

      final all = await collabRepo1.getConflicts(testClinicId, unresolvedOnly: false);
      expect(all.first.isResolved, isTrue);
      expect(all.first.resolutionStatus, equals('resolved_keep_local'));
      expect(all.first.resolvedByStaffId, equals(testOwnerStaffId));
      expect(all.first.resolutionNotes, contains('Reception desk slot'));
    });

    test('10. Strict RBAC: Owner and Receptionist manage lease; Doctor and Accountant denied', () {
      // Owner
      expect(
        AuthorizationService.hasPermission(role: UserRole.owner, permission: AppPermission.manageDeviceLease),
        isTrue,
      );
      expect(
        AuthorizationService.hasPermission(role: UserRole.owner, permission: AppPermission.resolveConflicts),
        isTrue,
      );

      // Receptionist
      expect(
        AuthorizationService.hasPermission(role: UserRole.receptionist, permission: AppPermission.manageDeviceLease),
        isTrue,
      );
      expect(
        AuthorizationService.hasPermission(role: UserRole.receptionist, permission: AppPermission.resolveConflicts),
        isTrue,
      );

      // Doctor (strictly denied administrative lease grabbing)
      expect(
        AuthorizationService.hasPermission(role: UserRole.doctor, permission: AppPermission.manageDeviceLease),
        isFalse,
      );
      expect(
        AuthorizationService.hasPermission(role: UserRole.doctor, permission: AppPermission.resolveConflicts),
        isFalse,
      );

      // Accountant (strictly denied device administration)
      expect(
        AuthorizationService.hasPermission(role: UserRole.accountant, permission: AppPermission.manageDeviceLease),
        isFalse,
      );
      expect(
        AuthorizationService.hasPermission(role: UserRole.accountant, permission: AppPermission.resolveConflicts),
        isFalse,
      );
    });
  });
}
