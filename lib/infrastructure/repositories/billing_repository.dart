// Apna Clinic - Concrete Billing Repository
// FINANCIAL IMMUTABILITY: Integer paise math, monotonic invoice numbers, no destructive edits.
// Primary source of truth: PRD Section 5 M06 & Section 6.2

import 'dart:convert';

import '../../domain/entities/entities.dart';
import '../../domain/enums/domain_enums.dart';
import '../../domain/repositories/i_billing_repository.dart';
import '../../core/errors/failures.dart';
import '../database/local_database.dart';

class BillingRepository implements IBillingRepository {
  final LocalDatabase _db;

  BillingRepository(this._db);

  @override
  Future<List<FeeCatalog>> getFeeCatalog(
    String clinicId, {
    bool activeOnly = true,
  }) async {
    final records = _db.query(
      'Fee_Catalog',
      where: (r) {
        if (r['clinic_id'] != clinicId) {
          return false;
        }
        if (activeOnly && (r['active'] == 0 || r['active'] == false)) {
          return false;
        }
        return true;
      },
    );
    return records.map((r) => FeeCatalog.fromMap(r)).toList();
  }

  @override
  Future<void> saveFeeCatalogItem(FeeCatalog item) async {
    await _db.upsert('Fee_Catalog', item.feeId, item.toMap());

    // Stage 12_SERVICES into sync_outbox so services are persisted to Google Sheets
    final now = DateTime.now().toUtc();
    final outboxEvent = SyncOutboxEvent(
      outboxEventId: 'outbox_service_${item.feeId}',
      clinicId: item.clinicId,
      entityType: '12_SERVICES',
      entityId: item.feeId,
      operation: OutboxOperation.insert,
      payloadJson: jsonEncode(item.toMap()),
      createdAt: now,
      idempotencyKey: 'service_${item.feeId}',
    );
    await _db.upsert('sync_outbox', outboxEvent.outboxEventId, outboxEvent.toMap());
  }

