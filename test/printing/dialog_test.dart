import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_clinic/domain/entities/entities.dart';
import 'package:apna_clinic/presentation/shared/dialogs/consultation_slip_preview_dialog.dart';

void main() {
  testWidgets('ConsultationSlipPreviewDialog can be constructed', (tester) async {
    final now = DateTime.now().toUtc();
    final clinic = Clinic(
      clinicId: 'c1',
      legalName: 'Test Clinic',
      displayName: 'Test Clinic',
      ownerName: 'Dr. Owner',
      contactPhone: '9999999999',
      contactEmail: 'clinic@test.com',
      addressLine1: 'Line 1',
      city: 'Delhi',
      district: 'Delhi',
      state: 'Delhi',
      pincode: '110001',
      createdAt: now,
      updatedAt: now,
    );

    final doctor = Doctor(
      doctorId: 'd1',
      clinicId: 'c1',
      displayName: 'Dr. Tester',
      qualificationText: 'MBBS, MD',
      registrationNumber: 'MED-12345',
      roomLabel: 'Cabin 1',
      createdAt: now,
      updatedAt: now,
    );

    final patient = Patient(
      patientId: 'p1',
      clinicId: 'c1',
      patientNumber: 'P-1001',
      fullName: 'Raghav',
      phoneOptional: '9876543210',
      createdAt: now,
      updatedAt: now,
    );

    final visit = Visit(
      visitId: 'v1',
      clinicId: 'c1',
      patientId: 'p1',
      doctorId: 'd1',
      tokenNumber: 4,
      tokenScopeKey: 'c1:d1:2026-10-28',
      createdByStaffId: 'staff1',
      visitDateLocal: '2026-10-28',
      checkinAt: now,
      slipPrintCount: 0,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ConsultationSlipPreviewDialog(
              clinic: clinic,
              doctor: doctor,
              patient: patient,
              visit: visit,
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Consultation Slip Preview'), findsOneWidget);
  });
}
