/**
 * Apna Clinic - Entry Point
 * Google Apps Script Web App Entrypoint (doGet, doPost)
 * Feature TRD Section 4, 9
 */

function doGet(e) {
  var statusOutput = {
    status: 'ONLINE',
    service: 'Apna Clinic Monthly Storage & Partitioning API',
    version: '1.0.0',
    timeZone: 'Asia/Kolkata',
    timestamp: new Date().toISOString()
  };

  return ContentService
    .createTextOutput(JSON.stringify(statusOutput))
    .setMimeType(ContentService.MimeType.JSON);
}

function doPost(e) {
  var requestId = null;
  try {
    if (!e || !e.postData || !e.postData.contents) {
      return ContentService
        .createTextOutput(JSON.stringify(createErrorResponse(null, 'INVALID_REQUEST', 'Missing request body')))
        .setMimeType(ContentService.MimeType.JSON);
    }

    var requestEnvelope = JSON.parse(e.postData.contents);
    requestId = requestEnvelope.requestId;

    var responseEnvelope = RequestRouter.handleRequest(requestEnvelope);

    return ContentService
      .createTextOutput(JSON.stringify(responseEnvelope))
      .setMimeType(ContentService.MimeType.JSON);

  } catch (error) {
    var code = (error && error.code) || 'TEMPORARY_FAILURE';
    var message = (error && error.message) || String(error);

    var errorResponse = createErrorResponse(requestId, code, message);

    return ContentService
      .createTextOutput(JSON.stringify(errorResponse))
      .setMimeType(ContentService.MimeType.JSON);
  }
}

