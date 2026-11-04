// Queue State Machine Unit Tests
// Requirements: Section 28 - Queue State Machine

import 'package:flutter_test/flutter_test.dart';
import 'package:apna_clinic/domain/enums/domain_enums.dart';

void main() {
  group('Queue State Machine Transitions', () {
    test('Allowed standard progression', () {
      // registered -> waiting -> called -> in_consultation -> completed
      expect(
        QueueStatus.registered.canTransitionTo(QueueStatus.waiting),
        isTrue,
      );
      expect(QueueStatus.waiting.canTransitionTo(QueueStatus.called), isTrue);
      expect(
        QueueStatus.called.canTransitionTo(QueueStatus.inConsultation),
        isTrue,
      );
      expect(
        QueueStatus.inConsultation.canTransitionTo(QueueStatus.completed),
        isTrue,
      );
    });

    test('Allowed early terminal transitions (cancelled, no-show)', () {
      expect(
        QueueStatus.registered.canTransitionTo(QueueStatus.cancelled),
        isTrue,
      );
      expect(
        QueueStatus.waiting.canTransitionTo(QueueStatus.cancelled),
        isTrue,
      );
      expect(QueueStatus.waiting.canTransitionTo(QueueStatus.noShow), isTrue);
      expect(QueueStatus.called.canTransitionTo(QueueStatus.noShow), isTrue);
      expect(
        QueueStatus.inConsultation.canTransitionTo(QueueStatus.cancelled),
        isTrue,
      );
    });

    test('Called can return to waiting if patient stepped out', () {
      expect(QueueStatus.called.canTransitionTo(QueueStatus.waiting), isTrue);
    });

    test('Forbidden arbitrary transitions are blocked', () {
      // Cannot jump from registered straight to inConsultation or completed
      expect(
        QueueStatus.registered.canTransitionTo(QueueStatus.inConsultation),
        isFalse,
      );
      expect(
        QueueStatus.registered.canTransitionTo(QueueStatus.completed),
        isFalse,
      );

      // Cannot jump from waiting directly to completed
      expect(
        QueueStatus.waiting.canTransitionTo(QueueStatus.completed),
        isFalse,
      );
    });

    test('Terminal states cannot transition anywhere', () {
      for (final terminal in [
        QueueStatus.completed,
        QueueStatus.cancelled,
        QueueStatus.noShow,
      ]) {
        expect(terminal.isTerminal, isTrue);
        expect(terminal.canTransitionTo(QueueStatus.waiting), isFalse);
        expect(terminal.canTransitionTo(QueueStatus.called), isFalse);
        expect(terminal.canTransitionTo(QueueStatus.inConsultation), isFalse);
      }
    });

    test('Wire serialization round-trip', () {
      for (final status in QueueStatus.values) {
        final wire = status.wireValue;
        expect(QueueStatus.fromWire(wire), equals(status));
      }
    });
  });
}
