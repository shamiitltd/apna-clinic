// Apna Clinic - Consultation Slip Preview & Print Dialog
// Primary source of truth: PRD Section 5 M05 and TRD Section 9
// Printing workflow: Preview -> Choose A5/A4 -> Render client-side PDF -> Browser print -> Record print attempt & sync

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../application/printing/consultation_slip_service.dart';
import '../../../application/providers.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/enums/domain_enums.dart';
import '../theme/app_theme.dart';

class ConsultationSlipPreviewDialog extends ConsumerStatefulWidget {
  final Clinic clinic;
  final Doctor doctor;
  final Patient patient;
  final Visit visit;
  final String? patientReportedReasonForVisit;
  final String? clinicalNotes;
  final VoidCallback? onPrinted;

  const ConsultationSlipPreviewDialog({
    super.key,
    required this.clinic,
    required this.doctor,
    required this.patient,
    required this.visit,
    this.patientReportedReasonForVisit,
    this.clinicalNotes,
    this.onPrinted,
  });

  static Future<void> show({
    required BuildContext context,
    required Clinic clinic,
    required Doctor doctor,
    required Patient patient,
    required Visit visit,
    String? patientReportedReasonForVisit,
    String? clinicalNotes,
    VoidCallback? onPrinted,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ConsultationSlipPreviewDialog(
        clinic: clinic,
        doctor: doctor,
        patient: patient,
        visit: visit,
        patientReportedReasonForVisit: patientReportedReasonForVisit,
        clinicalNotes: clinicalNotes,
        onPrinted: onPrinted,
      ),
    );
  }

  @override
  ConsumerState<ConsultationSlipPreviewDialog> createState() =>
      _ConsultationSlipPreviewDialogState();
}

