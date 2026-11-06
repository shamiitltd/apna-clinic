/**
 * Apna Clinic - Validation and Constants
 * Feature TRD Section 5, 9, 10
 */

const CANONICAL_HEADERS = {
  Spreadsheet_Registry: [
    'clinic_id',
    'year_month',
    'spreadsheet_id',
    'status',
    'schema_version',
    'created_at',
    'created_by',
    'last_verified_at'
  ],
  Patient_History_Index: [
    'clinic_id',
    'patient_id',
    'year_month',
    'record_type',
    'first_record_at',
    'last_record_at',
    'record_count',
    'last_updated_at'
  ],
  Sync_Manifest: [
    'batch_id',
    'clinic_id',
    'device_id',
    'first_event_id',
    'last_event_id',
    'event_count',
    'checksum',
    'schema_version',
    'status',
    'created_at',
    'confirmed_at',
    'last_error_code'
  ],
  Appointments: [
    'appointment_id',
    'appointment_code',
    'patient_id',
    'doctor_id',
    'appointment_date',
    'start_time',
    'end_time',
    'appointment_type',
    'booking_source',
    'status',
    'token_number',
    'room_id',
    'notes',
    'cancel_reason',
    'reminder_consent',
    'reminder_status',
    'created_at',
    'updated_at',
    'created_by',
    'updated_by'
  ],
  Visits: [
    'consultation_id',
    'appointment_id',
    'patient_id',
    'doctor_id',
    'chief_complaint',
    'clinical_summary',
    'diagnosis',
    'advice',
    'follow_up_required',
    'follow_up_date',
    'consultation_status',
    'started_at',
    'completed_at',
    'created_at',
    'updated_at'
  ],
  Billing: [
    'invoice_id',
    'invoice_number',
    'patient_id',
    'appointment_id',
    'invoice_date',
    'subtotal',
    'discount',
    'tax',
    'total_amount',
    'paid_amount',
    'due_amount',
    'payment_status',
    'notes',
    'created_at',
    'updated_at'
  ],
  Payments: [
    'payment_id',
    'invoice_id',
    'patient_id',
    'payment_date',
    'amount',
    'payment_method',
    'transaction_reference',
    'payment_status',
    'received_by',
    'notes',
    'created_at'
  ],
  Queue_Events: [
    'queue_id',
    'appointment_id',
    'patient_id',
    'doctor_id',
    'token_number',
    'queue_date',
    'check_in_time',
    'called_time',
    'consultation_start_time',
    'consultation_end_time',
    'queue_status',
    'priority',
    'room_id',
    'created_at',
    'updated_at'
  ]
};

const VALID_ACTIONS = [
  'monthlyStorage.resolveMonth',
  'monthlyStorage.provisionMonth',
  'monthlyStorage.syncBatch',
  'monthlyStorage.getPatientHistory',
  'monthlyStorage.getSyncStatus',
  'monthlyStorage.reconcilePatientIndex',
  'monthlyStorage.listMonthsForClinic'
];

function validateYearMonth(ym) {
  if (!ym || typeof ym !== 'string') return false;
  return /^\d{4}-(0[1-9]|1[0-2])$/.test(ym);
}

function validateClinicId(clinicId) {
  if (!clinicId || typeof clinicId !== 'string') return false;
  return clinicId.trim().length > 0;
}

function validateEnvelope(envelope) {
  if (!envelope || typeof envelope !== 'object') {
    throw { code: 'INVALID_REQUEST', message: 'Request body must be a valid JSON object' };
  }
  if (!envelope.action || typeof envelope.action !== 'string') {
    throw { code: 'INVALID_REQUEST', message: 'Missing required field: action' };
  }
  if (VALID_ACTIONS.indexOf(envelope.action) === -1) {
    throw { code: 'INVALID_REQUEST', message: 'Unsupported action: ' + envelope.action };
  }
  if (!validateClinicId(envelope.clinicId)) {
    throw { code: 'INVALID_REQUEST', message: 'Missing or invalid clinicId' };
  }
  if (!envelope.requestId) {
    envelope.requestId = Utilities.getUuid();
  }
}

function hashPayload(payload) {
  if (!payload) return '';
  var raw = typeof payload === 'string' ? payload : JSON.stringify(payload);
  var signature = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, raw);
  var hex = '';
  for (var i = 0; i < signature.length; i++) {
    var b = signature[i];
    if (b < 0) b += 256;
    var s = b.toString(16);
    if (s.length === 1) s = '0' + s;
    hex += s;
  }
  return hex;
}

function createSuccessResponse(requestId, data, meta) {
  var responseMeta = meta || {};
  responseMeta.traceId = Utilities.getUuid();
  responseMeta.serverTime = new Date().toISOString();
  return {
    apiVersion: 'v1',
    requestId: requestId,
    ok: true,
    data: data || {},
    error: null,
    meta: responseMeta
  };
}

function createErrorResponse(requestId, errorCode, errorMessage) {
  return {
    apiVersion: 'v1',
    requestId: requestId || Utilities.getUuid(),
    ok: false,
    data: null,
    error: {
      code: errorCode || 'TEMPORARY_FAILURE',
      message: errorMessage || 'An unexpected error occurred'
    },
    meta: {
      traceId: Utilities.getUuid(),
      serverTime: new Date().toISOString()
    }
  };
}

