/**
 * Apna Clinic - Reconciliation Service
 * Reconciles Patient_History_Index against partitioned monthly workbooks
 * Feature TRD Section 12, 13
 */

var ReconciliationService = {
  reconcilePatientIndex: function(params) {
    var clinicId = params.clinicId;
    var masterSpreadsheetId = params.masterSpreadsheetId;
    if (!masterSpreadsheetId) {
      throw { code: 'INVALID_REQUEST', message: 'Master spreadsheet ID required for reconciliation' };
    }

    var months = MonthlyWorkbookRegistry.listMonthsForClinic(masterSpreadsheetId, clinicId);
    var indexItems = [];
    var scannedMonths = [];

    for (var m = 0; m < months.length; m++) {
      var monthEntry = months[m];
      if (monthEntry.status !== 'ACTIVE' || !monthEntry.spreadsheetId) continue;

      scannedMonths.push(monthEntry.yearMonth);
      try {
        var monthlySs = SheetsRepository.openSpreadsheet(monthEntry.spreadsheetId);
        var tabsToCheck = [
          { name: 'Visits', type: 'visits', patientCol: 2, dateCol: 6 },
          { name: 'Appointments', type: 'appointments', patientCol: 2, dateCol: 4 },
          { name: 'Billing', type: 'billing', patientCol: 3, dateCol: 4 },
          { name: 'Payments', type: 'payments', patientCol: 3, dateCol: 4 }
        ];

        for (var t = 0; t < tabsToCheck.length; t++) {
          var cfg = tabsToCheck[t];
          var rows = SheetsRepository.readRows(monthlySs, cfg.name);
          for (var r = 0; r < rows.length; r++) {
            var row = rows[r];
            var pId = String(row[cfg.patientCol] || '');
            var dStr = String(row[cfg.dateCol] || '');
            if (pId) {
              indexItems.push({
                patientId: pId,
                yearMonth: monthEntry.yearMonth,
                recordType: cfg.type,
                recordTimestamp: dStr || new Date().toISOString()
              });
            }
          }
        }
      } catch (e) {
        // Individual month workbook read failure
      }
    }

    if (indexItems.length > 0) {
      PatientHistoryIndexService.updateIndexBatch(masterSpreadsheetId, clinicId, indexItems);
    }

    return {
      clinicId: clinicId,
      scannedMonths: scannedMonths,
      totalRecordsIndexed: indexItems.length,
      timestamp: new Date().toISOString()
    };
  }
};

