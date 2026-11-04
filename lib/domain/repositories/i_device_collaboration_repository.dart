// Apna Clinic - Module 13: Multi-Doctor & Multi-Device Live Collaboration Repository Interface
// Primary Source of Truth: PRD Section 5 (M13), Section 7.3, TRD Section 2, Section 8, ADR-003, ADR-011.

import '../../core/permissions/roles.dart';
import '../entities/device_state.dart';

abstract class IDeviceCollaborationRepository {
  /// Gets or creates the local workstation's persistent registration.
  Future<DeviceRegistration> getLocalDevice(
    String clinicId, {
    String? defaultName,
    DeviceRole? defaultRole,
  });

  /// Persists or updates workstation registration in the clinic roster.
  Future<void> registerDevice(DeviceRegistration device);

  /// Updates friendly workstation name (e.g., 'Reception Counter 1').
  Future<void> updateDeviceName({
    required String clinicId,
    required String deviceId,
    required String newName,
  });

  /// Returns all connected workstations/devices registered to this clinic.
  Future<List<DeviceRegistration>> getConnectedDevices(String clinicId);

  /// Returns the current active single-writer lease, or null if unassigned/expired.
  Future<DeviceLease?> getActiveWriteLease(String clinicId);

  /// Checks whether the local device currently holds authoritative write authority.
  Future<bool> isCurrentDeviceAuthoritativeWriter(String clinicId);

  /// Acquires single-writer lease for the current device.
  /// Throws [DeviceLeaseConflictException] if another device holds an active unexpired lease.
  Future<DeviceLease> acquireWriteLease({
    required String clinicId,
    required String staffId,
    required UserRole role,
    int durationSeconds = 300,
  });

  /// Renews current device's lease duration via periodic heartbeat.
  Future<DeviceLease> renewWriteLease({
    required String clinicId,
    required String staffId,
  });

  /// Explicitly releases write lease back to unassigned state.
  Future<void> releaseWriteLease({
    required String clinicId,
    required String staffId,
  });

  /// Forcibly transfers write lease to a target workstation with immutable audit log (Owner only).
  Future<DeviceLease> forceTransferLease({
    required String clinicId,
    required String staffId,
    required String targetDeviceId,
    required String reason,
  });

  /// Broadcasts a device presence heartbeat to keep workstation active in roster.
  Future<void> sendHeartbeat(String clinicId);

  /// Returns conflict records for the clinic.
  Future<List<CollaborationConflict>> getConflicts(
    String clinicId, {
    bool unresolvedOnly = true,
  });

  /// Records a detected concurrent conflict (e.g., overlapping appointment slots).
  Future<void> recordConflict(CollaborationConflict conflict);

  /// Resolves a collaboration conflict with explicit resolution action and audit notes.
  Future<void> resolveConflict({
    required String conflictId,
    required String clinicId,
    required String staffId,
    required String resolutionStatus,
    String? notes,
  });

  /// Generates the next monotonic sequence number for causal ordering across devices.
  Future<int> getNextAuthoritativeSequence(String clinicId, String streamKey);
}