class _ConsultationSlipPreviewDialogState
    extends ConsumerState<ConsultationSlipPreviewDialog> {
  late String _selectedPaperSize;
  bool _showReasonForVisit = true;
  bool _isActionInProgress = false;

  @override
  void initState() {
    super.initState();
    final defaultPaper = widget.clinic.defaultPaperSize;
    _selectedPaperSize = (defaultPaper.isNotEmpty && defaultPaper.toUpperCase() == 'A4')
        ? 'A4'
        : 'A5';
  }

  Future<void> _handlePrint() async {
    if (_isActionInProgress) return;
    setState(() => _isActionInProgress = true);

    final session = ref.read(sessionProvider);
    final visitRepo = ref.read(visitRepositoryProvider);

    try {
      await ConsultationSlipService.printSlip(
        clinic: widget.clinic,
        doctor: widget.doctor,
        patient: widget.patient,
        visit: widget.visit,
        patientReportedReasonForVisit: widget.patientReportedReasonForVisit,
        clinicalNotes: widget.clinicalNotes,
        paperSize: _selectedPaperSize,
        isReprint: widget.visit.slipPrintCount > 0,
        showReasonForVisit: _showReasonForVisit,
      );

      // Increment print count transactionally with audit event and cloud sync staging
      await visitRepo.incrementSlipPrintCount(
        clinicId: session.clinicId,
        visitId: widget.visit.visitId,
        paperSize: _selectedPaperSize,
        staffId: session.staffId,
        deviceId: session.deviceId,
      );

      // Trigger background sync to Google Master Sheet
      unawaited(
        ref
            .read(masterSheetSyncSchedulerProvider)
            .triggerManualSync(clinicId: session.clinicId),
      );

      widget.onPrinted?.call();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Consultation slip sent to printer for Token #${widget.visit.tokenNumber} (${widget.patient.fullName}).',
            ),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActionInProgress = false);
      }
    }
  }

  Future<void> _handleDownload() async {
    if (_isActionInProgress) return;
    setState(() => _isActionInProgress = true);

    try {
      await ConsultationSlipService.downloadSlipPdf(
        clinic: widget.clinic,
        doctor: widget.doctor,
        patient: widget.patient,
        visit: widget.visit,
        patientReportedReasonForVisit: widget.patientReportedReasonForVisit,
        clinicalNotes: widget.clinicalNotes,
        paperSize: _selectedPaperSize,
        isReprint: widget.visit.slipPrintCount > 0,
        showReasonForVisit: _showReasonForVisit,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActionInProgress = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReprint = widget.visit.slipPrintCount > 0;
    final hasPriority = widget.visit.priority != QueuePriority.normal;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isDesktop = screenWidth >= 800;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 48.0 : 16.0,
        vertical: 24.0,
      ),
      child: Container(
        width: isDesktop ? 860.0 : double.infinity,
        height: screenHeight * 0.90,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Dialog Header Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.print, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Consultation Slip Preview — Token #${widget.visit.tokenNumber}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (isReprint)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.amber.shade400),
                              ),
                              child: Text(
                                'DUPLICATE / REPRINT #${widget.visit.slipPrintCount + 1}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ),
                          if (hasPriority)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: widget.visit.priority == QueuePriority.emergency
                                    ? Colors.red.shade100
                                    : (widget.visit.priority == QueuePriority.urgent
                                        ? Colors.orange.shade100
                                        : Colors.purple.shade100),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                widget.visit.priority.displayName.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: widget.visit.priority == QueuePriority.emergency
                                      ? Colors.red.shade800
                                      : (widget.visit.priority == QueuePriority.urgent
                                          ? Colors.orange.shade900
                                          : Colors.purple.shade800),
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        '${widget.patient.fullName} (${widget.patient.patientNumber}) • Dr. ${widget.doctor.displayName} • ${widget.doctor.roomLabel}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close Preview',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 10),

            // 2. Customization Toolbar: Paper Size + Privacy Toggle
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Paper Format:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                SegmentedButton<String>(
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  segments: const [
                    ButtonSegment(
                      value: 'A5',
                      label: Text('A5 Portrait (Standard OPD)', style: TextStyle(fontSize: 12)),
                      icon: Icon(Icons.description_outlined, size: 14),
                    ),
                    ButtonSegment(
                      value: 'A4',
                      label: Text('A4 Portrait (Full Sheet)', style: TextStyle(fontSize: 12)),
                      icon: Icon(Icons.note_outlined, size: 14),
                    ),
                  ],
                  selected: {_selectedPaperSize},
                  onSelectionChanged: (val) {
                    setState(() => _selectedPaperSize = val.first);
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Include Reason for Visit', style: TextStyle(fontSize: 12)),
                  selected: _showReasonForVisit,
                  onSelected: (val) => setState(() => _showReasonForVisit = val),
                  avatar: Icon(
                    _showReasonForVisit ? Icons.check_circle : Icons.visibility_off,
                    size: 14,
                    color: _showReasonForVisit ? Colors.white : AppColors.textSecondary,
                  ),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: _showReasonForVisit ? Colors.white : AppColors.textPrimary,
                    fontWeight: _showReasonForVisit ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 3. Interactive Client-Side PDF Preview Area
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  color: const Color(0xFFF8FAFC),
                  child: PdfPreview(
                    build: (format) => ConsultationSlipService.generateConsultationSlipPdf(
                      clinic: widget.clinic,
                      doctor: widget.doctor,
                      patient: widget.patient,
                      visit: widget.visit,
                      patientReportedReasonForVisit: widget.patientReportedReasonForVisit,
                      clinicalNotes: widget.clinicalNotes,
                      paperSize: _selectedPaperSize,
                      isReprint: isReprint,
                      showReasonForVisit: _showReasonForVisit,
                    ),
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    allowPrinting: false, // Governed by dialog action buttons
                    allowSharing: false,
                    initialPageFormat: _selectedPaperSize == 'A4'
                        ? PdfPageFormat.a4
                        : PdfPageFormat.a5,
                    pdfFileName:
                        'Consultation_Slip_Token_${widget.visit.tokenNumber}_${widget.visit.visitDateLocal}.pdf',
                    loadingWidget: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text(
                            'Rendering print-safe consultation slip...',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 4. Action Footer Toolbar
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: _isActionInProgress ? null : () => Navigator.of(context).pop(),
                  child: const Text('CANCEL'),
                ),
                OutlinedButton.icon(
                  onPressed: _isActionInProgress ? null : _handleDownload,
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('DOWNLOAD PDF'),
                ),
                FilledButton.icon(
                  onPressed: _isActionInProgress ? null : _handlePrint,
                  icon: const Icon(Icons.print, size: 16),
                  label: Text(
                    isReprint
                        ? 'PRINT DUPLICATE / REPRINT SLIP'
                        : 'PRINT CONSULTATION SLIP',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
