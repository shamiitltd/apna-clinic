// Apna Clinic — Realistic Demo Data Seeder for Phase 1 Web UI
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/permissions/roles.dart';
import '../../domain/entities/entities.dart';
import '../../domain/enums/domain_enums.dart';
import '../providers.dart';

class DemoDataSeeder {
  static bool _isSeeding = false;
  static bool _hasSeeded = false;

  static Future<void> seed(WidgetRef ref) async {
    if (_isSeeding || _hasSeeded) return;
    _isSeeding = true;
    try {
      final session = ref.read(sessionProvider);
      final clinicRepo = ref.read(clinicRepositoryProvider);
      final patientRepo = ref.read(patientRepositoryProvider);
      final visitRepo = ref.read(visitRepositoryProvider);
      final appointmentRepo = ref.read(appointmentRepositoryProvider);
      final billingRepo = ref.read(billingRepositoryProvider);

    final now = DateTime.now();
    final todayStr =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // 1. Clinic Setup
    final clinic = Clinic(
      clinicId: session.clinicId,
      legalName: 'City Health Clinic Pvt. Ltd.',
      displayName: 'City Health Clinic',
      ownerName: 'Dr. Rajesh Sharma',
      contactPhone: '+919876543210',
      contactEmail: 'reception@cityhealthclinic.in',
      addressLine1: 'B-14, Ground Floor, Outer Ring Road, Connaught Place',
      city: 'New Delhi',
      district: 'Central Delhi',
      state: 'Delhi',
      pincode: '110001',
      defaultPaperSize: AppConstants.paperSizeA5,
      defaultConsultationFee: 30000,
      createdAt: now.subtract(const Duration(days: 90)).toUtc(),
      updatedAt: now.toUtc(),
    );
    await clinicRepo.saveClinic(clinic);

    // 2. Doctors (General Medicine & Gynecology)
    final doc1 = Doctor(
      doctorId: 'doc_sharma_01',
      clinicId: session.clinicId,
      displayName: 'Dr. Rajesh Sharma',
      qualificationText: 'MBBS, MD (General Medicine)',
      registrationNumber: 'DMC-48291',
      specialtyLabel: 'Senior Consultant Physician',
      contactPhone: '+919876543210',
      active: true,
      defaultFee: 30000,
      createdAt: now.subtract(const Duration(days: 90)).toUtc(),
      updatedAt: now.toUtc(),
    );
    final doc2 = Doctor(
      doctorId: 'doc_priya_02',
      clinicId: session.clinicId,
      displayName: 'Dr. Priya Nair',
      qualificationText: 'MBBS, DGO (Obstetrics & Gynecology)',
      registrationNumber: 'DMC-59302',
      specialtyLabel: 'Consultant Obstetrician & Gynecologist',
      contactPhone: '+919876543220',
      active: true,
      defaultFee: 50000,
      createdAt: now.subtract(const Duration(days: 60)).toUtc(),
      updatedAt: now.toUtc(),
    );
    await clinicRepo.saveDoctor(doc1);
    await clinicRepo.saveDoctor(doc2);

    // 2.1 Seed Staff Members with Quick Workstation PINs (PRD Module 8)
    final recPin = Staff.generatePinHash('1111');
    final doc1Pin = Staff.generatePinHash('2222');
    final acctPin = Staff.generatePinHash('3333');

    final staffMembers = [
      Staff(
        staffId: 'staff_reception_01',
        clinicId: session.clinicId,
        displayName: 'Suman Sharma',
        role: UserRole.receptionist,
        email: 'reception@apnaclinic.in',
        phone: '+919876543201',
        active: true,
        pinHash: recPin['pin_hash'],
        pinSalt: recPin['pin_salt'],
        createdAt: now.toUtc(),
        updatedAt: now.toUtc(),
      ),
      Staff(
        staffId: 'staff_doc_sharma',
        clinicId: session.clinicId,
        displayName: 'Dr. Rajesh Sharma',
        role: UserRole.doctor,
        email: 'dr.sharma@apnaclinic.in',
        phone: '+919876543210',
        active: true,
        assignedDoctorIds: const ['doc_sharma_01'],
        pinHash: doc1Pin['pin_hash'],
        pinSalt: doc1Pin['pin_salt'],
        createdAt: now.toUtc(),
        updatedAt: now.toUtc(),
      ),
      Staff(
        staffId: 'staff_accountant_01',
        clinicId: session.clinicId,
        displayName: 'Pooja Verma',
        role: UserRole.accountant,
        email: 'accounts@apnaclinic.in',
        phone: '+919876543202',
        active: true,
        pinHash: acctPin['pin_hash'],
        pinSalt: acctPin['pin_salt'],
        createdAt: now.toUtc(),
        updatedAt: now.toUtc(),
      ),
    ];
    for (final s in staffMembers) {
      await clinicRepo.saveStaff(s);
    }

    // 3. Fee Catalog
    final fees = [
      FeeCatalog(
        feeId: 'fee_gen_consult',
        clinicId: session.clinicId,
        feeCode: 'CONSULT-GEN',
        feeName: 'General OPD Consultation',
        defaultAmountMinor: 30000,
        createdAt: now.toUtc(),
        updatedAt: now.toUtc(),
      ),
      FeeCatalog(
        feeId: 'fee_special_consult',
        clinicId: session.clinicId,
        feeCode: 'CONSULT-SPEC',
        feeName: 'Specialist Consultation',
        defaultAmountMinor: 50000,
        createdAt: now.toUtc(),
        updatedAt: now.toUtc(),
      ),
      FeeCatalog(
        feeId: 'fee_ecg',
        clinicId: session.clinicId,
        feeCode: 'DIAG-ECG',
        feeName: '12-Lead Resting ECG',
        defaultAmountMinor: 40000,
        createdAt: now.toUtc(),
        updatedAt: now.toUtc(),
      ),
      FeeCatalog(
        feeId: 'fee_dressing',
        clinicId: session.clinicId,
        feeCode: 'PROC-DRESS',
        feeName: 'Aseptic Wound Dressing',
        defaultAmountMinor: 15000,
        createdAt: now.toUtc(),
        updatedAt: now.toUtc(),
      ),
      FeeCatalog(
        feeId: 'fee_injection',
        clinicId: session.clinicId,
        feeCode: 'PROC-INJ',
        feeName: 'Intramuscular / IV Injection',
        defaultAmountMinor: 10000,
        createdAt: now.toUtc(),
        updatedAt: now.toUtc(),
      ),
    ];
    for (final f in fees) {
      await billingRepo.saveFeeCatalogItem(f);
    }

    // 4. Patients (8 diverse patients across clinical cases)
    final patients = [
      Patient(
        patientId: 'pat_demo_001',
        clinicId: session.clinicId,
        patientNumber: 'P-1001',
        fullName: 'Rahul Verma',
        phoneOptional: '+919876543211',
        ageIfDobUnknown: 34,
        sexOptional: 'male',
        cityOptional: 'New Delhi',
        consentStatus: 'granted',
        createdAt: now.subtract(const Duration(days: 30)).toUtc(),
        updatedAt: now.toUtc(),
      ),
      Patient(
        patientId: 'pat_demo_002',
        clinicId: session.clinicId,
        patientNumber: 'P-1002',
        fullName: 'Sunita Patel',
        phoneOptional: '+919876543212',
        ageIfDobUnknown: 28,
        sexOptional: 'female',
        cityOptional: 'New Delhi',
        consentStatus: 'granted',
        createdAt: now.subtract(const Duration(days: 20)).toUtc(),
        updatedAt: now.toUtc(),
      ),
      Patient(
        patientId: 'pat_demo_003',
        clinicId: session.clinicId,
        patientNumber: 'P-1003',
        fullName: 'Amit Kumar',
        phoneOptional: '+919876543213',
        ageIfDobUnknown: 45,
        sexOptional: 'male',
        cityOptional: 'South Delhi',
        consentStatus: 'granted',
        createdAt: now.subtract(const Duration(days: 15)).toUtc(),
        updatedAt: now.toUtc(),
      ),
      Patient(
        patientId: 'pat_demo_004',
        clinicId: session.clinicId,
        patientNumber: 'P-1004',
        fullName: 'Pooja Mehta',
        phoneOptional: '+919876543214',
        ageIfDobUnknown: 22,
        sexOptional: 'female',
        cityOptional: 'New Delhi',
        consentStatus: 'granted',
        createdAt: now.subtract(const Duration(days: 10)).toUtc(),
        updatedAt: now.toUtc(),
      ),
      Patient(
        patientId: 'pat_demo_005',
        clinicId: session.clinicId,
        patientNumber: 'P-1005',
        fullName: 'Rajesh Gupta',
        phoneOptional: '+919876543215',
        ageIfDobUnknown: 62,
        sexOptional: 'male',
        cityOptional: 'Central Delhi',
        consentStatus: 'granted',
        createdAt: now.subtract(const Duration(days: 7)).toUtc(),
        updatedAt: now.toUtc(),
      ),
      Patient(
        patientId: 'pat_demo_006',
        clinicId: session.clinicId,
        patientNumber: 'P-1006',
        fullName: 'Meena Devi',
        phoneOptional: '+919876543216',
        ageIfDobUnknown: 50,
        sexOptional: 'female',
        cityOptional: 'West Delhi',
        consentStatus: 'granted',
        createdAt: now.subtract(const Duration(days: 5)).toUtc(),
        updatedAt: now.toUtc(),
      ),
      Patient(
        patientId: 'pat_demo_007',
        clinicId: session.clinicId,
        patientNumber: 'P-1007',
        fullName: 'Vikram Singh',
        phoneOptional: '+919876543217',
        ageIfDobUnknown: 38,
        sexOptional: 'male',
        cityOptional: 'New Delhi',
        consentStatus: 'granted',
        createdAt: now.subtract(const Duration(days: 3)).toUtc(),
        updatedAt: now.toUtc(),
      ),
      Patient(
        patientId: 'pat_demo_008',
        clinicId: session.clinicId,
        patientNumber: 'P-1008',
        fullName: 'Ananya Sharma',
        phoneOptional: '+919876543218',
        ageIfDobUnknown: 8,
        sexOptional: 'female',
        cityOptional: 'East Delhi',
        consentStatus: 'granted',
        createdAt: now.subtract(const Duration(days: 1)).toUtc(),
        updatedAt: now.toUtc(),
      ),
    ];
    for (final p in patients) {
      await patientRepo.savePatient(p);
    }

    // 5. Visits & Live Queue for Today (Tokens #1 to #5 across all states)
    final existingVisits = await visitRepo.getVisitsForDate(session.clinicId, todayStr);
    if (existingVisits.isEmpty) {
      final v1 = Visit(
      visitId: 'visit_demo_001',
      clinicId: session.clinicId,
      patientId: 'pat_demo_001',
      doctorId: doc1.doctorId,
      visitDateLocal: todayStr,
      checkinAt: now.subtract(const Duration(hours: 2)),
      tokenNumber: 1,
      tokenScopeKey: '${session.clinicId}:${doc1.doctorId}:$todayStr',
      queueStatus: QueueStatus.waiting,
      visitType: 'walkin',
      createdByStaffId: session.staffId,
      createdAt: now.subtract(const Duration(hours: 2)).toUtc(),
      updatedAt: now.subtract(const Duration(hours: 2)).toUtc(),
    );
    await visitRepo.createVisitAtomic(
      visit: v1,
      idempotencyKey: 'seed_visit_001',
      deviceId: session.deviceId,
      staffId: session.staffId,
    );
    await visitRepo.updateQueueStatus(
      clinicId: session.clinicId,
      visitId: v1.visitId,
      newStatus: QueueStatus.called,
      staffId: session.staffId,
      deviceId: session.deviceId,
    );
    await visitRepo.updateQueueStatus(
      clinicId: session.clinicId,
      visitId: v1.visitId,
      newStatus: QueueStatus.inConsultation,
      staffId: session.staffId,
      deviceId: session.deviceId,
    );
    await visitRepo.updateQueueStatus(
      clinicId: session.clinicId,
      visitId: v1.visitId,
      newStatus: QueueStatus.completed,
      staffId: session.staffId,
      deviceId: session.deviceId,
    );

    final v2 = Visit(
      visitId: 'visit_demo_002',
      clinicId: session.clinicId,
      patientId: 'pat_demo_002',
      doctorId: doc1.doctorId,
      visitDateLocal: todayStr,
      checkinAt: now.subtract(const Duration(minutes: 50)),
      tokenNumber: 2,
      tokenScopeKey: '${session.clinicId}:${doc1.doctorId}:$todayStr',
      queueStatus: QueueStatus.waiting,
      visitType: 'appointment',
      createdByStaffId: session.staffId,
      createdAt: now.subtract(const Duration(minutes: 50)).toUtc(),
      updatedAt: now.subtract(const Duration(minutes: 50)).toUtc(),
    );
    await visitRepo.createVisitAtomic(
      visit: v2,
      idempotencyKey: 'seed_visit_002',
      deviceId: session.deviceId,
      staffId: session.staffId,
    );
    await visitRepo.updateQueueStatus(
      clinicId: session.clinicId,
      visitId: v2.visitId,
      newStatus: QueueStatus.called,
      staffId: session.staffId,
      deviceId: session.deviceId,
    );
    await visitRepo.updateQueueStatus(
      clinicId: session.clinicId,
      visitId: v2.visitId,
      newStatus: QueueStatus.inConsultation,
      staffId: session.staffId,
      deviceId: session.deviceId,
    );

    final v3 = Visit(
      visitId: 'visit_demo_003',
      clinicId: session.clinicId,
      patientId: 'pat_demo_003',
      doctorId: doc1.doctorId,
      visitDateLocal: todayStr,
      checkinAt: now.subtract(const Duration(minutes: 35)),
      tokenNumber: 3,
      tokenScopeKey: '${session.clinicId}:${doc1.doctorId}:$todayStr',
      queueStatus: QueueStatus.waiting,
      visitType: 'walkin',
      createdByStaffId: session.staffId,
      createdAt: now.subtract(const Duration(minutes: 35)).toUtc(),
      updatedAt: now.subtract(const Duration(minutes: 35)).toUtc(),
    );
    await visitRepo.createVisitAtomic(
      visit: v3,
      idempotencyKey: 'seed_visit_003',
      deviceId: session.deviceId,
      staffId: session.staffId,
    );
    await visitRepo.updateQueueStatus(
      clinicId: session.clinicId,
      visitId: v3.visitId,
      newStatus: QueueStatus.called,
      staffId: session.staffId,
      deviceId: session.deviceId,
    );

    final v4 = Visit(
      visitId: 'visit_demo_004',
      clinicId: session.clinicId,
      patientId: 'pat_demo_006',
      doctorId: doc1.doctorId,
      visitDateLocal: todayStr,
      checkinAt: now.subtract(const Duration(minutes: 25)),
      tokenNumber: 4,
      tokenScopeKey: '${session.clinicId}:${doc1.doctorId}:$todayStr',
      queueStatus: QueueStatus.waiting,
      priority: QueuePriority.urgent,
      visitType: 'walkin',
      createdByStaffId: session.staffId,
      createdAt: now.subtract(const Duration(minutes: 25)).toUtc(),
      updatedAt: now.subtract(const Duration(minutes: 25)).toUtc(),
    );
    await visitRepo.createVisitAtomic(
      visit: v4,
      idempotencyKey: 'seed_visit_004',
      deviceId: session.deviceId,
      staffId: session.staffId,
    );

    final v5 = Visit(
      visitId: 'visit_demo_005',
      clinicId: session.clinicId,
      patientId: 'pat_demo_007',
      doctorId: doc2.doctorId,
      visitDateLocal: todayStr,
      checkinAt: now.subtract(const Duration(minutes: 15)),
      tokenNumber: 1,
      tokenScopeKey: '${session.clinicId}:${doc2.doctorId}:$todayStr',
      queueStatus: QueueStatus.waiting,
      priority: QueuePriority.normal,
      visitType: 'walkin',
      createdByStaffId: session.staffId,
      createdAt: now.subtract(const Duration(minutes: 15)).toUtc(),
      updatedAt: now.subtract(const Duration(minutes: 15)).toUtc(),
    );
    await visitRepo.createVisitAtomic(
      visit: v5,
      idempotencyKey: 'seed_visit_005',
      deviceId: session.deviceId,
      staffId: session.staffId,
    );

    final v6 = Visit(
      visitId: 'visit_demo_006',
      clinicId: session.clinicId,
      patientId: 'pat_demo_008',
      doctorId: doc1.doctorId,
      visitDateLocal: todayStr,
      checkinAt: now.subtract(const Duration(minutes: 10)),
      tokenNumber: 5,
      tokenScopeKey: '${session.clinicId}:${doc1.doctorId}:$todayStr',
      queueStatus: QueueStatus.waiting,
      priority: QueuePriority.emergency,
      visitType: 'walkin',
      createdByStaffId: session.staffId,
      createdAt: now.subtract(const Duration(minutes: 10)).toUtc(),
      updatedAt: now.subtract(const Duration(minutes: 10)).toUtc(),
    );
    await visitRepo.createVisitAtomic(
      visit: v6,
      idempotencyKey: 'seed_visit_006',
      deviceId: session.deviceId,
      staffId: session.staffId,
    );
    }

    // 6. Appointments (Today & Upcoming)
    final appointments = [
      Appointment(
        appointmentId: 'apt_demo_001',
        clinicId: session.clinicId,
        patientId: 'pat_demo_001',
        doctorId: doc1.doctorId,
        scheduledStartAt: DateTime(now.year, now.month, now.day, 9, 30),
        scheduledEndAt: DateTime(now.year, now.month, now.day, 9, 45),
        status: AppointmentStatus.completed,
        createdByStaffId: session.staffId,
        createdAt: now.subtract(const Duration(days: 3)).toUtc(),
        updatedAt: now.toUtc(),
      ),
      Appointment(
        appointmentId: 'apt_demo_002',
        clinicId: session.clinicId,
        patientId: 'pat_demo_002',
        doctorId: doc1.doctorId,
        scheduledStartAt: DateTime(now.year, now.month, now.day, 10, 15),
        scheduledEndAt: DateTime(now.year, now.month, now.day, 10, 30),
        status: AppointmentStatus.checkedIn,
        createdByStaffId: session.staffId,
        createdAt: now.subtract(const Duration(days: 2)).toUtc(),
        updatedAt: now.toUtc(),
      ),
      Appointment(
        appointmentId: 'apt_demo_003',
        clinicId: session.clinicId,
        patientId: 'pat_demo_003',
        doctorId: doc1.doctorId,
        scheduledStartAt: DateTime(now.year, now.month, now.day, 11, 0),
        scheduledEndAt: DateTime(now.year, now.month, now.day, 11, 15),
        status: AppointmentStatus.checkedIn,
        createdByStaffId: session.staffId,
        createdAt: now.subtract(const Duration(days: 1)).toUtc(),
        updatedAt: now.toUtc(),
      ),
      Appointment(
        appointmentId: 'apt_demo_004',
        clinicId: session.clinicId,
        patientId: 'pat_demo_004',
        doctorId: doc2.doctorId,
        scheduledStartAt: DateTime(now.year, now.month, now.day, 11, 30),
        scheduledEndAt: DateTime(now.year, now.month, now.day, 11, 45),
        status: AppointmentStatus.scheduled,
        createdByStaffId: session.staffId,
        createdAt: now.toUtc(),
        updatedAt: now.toUtc(),
      ),
      Appointment(
        appointmentId: 'apt_demo_005',
        clinicId: session.clinicId,
        patientId: 'pat_demo_005',
        doctorId: doc1.doctorId,
        scheduledStartAt: DateTime(now.year, now.month, now.day + 1, 10, 0),
        scheduledEndAt: DateTime(now.year, now.month, now.day + 1, 10, 15),
        status: AppointmentStatus.scheduled,
        createdByStaffId: session.staffId,
        createdAt: now.toUtc(),
        updatedAt: now.toUtc(),
      ),
    ];
    for (final a in appointments) {
      await appointmentRepo.saveAppointment(a);
    }

    // 7. Invoices & Payments
    final existingInvoices = await billingRepo.getInvoicesForDate(session.clinicId, todayStr);
    if (existingInvoices.isEmpty) {
      // Invoice 1: Rahul Verma — ₹300 (Paid via Cash)
      final inv1 = Invoice(
      invoiceId: 'inv_demo_001',
      clinicId: session.clinicId,
      invoiceNumber: 'INV-2026-0001',
      financialYear: '2026-2027',
      patientId: 'pat_demo_001',
      visitId: 'visit_demo_001',
      issueDateLocal: todayStr,
      status: InvoiceStatus.paid,
      subtotalMinor: 30000,
      totalMinor: 30000,
      paidMinor: 30000,
      balanceMinor: 0,
      createdByStaffId: session.staffId,
      createdAt: now.subtract(const Duration(hours: 1, minutes: 15)).toUtc(),
      updatedAt: now.subtract(const Duration(hours: 1, minutes: 10)).toUtc(),
      items: [
        InvoiceItem(
          invoiceItemId: 'item_001',
          clinicId: session.clinicId,
          invoiceId: 'inv_demo_001',
          feeIdOptional: 'fee_gen_consult',
          description: 'General OPD Consultation (Dr. Sharma)',
          unitPriceMinor: 30000,
          lineTotalMinor: 30000,
          createdAt: now.toUtc(),
        ),
      ],
    );
    final pay1 = Payment(
      paymentId: 'pay_demo_001',
      clinicId: session.clinicId,
      invoiceId: inv1.invoiceId,
      amountMinor: 30000,
      method: PaymentMethod.cash,
      cashUpiCardReferenceOptional: 'CASH-REC-101',
      receivedAt: now.subtract(const Duration(hours: 1, minutes: 10)),
      receivedByStaffId: session.staffId,
      createdAt: now.subtract(const Duration(hours: 1, minutes: 10)).toUtc(),
    );
    await billingRepo.createInvoiceAtomic(
      invoice: inv1,
      items: inv1.items,
      initialPayment: pay1,
      idempotencyKey: 'seed_inv_001',
    );

    // Invoice 2: Sunita Patel — ₹500 (Paid via UPI)
    final inv2 = Invoice(
      invoiceId: 'inv_demo_002',
      clinicId: session.clinicId,
      invoiceNumber: 'INV-2026-0002',
      financialYear: '2026-2027',
      patientId: 'pat_demo_002',
      visitId: 'visit_demo_002',
      issueDateLocal: todayStr,
      status: InvoiceStatus.paid,
      subtotalMinor: 50000,
      totalMinor: 50000,
      paidMinor: 50000,
      balanceMinor: 0,
      createdByStaffId: session.staffId,
      createdAt: now.subtract(const Duration(minutes: 40)).toUtc(),
      updatedAt: now.subtract(const Duration(minutes: 38)).toUtc(),
      items: [
        InvoiceItem(
          invoiceItemId: 'item_002',
          clinicId: session.clinicId,
          invoiceId: 'inv_demo_002',
          feeIdOptional: 'fee_special_consult',
          description: 'Consultation & Preventive Screen',
          unitPriceMinor: 50000,
          lineTotalMinor: 50000,
          createdAt: now.toUtc(),
        ),
      ],
    );
    final pay2 = Payment(
      paymentId: 'pay_demo_002',
      clinicId: session.clinicId,
      invoiceId: inv2.invoiceId,
      amountMinor: 50000,
      method: PaymentMethod.upi,
      cashUpiCardReferenceOptional: 'UPI/20260927/9847291',
      receivedAt: now.subtract(const Duration(minutes: 38)),
      receivedByStaffId: session.staffId,
      createdAt: now.subtract(const Duration(minutes: 38)).toUtc(),
    );
    await billingRepo.createInvoiceAtomic(
      invoice: inv2,
      items: inv2.items,
      initialPayment: pay2,
      idempotencyKey: 'seed_inv_002',
    );

    // Invoice 3: Amit Kumar — ₹450 (Consultation ₹300 + Dressing ₹150; Paid ₹250 UPI, Balance ₹200)
    final inv3 = Invoice(
      invoiceId: 'inv_demo_003',
      clinicId: session.clinicId,
      invoiceNumber: 'INV-2026-0003',
      financialYear: '2026-2027',
      patientId: 'pat_demo_003',
      visitId: 'visit_demo_003',
      issueDateLocal: todayStr,
      status: InvoiceStatus.partiallyPaid,
      subtotalMinor: 45000,
      totalMinor: 45000,
      paidMinor: 25000,
      balanceMinor: 20000,
      createdByStaffId: session.staffId,
      createdAt: now.subtract(const Duration(minutes: 30)).toUtc(),
      updatedAt: now.subtract(const Duration(minutes: 28)).toUtc(),
      items: [
        InvoiceItem(
          invoiceItemId: 'item_003a',
          clinicId: session.clinicId,
          invoiceId: 'inv_demo_003',
          feeIdOptional: 'fee_gen_consult',
          description: 'General OPD Consultation',
          unitPriceMinor: 30000,
          lineTotalMinor: 30000,
          createdAt: now.toUtc(),
        ),
        InvoiceItem(
          invoiceItemId: 'item_003b',
          clinicId: session.clinicId,
          invoiceId: 'inv_demo_003',
          feeIdOptional: 'fee_dressing',
          description: 'Aseptic Wound Dressing',
          unitPriceMinor: 15000,
          lineTotalMinor: 15000,
          createdAt: now.toUtc(),
        ),
      ],
    );
    final pay3 = Payment(
      paymentId: 'pay_demo_003',
      clinicId: session.clinicId,
      invoiceId: inv3.invoiceId,
      amountMinor: 25000,
      method: PaymentMethod.upi,
      cashUpiCardReferenceOptional: 'UPI/20260927/6391024',
      receivedAt: now.subtract(const Duration(minutes: 28)),
      receivedByStaffId: session.staffId,
      createdAt: now.subtract(const Duration(minutes: 28)).toUtc(),
    );
    await billingRepo.createInvoiceAtomic(
      invoice: inv3,
      items: inv3.items,
      initialPayment: pay3,
      idempotencyKey: 'seed_inv_003',
    );

    // Invoice 4: Meena Devi — ₹300 (Pending)
    final inv4 = Invoice(
      invoiceId: 'inv_demo_004',
      clinicId: session.clinicId,
      invoiceNumber: 'INV-2026-0004',
      financialYear: '2026-2027',
      patientId: 'pat_demo_006',
      visitId: 'visit_demo_004',
      issueDateLocal: todayStr,
      status: InvoiceStatus.issued,
      subtotalMinor: 30000,
      totalMinor: 30000,
      paidMinor: 0,
      balanceMinor: 30000,
      createdByStaffId: session.staffId,
      createdAt: now.subtract(const Duration(minutes: 20)).toUtc(),
      updatedAt: now.subtract(const Duration(minutes: 20)).toUtc(),
      items: [
        InvoiceItem(
          invoiceItemId: 'item_004',
          clinicId: session.clinicId,
          invoiceId: 'inv_demo_004',
          feeIdOptional: 'fee_gen_consult',
          description: 'General OPD Consultation',
          unitPriceMinor: 30000,
          lineTotalMinor: 30000,
          createdAt: now.toUtc(),
        ),
      ],
    );
      await billingRepo.createInvoiceAtomic(
        invoice: inv4,
        items: inv4.items,
        initialPayment: null,
        idempotencyKey: 'seed_inv_004',
      );
    }
    _hasSeeded = true;
  } catch (_) {
    // Do not allow demo seeding exceptions to crash or freeze the app
  } finally {
    _isSeeding = false;
  }
}
}
