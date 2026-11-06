/**
 * Apna Clinic - Idempotency Service
 * Prevents double-processing of network retries
 * Feature TRD Section 10
 */

var IdempotencyService = {
  checkIdempotency: function(request) {
    if (!request.idempotencyKey) return null;
    var cache = CacheService.getScriptCache();
    var cacheKey = 'idem_' + request.clinicId + '_' + request.idempotencyKey;
    var cached = cache.get(cacheKey);

    if (cached) {
      try {
        var parsed = JSON.parse(cached);
        var currentHash = hashPayload(request.payload);
        if (parsed.payloadHash && parsed.payloadHash !== currentHash) {
          throw {
            code: 'IDEMPOTENCY_CONFLICT',
            message: 'Idempotency key reused with different payload: ' + request.idempotencyKey
          };
        }
        return parsed.result;
      } catch (e) {
        if (e.code === 'IDEMPOTENCY_CONFLICT') throw e;
      }
    }
    return null;
  },

  recordResult: function(request, result) {
    if (!request.idempotencyKey) return;
    try {
      var cache = CacheService.getScriptCache();
      var cacheKey = 'idem_' + request.clinicId + '_' + request.idempotencyKey;
      var currentHash = hashPayload(request.payload);
      var record = {
        payloadHash: currentHash,
        result: result,
        timestamp: new Date().toISOString()
      };
      // Cache for 6 hours (21600 seconds)
      cache.put(cacheKey, JSON.stringify(record), 21600);
    } catch (_) {}
  }
};

