/**
 * Apna Clinic - Monthly Workbook Registry
 * Manages the Spreadsheet_Registry tab in Master Workbook
 */

var MonthlyWorkbookRegistry = {
  TAB_NAME: 'Spreadsheet_Registry',

  resolveMonth: function(masterSpreadsheetId, clinicId, yearMonth) {
    if (!masterSpreadsheetId) return null;
    var masterSs = SheetsRepository.openSpreadsheet(masterSpreadsheetId);
    var rows = SheetsRepository.readRows(masterSs, this.TAB_NAME);

    for (var i = 0; i < rows.length; i++) {
      var row = rows[i];
      if (String(row[0]) === String(clinicId) && String(row[1]) === String(yearMonth)) {
        return {
          clinicId: String(row[0]),
          yearMonth: String(row[1]),
          spreadsheetId: String(row[2]),
          status: String(row[3]),
          schemaVersion: String(row[4]),
          createdAt: String(row[5]),
          createdBy: String(row[6]),
          lastVerifiedAt: String(row[7])
        };
      }
    }
    return null;
  },

  registerMonth: function(masterSpreadsheetId, entry) {
    if (!masterSpreadsheetId) return;
    var masterSs = SheetsRepository.openSpreadsheet(masterSpreadsheetId);
    var rowValues = [
      entry.clinicId,
      entry.yearMonth,
      entry.spreadsheetId,
      entry.status || 'ACTIVE',
      entry.schemaVersion || '1.0.0',
      entry.createdAt || new Date().toISOString(),
      entry.createdBy || 'system_sync',
      entry.lastVerifiedAt || new Date().toISOString()
    ];

    // Find row by clinic_id + year_month
    var sheet = SheetsRepository.ensureTab(masterSs, this.TAB_NAME, CANONICAL_HEADERS.Spreadsheet_Registry);
    var lastRow = sheet.getLastRow();
    var foundIndex = -1;

    if (lastRow > 1) {
      var existingData = sheet.getRange(2, 1, lastRow - 1, 2).getValues();
      for (var i = 0; i < existingData.length; i++) {
        if (String(existingData[i][0]) === String(entry.clinicId) &&
            String(existingData[i][1]) === String(entry.yearMonth)) {
          foundIndex = i + 2;
          break;
        }
      }
    }

    if (foundIndex > 0) {
      sheet.getRange(foundIndex, 1, 1, rowValues.length).setValues([rowValues]);
    } else {
      sheet.appendRow(rowValues);
    }
  },

  listMonthsForClinic: function(masterSpreadsheetId, clinicId) {
    if (!masterSpreadsheetId) return [];
    var masterSs = SheetsRepository.openSpreadsheet(masterSpreadsheetId);
    var rows = SheetsRepository.readRows(masterSs, this.TAB_NAME);
    var result = [];

    for (var i = 0; i < rows.length; i++) {
      var row = rows[i];
      if (String(row[0]) === String(clinicId)) {
        result.push({
          clinicId: String(row[0]),
          yearMonth: String(row[1]),
          spreadsheetId: String(row[2]),
          status: String(row[3]),
          schemaVersion: String(row[4]),
          createdAt: String(row[5]),
          createdBy: String(row[6]),
          lastVerifiedAt: String(row[7])
        });
      }
    }

    // Sort descending by yearMonth
    result.sort(function(a, b) {
      return b.yearMonth.localeCompare(a.yearMonth);
    });

    return result;
  }
};

