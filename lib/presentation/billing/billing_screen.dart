// Apna Clinic - Billing, Invoices & Day Close Screen
// Primary source of truth: PRD Section 5 M06 & Section 6.2
// Immutable ledger, integer paise arithmetic, fee catalog integration, discounts with reason
// and approval threshold, configurable tax fields, mixed tender payments, refunds, voids, and day close reconciliation.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/permissions/roles.dart';
import '../../core/utils/downloader/file_download_helper.dart';
import '../../core/utils/money.dart';
import '../../domain/entities/entities.dart';
import '../../domain/enums/domain_enums.dart';
import '../../domain/repositories/i_billing_repository.dart';
import '../../domain/services/authorization_service.dart';
import '../../application/providers.dart';
import '../../application/printing/receipt_slip_service.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/app_scaffold.dart';
import '../shared/widgets/unauthorized_screen.dart';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  List<Invoice> _invoices = [];
  List<Expense> _expenses = [];
  int _selectedBillingTab = 0; // 0: Invoices, 1: Operating Expenses (M11)
  Map<String, Patient> _patientMap = {};
  DailyReconciliation? _reconciliation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBillingData();
  }

  Future<void> _loadBillingData() async {
    setState(() => _isLoading = true);
    final session = ref.read(sessionProvider);
    final billingRepo = ref.read(billingRepositoryProvider);
    final patientRepo = ref.read(patientRepositoryProvider);
    final expenseRepo = ref.read(expenseRepositoryProvider);

    final today = DateTime.now().toIso8601String().split('T').first;
    final invoices = await billingRepo.getInvoicesForDate(
      session.clinicId,
      today,
    );
    final expenses = await expenseRepo.getExpensesForDate(
      session.clinicId,
      today,
    );
    final recon = await billingRepo.getDailyFinancialReconciliation(
      session.clinicId,
      today,
    );

    final pMap = <String, Patient>{};
    for (final inv in invoices) {
      if (!pMap.containsKey(inv.patientId)) {
        final p = await patientRepo.getPatientById(
          session.clinicId,
          inv.patientId,
        );
        if (p != null) pMap[inv.patientId] = p;
      }
    }

    setState(() {
      _invoices = invoices;
      _expenses = expenses;
      _patientMap = pMap;
      _reconciliation = recon;
      _isLoading = false;
    });
  }

  void _openCreateInvoiceDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _CreateInvoiceDialog(),
    ).then((_) => _loadBillingData());
  }

  void _openCollectPaymentDialog(Invoice invoice, String patientName) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CollectPaymentDialog(
        invoice: invoice,
        patientName: patientName,
      ),
    ).then((_) => _loadBillingData());
  }

  void _openProcessRefundDialog(Invoice invoice, String patientName) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ProcessRefundDialog(
        invoice: invoice,
        patientName: patientName,
      ),
    ).then((_) => _loadBillingData());
  }

  void _openVoidInvoiceDialog(Invoice invoice, String patientName) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _VoidInvoiceDialog(
        invoice: invoice,
        patientName: patientName,
      ),
    ).then((_) => _loadBillingData());
  }

  void _openViewDetailsDialog(Invoice invoice, String patientName) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _ViewInvoiceDetailsDialog(
        invoice: invoice,
        patientName: patientName,
      ),
    );
  }

  void _openDayCloseDialog() {
    if (_reconciliation == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => _DayCloseDialog(recon: _reconciliation!),
    ).then((_) => _loadBillingData());
  }

  Future<void> _printReceipt(Invoice invoice) async {
    try {
      final session = ref.read(sessionProvider);
      final clinicRepo = ref.read(clinicRepositoryProvider);
      final billingRepo = ref.read(billingRepositoryProvider);
      final patientRepo = ref.read(patientRepositoryProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Generating billing receipt PDF...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      final clinic = await clinicRepo.getClinic(session.clinicId) ??
          Clinic(
            clinicId: session.clinicId,
            legalName: 'Apna Clinic',
            displayName: 'Apna Clinic',
            ownerName: session.staffName,
            contactPhone: '9876543210',
            contactEmail:
                session.googleUserEmail ?? 'contact@apnaclinic.com',
            addressLine1: 'Clinic Address',
            city: 'Delhi',
            district: 'Delhi',
            state: 'Delhi',
            pincode: '110001',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          );

      var patient = _patientMap[invoice.patientId];
      patient ??= await patientRepo.getPatientById(
        session.clinicId,
        invoice.patientId,
      );
      patient ??= Patient(
        patientId: invoice.patientId,
        clinicId: session.clinicId,
        patientNumber: 'P-GEN',
        fullName: 'Valued Patient',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      final payments = await billingRepo.getPaymentsForInvoice(
        session.clinicId,
        invoice.invoiceId,
      );

      await ReceiptSlipService.printReceipt(
        clinic: clinic,
        invoice: invoice,
        patient: patient,
        payments: payments,
        paperSize: clinic.defaultPaperSize,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating billing receipt: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);

    // Layer 2 RBAC Guard: Doctor role is blocked from Billing & Financial Ledgers (PRD Section 2)
    if (session.role == UserRole.doctor) {
      return const UnauthorizedScreen(
        customMessage:
            'Doctor role is restricted from accessing Billing, Fees & Financial Ledgers as per PRD Section 2.',
      );
    }

    final canManageExpenses = AuthorizationService.hasPermission(
      role: session.role,
      permission: AppPermission.manageExpenses,
    );

    return AppScaffold(
      currentRoute: '/billing',
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1024;
          final isMobile = constraints.maxWidth < 768;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 24.0 : 16.0,
              vertical: 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Responsive Header Row
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMobile ? 'Billing & Day Close' : 'Billing, Payments & Day Close',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: isDesktop ? 24 : 20,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isMobile
                              ? 'Immutable ledger & paise reconciliation'
                              : 'PRD M06 & M11: Immutable financial ledger, expenses & paise reconciliation',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: isMobile ? 12 : 13,
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (canManageExpenses)
                          FilledButton.icon(
                            onPressed: _openRecordExpenseDialog,
                            icon: const Icon(Icons.add_card, size: 16),
                            label: Text(
                              isMobile ? 'Expense' : 'RECORD EXPENSE',
                              style: TextStyle(fontSize: isMobile ? 13 : 14),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFD97706),
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: _openDayCloseDialog,
                          icon: const Icon(Icons.point_of_sale, size: 16),
                          label: Text(
                            isMobile ? 'Day Close' : 'DAY CLOSE RECONCILIATION',
                            style: TextStyle(fontSize: isMobile ? 13 : 14),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F766E),
                            side: const BorderSide(color: Color(0xFF0F766E)),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _openCreateInvoiceDialog,
                          icon: const Icon(Icons.add_shopping_cart, size: 16),
                          label: Text(
                            isMobile ? 'New Invoice' : 'CREATE INVOICE & COLLECT',
                            style: TextStyle(fontSize: isMobile ? 13 : 14),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Responsive Financial Summary Cards
                if (_reconciliation != null) ...[
                  _buildResponsiveSummaryGrid(constraints),
                  const SizedBox(height: 18),
                ],

                // Tab Switcher: Invoices vs Operating Expenses
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          selected: _selectedBillingTab == 0,
                          label: Text(
                            isMobile
                                ? 'Invoices (${_invoices.length})'
                                : 'Invoices & Collections (${_invoices.length})',
                          ),
                          selectedColor: const Color(0xFF0F766E),
                          labelStyle: TextStyle(
                            color: _selectedBillingTab == 0 ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 12 : 13,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _selectedBillingTab = 0);
                          },
                        ),
                        ChoiceChip(
                          selected: _selectedBillingTab == 1,
                          label: Text(
                            isMobile
                                ? 'Expenses (${_expenses.length})'
                                : 'Clinic Expenses (${_expenses.length})',
                          ),
                          selectedColor: const Color(0xFFD97706),
                          labelStyle: TextStyle(
                            color: _selectedBillingTab == 1 ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 12 : 13,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _selectedBillingTab = 1);
                          },
                        ),
                      ],
                    ),
                    if (_selectedBillingTab == 1 && _expenses.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: _exportExpensesCsv,
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Export Expenses (CSV)'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_selectedBillingTab == 0) ...[

                // Invoices Table / List
                _isLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _invoices.isEmpty
                        ? EmptyStateWidget(
                            icon: Icons.receipt_long,
                            title: 'No Invoices Issued Today',
                            description:
                                'Invoices created for patient visits, doctor consultations, and fee items will be tracked here in real-time.',
                            actionLabel: 'Create First Invoice for Today',
                            onAction: _openCreateInvoiceDialog,
                          )
                        : Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              side: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _invoices.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              itemBuilder: (context, index) {
                                final inv = _invoices[index];
                                final p = _patientMap[inv.patientId];
                                final pName = p?.fullName ?? 'Patient';

                                Color avatarBg;
                                Color avatarFg;
                                IconData avatarIcon;

                                switch (inv.status) {
                                  case InvoiceStatus.paid:
                                    avatarBg = const Color(0xFFDCFCE7);
                                    avatarFg = const Color(0xFF15803D);
                                    avatarIcon = Icons.check;
                                    break;
                                  case InvoiceStatus.partiallyPaid:
                                    avatarBg = Colors.amber.shade100;
                                    avatarFg = Colors.amber.shade900;
                                    avatarIcon = Icons.timelapse;
                                    break;
                                  case InvoiceStatus.issued:
                                  case InvoiceStatus.draft:
                                    avatarBg = Colors.blue.shade100;
                                    avatarFg = Colors.blue.shade900;
                                    avatarIcon = Icons.access_time;
                                    break;
                                  case InvoiceStatus.refunded:
                                    avatarBg = Colors.purple.shade100;
                                    avatarFg = Colors.purple.shade900;
                                    avatarIcon = Icons.undo;
                                    break;
                                  case InvoiceStatus.voided:
                                    avatarBg = Colors.red.shade100;
                                    avatarFg = Colors.red.shade900;
                                    avatarIcon = Icons.block;
                                    break;
                                }

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: avatarBg,
                                    child: Icon(avatarIcon, color: avatarFg),
                                  ),
                                  title: Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        inv.invoiceNumber,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(pName),
                                      _buildInvoiceStatusChip(inv.status),
                                    ],
                                  ),
                                  subtitle: Text(
                                    'Total: ${Money.fromPaise(inv.totalMinor).formatted} • Paid: ${Money.fromPaise(inv.paidMinor).formatted} • Balance: ${Money.fromPaise(inv.balanceMinor).formatted}${inv.discountMinor > 0 ? " (Discount: ${Money.fromPaise(inv.discountMinor).formatted})" : ""}${inv.taxMinor > 0 ? " (Tax: ${Money.fromPaise(inv.taxMinor).formatted})" : ""}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (inv.balanceMinor > 0 &&
                                          inv.status != InvoiceStatus.voided &&
                                          inv.status != InvoiceStatus.refunded)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(right: 6.0),
                                          child: FilledButton.tonalIcon(
                                            onPressed: () =>
                                                _openCollectPaymentDialog(
                                                  inv,
                                                  pName,
                                                ),
                                            icon: const Icon(
                                              Icons.payments_outlined,
                                              size: 16,
                                            ),
                                            label: Text(
                                              'Collect ${Money.fromPaise(inv.balanceMinor).formatted}',
                                            ),
                                            style: FilledButton.styleFrom(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 0,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.print,
                                          color: Color(0xFF0F766E),
                                        ),
                                        tooltip: 'Print Itemized Receipt',
                                        onPressed: () => _printReceipt(inv),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert),
                                        tooltip: 'Invoice Actions',
                                        onSelected: (val) {
                                          if (val == 'details') {
                                            _openViewDetailsDialog(inv, pName);
                                          } else if (val == 'refund') {
                                            _openProcessRefundDialog(inv, pName);
                                          } else if (val == 'void') {
                                            _openVoidInvoiceDialog(inv, pName);
                                          }
                                        },
                                        itemBuilder: (ctx) => [
                                          const PopupMenuItem(
                                            value: 'details',
                                            child: Row(
                                              children: [
                                                Icon(Icons.receipt_long, size: 18),
                                                SizedBox(width: 8),
                                                Text('View Details & Ledger'),
                                              ],
                                            ),
                                          ),
                                          if (inv.paidMinor > 0 &&
                                              inv.status != InvoiceStatus.voided)
                                            const PopupMenuItem(
                                              value: 'refund',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.undo,
                                                      size: 18, color: Colors.purple),
                                                  SizedBox(width: 8),
                                                  Text('Issue Refund / Reversal'),
                                                ],
                                              ),
                                            ),
                                          if (inv.paidMinor == 0 &&
                                              inv.status != InvoiceStatus.voided)
                                            const PopupMenuItem(
                                              value: 'void',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.cancel_outlined,
                                                      size: 18, color: Colors.red),
                                                  SizedBox(width: 8),
                                                  Text('Void Invoice'),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                ] else ...[
                  _buildExpensesList(isDesktop, isMobile),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildResponsiveSummaryGrid(BoxConstraints constraints) {
    if (_reconciliation == null) return const SizedBox.shrink();

    final cards = [
      _buildSummaryCard(
        'Total Invoiced',
        Money.fromPaise(_reconciliation!.totalInvoicedMinor).formatted,
        Icons.receipt,
        Colors.blue.shade800,
      ),
      _buildSummaryCard(
        'Cash Collected',
        Money.fromPaise(_reconciliation!.totalCashCollectedMinor).formatted,
        Icons.payments,
        Colors.green.shade800,
      ),
      _buildSummaryCard(
        'UPI Collected',
        Money.fromPaise(_reconciliation!.totalUpiCollectedMinor).formatted,
        Icons.qr_code,
        Colors.purple.shade800,
      ),
      _buildSummaryCard(
        'Expenses Settled',
        Money.fromPaise(_reconciliation!.totalExpensesMinor).formatted,
        Icons.money_off,
        Colors.orange.shade800,
      ),
      _buildSummaryCard(
        'Net Cash in Hand',
        Money.fromPaise(_reconciliation!.netCashInHandMinor).formatted,
        Icons.account_balance_wallet,
        const Color(0xFF0D9488),
      ),
      _buildSummaryCard(
        'Outstanding Balance',
        Money.fromPaise(_reconciliation!.totalOutstandingMinor).formatted,
        Icons.pending_actions,
        Colors.amber.shade900,
      ),
    ];

    final width = constraints.maxWidth;
    final int crossAxisCount = width >= 1400
        ? 6
        : (width >= 900 ? 3 : (width >= 480 ? 2 : 1));

    final rows = <Widget>[];
    for (int i = 0; i < cards.length; i += crossAxisCount) {
      final chunk = cards.sublist(
        i,
        i + crossAxisCount > cards.length ? cards.length : i + crossAxisCount,
      );
      rows.add(
        Row(
          children: chunk
              .map(
                (c) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4.0,
                      vertical: 4.0,
                    ),
                    child: c,
                  ),
                ),
              )
              .toList(),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildExpensesList(bool isDesktop, bool isMobile) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_expenses.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.payments_outlined,
        title: 'No Operating Expenses Recorded Today',
        description:
            'PRD M11: Rent, staff salaries, utilities, supplies, and printer consumables are tracked here.',
        actionLabel: 'Record First Operating Expense',
        onAction: _openRecordExpenseDialog,
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _expenses.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
        itemBuilder: (context, index) {
          final exp = _expenses[index];
          final amountFormatted = Money.fromPaise(exp.amountMinor).formatted;

          IconData categoryIcon;
          Color categoryColor;
          String categoryLabel;

          switch (exp.category) {
            case 'rent':
              categoryIcon = Icons.home_work_outlined;
              categoryColor = Colors.brown;
              categoryLabel = 'Rent';
              break;
            case 'salaries':
              categoryIcon = Icons.people_outline;
              categoryColor = Colors.indigo;
              categoryLabel = 'Salaries & Wages';
              break;
            case 'utilities':
              categoryIcon = Icons.bolt_outlined;
              categoryColor = Colors.amber.shade900;
              categoryLabel = 'Utilities';
              break;
            case 'printer_consumables':
              categoryIcon = Icons.print_outlined;
              categoryColor = Colors.teal;
              categoryLabel = 'Printer Consumables';
              break;
            case 'supplies':
              categoryIcon = Icons.medical_services_outlined;
              categoryColor = Colors.blue;
              categoryLabel = 'Clinic Supplies';
              break;
            case 'refreshments':
              categoryIcon = Icons.coffee_outlined;
              categoryColor = Colors.orange;
              categoryLabel = 'Tea & Refreshments';
              break;
            case 'maintenance':
              categoryIcon = Icons.build_outlined;
              categoryColor = Colors.blueGrey;
              categoryLabel = 'Maintenance & Repairs';
              break;
            default:
              categoryIcon = Icons.attach_money;
              categoryColor = Colors.purple;
              categoryLabel = 'Operating Expense';
              break;
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: categoryColor.withValues(alpha: 0.1),
                  child: Icon(categoryIcon, color: categoryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            exp.description,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              categoryLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: categoryColor,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              exp.paymentMethod.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (exp.vendorOptional != null && exp.vendorOptional!.isNotEmpty)
                            'Payee: ${exp.vendorOptional}',
                          if (exp.paymentReferenceOptional != null && exp.paymentReferenceOptional!.isNotEmpty)
                            'Ref: ${exp.paymentReferenceOptional}',
                          'Date: ${exp.expenseDate}',
                        ].join(' • '),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amountFormatted,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      tooltip: 'Delete Expense',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _confirmDeleteExpense(exp),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openRecordExpenseDialog() async {
    final session = ref.read(sessionProvider);
    final descriptionCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final vendorCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    final driveFileCtrl = TextEditingController();

    String selectedCategory = 'supplies';
    PaymentMethod selectedMethod = PaymentMethod.cash;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.add_card, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Text('Record Clinic Operating Expense'),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Expense Category (PRD M11):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'supplies', child: Text('Medical & Clinic Supplies')),
                      DropdownMenuItem(value: 'printer_consumables', child: Text('Printer Consumables (Paper, Cartridges)')),
                      DropdownMenuItem(value: 'rent', child: Text('Clinic Rent')),
                      DropdownMenuItem(value: 'salaries', child: Text('Staff Salaries & Wages')),
                      DropdownMenuItem(value: 'utilities', child: Text('Utilities (Power, Water, Net)')),
                      DropdownMenuItem(value: 'refreshments', child: Text('Tea & Staff Refreshments')),
                      DropdownMenuItem(value: 'maintenance', child: Text('Maintenance & Equipment Repairs')),
                      DropdownMenuItem(value: 'other', child: Text('Other Operating Expenses')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text('Amount in Rupees (₹):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      prefixText: '₹ ',
                      hintText: 'e.g. 450.00',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Payment Method:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<PaymentMethod>(
                    value: selectedMethod,
                    decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                    items: const [
                      DropdownMenuItem(value: PaymentMethod.cash, child: Text('Cash')),
                      DropdownMenuItem(value: PaymentMethod.upi, child: Text('UPI / QR')),
                      DropdownMenuItem(value: PaymentMethod.card, child: Text('Card / POS')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedMethod = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text('Description / Purpose:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descriptionCtrl,
                    decoration: const InputDecoration(
                      hintText: 'e.g. 5 Reams A5 Paper for slips',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Vendor / Payee (Optional):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: vendorCtrl,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Metro Stationers',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Payment Reference ID / Cheque # (Optional):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: refCtrl,
                    decoration: const InputDecoration(
                      hintText: 'e.g. UPI Ref / Cash Memo #',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Google Drive Receipt File ID (Optional):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: driveFileCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Drive File ID or URL',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                final desc = descriptionCtrl.text.trim();
                if (amt <= 0 || desc.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      backgroundColor: Colors.red,
                      content: Text('Please enter a valid amount and description.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Record Expense'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final amtRupees = double.tryParse(amountCtrl.text.trim()) ?? 0;
      final amountMinor = (amtRupees * 100).round();
      final now = DateTime.now().toUtc();
      final today = now.toIso8601String().split('T').first;

      final expense = Expense(
        expenseId: 'exp_${DateTime.now().millisecondsSinceEpoch}',
        clinicId: session.clinicId,
        expenseDate: today,
        category: selectedCategory,
        description: descriptionCtrl.text.trim(),
        amountMinor: amountMinor,
        paymentMethod: selectedMethod,
        vendorOptional: vendorCtrl.text.trim().isEmpty ? null : vendorCtrl.text.trim(),
        paymentReferenceOptional: refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
        receiptDriveFileIdOptional: driveFileCtrl.text.trim().isEmpty ? null : driveFileCtrl.text.trim(),
        createdByStaffId: session.staffId,
        createdAt: now,
        updatedAt: now,
      );

      final expenseRepo = ref.read(expenseRepositoryProvider);
      await expenseRepo.recordExpense(expense);
      await _loadBillingData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFD97706),
            content: Text(
              'Operating expense recorded: ${Money.fromPaise(amountMinor).formatted}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteExpense(Expense exp) async {
    final reasonCtrl = TextEditingController(text: 'Entered by mistake');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Operating Expense?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to remove this expense record (${Money.fromPaise(exp.amountMinor).formatted} - ${exp.description})?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason for deletion',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final session = ref.read(sessionProvider);
      final expenseRepo = ref.read(expenseRepositoryProvider);
      await expenseRepo.deleteExpense(
        clinicId: session.clinicId,
        expenseId: exp.expenseId,
        actorId: session.staffId,
        reason: reasonCtrl.text.trim(),
      );
      await _loadBillingData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense record deleted.')),
        );
      }
    }
  }

  Future<void> _exportExpensesCsv() async {
    try {
      final session = ref.read(sessionProvider);
      final expenseRepo = ref.read(expenseRepositoryProvider);
      final csv = expenseRepo.exportExpensesToCsv(_expenses);
      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final fileName = 'apna_clinic_expenses_${session.clinicId}_$dateStr.csv';
      await FileDownloadHelper.downloadFile(
        fileName: fileName,
        content: csv,
        mimeType: 'text/csv;charset=utf-8',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Expenses exported successfully (${_expenses.length} records, 0 patient data).'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Export failed: $e')),
        );
      }
    }
  }

  Widget _buildSummaryCard(
    String title,
    String amount,
    IconData icon,
    Color color,
  ) {
    return MetricCard(
      title: title,
      value: amount,
      subtitle: "Today's ledger",
      icon: icon,
      iconColor: color,
    );
  }

  Widget _buildInvoiceStatusChip(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return StatusBadge.completed('PAID');
      case InvoiceStatus.partiallyPaid:
        return StatusBadge.waiting('PARTIAL');
      case InvoiceStatus.issued:
      case InvoiceStatus.draft:
        return StatusBadge.waiting('PENDING');
      case InvoiceStatus.refunded:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.shade300),
          ),
          child: Text(
            'REFUNDED',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.purple.shade900,
            ),
          ),
        );
      case InvoiceStatus.voided:
        return StatusBadge.cancelled('VOIDED');
    }
  }
}

/// CREATE INVOICE DIALOG WITH INTEGER PAISE CALCULATIONS, FEE CATALOG, DISCOUNTS, TAX & MIXED TENDER
class _CreateInvoiceDialog extends ConsumerStatefulWidget {
  const _CreateInvoiceDialog();

  @override
  ConsumerState<_CreateInvoiceDialog> createState() =>
      _CreateInvoiceDialogState();
}

class _CreateInvoiceDialogState extends ConsumerState<_CreateInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  List<Patient> _patients = [];
  List<FeeCatalog> _feeCatalog = [];
  String? _selectedPatientId;
  String? _selectedFeeCatalogId;

  String _paymentMode = 'full'; // 'full', 'partial', 'unpaid'
  String _selectedPaymentMethod = 'cash'; // 'cash', 'upi', 'card', 'mixed'

  final _subtotalController = TextEditingController(text: '500');
  final _discountController = TextEditingController(text: '0');
  final _discountReasonController = TextEditingController();
  final _discountApproverController = TextEditingController();
  final _descriptionController = TextEditingController(
    text: 'General Consultation',
  );
  final _paidNowController = TextEditingController(text: '500');

  // Mixed Tender Controllers
  final _mixedCashController = TextEditingController(text: '250');
  final _mixedUpiController = TextEditingController(text: '250');
  final _referenceController = TextEditingController();

  String _selectedTaxRate = '0.0'; // Exempt (0.0), 5.0, 12.0, 18.0
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _subtotalController.dispose();
    _discountController.dispose();
    _discountReasonController.dispose();
    _discountApproverController.dispose();
    _descriptionController.dispose();
    _paidNowController.dispose();
    _mixedCashController.dispose();
    _mixedUpiController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final session = ref.read(sessionProvider);
    final patientRepo = ref.read(patientRepositoryProvider);
    final billingRepo = ref.read(billingRepositoryProvider);

    final patients = await patientRepo.searchPatients(
      session.clinicId,
      '',
      limit: 100,
    );
    final fees = await billingRepo.getFeeCatalog(session.clinicId);

    setState(() {
      _patients = patients;
      _feeCatalog = fees;
      if (patients.isNotEmpty) {
        _selectedPatientId = patients.first.patientId;
      }
      _isLoading = false;
      _recalculateTotal();
    });
  }

  void _onFeeCatalogSelected(String? feeId) {
    setState(() {
      _selectedFeeCatalogId = feeId;
      if (feeId != null) {
        final fee = _feeCatalog.firstWhere((f) => f.feeId == feeId);
        _descriptionController.text = fee.feeName;
        _subtotalController.text = (fee.defaultAmountMinor / 100).toStringAsFixed(0);
        _selectedTaxRate = fee.taxRateConfig.isNotEmpty ? fee.taxRateConfig : '0.0';
      }
      _recalculateTotal();
    });
  }

  void _recalculateTotal() {
    final subtotalRupees = double.tryParse(_subtotalController.text.trim()) ?? 0.0;
    final discountRupees = double.tryParse(_discountController.text.trim()) ?? 0.0;
    final taxRate = double.tryParse(_selectedTaxRate) ?? 0.0;

    final subtotalMinor = (subtotalRupees * 100).round();
    final discountMinor = (discountRupees * 100).round().clamp(0, subtotalMinor);
    final taxableMinor = subtotalMinor - discountMinor;
    final taxMinor = (taxableMinor * (taxRate / 100.0)).round();
    final totalMinor = taxableMinor + taxMinor;

    final totalRupees = totalMinor / 100.0;

    if (_paymentMode == 'full') {
      _paidNowController.text = totalRupees.toStringAsFixed(2);
      _updateMixedDefaults(totalRupees);
    }
  }

  void _updateMixedDefaults(double paidRupees) {
    final half = (paidRupees / 2.0);
    _mixedCashController.text = half.toStringAsFixed(2);
    final remaining = paidRupees - half;
    _mixedUpiController.text = remaining.toStringAsFixed(2);
  }

  Future<void> _submitInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Please select a patient to issue an invoice.'),
        ),
      );
      return;
    }

    final subtotalRupees = double.tryParse(_subtotalController.text.trim()) ?? 0.0;
    final discountRupees = double.tryParse(_discountController.text.trim()) ?? 0.0;
    final taxRate = double.tryParse(_selectedTaxRate) ?? 0.0;

    if (subtotalRupees <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Subtotal amount must be greater than ₹0.00'),
        ),
      );
      return;
    }

    final subtotalMinor = (subtotalRupees * 100).round();
    final discountMinor = (discountRupees * 100).round().clamp(0, subtotalMinor);

    // PRD M06 Requirement: "discounts with reason and approval threshold"
    if (discountMinor > 0 && _discountReasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Discount reason is mandatory when discount is applied.'),
        ),
      );
      return;
    }

    final isThresholdExceeded =
        discountMinor > 20000 || discountMinor > (subtotalMinor * 0.20);
    if (isThresholdExceeded && _discountApproverController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Discount threshold exceeded (> ₹200 or 20%). Supervisor approval is required.',
          ),
        ),
      );
      return;
    }

    final taxableMinor = subtotalMinor - discountMinor;
    final taxMinor = (taxableMinor * (taxRate / 100.0)).round();
    final totalMinor = taxableMinor + taxMinor;

    final session = ref.read(sessionProvider);
    final billingRepo = ref.read(billingRepositoryProvider);

    final now = DateTime.now().toUtc();
    final today = DateTime.now().toIso8601String().split('T').first;

    int paidMinor = 0;
    List<Payment> initialPayments = [];

    if (_paymentMode == 'full') {
      paidMinor = totalMinor;
    } else if (_paymentMode == 'partial') {
      final partialRupees =
          double.tryParse(_paidNowController.text.trim()) ?? 0.0;
      paidMinor = (partialRupees * 100).round().clamp(0, totalMinor);
    } else {
      paidMinor = 0;
    }

    final invoiceId = const Uuid().v4();
    final currentYear = DateTime.now().year;
    final financialYear = '$currentYear-${currentYear + 1}';
    final invoiceNumber = await billingRepo.generateNextInvoiceNumber(
      session.clinicId,
      financialYear,
    );

    // Multi-tender / Mixed tender check
    if (paidMinor > 0) {
      if (_selectedPaymentMethod == 'mixed') {
        final cashRupees = double.tryParse(_mixedCashController.text.trim()) ?? 0.0;
        final upiRupees = double.tryParse(_mixedUpiController.text.trim()) ?? 0.0;
        final cashMinor = (cashRupees * 100).round();
        final upiMinor = (upiRupees * 100).round();

        if (cashMinor + upiMinor != paidMinor) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.red,
                content: Text(
                  'Mixed tender total (${Money.fromPaise(cashMinor + upiMinor).formatted}) must match paid amount (${Money.fromPaise(paidMinor).formatted}) exactly.',
                ),
              ),
            );
          }
          return;
        }

        if (cashMinor > 0) {
          initialPayments.add(
            Payment(
              paymentId: const Uuid().v4(),
              clinicId: session.clinicId,
              invoiceId: invoiceId,
              amountMinor: cashMinor,
              method: PaymentMethod.cash,
              cashUpiCardReferenceOptional: 'Split Tender (Cash)',
              receivedAt: now,
              receivedByStaffId: session.staffId,
              status: PaymentStatus.completed,
              createdAt: now,
            ),
          );
        }
        if (upiMinor > 0) {
          initialPayments.add(
            Payment(
              paymentId: const Uuid().v4(),
              clinicId: session.clinicId,
              invoiceId: invoiceId,
              amountMinor: upiMinor,
              method: PaymentMethod.upi,
              cashUpiCardReferenceOptional: _referenceController.text.trim().isEmpty
                  ? 'Split Tender (UPI)'
                  : _referenceController.text.trim(),
              receivedAt: now,
              receivedByStaffId: session.staffId,
              status: PaymentStatus.completed,
              createdAt: now,
            ),
          );
        }
      } else {
        initialPayments.add(
          Payment(
            paymentId: const Uuid().v4(),
            clinicId: session.clinicId,
            invoiceId: invoiceId,
            amountMinor: paidMinor,
            method: PaymentMethod.fromWire(_selectedPaymentMethod),
            cashUpiCardReferenceOptional: _referenceController.text.trim().isEmpty
                ? null
                : _referenceController.text.trim(),
            receivedAt: now,
            receivedByStaffId: session.staffId,
            status: PaymentStatus.completed,
            createdAt: now,
          ),
        );
      }
    }

    final balanceMinor = totalMinor - paidMinor;
    final status = balanceMinor <= 0
        ? InvoiceStatus.paid
        : (paidMinor > 0 ? InvoiceStatus.partiallyPaid : InvoiceStatus.issued);

    final item = InvoiceItem(
      invoiceItemId: const Uuid().v4(),
      clinicId: session.clinicId,
      invoiceId: invoiceId,
      feeIdOptional: _selectedFeeCatalogId,
      description: _descriptionController.text.trim(),
      quantity: 1,
      unitPriceMinor: subtotalMinor,
      discountMinor: discountMinor,
      taxRateSnapshot: _selectedTaxRate,
      taxMinor: taxMinor,
      lineTotalMinor: totalMinor,
      createdAt: now,
    );

    final invoice = Invoice(
      invoiceId: invoiceId,
      clinicId: session.clinicId,
      invoiceNumber: invoiceNumber,
      financialYear: financialYear,
      patientId: _selectedPatientId!,
      issueDateLocal: today,
      subtotalMinor: subtotalMinor,
      discountMinor: discountMinor,
      discountReasonOptional: discountMinor > 0 ? _discountReasonController.text.trim() : null,
      discountApprovedByOptional:
          isThresholdExceeded ? _discountApproverController.text.trim() : null,
      taxMinor: taxMinor,
      totalMinor: totalMinor,
      paidMinor: paidMinor,
      balanceMinor: balanceMinor,
      status: status,
      createdByStaffId: session.staffId,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await billingRepo.createInvoiceAtomic(
        invoice: invoice,
        items: [item],
        initialPayments: initialPayments,
        idempotencyKey: 'inv_${_selectedPatientId}_${now.millisecondsSinceEpoch}',
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Issued Invoice $invoiceNumber for ${Money.fromPaise(totalMinor).formatted} (Paid: ${Money.fromPaise(paidMinor).formatted})',
            ),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text('Failed to issue invoice: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 580 ? 540.0 : screenWidth - 32;

    final subtotalRupees = double.tryParse(_subtotalController.text.trim()) ?? 0.0;
    final discountRupees = double.tryParse(_discountController.text.trim()) ?? 0.0;
    final taxRate = double.tryParse(_selectedTaxRate) ?? 0.0;
    final subtotalMinor = (subtotalRupees * 100).round();
    final discountMinor = (discountRupees * 100).round().clamp(0, subtotalMinor);
    final taxableMinor = subtotalMinor - discountMinor;
    final taxMinor = (taxableMinor * (taxRate / 100.0)).round();
    final totalMinor = taxableMinor + taxMinor;

    final isThresholdExceeded =
        discountMinor > 20000 || discountMinor > (subtotalMinor * 0.20);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Create Invoice & Bill',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00796B),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),

                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPatientId,
                    decoration: const InputDecoration(
                      labelText: 'Billed Patient *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Please select a patient to bill' : null,
                    items: _patients.map((p) {
                      return DropdownMenuItem(
                        value: p.patientId,
                        child: Text('${p.fullName} (${p.patientNumber})'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedPatientId = val),
                  ),
                  const SizedBox(height: 12),

                  if (_feeCatalog.isNotEmpty) ...[
                    DropdownButtonFormField<String?>(
                      initialValue: _selectedFeeCatalogId,
                      decoration: const InputDecoration(
                        labelText: 'Select Service / Fee from Catalog (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Custom Fee / Consultation'),
                        ),
                        ..._feeCatalog.map((f) {
                          return DropdownMenuItem<String?>(
                            value: f.feeId,
                            child: Text(
                              '${f.feeName} — ${Money.fromPaise(f.defaultAmountMinor).formatted}',
                            ),
                          );
                        }),
                      ],
                      onChanged: _onFeeCatalogSelected,
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Fee / Service Description *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) =>
                        val == null || val.trim().isEmpty ? 'Please enter a fee description' : null,
                  ),
                  const SizedBox(height: 12),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _subtotalController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Fee Subtotal (₹) *',
                            prefixText: '₹ ',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Enter subtotal';
                            }
                            final parsed = double.tryParse(val.trim());
                            if (parsed == null || parsed <= 0) {
                              return 'Must be > ₹0';
                            }
                            return null;
                          },
                          onChanged: (_) => _recalculateTotal(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _discountController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Discount (₹)',
                            prefixText: '₹ ',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return null;
                            final disc = double.tryParse(val.trim());
                            if (disc == null || disc < 0) return 'Invalid';
                            final sub =
                                double.tryParse(_subtotalController.text.trim()) ?? 0.0;
                            if (disc > sub) return 'Cannot exceed ₹$sub';
                            return null;
                          },
                          onChanged: (_) => _recalculateTotal(),
                        ),
                      ),
                    ],
                  ),

                  if (discountMinor > 0) ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _discountReasonController,
                      decoration: const InputDecoration(
                        labelText: 'Mandatory Reason for Discount *',
                        hintText: 'e.g. Senior Citizen Concession / Camp Referral',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (discountMinor > 0 && (val == null || val.trim().isEmpty)) {
                          return 'Discount reason is required';
                        }
                        return null;
                      },
                    ),
                    if (isThresholdExceeded) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade400),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Approval Threshold Reached (> ₹200 / 20%)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _discountApproverController,
                              decoration: const InputDecoration(
                                labelText: 'Approved By (Supervisor / Owner Name) *',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              validator: (val) {
                                if (isThresholdExceeded &&
                                    (val == null || val.trim().isEmpty)) {
                                  return 'Approval required';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],

                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedTaxRate,
                    decoration: const InputDecoration(
                      labelText: 'Tax Category / Rate (Configurable) *',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: '0.0',
                        child: Text('Healthcare Services Exempt (0% GST)'),
                      ),
                      DropdownMenuItem(
                        value: '5.0',
                        child: Text('Concessional 5% GST'),
                      ),
                      DropdownMenuItem(
                        value: '12.0',
                        child: Text('Standard 12% GST'),
                      ),
                      DropdownMenuItem(
                        value: '18.0',
                        child: Text('Standard 18% GST'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedTaxRate = val;
                          _recalculateTotal();
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 12),
                  // Live Invoice Total Display Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal:'),
                            Text(Money.fromPaise(subtotalMinor).formatted),
                          ],
                        ),
                        if (discountMinor > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Discount Applied:',
                                  style: TextStyle(color: Colors.green)),
                              Text('- ${Money.fromPaise(discountMinor).formatted}',
                                  style: const TextStyle(color: Colors.green)),
                            ],
                          ),
                        ],
                        if (taxMinor > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Tax ($_selectedTaxRate%):'),
                              Text('+ ${Money.fromPaise(taxMinor).formatted}'),
                            ],
                          ),
                        ],
                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Net Payable:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              Money.fromPaise(totalMinor).formatted,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _paymentMode,
                    decoration: const InputDecoration(
                      labelText: 'Payment Settlement *',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'full',
                        child: Text('Collect in Full Now'),
                      ),
                      DropdownMenuItem(
                        value: 'partial',
                        child: Text('Collect Partial Advance Now'),
                      ),
                      DropdownMenuItem(
                        value: 'unpaid',
                        child: Text('Unpaid / Credit (Collect Later)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _paymentMode = val;
                          _recalculateTotal();
                        });
                      }
                    },
                  ),

                  if (_paymentMode == 'partial') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _paidNowController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Amount Paid Now (₹) *',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (_paymentMode != 'partial') return null;
                        if (val == null || val.trim().isEmpty) {
                          return 'Enter partial amount';
                        }
                        final parsed = double.tryParse(val.trim());
                        if (parsed == null || parsed <= 0) {
                          return 'Must be > ₹0';
                        }
                        final total = totalMinor / 100.0;
                        if (parsed > total) {
                          return 'Cannot exceed total bill (₹$total)';
                        }
                        return null;
                      },
                      onChanged: (val) {
                        final parsed = double.tryParse(val) ?? 0.0;
                        _updateMixedDefaults(parsed);
                      },
                    ),
                  ],

                  if (_paymentMode != 'unpaid') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedPaymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Tender *',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(
                          value: 'upi',
                          child: Text('UPI / QR Code'),
                        ),
                        DropdownMenuItem(
                          value: 'card',
                          child: Text('Card (Debit/Credit)'),
                        ),
                        DropdownMenuItem(
                          value: 'mixed',
                          child: Text('Mixed Tender (Split Cash + UPI/Card)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedPaymentMethod = val);
                        }
                      },
                    ),

                    if (_selectedPaymentMethod == 'mixed') ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mixed Tender Split',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _mixedCashController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Cash Portion (₹) *',
                                      prefixText: '₹ ',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    controller: _mixedUpiController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'UPI/Card Portion (₹) *',
                                      prefixText: '₹ ',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _referenceController,
                      decoration: const InputDecoration(
                        labelText: 'Reference / UTR / Card Auth (Optional)',
                        border: OutlineInputBorder(),
                        hintText: 'e.g. UTR12345678 or Auth Code',
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('CANCEL'),
                      ),
                      FilledButton.icon(
                        onPressed: _submitInvoice,
                        icon: const Icon(Icons.check),
                        label: const Text('ISSUE INVOICE'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// COLLECT PAYMENT FOR OUTSTANDING INVOICE (SUPPORTS SINGLE & MIXED TENDER)
class _CollectPaymentDialog extends ConsumerStatefulWidget {
  final Invoice invoice;
  final String patientName;

  const _CollectPaymentDialog({
    required this.invoice,
    required this.patientName,
  });

  @override
  ConsumerState<_CollectPaymentDialog> createState() =>
      _CollectPaymentDialogState();
}

class _CollectPaymentDialogState extends ConsumerState<_CollectPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  final _referenceController = TextEditingController();
  final _mixedCashController = TextEditingController();
  final _mixedUpiController = TextEditingController();

  String _selectedPaymentMethod = 'cash'; // 'cash', 'upi', 'card', 'mixed'
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final balanceRupees = widget.invoice.balanceMinor / 100.0;
    _amountController = TextEditingController(
      text: widget.invoice.balanceMinor % 100 == 0
          ? balanceRupees.toInt().toString()
          : balanceRupees.toStringAsFixed(2),
    );
    final half = balanceRupees / 2.0;
    _mixedCashController.text = half.toStringAsFixed(2);
    _mixedUpiController.text = (balanceRupees - half).toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _mixedCashController.dispose();
    _mixedUpiController.dispose();
    super.dispose();
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final session = ref.read(sessionProvider);
      final billingRepo = ref.read(billingRepositoryProvider);

      final enteredRupees = double.parse(_amountController.text.trim());
      final amountMinor = (enteredRupees * 100).round();
      final now = DateTime.now().toUtc();

      if (_selectedPaymentMethod == 'mixed') {
        final cashRupees = double.tryParse(_mixedCashController.text.trim()) ?? 0.0;
        final upiRupees = double.tryParse(_mixedUpiController.text.trim()) ?? 0.0;
        final cashMinor = (cashRupees * 100).round();
        final upiMinor = (upiRupees * 100).round();

        if (cashMinor + upiMinor != amountMinor) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text(
                'Split amounts (${Money.fromPaise(cashMinor + upiMinor).formatted}) must equal collected total (${Money.fromPaise(amountMinor).formatted}).',
              ),
            ),
          );
          return;
        }

        final payments = <Payment>[];
        if (cashMinor > 0) {
          payments.add(
            Payment(
              paymentId: const Uuid().v4(),
              clinicId: widget.invoice.clinicId,
              invoiceId: widget.invoice.invoiceId,
              amountMinor: cashMinor,
              method: PaymentMethod.cash,
              cashUpiCardReferenceOptional: 'Split Tender (Cash)',
              receivedAt: now,
              receivedByStaffId: session.staffId,
              status: PaymentStatus.completed,
              createdAt: now,
            ),
          );
        }
        if (upiMinor > 0) {
          payments.add(
            Payment(
              paymentId: const Uuid().v4(),
              clinicId: widget.invoice.clinicId,
              invoiceId: widget.invoice.invoiceId,
              amountMinor: upiMinor,
              method: PaymentMethod.upi,
              cashUpiCardReferenceOptional: _referenceController.text.trim().isEmpty
                  ? 'Split Tender (UPI)'
                  : _referenceController.text.trim(),
              receivedAt: now,
              receivedByStaffId: session.staffId,
              status: PaymentStatus.completed,
              createdAt: now,
            ),
          );
        }

        await billingRepo.recordPayments(
          payments: payments,
          idempotencyKey: 'pay_mixed_${widget.invoice.invoiceId}_${now.millisecondsSinceEpoch}',
        );
      } else {
        final payment = Payment(
          paymentId: const Uuid().v4(),
          clinicId: widget.invoice.clinicId,
          invoiceId: widget.invoice.invoiceId,
          amountMinor: amountMinor,
          currency: 'INR',
          method: PaymentMethod.fromWire(_selectedPaymentMethod),
          cashUpiCardReferenceOptional: _referenceController.text.trim().isEmpty
              ? null
              : _referenceController.text.trim(),
          receivedAt: now,
          receivedByStaffId: session.staffId,
          status: PaymentStatus.completed,
          createdAt: now,
        );

        await billingRepo.recordPayment(
          payment: payment,
          idempotencyKey:
              'pay_${widget.invoice.invoiceId}_${now.millisecondsSinceEpoch}',
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Collected ${Money.fromPaise(amountMinor).formatted} for ${widget.invoice.invoiceNumber}',
            ),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 540 ? 500.0 : screenWidth - 32;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Collect Payment',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F766E),
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Invoice #:',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              widget.invoice.invoiceNumber,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Patient:',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(widget.patientName),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Invoiced:'),
                            Text(
                              Money.fromPaise(widget.invoice.totalMinor).formatted,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Already Paid:'),
                            Text(
                              Money.fromPaise(widget.invoice.paidMinor).formatted,
                              style: const TextStyle(color: Colors.green),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Outstanding Balance:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              Money.fromPaise(widget.invoice.balanceMinor).formatted,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount to Collect (₹) *',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter payment amount';
                      }
                      final val = double.tryParse(value.trim());
                      if (val == null || val <= 0) {
                        return 'Enter a valid amount greater than 0';
                      }
                      final enteredPaise = (val * 100).round();
                      if (enteredPaise > widget.invoice.balanceMinor) {
                        return 'Cannot exceed remaining balance of ${Money.fromPaise(widget.invoice.balanceMinor).formatted}';
                      }
                      return null;
                    },
                    onChanged: (val) {
                      final parsed = double.tryParse(val) ?? 0.0;
                      final half = parsed / 2.0;
                      _mixedCashController.text = half.toStringAsFixed(2);
                      _mixedUpiController.text = (parsed - half).toStringAsFixed(2);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPaymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Payment Method *',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(
                        value: 'upi',
                        child: Text('UPI / QR'),
                      ),
                      DropdownMenuItem(
                        value: 'card',
                        child: Text('Card (Debit/Credit)'),
                      ),
                      DropdownMenuItem(
                        value: 'mixed',
                        child: Text('Mixed Tender (Split Cash + UPI/Card)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedPaymentMethod = val);
                      }
                    },
                  ),

                  if (_selectedPaymentMethod == 'mixed') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Split Tender Details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _mixedCashController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Cash (₹) *',
                                    prefixText: '₹ ',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _mixedUpiController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'UPI/Card (₹) *',
                                    prefixText: '₹ ',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _referenceController,
                    decoration: const InputDecoration(
                      labelText: 'Reference / UTR / Card Auth (Optional)',
                      border: OutlineInputBorder(),
                      hintText: 'e.g. UTR12345678 or Auth Code',
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            _isSubmitting ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _isSubmitting ? null : _submitPayment,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          _isSubmitting ? 'Recording...' : 'Record Payment',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// PROCESS REFUND / REVERSAL DIALOG (PRD M06 & SECTION 15 MATRIX TEST 10)
class _ProcessRefundDialog extends ConsumerStatefulWidget {
  final Invoice invoice;
  final String patientName;

  const _ProcessRefundDialog({
    required this.invoice,
    required this.patientName,
  });

  @override
  ConsumerState<_ProcessRefundDialog> createState() =>
      _ProcessRefundDialogState();
}

class _ProcessRefundDialogState extends ConsumerState<_ProcessRefundDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _refundAmountController;
  final _reasonController = TextEditingController();
  final _approverController = TextEditingController();
  final _referenceController = TextEditingController();
  final _supervisorPinController = TextEditingController();
  String _refundMethod = 'cash';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final maxRefundRupees = widget.invoice.paidMinor / 100.0;
    _refundAmountController = TextEditingController(
      text: widget.invoice.paidMinor % 100 == 0
          ? maxRefundRupees.toInt().toString()
          : maxRefundRupees.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _refundAmountController.dispose();
    _reasonController.dispose();
    _approverController.dispose();
    _referenceController.dispose();
    _supervisorPinController.dispose();
    super.dispose();
  }

  Future<void> _submitRefund() async {
    if (!_formKey.currentState!.validate()) return;

    final session = ref.read(sessionProvider);
    final db = ref.read(localDatabaseProvider);
    final isAuthorizedDirectly =
        session.role == UserRole.owner || session.role == UserRole.accountant;

    // PRD Module 8: Unauthorized roles cannot access billing reversals without owner approval
    if (!isAuthorizedDirectly) {
      final pin = _supervisorPinController.text.trim();
      final isValidPin =
          await ref.read(sessionProvider.notifier).verifyOwnerPin(pin);
      if (!isValidPin) {
        final now = DateTime.now().toUtc();
        final deniedEvent = AuditEvent(
          auditEventId: 'audit_refund_denied_${now.millisecondsSinceEpoch}',
          clinicId: widget.invoice.clinicId,
          actorId: session.staffId,
          actorRole: session.role.wireValue,
          deviceId: session.deviceId,
          action: 'billing.refund_denied',
          entityType: 'Refunds',
          entityId: widget.invoice.invoiceId,
          result: AuditResult.denied,
          reasonOptional:
              'Unauthorized refund reversal attempt: Invalid supervisor PIN',
          occurredAt: now,
          correlationId: const Uuid().v4(),
        );
        await db.upsert(
            'Audit_Events', deniedEvent.auditEventId, deniedEvent.toMap());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.red,
              content: Text(
                'Reversal Denied: Invalid Owner Security PIN. Only Owner or Accountant can authorize refunds.',
              ),
            ),
          );
        }
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final billingRepo = ref.read(billingRepositoryProvider);

      final enteredRupees = double.parse(_refundAmountController.text.trim());
      final refundMinor = (enteredRupees * 100).round();
      final now = DateTime.now().toUtc();
      final refundId = 'ref_${const Uuid().v4()}';

      final approver = isAuthorizedDirectly
          ? (session.staffName.isNotEmpty ? session.staffName : session.role.wireValue)
          : (_approverController.text.trim().isNotEmpty
              ? '${_approverController.text.trim()} (PIN Verified)'
              : 'Owner (PIN Verified)');

      final refund = Refund(
        refundId: refundId,
        clinicId: widget.invoice.clinicId,
        invoiceId: widget.invoice.invoiceId,
        amountMinor: refundMinor,
        reason: _reasonController.text.trim(),
        requestedByStaffId: session.staffId,
        approvedByStaffId: approver,
        status: RefundStatus.settled,
        refundedAt: now,
        refundMethod: PaymentMethod.fromWire(_refundMethod),
        referenceOptional: _referenceController.text.trim().isEmpty
            ? null
            : _referenceController.text.trim(),
        createdAt: now,
      );

      await billingRepo.recordRefund(
        refund: refund,
        idempotencyKey: 'refund_${widget.invoice.invoiceId}_${now.millisecondsSinceEpoch}',
      );

      // Record immutable Audit Event
      final auditEvent = AuditEvent(
        auditEventId: 'audit_refund_${now.millisecondsSinceEpoch}',
        clinicId: widget.invoice.clinicId,
        actorId: session.staffId,
        actorRole: session.role.wireValue,
        deviceId: session.deviceId,
        action: 'billing.refund_issued',
        entityType: 'Refunds',
        entityId: refundId,
        fieldNamesJson: jsonEncode({
          'invoice_id': widget.invoice.invoiceId,
          'invoice_number': widget.invoice.invoiceNumber,
          'refund_amount_minor': refundMinor,
          'reason': _reasonController.text.trim(),
          'approved_by': approver,
          'method': _refundMethod,
        }),
        occurredAt: now,
        correlationId: const Uuid().v4(),
      );
      await db.upsert('Audit_Events', auditEvent.auditEventId, auditEvent.toMap());

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully issued refund of ${Money.fromPaise(refundMinor).formatted} for ${widget.invoice.invoiceNumber}',
            ),
            backgroundColor: Colors.purple,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process refund: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Process Refund / Credit Reversal',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade800,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Invoice #:',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            Text(widget.invoice.invoiceNumber,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Patient:',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            Text(widget.patientName),
                          ],
                        ),
                        const Divider(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Invoiced:'),
                            Text(Money.fromPaise(widget.invoice.totalMinor).formatted),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Max Available to Refund:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              Money.fromPaise(widget.invoice.paidMinor).formatted,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple.shade900),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _refundAmountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Refund Amount (₹) *',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Enter refund amount';
                      }
                      final parsed = double.tryParse(val.trim());
                      if (parsed == null || parsed <= 0) {
                        return 'Must be greater than ₹0';
                      }
                      final enteredMinor = (parsed * 100).round();
                      if (enteredMinor > widget.invoice.paidMinor) {
                        return 'Cannot exceed paid amount (${Money.fromPaise(widget.invoice.paidMinor).formatted})';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Mandatory Reason for Refund *',
                      hintText: 'e.g. Doctor unavailable / Duplicate fee collected',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Reason is mandatory for financial refund audit';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _approverController,
                    decoration: const InputDecoration(
                      labelText: 'Approved by (Supervisor / Doctor Name) *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Supervisor / Doctor approval is mandatory';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _refundMethod,
                    decoration: const InputDecoration(
                      labelText: 'Refund Payout Method *',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash Payout')),
                      DropdownMenuItem(value: 'upi', child: Text('UPI / Bank Reversal')),
                      DropdownMenuItem(value: 'card', child: Text('Card Chargeback / Credit')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _refundMethod = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _referenceController,
                    decoration: const InputDecoration(
                      labelText: 'Reference / Voucher # (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  // PRD Module 8: Supervisor Authorization for Receptionist Reversals
                  if (ref.watch(sessionProvider).role != UserRole.owner &&
                      ref.watch(sessionProvider).role != UserRole.accountant) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.shield_outlined,
                                  size: 16, color: Colors.amber.shade900),
                              const SizedBox(width: 6),
                              Text(
                                'Supervisor Authorization Required (PRD M08)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Under clinic policy, staff must verify Supervisor Security PIN to issue payment refunds and ledger reversals.',
                            style: TextStyle(fontSize: 11, color: Colors.black87),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _supervisorPinController,
                            obscureText: true,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: const InputDecoration(
                              labelText: 'Owner / Supervisor Security PIN *',
                              hintText: 'Default: 1234',
                              border: OutlineInputBorder(),
                              isDense: true,
                              counterText: '',
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Supervisor PIN is required to authorize refund';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _isSubmitting ? null : _submitRefund,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.purple.shade700,
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.undo),
                        label: Text(_isSubmitting ? 'Processing...' : 'Confirm Refund'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// VOID UNPAID INVOICE DIALOG (PRD M06 IMMUTABILITY & REVERSAL ENFORCEMENT)
class _VoidInvoiceDialog extends ConsumerStatefulWidget {
  final Invoice invoice;
  final String patientName;

  const _VoidInvoiceDialog({
    required this.invoice,
    required this.patientName,
  });

  @override
  ConsumerState<_VoidInvoiceDialog> createState() => _VoidInvoiceDialogState();
}

class _VoidInvoiceDialogState extends ConsumerState<_VoidInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _supervisorPinController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _supervisorPinController.dispose();
    super.dispose();
  }

  Future<void> _submitVoid() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.invoice.paidMinor > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'PRD M06: Cannot void an invoice with recorded payments. Process an approved refund instead.',
          ),
        ),
      );
      return;
    }

    final session = ref.read(sessionProvider);
    final db = ref.read(localDatabaseProvider);
    final isAuthorizedDirectly =
        session.role == UserRole.owner || session.role == UserRole.accountant;

    // PRD Module 8: Reversal authorization required for staff
    if (!isAuthorizedDirectly) {
      final pin = _supervisorPinController.text.trim();
      final isValidPin =
          await ref.read(sessionProvider.notifier).verifyOwnerPin(pin);
      if (!isValidPin) {
        final now = DateTime.now().toUtc();
        final deniedEvent = AuditEvent(
          auditEventId: 'audit_void_denied_${now.millisecondsSinceEpoch}',
          clinicId: widget.invoice.clinicId,
          actorId: session.staffId,
          actorRole: session.role.wireValue,
          deviceId: session.deviceId,
          action: 'billing.void_denied',
          entityType: 'Invoices',
          entityId: widget.invoice.invoiceId,
          result: AuditResult.denied,
          reasonOptional:
              'Unauthorized invoice void attempt: Invalid supervisor PIN',
          occurredAt: now,
          correlationId: const Uuid().v4(),
        );
        await db.upsert(
            'Audit_Events', deniedEvent.auditEventId, deniedEvent.toMap());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.red,
              content: Text(
                'Reversal Denied: Invalid Owner Security PIN. Only Owner or Accountant can void invoices.',
              ),
            ),
          );
        }
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final billingRepo = ref.read(billingRepositoryProvider);
      final now = DateTime.now().toUtc();

      await billingRepo.voidInvoice(
        clinicId: widget.invoice.clinicId,
        invoiceId: widget.invoice.invoiceId,
        reason: _reasonController.text.trim(),
        staffId: session.staffId,
      );

      // Audit Event
      final auditEvent = AuditEvent(
        auditEventId: 'audit_void_${now.millisecondsSinceEpoch}',
        clinicId: widget.invoice.clinicId,
        actorId: session.staffId,
        actorRole: session.role.wireValue,
        deviceId: session.deviceId,
        action: 'billing.invoice_voided',
        entityType: 'Invoices',
        entityId: widget.invoice.invoiceId,
        fieldNamesJson: jsonEncode({
          'invoice_number': widget.invoice.invoiceNumber,
          'void_reason': _reasonController.text.trim(),
          'authorized_by': isAuthorizedDirectly ? session.role.wireValue : 'Owner (PIN Verified)',
        }),
        occurredAt: now,
        correlationId: const Uuid().v4(),
      );
      await db.upsert('Audit_Events', auditEvent.auditEventId, auditEvent.toMap());

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invoice ${widget.invoice.invoiceNumber} has been voided.'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to void invoice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = widget.invoice.paidMinor > 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Void Invoice',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade800,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (isPaid)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Text(
                      'PRD M06 Immutability Rule: Paid invoices cannot be deleted or voided directly. A refund transaction must be recorded to preserve the financial audit ledger.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade900,
                      ),
                    ),
                  )
                else
                  Text(
                    'Are you sure you want to void invoice ${widget.invoice.invoiceNumber} for ${widget.patientName} (${Money.fromPaise(widget.invoice.totalMinor).formatted})? This action is permanent and recorded in the audit trail.',
                    style: const TextStyle(fontSize: 13),
                  ),
                if (!isPaid) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Mandatory Reason for Voiding *',
                      hintText: 'e.g. Created by mistake / Patient cancelled visit',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Reason is mandatory for voiding an invoice';
                      }
                      return null;
                    },
                  ),
                  if (ref.watch(sessionProvider).role != UserRole.owner &&
                      ref.watch(sessionProvider).role != UserRole.accountant) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.shield_outlined,
                                  size: 16, color: Colors.amber.shade900),
                              const SizedBox(width: 6),
                              Text(
                                'Supervisor PIN Authorization Required',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Voiding an issued invoice is an immutable accounting reversal requiring Owner / Supervisor PIN authorization.',
                            style: TextStyle(fontSize: 11, color: Colors.black87),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _supervisorPinController,
                            obscureText: true,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: const InputDecoration(
                              labelText: 'Owner / Supervisor Security PIN *',
                              hintText: 'Default: 1234',
                              border: OutlineInputBorder(),
                              isDense: true,
                              counterText: '',
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Supervisor PIN is required to void invoice';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: isPaid || _isSubmitting ? null : _submitVoid,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                      ),
                      child: Text(_isSubmitting ? 'Voiding...' : 'Confirm Void'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// VIEW INVOICE DETAILS & TRANSACTION LEDGER DIALOG
class _ViewInvoiceDetailsDialog extends ConsumerWidget {
  final Invoice invoice;
  final String patientName;

  const _ViewInvoiceDetailsDialog({
    required this.invoice,
    required this.patientName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billingRepo = ref.read(billingRepositoryProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invoice #${invoice.invoiceNumber}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                      Text(
                        'UUID: ${invoice.invoiceId}',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Billed to: $patientName',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Issued: ${invoice.issueDateLocal} • FY: ${invoice.financialYear}'),
                      const SizedBox(height: 12),

                      // Line items
                      const Text('Line Items',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      for (final item in invoice.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${item.description} (x${item.quantity})'),
                              Text(Money.fromPaise(item.lineTotalMinor).formatted),
                            ],
                          ),
                        ),
                      const Divider(height: 16),

                      // Financial Breakdown
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal:'),
                          Text(Money.fromPaise(invoice.subtotalMinor).formatted),
                        ],
                      ),
                      if (invoice.discountMinor > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Discount (${invoice.discountReasonOptional ?? "Applied"}):',
                              style: const TextStyle(color: Colors.green),
                            ),
                            Text(
                              '- ${Money.fromPaise(invoice.discountMinor).formatted}',
                              style: const TextStyle(color: Colors.green),
                            ),
                          ],
                        ),
                        if (invoice.discountApprovedByOptional != null) ...[
                          Text(
                            'Approved by: ${invoice.discountApprovedByOptional}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ],
                      if (invoice.taxMinor > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tax / GST:'),
                            Text('+ ${Money.fromPaise(invoice.taxMinor).formatted}'),
                          ],
                        ),
                      ],
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Net:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            Money.fromPaise(invoice.totalMinor).formatted,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Amount Paid:'),
                          Text(
                            Money.fromPaise(invoice.paidMinor).formatted,
                            style: const TextStyle(color: Colors.green),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Balance Due:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            Money.fromPaise(invoice.balanceMinor).formatted,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange),
                          ),
                        ],
                      ),
                      if (invoice.status == InvoiceStatus.voided) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.red.shade50,
                          child: Text(
                            'Voided on: ${invoice.voidedAt?.toLocal().toString().split(".").first ?? "N/A"}\nReason: ${invoice.voidReason ?? "None provided"}',
                            style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      const Text('Payment Transactions (Ledger)',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      FutureBuilder<List<Payment>>(
                        future: billingRepo.getPaymentsForInvoice(
                            invoice.clinicId, invoice.invoiceId),
                        builder: (ctx, snap) {
                          if (!snap.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final payments = snap.data!;
                          if (payments.isEmpty) {
                            return const Text('No payments recorded yet.',
                                style: TextStyle(color: Colors.grey, fontSize: 12));
                          }
                          return Column(
                            children: payments.map((p) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${p.method.name.toUpperCase()} • ${Money.fromPaise(p.amountMinor).formatted}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        Text(
                                          '${p.receivedAt.toLocal().toString().split('.').first}${p.cashUpiCardReferenceOptional != null ? ' (${p.cashUpiCardReferenceOptional})' : ''}',
                                          style: const TextStyle(
                                              fontSize: 11, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                    StatusBadge.completed('SUCCESS'),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 16),
                      const Text('Refund & Credit Reversals',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      FutureBuilder<List<Refund>>(
                        future: billingRepo.getRefundsForInvoice(
                            invoice.clinicId, invoice.invoiceId),
                        builder: (ctx, snap) {
                          if (!snap.hasData) return const SizedBox.shrink();
                          final refunds = snap.data!;
                          if (refunds.isEmpty) {
                            return const Text('No refunds issued for this invoice.',
                                style: TextStyle(color: Colors.grey, fontSize: 12));
                          }
                          return Column(
                            children: refunds.map((r) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.purple.shade200),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Refund: ${Money.fromPaise(r.amountMinor).formatted} (${r.refundMethod.name.toUpperCase()})',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Colors.purple.shade900),
                                        ),
                                        Text(
                                          'Reason: ${r.reason} • Approved by: ${r.approvedByStaffId}',
                                          style: const TextStyle(
                                              fontSize: 11, color: Colors.black87),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      r.refundedAt.toLocal().toString().split('.').first,
                                      style: const TextStyle(
                                          fontSize: 10, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// DAY CLOSE RECONCILIATION DIALOG (PRD SECTION 6.2 `Finance / day_close`)
class _DayCloseDialog extends ConsumerStatefulWidget {
  final DailyReconciliation recon;

  const _DayCloseDialog({required this.recon});

  @override
  ConsumerState<_DayCloseDialog> createState() => _DayCloseDialogState();
}

class _DayCloseDialogState extends ConsumerState<_DayCloseDialog> {
  final _countedCashController = TextEditingController();
  final _varianceExplanationController = TextEditingController();
  int _varianceMinor = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _countedCashController.text = Money.fromPaise(
      widget.recon.netCashInHandMinor,
    ).inRupees.toStringAsFixed(2);
    _calculateVariance();
  }

  @override
  void dispose() {
    _countedCashController.dispose();
    _varianceExplanationController.dispose();
    super.dispose();
  }

  void _calculateVariance() {
    final countedRupees =
        double.tryParse(_countedCashController.text.trim()) ?? 0.0;
    final countedMinor = Money.fromRupees(countedRupees).minorUnits;
    setState(() {
      _varianceMinor = countedMinor - widget.recon.netCashInHandMinor;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 540 ? 500.0 : screenWidth - 32;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'End of Day Cash Reconciliation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00796B),
                ),
              ),
              const Divider(),
              const SizedBox(height: 8),

              Text(
                'Expected Net Cash in Drawer: ${Money.fromPaise(widget.recon.netCashInHandMinor).formatted}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                '(Gross Cash: ${Money.fromPaise(widget.recon.totalCashCollectedMinor).formatted} - Refunds: ${Money.fromPaise(widget.recon.totalRefundedMinor).formatted} - Expenses: ${Money.fromPaise(widget.recon.totalExpensesMinor).formatted})',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _countedCashController,
                keyboardType: TextInputType.number,
                onChanged: (_) => _calculateVariance(),
                decoration: const InputDecoration(
                  labelText: 'Physically Counted Cash (₹) *',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Cash Variance: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    Money.fromPaise(_varianceMinor).formatted,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _varianceMinor == 0
                          ? Colors.green
                          : (_varianceMinor < 0 ? Colors.red : Colors.blue),
                    ),
                  ),
                  if (_varianceMinor == 0)
                    const Chip(
                      label: Text('Balanced'),
                      backgroundColor: Color(0xFFE8F5E9),
                      side: BorderSide.none,
                    )
                  else
                    Chip(
                      label: const Text('Variance Detected'),
                      backgroundColor: Colors.amber.shade100,
                      side: BorderSide.none,
                    ),
                ],
              ),

              if (_varianceMinor != 0) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _varianceExplanationController,
                  decoration: const InputDecoration(
                    labelText: 'Mandatory Explanation for Variance *',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('CLOSE'),
                  ),
                  FilledButton(
                    onPressed: _isSubmitting
                        ? null
                        : () async {
                            if (_varianceMinor != 0 &&
                                _varianceExplanationController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Mandatory explanation required for cash variance.',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            final navigator = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);
                            setState(() => _isSubmitting = true);
                            try {
                              final session = ref.read(sessionProvider);
                              final billingRepo = ref.read(billingRepositoryProvider);
                              final db = ref.read(localDatabaseProvider);
                              final today =
                                  DateTime.now().toIso8601String().split('T').first;
                              final countedRupees =
                                  double.tryParse(_countedCashController.text.trim()) ??
                                      0.0;
                              final countedMinor = (countedRupees * 100).round();
                              final now = DateTime.now().toUtc();

                              // PRD Section 6.2: Finance / day_close
                              final dayClose = DayClose(
                                closeId:
                                    'dc_${session.clinicId}_${today}_${now.millisecondsSinceEpoch}',
                                clinicId: session.clinicId,
                                businessDate: today,
                                openedBy: session.staffName,
                                closedBy: session.staffName,
                                closedAt: now,
                                openingCashPaise: 0,
                                expectedCashPaise: widget.recon.netCashInHandMinor,
                                countedCashPaise: countedMinor,
                                variancePaise: _varianceMinor,
                                upiTotalPaise: widget.recon.totalUpiCollectedMinor,
                                cardTotalPaise: widget.recon.totalCardCollectedMinor,
                                refundTotalPaise: widget.recon.totalRefundedMinor,
                                notesOptional: _varianceExplanationController.text.trim().isEmpty
                                    ? null
                                    : _varianceExplanationController.text.trim(),
                              );

                              await billingRepo.performDayClose(dayClose);

                              final auditEvent = AuditEvent(
                                auditEventId:
                                    'audit_dayclose_${now.millisecondsSinceEpoch}',
                                clinicId: session.clinicId,
                                actorId: session.staffId,
                                actorRole: session.role.wireValue,
                                deviceId: session.deviceId,
                                action: 'billing.day_close',
                                entityType: 'daily_reconciliation',
                                entityId: today,
                                fieldNamesJson: jsonEncode({
                                  'close_id': dayClose.closeId,
                                  'counted_cash_minor': countedMinor,
                                  'variance_minor': _varianceMinor,
                                  'variance_explanation':
                                      _varianceExplanationController.text.trim(),
                                }),
                                occurredAt: now,
                                correlationId: const Uuid().v4(),
                              );
                              final dailySummary = DailySummary(
                                summaryId: 'summary_${session.clinicId}_$today',
                                clinicId: session.clinicId,
                                localDate: today,
                                invoicedMinor: widget.recon.totalInvoicedMinor,
                                paidCashMinor: widget.recon.totalCashCollectedMinor,
                                paidUpiMinor: widget.recon.totalUpiCollectedMinor,
                                paidCardMinor: widget.recon.totalCardCollectedMinor,
                                refundedMinor: widget.recon.totalRefundedMinor,
                                outstandingMinor: widget.recon.totalOutstandingMinor,
                                expensesMinor: widget.recon.totalExpensesMinor,
                                generatedAt: now,
                              );

                              await db.upsert(
                                'Audit_Events',
                                auditEvent.auditEventId,
                                auditEvent.toMap(),
                              );

                              await db.upsert(
                                'Daily_Summary',
                                dailySummary.summaryId,
                                dailySummary.toMap(),
                              );

                              if (mounted) {
                                navigator.pop();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Day close confirmed. Net cash in hand: ${Money.fromPaise(countedMinor).formatted}',
                                    ),
                                    backgroundColor: Colors.teal,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                setState(() => _isSubmitting = false);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to confirm day close: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                    child: Text(_isSubmitting ? 'Saving...' : 'CONFIRM DAY CLOSE'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
