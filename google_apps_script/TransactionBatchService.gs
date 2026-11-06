/**
 * Apna Clinic - Transaction Batch Service
 * Appends transaction batches to partitioned monthly workbooks
 * Feature TRD Section 7, 9, 10
 */

var TransactionBatchService = {
  resolveDestinationTab: function(entityType) {
    var lower = String(entityType || '').toLowerCase();
    switch (lower) {
      case 'appointments':
      case '06_appointments':
        return 'Appointments';
      case 'visits':
      case 'consultations':
      case '09_consultations':
        return 'Visits';
      case 'invoices':
      case 'billing':
      case '10_billing':
        return 'Billing';
      case 'payments':
      case '11_payments':
        return 'Payments';
      case 'queue_events':
      case '08_queue':
        return 'Queue_Events';
      default:
        return entityType;
    }
  },

  formatPayloadToRow: function(tabName, payload) {
    var headers = CANONICAL_HEADERS[tabName] || [];
    if (!headers.length) {
      return Object.keys(payload).map(function(k) { return payload[k]; });
    }
    var row = [];
    for (var i = 0; i < headers.length; i++) {
      var key = headers[i];
      var val = payload[key];
      if (val === undefined || val === null) {
        val = '';
      }
      row.push(val);
    }
    return row;
  },

  processBatch: function(params) {
    var payload = params.payload || {};
    var clinicId = params.clinicId;
    var yearMonth = payload.yearMonth;
    var batchId = payload.batchId || Utilities.getUuid();
    var operations = payload.operations || [];
    var masterSpreadsheetId = payload.masterSpreadsheetId;
    var clinicDriveFolderId = payload.clinicDriveFolderId;

    if (!validateYearMonth(yearMonth)) {
      throw { code: 'INVALID_REQUEST', message: 'Invalid or missing yearMonth: ' + yearMonth };
    }

    // 1. Resolve or provision destination monthly workbook
    var monthEntry = MonthlyWorkbookProvisioner.provisionMonth({
      clinicId: clinicId,
      yearMonth: yearMonth,
      clinicDriveFolderId: clinicDriveFolderId,
      masterSpreadsheetId: masterSpreadsheetId
    });

    var monthlySs = SheetsRepository.openSpreadsheet(monthEntry.spreadsheetId);

    // 2. Group operations by destination tab
    var opsByTab = {};
    for (var i = 0; i < operations.length; i++) {
      var op = operations[i];
      var tabName = this.resolveDestinationTab(op.entityType);
      if (!opsByTab[tabName]) opsByTab[tabName] = [];
      opsByTab[tabName].push(op);
    }

    var results = [];
    var patientIndexItems = [];

    // 3. Append to each tab
    var tabNames = Object.keys(opsByTab);
    for (var t = 0; t < tabNames.length; t++) {
      var curTab = tabNames[t];
      var ops = opsByTab[curTab];
      var rowsToAppend = [];

      for (var j = 0; j < ops.length; j++) {
        var op = ops[j];
        var row = Array.isArray(op.payload) ? op.payload : this.formatPayloadToRow(curTab, op.payload || {});
        rowsToAppend.push(row);

        if (op.patientId) {
          patientIndexItems.push({
            patientId: op.patientId,
            yearMonth: yearMonth,
            recordType: String(op.entityType).toLowerCase(),
            recordTimestamp: op.businessDate || new Date().toISOString()
          });
        }

        results.push({
          operationId: op.operationId || Utilities.getUuid(),
          entityId: op.entityId || '',
          success: true,
          status: 'COMMITTED',
          targetSpreadsheetId: monthEntry.spreadsheetId,
          targetSheetName: curTab
        });
      }

      if (rowsToAppend.length > 0) {
        SheetsRepository.appendRows(monthlySs, curTab, rowsToAppend);
      }
    }

    // 4. Update Patient History Index in Master Workbook
    if (masterSpreadsheetId && patientIndexItems.length > 0) {
      try {
        PatientHistoryIndexService.updateIndexBatch(masterSpreadsheetId, clinicId, patientIndexItems);
      } catch (e) {
        // Log error, but batch itself succeeded
      }
    }

    // 5. Update Sync Manifest
    if (masterSpreadsheetId) {
      try {
        SyncManifestService.recordBatch(masterSpreadsheetId, {
          batchId: batchId,
          clinicId: clinicId,
          deviceId: payload.deviceId || 'primary_device',
          eventCount: operations.length,
          status: 'COMMITTED'
        });
      } catch (e) {}
    }

    return {
      batchId: batchId,
      yearMonth: yearMonth,
      spreadsheetId: monthEntry.spreadsheetId,
      results: results
    };
  }
};

