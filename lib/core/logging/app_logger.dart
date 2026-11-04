import 'dart:developer' as developer;

enum LogLevel { debug, info, warning, error }

/// Privacy-safe structured logger.
///
/// CRITICAL PRIVACY MANDATE:
/// NEVER log patient names, phone numbers, addresses, reason-for-visit text,
/// clinical descriptions, OAuth refresh tokens, or encryption keys.
class AppLogger {
  final String component;

  const AppLogger(this.component);

  static void info(String message, [Map<String, dynamic>? metadata]) {
    _log(LogLevel.info, 'App', message, metadata);
  }

  static void warning(
    String message, [
    Map<String, dynamic>? metadata,
    Object? error,
  ]) {
    _log(LogLevel.warning, 'App', message, metadata, error);
  }

  static void error(
    String message, [
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
  ]) {
    _log(LogLevel.error, 'App', message, metadata, error, stackTrace);
  }

  static void debug(String message, [Map<String, dynamic>? metadata]) {
    _log(LogLevel.debug, 'App', message, metadata);
  }

  static void _log(
    LogLevel level,
    String componentName,
    String message, [
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
  ]) {
    final sanitizedMeta = _sanitize(metadata);
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final logPayload = {
      'timestamp': timestamp,
      'level': level.name.toUpperCase(),
      'component': componentName,
      'message': message,
      if (sanitizedMeta.isNotEmpty) 'metadata': sanitizedMeta,
      if (error != null) 'error': error.toString(),
    };

    developer.log(
      logPayload.toString(),
      name: componentName,
      level: _levelToInt(level),
      error: error,
      stackTrace: stackTrace,
    );
  }

  static int _levelToInt(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }

  static Map<String, dynamic> _sanitize(Map<String, dynamic>? input) {
    if (input == null) return {};
    final output = <String, dynamic>{};
    final forbiddenKeys = {
      'name',
      'fullname',
      'full_name',
      'phone',
      'phone_number',
      'reason',
      'reason_for_visit',
      'symptoms',
      'token',
      'secret',
      'key',
      'prescription',
      'medical',
    };

    input.forEach((k, v) {
      final lowerKey = k.toLowerCase();
      if (forbiddenKeys.any((f) => lowerKey.contains(f))) {
        output[k] = '[REDACTED]';
      } else if (v is Map<String, dynamic>) {
        output[k] = _sanitize(v);
      } else {
        output[k] = v;
      }
    });

    return output;
  }
}
