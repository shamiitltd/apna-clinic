/**
 * Apna Clinic - Sync Manifest Service
 * Tracks batch execution metadata in Sync_Manifest tab
 * Feature TRD Section 5.2
 */

var SyncManifestService = {
  TAB_NAME: 'Sync_Manifest',

  recordBatch: function(masterSpreadsheetId, entry) {
    if (!masterSpreadsheetId) return;
    var masterSs = SheetsRepository.openSpreadsheet(masterSpreadsheetId);
    var rowValues = [
      entry.batchId,
      entry.clinicId,
      entry.deviceId || 'primary_device',
      entry.firstEventId || '',
      entry.lastEventId || '',
      Number(entry.eventCount) || 0,
      entry.checksum || '',
      entry.schemaVersion || '1.0.0',
      entry.status || 'COMMITTED',
      entry.createdAt || new Date().toISOString(),
      entry.confirmedAt || new Date().toISOString(),
      entry.lastErrorCode || ''
    ];

    SheetsRepository.upsertRowByKey(
      masterSs,
      this.TAB_NAME,
      0, // column 0 is batch_id
      entry.batchId,
      rowValues
    );
  },

  getSyncStatus: function(masterSpreadsheetId, clinicId, batchId) {
    if (!masterSpreadsheetId) return null;
    var masterSs = SheetsRepository.openSpreadsheet(masterSpreadsheetId);
    var rows = SheetsRepository.readRows(masterSs, this.TAB_NAME);

    for (var i = 0; i < rows.length; i++) {
      var row = rows[i];
      if (String(row[0]) === String(batchId) && String(row[1]) === String(clinicId)) {
        return {
          batchId: String(row[0]),
          clinicId: String(row[1]),
          deviceId: String(row[2]),
          eventCount: Number(row[5]),
          status: String(row[8]),
          createdAt: String(row[9]),
          confirmedAt: String(row[10])
        };
      }
    }
    return null;
  }
};

