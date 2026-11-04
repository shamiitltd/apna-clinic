abstract class Failure {
  final String message;
  final String? code;
  final Object? details;

  const Failure(this.message, {this.code, this.details});

  @override
  String toString() => 'Failure(code: $code, message: $message)';
}

class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message, {super.code, super.details});
}

class StorageUnavailableFailure extends Failure {
  const StorageUnavailableFailure([
    super.message =
        'Local storage is unavailable or restricted in this browser session.',
  ]) : super(code: 'STORAGE_UNAVAILABLE');
}

class AuthorizationFailure extends Failure {
  const AuthorizationFailure([
    super.message = 'You do not have permission to perform this action.',
  ]) : super(code: 'UNAUTHORIZED');
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.code, super.details});
}

class DuplicateEntityFailure extends Failure {
  const DuplicateEntityFailure(super.message, {super.code, super.details});
}

class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message =
        'Unable to connect to the network. Offline mode remains active.',
  ]) : super(code: 'NETWORK_ERROR');
}

class QuotaExceededFailure extends Failure {
  const QuotaExceededFailure([
    super.message =
        'Google API quota reached. Retrying automatically with backoff.',
  ]) : super(code: 'QUOTA_EXCEEDED');
}

class BackupCorruptionFailure extends Failure {
  const BackupCorruptionFailure([
    super.message =
        'Backup archive failed integrity checksum validation or decryption.',
  ]) : super(code: 'BACKUP_CORRUPTED');
}

class DecryptionKeyFailure extends Failure {
  const DecryptionKeyFailure([
    super.message = 'Invalid encryption key. Cannot decrypt backup archive.',
  ]) : super(code: 'INVALID_KEY');
}

class ConcurrencyConflictFailure extends Failure {
  const ConcurrencyConflictFailure([
    super.message = 'Conflict detected with another transaction. Action was safely aborted.',
  ]) : super(code: 'CONCURRENCY_CONFLICT');
}

class DeviceLeaseFailure extends Failure {
  const DeviceLeaseFailure([
    super.message = 'Another workstation holds the authoritative write lease for this clinic.',
  ]) : super(code: 'LEASE_CONFLICT');
}

class CryptoFailure extends Failure {
  const CryptoFailure(
    super.message, {
    super.code = 'CRYPTO_ERROR',
    super.details,
  });
}