  @override
  Future<Invoice> createInvoiceAtomic({
    required Invoice invoice,
    required List<InvoiceItem> items,
    Payment? initialPayment,
    List<Payment>? initialPayments,
    required String idempotencyKey,
  }) async {
    final cached = _db.checkIdempotency(idempotencyKey);
    if (cached != null) {
      final itemsRecs = _db.query(
        'Invoice_Items',
        where: (r) => r['invoice_id'] == cached['invoice_id'],
      );
      final loadedItems = itemsRecs.map((r) => InvoiceItem.fromMap(r)).toList();
      return Invoice.fromMap(cached, loadedItems);
    }

    return await _db.transaction<Invoice>((tx) async {
      // 1. Calculate deterministic totals from line items
      int subtotal = 0;
      int discount = 0;
      int tax = 0;

      for (final item in items) {
        subtotal += item.unitPriceMinor * item.quantity;
        discount += item.discountMinor;
        tax += item.taxMinor;
      }

      // If line items didn't specify invoice-level discount or tax, preserve invoice level
      if (discount == 0 && invoice.discountMinor > 0) {
        discount = invoice.discountMinor;
      }
      if (tax == 0 && invoice.taxMinor > 0) {
        tax = invoice.taxMinor;
      }

      int total = subtotal - discount + tax;
      if (items.isEmpty && invoice.totalMinor > 0) {
        subtotal = invoice.subtotalMinor;
        total = invoice.totalMinor;
      }

      final allPayments = <Payment>[
        if (initialPayments != null) ...initialPayments,
        if (initialPayment != null &&
            (initialPayments == null || !initialPayments.contains(initialPayment)))
          initialPayment,
      ];

      int paid = 0;
      for (final p in allPayments) {
        paid += p.amountMinor;
      }

      final balance = total - paid;
      final status = balance <= 0
          ? InvoiceStatus.paid
          : (paid > 0 ? InvoiceStatus.partiallyPaid : InvoiceStatus.issued);

      final finalInvoice = invoice.copyWith(
        status: status,
        subtotalMinor: subtotal,
        discountMinor: discount,
        taxMinor: tax,
        totalMinor: total,
        paidMinor: paid,
        balanceMinor: balance,
        items: items,
      );

      final invoiceMap = finalInvoice.toMap();

      // 2. Persist invoice
      await _db.upsert('Invoices', invoice.invoiceId, invoiceMap, tx: tx);

      // 3. Persist line items
      for (final item in items) {
        await _db.upsert(
          'Invoice_Items',
          item.invoiceItemId,
          item.toMap(),
          tx: tx,
        );
      }

      // 4. Persist optional initial payment(s) (supports single and mixed tender)
      for (final p in allPayments) {
        await _db.upsert(
          'Payments',
          p.paymentId,
          p.toMap(),
          tx: tx,
        );

        final outboxPay = SyncOutboxEvent(
          outboxEventId: 'outbox_pay_${p.paymentId}',
          clinicId: p.clinicId,
          entityType: 'Payments',
          entityId: p.paymentId,
          operation: OutboxOperation.insert,
          payloadJson: jsonEncode(p.toMap()),
          createdAt: DateTime.now().toUtc(),
          idempotencyKey: 'pay_${p.paymentId}',
        );
        await _db.upsert(
          'sync_outbox',
          outboxPay.outboxEventId,
          outboxPay.toMap(),
          tx: tx,
        );
      }

      // 5. Stage SyncOutbox event for invoice
      final outboxEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_inv_${invoice.invoiceId}',
        clinicId: invoice.clinicId,
        entityType: 'Invoices',
        entityId: invoice.invoiceId,
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode(invoiceMap),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: idempotencyKey,
      );
      await _db.upsert(
        'sync_outbox',
        outboxEvent.outboxEventId,
        outboxEvent.toMap(),
        tx: tx,
      );

      tx.onCommit(() {
        _db.recordIdempotency(idempotencyKey, invoiceMap);
      });

      return Invoice.fromMap(invoiceMap, items);
    });
  }

  @override
  Future<Invoice?> getInvoiceById(String clinicId, String invoiceId) async {
    final record = _db.get('Invoices', invoiceId);
    if (record == null || record['clinic_id'] != clinicId) return null;

    final itemRecords = _db.query(
      'Invoice_Items',
      where: (r) => r['invoice_id'] == invoiceId,
    );
    final items = itemRecords.map((r) => InvoiceItem.fromMap(r)).toList();
    return Invoice.fromMap(record, items);
  }

  @override
  Future<List<Invoice>> getInvoicesForDate(
    String clinicId,
    String localDate,
  ) async {
    final records = _db.query(
      'Invoices',
      where: (r) =>
          r['clinic_id'] == clinicId && r['issue_date_local'] == localDate,
    );

    final invoices = <Invoice>[];
    for (final r in records) {
      final id = r['invoice_id'] as String;
      final itemRecords = _db.query(
        'Invoice_Items',
        where: (it) => it['invoice_id'] == id,
      );
      final items = itemRecords.map((it) => InvoiceItem.fromMap(it)).toList();
      invoices.add(Invoice.fromMap(r, items));
    }
    return invoices;
  }

  @override
  Future<Payment> recordPayment({
    required Payment payment,
    required String idempotencyKey,
  }) async {
    final cached = _db.checkIdempotency(idempotencyKey);
    if (cached != null) {
      return Payment.fromMap(cached);
    }

    return await _db.transaction<Payment>((tx) async {
      final invoiceRecord = _db.get('Invoices', payment.invoiceId);
      if (invoiceRecord == null ||
          invoiceRecord['clinic_id'] != payment.clinicId) {
        throw const DatabaseFailure('Invoice not found');
      }

      final invoice = Invoice.fromMap(invoiceRecord);
      final newPaid = invoice.paidMinor + payment.amountMinor;
      final newBalance = invoice.totalMinor - newPaid;
      final newStatus = newBalance <= 0
          ? InvoiceStatus.paid
          : InvoiceStatus.partiallyPaid;

      final updatedInvoice = invoice.copyWith(
        paidMinor: newPaid,
        balanceMinor: newBalance,
        status: newStatus,
        updatedAt: DateTime.now().toUtc(),
      );

      await _db.upsert(
        'Invoices',
        invoice.invoiceId,
        updatedInvoice.toMap(),
        tx: tx,
      );
      await _db.upsert('Payments', payment.paymentId, payment.toMap(), tx: tx);

      // Sync outbox
      final outboxEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_pay_${payment.paymentId}',
        clinicId: payment.clinicId,
        entityType: 'Payments',
        entityId: payment.paymentId,
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode(payment.toMap()),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: idempotencyKey,
      );
      await _db.upsert(
        'sync_outbox',
        outboxEvent.outboxEventId,
        outboxEvent.toMap(),
        tx: tx,
      );

      tx.onCommit(() {
        _db.recordIdempotency(idempotencyKey, payment.toMap());
      });

      return payment;
    });
  }

  @override
  Future<List<Payment>> recordPayments({
    required List<Payment> payments,
    required String idempotencyKey,
  }) async {
    if (payments.isEmpty) return [];

    final cached = _db.checkIdempotency(idempotencyKey);
    if (cached != null) {
      final invoiceId = payments.first.invoiceId;
      final clinicId = payments.first.clinicId;
      return getPaymentsForInvoice(clinicId, invoiceId);
    }

    return await _db.transaction<List<Payment>>((tx) async {
      final invoiceId = payments.first.invoiceId;
      final clinicId = payments.first.clinicId;
      final invoiceRecord = _db.get('Invoices', invoiceId);
      if (invoiceRecord == null || invoiceRecord['clinic_id'] != clinicId) {
        throw const DatabaseFailure('Invoice not found');
      }

      final invoice = Invoice.fromMap(invoiceRecord);
      int additionalPaid = 0;
      for (final p in payments) {
        additionalPaid += p.amountMinor;
      }

      final newPaid = invoice.paidMinor + additionalPaid;
      final newBalance = invoice.totalMinor - newPaid;
      final newStatus = newBalance <= 0
          ? InvoiceStatus.paid
          : InvoiceStatus.partiallyPaid;

      final updatedInvoice = invoice.copyWith(
        paidMinor: newPaid,
        balanceMinor: newBalance,
        status: newStatus,
        updatedAt: DateTime.now().toUtc(),
      );

      await _db.upsert(
        'Invoices',
        invoice.invoiceId,
        updatedInvoice.toMap(),
        tx: tx,
      );

      for (final p in payments) {
        await _db.upsert('Payments', p.paymentId, p.toMap(), tx: tx);

        final outboxEvent = SyncOutboxEvent(
          outboxEventId: 'outbox_pay_${p.paymentId}',
          clinicId: p.clinicId,
          entityType: 'Payments',
          entityId: p.paymentId,
          operation: OutboxOperation.insert,
          payloadJson: jsonEncode(p.toMap()),
          createdAt: DateTime.now().toUtc(),
          idempotencyKey: 'pay_${p.paymentId}',
        );
        await _db.upsert(
          'sync_outbox',
          outboxEvent.outboxEventId,
          outboxEvent.toMap(),
          tx: tx,
        );
      }

      tx.onCommit(() {
        _db.recordIdempotency(idempotencyKey, {
          'invoice_id': invoiceId,
          'count': payments.length,
          'additional_paid': additionalPaid,
        });
      });

      return payments;
    });
  }

  @override
  Future<List<Payment>> getPaymentsForInvoice(
    String clinicId,
    String invoiceId,
  ) async {
    final records = _db.query(
      'Payments',
      where: (r) => r['clinic_id'] == clinicId && r['invoice_id'] == invoiceId,
    );
    return records.map((r) => Payment.fromMap(r)).toList();
  }

  @override
  Future<List<Payment>> getPaymentsForDate(
    String clinicId,
    String localDate,
  ) async {
    final records = _db.query(
      'Payments',
      where: (r) {
        if (r['clinic_id'] != clinicId) return false;
        final received = r['received_at'] as String? ?? '';
        return received.startsWith(localDate);
      },
    );
    return records.map((r) => Payment.fromMap(r)).toList();
  }

  @override
  Future<Refund> recordRefund({
    required Refund refund,
    required String idempotencyKey,
  }) async {
    final cached = _db.checkIdempotency(idempotencyKey);
    if (cached != null) {
      return Refund.fromMap(cached);
    }

    return await _db.transaction<Refund>((tx) async {
      final invoiceRecord = _db.get('Invoices', refund.invoiceId);
      if (invoiceRecord == null ||
          invoiceRecord['clinic_id'] != refund.clinicId) {
        throw const DatabaseFailure('Invoice not found');
      }

      final invoice = Invoice.fromMap(invoiceRecord);
      final newPaid = invoice.paidMinor - refund.amountMinor;
      final newBalance = invoice.totalMinor - newPaid;
      final newStatus = newPaid <= 0
          ? InvoiceStatus.refunded
          : InvoiceStatus.partiallyPaid;

      final updatedInvoice = invoice.copyWith(
        paidMinor: newPaid,
        balanceMinor: newBalance,
        status: newStatus,
        updatedAt: DateTime.now().toUtc(),
      );

      await _db.upsert(
        'Invoices',
        invoice.invoiceId,
        updatedInvoice.toMap(),
        tx: tx,
      );
      await _db.upsert('Refunds', refund.refundId, refund.toMap(), tx: tx);

      // Outbox
      final outboxEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_ref_${refund.refundId}',
        clinicId: refund.clinicId,
        entityType: 'Refunds',
        entityId: refund.refundId,
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode(refund.toMap()),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: idempotencyKey,
      );
      await _db.upsert(
        'sync_outbox',
        outboxEvent.outboxEventId,
        outboxEvent.toMap(),
        tx: tx,
      );

      tx.onCommit(() {
        _db.recordIdempotency(idempotencyKey, refund.toMap());
      });

      return refund;
    });
  }

  @override
  Future<List<Refund>> getRefundsForInvoice(
    String clinicId,
    String invoiceId,
  ) async {
    final records = _db.query(
      'Refunds',
      where: (r) => r['clinic_id'] == clinicId && r['invoice_id'] == invoiceId,
    );
    return records.map((r) => Refund.fromMap(r)).toList();
  }

  @override
  Future<List<Refund>> getRefundsForDate(
    String clinicId,
    String localDate,
  ) async {
    final records = _db.query(
      'Refunds',
      where: (r) {
        if (r['clinic_id'] != clinicId) return false;
        final refundedAt = r['refunded_at'] as String? ?? '';
        return refundedAt.startsWith(localDate);
      },
    );
    return records.map((r) => Refund.fromMap(r)).toList();
  }

  @override
  Future<void> voidInvoice({
    required String clinicId,
    required String invoiceId,
    required String reason,
    required String staffId,
  }) async {
    await _db.transaction((tx) async {
      final invoiceRecord = _db.get('Invoices', invoiceId);
      if (invoiceRecord == null || invoiceRecord['clinic_id'] != clinicId) {
        throw const DatabaseFailure('Invoice not found');
      }

      final invoice = Invoice.fromMap(invoiceRecord);
      if (invoice.status == InvoiceStatus.paid || invoice.paidMinor > 0) {
        throw const ValidationFailure(
          'Cannot void an invoice with recorded payments. Process an approved refund instead.',
        );
      }

      final updated = invoice.copyWith(
        status: InvoiceStatus.voided,
        voidedAt: DateTime.now().toUtc(),
        voidReason: reason,
        updatedAt: DateTime.now().toUtc(),
      );

      await _db.upsert('Invoices', invoiceId, updated.toMap(), tx: tx);

      final outboxEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_void_$invoiceId',
        clinicId: clinicId,
        entityType: 'Invoices',
        entityId: invoiceId,
        operation: OutboxOperation.update,
        payloadJson: jsonEncode(updated.toMap()),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: 'void_$invoiceId',
      );
      await _db.upsert(
        'sync_outbox',
        outboxEvent.outboxEventId,
        outboxEvent.toMap(),
        tx: tx,
      );
    });
  }

  @override
  Future<String> generateNextInvoiceNumber(
    String clinicId,
    String financialYear,
  ) async {
    final prefix = 'INV-$financialYear-';

    final records = _db.query(
      'Invoices',
      where: (r) =>
          r['clinic_id'] == clinicId && r['financial_year'] == financialYear,
    );

    int maxSeq = 0;
    for (final r in records) {
      final invNum = r['invoice_number'] as String? ?? '';
      if (invNum.startsWith(prefix)) {
        final seqPart = invNum.substring(prefix.length);
        final seq = int.tryParse(seqPart);
        if (seq != null && seq > maxSeq) {
          maxSeq = seq;
        }
      }
    }

    final nextSeq = (maxSeq + 1).toString().padLeft(4, '0');
    return '$prefix$nextSeq';
  }

  @override
  Future<void> recordExpense(Expense expense) async {
    await _db.transaction((tx) async {
      await _db.upsert('Expenses', expense.expenseId, expense.toMap(), tx: tx);

      final outboxEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_exp_${expense.expenseId}',
        clinicId: expense.clinicId,
        entityType: 'Expenses',
        entityId: expense.expenseId,
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode(expense.toMap()),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: 'exp_${expense.expenseId}',
      );
      await _db.upsert(
        'sync_outbox',
        outboxEvent.outboxEventId,
        outboxEvent.toMap(),
        tx: tx,
      );
    });
  }

  @override
  Future<List<Expense>> getExpensesForDate(
    String clinicId,
    String localDate,
  ) async {
    final records = _db.query(
      'Expenses',
      where: (r) =>
          r['clinic_id'] == clinicId &&
          r['expense_date'] == localDate &&
          r['deleted_at'] == null,
    );
    return records.map((r) => Expense.fromMap(r)).toList();
  }

  @override
  Future<DailyReconciliation> getDailyFinancialReconciliation(
    String clinicId,
    String localDate,
  ) async {
    final invoices = await getInvoicesForDate(clinicId, localDate);
    final payments = await getPaymentsForDate(clinicId, localDate);
    final expenses = await getExpensesForDate(clinicId, localDate);

    final refundsRecords = _db.query(
      'Refunds',
      where: (r) {
        if (r['clinic_id'] != clinicId) return false;
        final refundedAt = r['refunded_at'] as String? ?? '';
        return refundedAt.startsWith(localDate);
      },
    );

    int totalInvoiced = 0;
    int totalOutstanding = 0;
    for (final inv in invoices) {
      if (inv.status != InvoiceStatus.voided) {
        totalInvoiced += inv.totalMinor;
        totalOutstanding += inv.balanceMinor;
      }
    }

    int totalCash = 0;
    int totalUpi = 0;
    int totalCard = 0;

    for (final pay in payments) {
      if (pay.status == PaymentStatus.completed) {
        switch (pay.method) {
          case PaymentMethod.cash:
            totalCash += pay.amountMinor;
            break;
          case PaymentMethod.upi:
            totalUpi += pay.amountMinor;
            break;
          case PaymentMethod.card:
            totalCard += pay.amountMinor;
            break;
          case PaymentMethod.mixed:
            totalCash += pay.amountMinor;
            break;
        }
      }
    }

    int totalRefunded = 0;
    for (final r in refundsRecords) {
      final refund = Refund.fromMap(r);
      if (refund.status == RefundStatus.settled) {
        totalRefunded += refund.amountMinor;
      }
    }

    int totalExpenses = 0;
    for (final exp in expenses) {
      totalExpenses += exp.amountMinor;
    }

    return DailyReconciliation(
      totalInvoicedMinor: totalInvoiced,
      totalCashCollectedMinor: totalCash,
      totalUpiCollectedMinor: totalUpi,
      totalCardCollectedMinor: totalCard,
      totalRefundedMinor: totalRefunded,
      totalExpensesMinor: totalExpenses,
      totalOutstandingMinor: totalOutstanding,
    );
  }

  @override
  Future<void> performDayClose(DayClose dayClose) async {
    await _db.transaction((tx) async {
      await _db.upsert('Day_Close', dayClose.closeId, dayClose.toMap(), tx: tx);
      await _db.upsert('day_close', dayClose.closeId, dayClose.toMap(), tx: tx);

      final outboxEvent = SyncOutboxEvent(
        outboxEventId: 'outbox_dayclose_${dayClose.closeId}',
        clinicId: dayClose.clinicId,
        entityType: 'Day_Close',
        entityId: dayClose.closeId,
        operation: OutboxOperation.insert,
        payloadJson: jsonEncode(dayClose.toMap()),
        createdAt: DateTime.now().toUtc(),
        idempotencyKey: 'dayclose_${dayClose.closeId}',
      );
      await _db.upsert(
        'sync_outbox',
        outboxEvent.outboxEventId,
        outboxEvent.toMap(),
        tx: tx,
      );
    });
  }

  @override
  Future<DayClose?> getDayClose(String clinicId, String businessDate) async {
    final records = _db.query(
      'Day_Close',
      where: (r) =>
          r['clinic_id'] == clinicId && r['business_date'] == businessDate,
    );
    if (records.isNotEmpty) {
      return DayClose.fromMap(records.first);
    }
    final recordsLower = _db.query(
      'day_close',
      where: (r) =>
          r['clinic_id'] == clinicId && r['business_date'] == businessDate,
    );
    if (recordsLower.isEmpty) return null;
    return DayClose.fromMap(recordsLower.first);
  }
}
