/**
 * Apna Clinic - Patient History Index Service
 * Manages Patient_History_Index in Master Workbook and routes cross-month patient queries
 */

var PatientHistoryIndexService = {
  TAB_NAME: 'Patient_History_Index',

  getPatientHistoryIndex: function(masterSpreadsheetId, clinicId, patientId) {
    if (!masterSpreadsheetId) return [];
    var masterSs = SheetsRepository.openSpreadsheet(masterSpreadsheetId);
    var rows = SheetsRepository.readRows(masterSs, this.TAB_NAME);
    var results = [];

    for (var i = 0; i < rows.length; i++) {
      var row = rows[i];
      if (String(row[0]) === String(clinicId) && String(row[1]) === String(patientId)) {
        results.push({
          clinicId: String(row[0]),
          patientId: String(row[1]),
          yearMonth: String(row[2]),
          recordType: String(row[3]),
          firstRecordAt: String(row[4]),
          lastRecordAt: String(row[5]),
          recordCount: Number(row[6]) || 1,
          lastUpdatedAt: String(row[7])
        });
      }
    }

    results.sort(function(a, b) {
      return b.yearMonth.localeCompare(a.yearMonth);
    });

    return results;
  },

  updateIndexBatch: function(masterSpreadsheetId, clinicId, items) {
    if (!masterSpreadsheetId || !items || items.length === 0) return;
    var masterSs = SheetsRepository.openSpreadsheet(masterSpreadsheetId);
    var sheet = SheetsRepository.ensureTab(masterSs, this.TAB_NAME, CANONICAL_HEADERS.Patient_History_Index);
    var lastRow = sheet.getLastRow();

    // Map existing rows: compositeKey -> rowIndex (1-based)
    var keyToRow = {};
    var existingRows = [];
    if (lastRow > 1) {
      existingRows = sheet.getRange(2, 1, lastRow - 1, 8).getValues();
      for (var i = 0; i < existingRows.length; i++) {
        var r = existingRows[i];
        var key = String(r[0]) + ':' + String(r[1]) + ':' + String(r[2]) + ':' + String(r[3]);
        keyToRow[key] = i + 2; // 1-based sheet row
      }
    }

    var nowIso = new Date().toISOString();

    for (var j = 0; j < items.length; j++) {
      var item = items[j];
      if (!item.patientId || !item.yearMonth || !item.recordType) continue;

      var compKey = clinicId + ':' + item.patientId + ':' + item.yearMonth + ':' + item.recordType;
      var ts = item.recordTimestamp || nowIso;

      if (keyToRow[compKey]) {
        var rowNum = keyToRow[compKey];
        var rowData = sheet.getRange(rowNum, 1, 1, 8).getValues()[0];
        var curCount = Number(rowData[6]) || 1;
        var firstAt = String(rowData[4]);
        var lastAt = String(rowData[5]);

        if (ts < firstAt || !firstAt) firstAt = ts;
        if (ts > lastAt || !lastAt) lastAt = ts;

        sheet.getRange(rowNum, 5, 1, 4).setValues([[
          firstAt,
          lastAt,
          curCount + 1,
          nowIso
        ]]);
      } else {
        var newRow = [
          clinicId,
          item.patientId,
          item.yearMonth,
          item.recordType,
          ts,
          ts,
          1,
          nowIso
        ];
        sheet.appendRow(newRow);
        keyToRow[compKey] = sheet.getLastRow();
      }
    }
  }
};

