// Apna Clinic - Sync Repository Interface
// BOUNDED BATCHES: Outbox pattern, acknowledgements before deletion, retry backoff.

import '../entities/entities.dart';

abstract class ISyncRepository {
  Future<List<SyncOutboxEvent>> getPendingOutboxEvents(
    String clinicId, {
    int limit = 50,
  });

  Future<void> markEventsInFlight(List<String> eventIds);

  Future<void> acknowledgeEvents(List<String> eventIds, String syncBatchId);

  Future<void> recordEventFailure(
    String eventId,
    String errorCode,
    String errorMessage,
  );

  Future<void> saveSyncManifest(SyncManifest manifest);

  Future<SyncManifest?> getLastSyncManifest(String clinicId);

  Future<int> countPendingOutboxEvents(String clinicId);
}
