/**
 * Apna Clinic - Sheets Repository
 * Low-level Google Sheets operations
 */

var SheetsRepository = {
  openSpreadsheet: function(spreadsheetId) {
    if (!spreadsheetId) {
      throw { code: 'INVALID_REQUEST', message: 'Spreadsheet ID cannot be empty' };
    }
    try {
      return SpreadsheetApp.openById(spreadsheetId);
    } catch (e) {
      throw { code: 'MONTH_WORKBOOK_UNAVAILABLE', message: 'Unable to open spreadsheet ' + spreadsheetId + ': ' + e.message };
    }
  },

  ensureTab: function(spreadsheet, tabName, headers) {
    var sheet = spreadsheet.getSheetByName(tabName);
    if (!sheet) {
      sheet = spreadsheet.insertSheet(tabName);
      if (headers && headers.length > 0) {
        sheet.appendRow(headers);
        sheet.getRange(1, 1, 1, headers.length).setFontWeight('bold');
        sheet.setFrozenRows(1);
      }
    } else {
      if (headers && headers.length > 0 && sheet.getLastRow() <= 1) {
        sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
        sheet.getRange(1, 1, 1, headers.length).setFontWeight('bold');
        sheet.setFrozenRows(1);
      }
    }
    return sheet;
  },

  readRows: function(spreadsheet, tabName) {
    var sheet = spreadsheet.getSheetByName(tabName);
    if (!sheet) return [];
    var lastRow = sheet.getLastRow();
    var lastCol = sheet.getLastColumn();
    if (lastRow <= 1 || lastCol === 0) return [];
    return sheet.getRange(2, 1, lastRow - 1, lastCol).getValues();
  },

  appendRows: function(spreadsheet, tabName, rows) {
    if (!rows || rows.length === 0) return;
    var sheet = this.ensureTab(spreadsheet, tabName, CANONICAL_HEADERS[tabName]);
    var startRow = sheet.getLastRow() + 1;
    var numRows = rows.length;
    var numCols = rows[0].length;
    sheet.getRange(startRow, 1, numRows, numCols).setValues(rows);
  },

  upsertRowByKey: function(spreadsheet, tabName, keyColumnIndex, keyValue, rowValues) {
    var sheet = this.ensureTab(spreadsheet, tabName, CANONICAL_HEADERS[tabName]);
    var lastRow = sheet.getLastRow();
    var foundRow = -1;

    if (lastRow > 1) {
      var keys = sheet.getRange(2, keyColumnIndex + 1, lastRow - 1, 1).getValues();
      for (var i = 0; i < keys.length; i++) {
        if (String(keys[i][0]) === String(keyValue)) {
          foundRow = i + 2;
          break;
        }
      }
    }

    if (foundRow > 0) {
      sheet.getRange(foundRow, 1, 1, rowValues.length).setValues([rowValues]);
    } else {
      sheet.appendRow(rowValues);
    }
  }
};

