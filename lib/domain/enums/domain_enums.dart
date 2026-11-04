// Apna Clinic - Domain Enums
// Primary source of truth: PRD and TRD Section 7 & 8

enum QueueStatus {
  registered,
  waiting,
  called,
  inConsultation,
  completed,
  cancelled,
  noShow;

  String get wireValue {
    switch (this) {
      case QueueStatus.registered:
        return 'registered';
      case QueueStatus.waiting:
        return 'waiting';
      case QueueStatus.called:
        return 'called';
      case QueueStatus.inConsultation:
        return 'in_consultation';
      case QueueStatus.completed:
        return 'completed';
      case QueueStatus.cancelled:
        return 'cancelled';
      case QueueStatus.noShow:
        return 'no_show';
    }
  }

  static QueueStatus fromWire(String val) {
    return QueueStatus.values.firstWhere(
      (e) => e.wireValue == val,
      orElse: () => QueueStatus.waiting,
    );
  }

  bool get isTerminal =>
      this == QueueStatus.completed ||
      this == QueueStatus.cancelled ||
      this == QueueStatus.noShow;

  bool canTransitionTo(QueueStatus next) {
    if (this == next) return true;
    if (isTerminal) return false;
    switch (this) {
      case QueueStatus.registered:
        return next == QueueStatus.waiting ||
            next == QueueStatus.cancelled ||
            next == QueueStatus.noShow;
      case QueueStatus.waiting:
        return next == QueueStatus.called ||
            next == QueueStatus.cancelled ||
            next == QueueStatus.noShow;
      case QueueStatus.called:
        return next == QueueStatus.inConsultation ||
            next == QueueStatus.waiting ||
            next == QueueStatus.cancelled ||
            next == QueueStatus.noShow;
      case QueueStatus.inConsultation:
        return next == QueueStatus.completed || next == QueueStatus.cancelled;
      case QueueStatus.completed:
      case QueueStatus.cancelled:
      case QueueStatus.noShow:
        return false;
    }
  }
}

enum QueuePriority {
  normal,
  urgent,
  vip,
  emergency;

  String get wireValue {
    switch (this) {
      case QueuePriority.normal:
        return 'NORMAL';
      case QueuePriority.urgent:
        return 'URGENT';
      case QueuePriority.vip:
        return 'VIP';
      case QueuePriority.emergency:
        return 'EMERGENCY';
    }
  }

  static QueuePriority fromWire(String? val) {
    if (val == null || val.isEmpty) return QueuePriority.normal;
    final upper = val.toUpperCase().trim();
    return QueuePriority.values.firstWhere(
      (e) =>
          e.wireValue == upper ||
          e.name.toLowerCase() == val.toLowerCase().trim(),
      orElse: () => QueuePriority.normal,
    );
  }

  int get level {
    switch (this) {
      case QueuePriority.emergency:
        return 4;
      case QueuePriority.urgent:
        return 3;
      case QueuePriority.vip:
        return 2;
      case QueuePriority.normal:
        return 1;
    }
  }

  String get displayName {
    switch (this) {
      case QueuePriority.normal:
        return 'Normal';
      case QueuePriority.urgent:
        return 'Urgent';
      case QueuePriority.vip:
        return 'Priority (Senior/Child)';
      case QueuePriority.emergency:
        return 'Emergency';
    }
  }
}

enum AppointmentStatus {
  scheduled,
  checkedIn,
  completed,
  cancelled,
  noShow;

  String get wireValue {
    switch (this) {
      case AppointmentStatus.scheduled:
        return 'scheduled';
      case AppointmentStatus.checkedIn:
        return 'checked_in';
      case AppointmentStatus.completed:
        return 'completed';
      case AppointmentStatus.cancelled:
        return 'cancelled';
      case AppointmentStatus.noShow:
        return 'no_show';
    }
  }

