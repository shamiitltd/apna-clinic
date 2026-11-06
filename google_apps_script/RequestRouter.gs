/**
 * Apna Clinic - Request Router
 * Routes incoming API actions to domain services
 * Feature TRD Section 4, 9
 */

var RequestRouter = {
  handleRequest: function(envelope) {
    validateEnvelope(envelope);

    var caller = CallerAuthService.authenticateCaller(envelope);
    var masterSpreadsheetId = envelope.payload && envelope.payload.masterSpreadsheetId;
    ClinicAccessService.verifyClinicAccess(caller, envelope.clinicId, masterSpreadsheetId);

    // Check Idempotency for mutating operations
    var cached = IdempotencyService.checkIdempotency(envelope);
    if (cached) {
      return createSuccessResponse(envelope.requestId, cached, { idempotentReplay: true });
    }

    var result;
    switch (envelope.action) {
      case 'monthlyStorage.resolveMonth':
        result = MonthlyWorkbookRegistry.resolveMonth(
          envelope.payload.masterSpreadsheetId,
          envelope.clinicId,
          envelope.payload.yearMonth
        );
        break;

      case 'monthlyStorage.provisionMonth':
        result = MonthlyWorkbookProvisioner.provisionMonth({
          clinicId: envelope.clinicId,
          yearMonth: envelope.payload.yearMonth,
          clinicDriveFolderId: envelope.payload.clinicDriveFolderId,
          masterSpreadsheetId: envelope.payload.masterSpreadsheetId,
          createdBy: caller.email
        });
        break;

      case 'monthlyStorage.syncBatch':
        result = TransactionBatchService.processBatch({
          clinicId: envelope.clinicId,
          payload: envelope.payload
        });
        break;

      case 'monthlyStorage.getPatientHistory':
        result = PatientHistoryIndexService.getPatientHistoryIndex(
          envelope.payload.masterSpreadsheetId,
          envelope.clinicId,
          envelope.payload.patientId
        );
        break;

      case 'monthlyStorage.getSyncStatus':
        result = SyncManifestService.getSyncStatus(
          envelope.payload.masterSpreadsheetId,
          envelope.clinicId,
          envelope.payload.batchId
        );
        break;

      case 'monthlyStorage.reconcilePatientIndex':
        result = ReconciliationService.reconcilePatientIndex({
          clinicId: envelope.clinicId,
          masterSpreadsheetId: envelope.payload.masterSpreadsheetId
        });
        break;

      case 'monthlyStorage.listMonthsForClinic':
        result = MonthlyWorkbookRegistry.listMonthsForClinic(
          envelope.payload.masterSpreadsheetId,
          envelope.clinicId
        );
        break;

      default:
        throw { code: 'INVALID_REQUEST', message: 'Action not handled: ' + envelope.action };
    }

    IdempotencyService.recordResult(envelope, result);
    return createSuccessResponse(envelope.requestId, result);
  }
};

