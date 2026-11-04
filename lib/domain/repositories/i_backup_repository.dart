// Apna Clinic - Backup Repository Interface
// ENCRYPTED SNAPSHOTS: Deterministic serialization, AES-GCM encryption, checksum validation.

import '../entities/entities.dart';

abstract class IBackupRepository {
  Future<Map<String, dynamic>> exportDatabaseSnapshot(String clinicId);
  Future<void> restoreDatabaseSnapshot(
    String clinicId,
    Map<String, dynamic> snapshot,
  );
  Future<void> saveBackupManifest(BackupManifest manifest);
  Future<BackupManifest?> getLatestBackupManifest(String clinicId);
  Future<void> updateVerificationStatus(
    String backupId,
    String status,
    DateTime verifiedAt,
  );
}