  static AppointmentStatus fromWire(String val) {
    return AppointmentStatus.values.firstWhere(
      (e) => e.wireValue == val,
      orElse: () => AppointmentStatus.scheduled,
    );
  }
}

enum InvoiceStatus {
  draft,
  issued,
  partiallyPaid,
  paid,
  refunded,
  voided;

  String get wireValue {
    switch (this) {
      case InvoiceStatus.draft:
        return 'draft';
      case InvoiceStatus.issued:
        return 'issued';
      case InvoiceStatus.partiallyPaid:
        return 'partially_paid';
      case InvoiceStatus.paid:
        return 'paid';
      case InvoiceStatus.refunded:
        return 'refunded';
      case InvoiceStatus.voided:
        return 'voided';
    }
  }

  static InvoiceStatus fromWire(String val) {
    return InvoiceStatus.values.firstWhere(
      (e) => e.wireValue == val,
      orElse: () => InvoiceStatus.draft,
    );
  }
}

enum PaymentMethod {
  cash,
  upi,
  card,
  mixed;

  String get wireValue {
    switch (this) {
      case PaymentMethod.cash:
        return 'cash';
      case PaymentMethod.upi:
        return 'upi';
      case PaymentMethod.card:
        return 'card';
      case PaymentMethod.mixed:
        return 'mixed';
    }
  }

  static PaymentMethod fromWire(String val) {
    return PaymentMethod.values.firstWhere(
      (e) => e.wireValue == val,
      orElse: () => PaymentMethod.cash,
    );
  }
}

enum PaymentStatus {
  completed,
  reversed;

  String get wireValue {
    switch (this) {
      case PaymentStatus.completed:
        return 'completed';
      case PaymentStatus.reversed:
        return 'reversed';
    }
  }

  static PaymentStatus fromWire(String val) {
    return PaymentStatus.values.firstWhere(
      (e) => e.wireValue == val,
      orElse: () => PaymentStatus.completed,
    );
  }
}

enum RefundStatus {
  requested,
  approved,
  settled,
  rejected;

  String get wireValue {
    switch (this) {
      case RefundStatus.requested:
        return 'requested';
      case RefundStatus.approved:
        return 'approved';
      case RefundStatus.settled:
        return 'settled';
      case RefundStatus.rejected:
        return 'rejected';
    }
  }

  static RefundStatus fromWire(String val) {
    return RefundStatus.values.firstWhere(
      (e) => e.wireValue == val,
      orElse: () => RefundStatus.requested,
    );
  }
}

enum OutboxOperation {
  insert,
  update,
  delete;

  String get wireValue {
    switch (this) {
      case OutboxOperation.insert:
        return 'insert';
      case OutboxOperation.update:
        return 'update';
      case OutboxOperation.delete:
        return 'delete';
    }
  }

  static OutboxOperation fromWire(String val) {
    return OutboxOperation.values.firstWhere(
      (e) => e.wireValue == val,
      orElse: () => OutboxOperation.insert,
    );
  }
}

enum OutboxStatus {
  pending,
  inFlight,
  acknowledged,
  failed;

  String get wireValue {
    switch (this) {
      case OutboxStatus.pending:
        return 'pending';
      case OutboxStatus.inFlight:
        return 'in_flight';
      case OutboxStatus.acknowledged:
        return 'acknowledged';
      case OutboxStatus.failed:
        return 'failed';
    }
  }

  static OutboxStatus fromWire(String val) {
    return OutboxStatus.values.firstWhere(
      (e) => e.wireValue == val,
      orElse: () => OutboxStatus.pending,
    );
  }
}

enum AuditResult {
  success,
  failure,
  denied;

  String get wireValue {
    switch (this) {
      case AuditResult.success:
        return 'success';
      case AuditResult.failure:
        return 'failure';
      case AuditResult.denied:
        return 'denied';
    }
  }

  static AuditResult fromWire(String val) {
    return AuditResult.values.firstWhere(
      (e) => e.wireValue == val,
      orElse: () => AuditResult.success,
    );
  }
}
