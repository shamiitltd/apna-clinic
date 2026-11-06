/**
 * Apna Clinic - Monthly Workbook Provisioner
 * Creates and initializes monthly transaction workbooks
 */

var MonthlyWorkbookProvisioner = {
  provisionMonth: function(params) {
    var clinicId = params.clinicId;
    var yearMonth = params.yearMonth;
    var clinicDriveFolderId = params.clinicDriveFolderId;
    var masterSpreadsheetId = params.masterSpreadsheetId;
    var createdBy = params.createdBy || 'system_sync';

    if (!validateYearMonth(yearMonth)) {
      throw { code: 'INVALID_REQUEST', message: 'Invalid year_month format: ' + yearMonth + '. Expected YYYY-MM.' };
    }

    // 1. Check if already registered
    if (masterSpreadsheetId) {
      var existing = MonthlyWorkbookRegistry.resolveMonth(masterSpreadsheetId, clinicId, yearMonth);
      if (existing && existing.status === 'ACTIVE' && existing.spreadsheetId) {
        return existing;
      }
    }

    var workbookTitle = 'ApnaClinic_' + clinicId + '_Transactions_' + yearMonth.replace('-', '_');

    // 2. Check if file already exists in Drive folder to avoid duplicate creation
    var existingFile = DriveRepository.findFileByName(workbookTitle, clinicDriveFolderId);
    var monthlySs;
    var spreadsheetId;

    if (existingFile) {
      spreadsheetId = existingFile.getId();
      monthlySs = SpreadsheetApp.openById(spreadsheetId);
    } else {
      monthlySs = DriveRepository.createSpreadsheetInFolder(workbookTitle, clinicDriveFolderId);
      spreadsheetId = monthlySs.getId();
    }

    // 3. Ensure transaction tabs and canonical headers
    var transactionTabs = ['Appointments', 'Visits', 'Billing', 'Payments', 'Queue_Events'];
    for (var i = 0; i < transactionTabs.length; i++) {
      var tabName = transactionTabs[i];
      SheetsRepository.ensureTab(monthlySs, tabName, CANONICAL_HEADERS[tabName]);
    }

    // Remove default 'Sheet1' if present and other tabs exist
    try {
      var defaultSheet = monthlySs.getSheetByName('Sheet1');
      if (defaultSheet && monthlySs.getSheets().length > 1) {
        monthlySs.deleteSheet(defaultSheet);
      }
    } catch (_) {}

    var nowIso = new Date().toISOString();
    var entry = {
      clinicId: clinicId,
      yearMonth: yearMonth,
      spreadsheetId: spreadsheetId,
      status: 'ACTIVE',
      schemaVersion: '1.0.0',
      createdAt: nowIso,
      createdBy: createdBy,
      lastVerifiedAt: nowIso
    };

    // 4. Register in Master Workbook
    if (masterSpreadsheetId) {
      MonthlyWorkbookRegistry.registerMonth(masterSpreadsheetId, entry);
    }

    return entry;
  }
};

