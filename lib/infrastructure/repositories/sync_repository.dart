// Apna Clinic - Concrete Sync Repository
// BOUNDED BATCHES: Outbox pattern, acknowledgements before deletion, retry backoff.
// Primary source of truth: PRD Section 38, 39, 40 and TRD Section 11

import '../../domain/entities/entities.dart';
import '../../domain/enums/domain_enums.dart';
import '../../domain/repositories/i_sync_repository.dart';
import '../database/local_database.dart';

class SyncRepository implements ISyncRepository {
  final LocalDatabase _db;

  SyncRepository(this._db);

  @override
  Future<List<SyncOutboxEvent>> getPendingOutboxEvents(
    String clinicId, {
    int limit = 50,
  }) async {
    final records = _db.query(
      'sync_outbox',
      where: (r) {
        final recordClinicId = r['clinic_id'] as String? ?? '';
        if (clinicId.isNotEmpty && recordClinicId.isNotEmpty) {
          final cleanClinicA = clinicId.replaceFirst('clinic_', '');
          final cleanClinicB = recordClinicId.replaceFirst('clinic_', '');
          final isMatch = clinicId == recordClinicId ||
              cleanClinicA == cleanClinicB ||
              clinicId == 'primary_clinic' ||
              recordClinicId == 'clinic_primary_demo';
          if (!isMatch) return false;
        }
        final status = r['status'] as String? ?? 'pending';
        return status == OutboxStatus.pending.wireValue ||
            status == OutboxStatus.failed.wireValue;
      },
      limit: limit,
    );

    final events = records.map((r) => SyncOutboxEvent.fromMap(r)).toList();
    events.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return events;
  }

  @override
  Future<void> markEventsInFlight(List<String> eventIds) async {
    for (final id in eventIds) {
      final record = _db.get('sync_outbox', id);
      if (record != null) {
        final updated = Map<String, dynamic>.from(record);
        updated['status'] = OutboxStatus.inFlight.wireValue;
        await _db.upsert('sync_outbox', id, updated);
      }
    }
  }

  @override
  Future<void> acknowledgeEvents(
    List<String> eventIds,
    String syncBatchId,
  ) async {
    for (final id in eventIds) {
      final record = _db.get('sync_outbox', id);
      if (record != null) {
        final updated = Map<String, dynamic>.from(record);
        updated['status'] = OutboxStatus.acknowledged.wireValue;
        await _db.upsert('sync_outbox', id, updated);
      }
    }
  }

  @override
  Future<void> recordEventFailure(
    String eventId,
    String errorCode,
    String errorMessage,
  ) async {
    final record = _db.get('sync_outbox', eventId);
    if (record != null) {
      final updated = Map<String, dynamic>.from(record);
      final currentRetries = (updated['retry_count'] as num?)?.toInt() ?? 0;
      updated['retry_count'] = currentRetries + 1;
      updated['status'] = OutboxStatus.failed.wireValue;
      updated['last_error'] = '$errorCode: $errorMessage';
      await _db.upsert('sync_outbox', eventId, updated);
    }
  }

  @override
  Future<void> saveSyncManifest(SyncManifest manifest) async {
    await _db.upsert('Sync_Manifest', manifest.syncBatchId, manifest.toMap());
  }

  @override
  Future<SyncManifest?> getLastSyncManifest(String clinicId) async {
    final records = _db.query(
      'Sync_Manifest',
      where: (r) => r['clinic_id'] == clinicId,
    );
    if (records.isEmpty) return null;

    final manifests = records.map((r) => SyncManifest.fromMap(r)).toList();
    manifests.sort((a, b) {
      final tA =
          a.confirmedAt ??
          a.uploadedAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final tB =
          b.confirmedAt ??
          b.uploadedAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return tB.compareTo(tA);
    });
    return manifests.first;
  }

  @override
  Future<int> countPendingOutboxEvents(String clinicId) async {
    final pending = await getPendingOutboxEvents(clinicId, limit: 1000);
    return pending.length;
  }
}
