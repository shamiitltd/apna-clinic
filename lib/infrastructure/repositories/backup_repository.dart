// Apna Clinic - Concrete Backup Repository
// ENCRYPTED SNAPSHOTS: Deterministic serialization, AES-GCM encryption, checksum validation.
// Primary source of truth: PRD Section 42, 43, 44, 45 and TRD Section 13

import '../../domain/entities/entities.dart';
import '../../domain/repositories/i_backup_repository.dart';
import '../database/local_database.dart';

class BackupRepository implements IBackupRepository {
  final LocalDatabase _db;

  BackupRepository(this._db);

  @override
  Future<Map<String, dynamic>> exportDatabaseSnapshot(String clinicId) async {
    return _db.exportFullSnapshot(clinicId);
  }

  @override
  Future<void> restoreDatabaseSnapshot(
    String clinicId,
    Map<String, dynamic> snapshot,
  ) async {
    await _db.restoreFullSnapshot(clinicId, snapshot);
  }

  @override
  Future<void> saveBackupManifest(BackupManifest manifest) async {
    await _db.upsert('backup_manifests', manifest.backupId, manifest.toMap());
  }

  @override
  Future<BackupManifest?> getLatestBackupManifest(String clinicId) async {
    final records = _db.query(
      'backup_manifests',
      where: (r) => r['clinic_id'] == clinicId,
    );
    if (records.isEmpty) return null;

    final manifests = records.map((r) => BackupManifest.fromMap(r)).toList();
    manifests.sort((a, b) => b.backupTimestamp.compareTo(a.backupTimestamp));
    return manifests.first;
  }

  @override
  Future<void> updateVerificationStatus(
    String backupId,
    String status,
    DateTime verifiedAt,
  ) async {
    final record = _db.get('backup_manifests', backupId);
    if (record != null) {
      final updated = Map<String, dynamic>.from(record);
      updated['verification_status'] = status;
      updated['verified_at'] = verifiedAt.toIso8601String();
      await _db.upsert('backup_manifests', backupId, updated);
    }
  }

  /// Returns all active monthly transaction workbooks for clinic backup inclusion
  Future<List<Map<String, dynamic>>> getActiveMonthlyWorkbooks(String clinicId) async {
    return _db.query(
      'Spreadsheet_Registry',
      where: (r) => r['clinic_id'] == clinicId && r['status'] == 'ACTIVE',
    );
  }
}
