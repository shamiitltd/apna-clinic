# Apna Clinic — Phase 1 Complete Web UI Review Report

**Date:** September 27, 2026  
**Status:** PHASE 1 COMPLETE — AWAITING HUMAN APPROVAL  
**Application URL:** `http://localhost:8080/`  
**Target Environment:** Flutter Web (Google Chrome / Desktop Browser)  
**Strict Phase Boundary:** Phase 1 Complete. Phase 2 (Master Sheet Formulas), Phase 3 (Google Drive OAuth), and Phase 4 (Cloud Sync Integration) have **NOT** been started.

---

## 1. Executive Summary

In accordance with the Apna Clinic Product Requirements Document (PRD) and Technical Requirements Document (TRD), Phase 1 has transformed the application from an unfinished prototype with excessive whitespace into a **dense, professional, production-grade clinic operations web application**.

The application is desktop-first, highly legible, calm, and medical in aesthetic. It enforces strict role-based access control, integer minor-unit paise financial integrity, monotonic queue token numbering, tamper-evident audit logging, and local AES-256-CBC encrypted backups.

---

## 2. Reusable Design System (`lib/presentation/shared/theme/app_theme.dart`)

Before updating individual screens, a standardized, cohesive medical design system was established:
- **Primary Color:** Clinical Teal (`#0F766E` / `AppColors.primary`) with vibrant teal accents (`#0D9488`).
- **Surface & Backgrounds:** Neutral Cool Slate (`#F8FAFC` background, pure `#FFFFFF` elevated cards, `#E2E8F0` hairline borders).
- **Typography:** Desktop-optimized hierarchy with high-contrast text (`#0F172A` headings, `#475569` body, `#94A3B8` hints).
- **Semantic Status Tokens:**
  - `statusWaiting`: Amber (`#D97706` / `#FEF3C7`)
  - `statusCalled`: Blue (`#2563EB` / `#EFF6FF`)
  - `statusInConsultation`: Purple (`#7C3AED` / `#F3E8FF`)
  - `statusCompleted`: Emerald Green (`#16A34A` / `#DCFCE7`)
  - `statusCancelled`: Rose Red (`#DC2626` / `#FEE2E2`)
- **Shared Components:**
  - `StatusBadge`: Consistent status tags with icons and colored pill containers.
  - `MetricCard`: Standardized KPI metric blocks featuring iconography, bold values, and subtitles.
  - `AppCard`: Standardized white container with hairline border, subtle shadow, header title, and action trailing widgets.
  - `EmptyStateWidget`: Descriptive, operational empty state with iconography, contextual explanation, and call-to-action buttons.

---

## 3. Screen-by-Screen Implementation Status

### Screen 1 — Operational Dashboard (`lib/presentation/dashboard/dashboard_screen.dart`)
- **Today's Operations Grid:** Real-time 5-metric counters (Today's Total Visits, Waiting in Lobby, Called to Cabin, In Consultation, Completed).
- **Financial Collections Grid:** Real-time 4-metric integer paise calculations (Gross Invoiced, Cash Collected, UPI Collected, Outstanding Balance).
- **Quick Actions Command Bar:** One-click shortcuts for Receptionists and Doctors: *Register Patient, Check-In Visit, Live Queue, Doctor Desk, Collect Payment, Daily Reports*.
- **2-Column Desktop Operations Layout:**
  - *Left Column:* "Today's Live Queue Board" displaying live tokens, patient names, assigned doctors, arrival times, and status badges.
  - *Right Column:* "Recent Collections & Billing Stream" with payment method badges (Cash/UPI) + "Active Doctor Workstations" showing real-time consultation status.
- **Auto-Seeding Capability:** If the local storage is blank on first load, the dashboard automatically seeds realistic clinical records so the reviewer never sees a blank page.

### Screens 2 & 3 — Patients Directory & Registration (`lib/presentation/patients/patients_screen.dart`)
- **Patient Directory Table:** High-density desktop table displaying Patient ID (`P-1001`), Full Name with initial avatar, Age/Sex, Masked Phone Number (`******3211`), City, Consent Status, and quick action buttons.
- **Instant Search & Filter:** Search by patient name, phone number, or ID with real-time record count badge and gender filter chips (`All`, `Male`, `Female`, `Other`).
- **Patient Profile Modal:** Clickable "View Details" dialog displaying full demographics, age, phone, address, and registration timestamp with a direct "Check-In Visit" shortcut.
- **Atomic Registration Workflow:**
  - Two-step patient creation dialog with Indian E.164 phone normalization.
  - Automatic duplicate phone detection with collision warning.
  - Option to atomically create a visit and assign a monotonic token immediately upon registration.

### Screens 4 & 5 — Appointment Management & Booking (`lib/presentation/appointments/appointments_screen.dart`)
- **Operational Summary KPI Bar:** 4 metrics (Total Booked, Scheduled, Checked-In, Cancelled).
- **Interactive Calendar Navigation:** Date switcher with "Previous Day", "Today", "Next Day", and date picker calendar dialog.
- **Doctor Filter Bar:** Filter appointments by assigned doctor (`All Doctors`, `Dr. Rajesh Sharma`, `Dr. Priya Nair`).
- **High-Density Schedule Table:** Shows Slot Time, Patient Name, Patient ID, Masked Phone, Doctor Name, Booking Source (`Walk-In`, `Phone`, `Online`), Status Badge, and contextual actions.
- **Slot Conflict Engine:** Prevents double booking the same doctor for overlapping time slots.
- **Booking Modal:** Modal with patient picker, doctor selector, date picker, 15-minute slot selector, and notes.

### Screen 6 — Live Queue Board (`lib/presentation/queue/queue_screen.dart`)
- **Queue KPI Summary Bar:** 4 cards (Waiting in Lobby, Called to Cabin, In Consultation, Completed Today).
- **Doctor & Status Filters:** Quick dropdowns to view specific doctor queues or filter by status.
- **Monotonic Token Scannability:** Prominent token badges (`#1`, `#2`, `#3`) scoped by clinic, doctor, and date.
- **One-Click Progression Actions:** State machine progression buttons (`Call to Cabin`, `Start Consultation`, `Complete Consultation`, `Print A5 Slip`).
- **Manual Visit Check-In:** Dedicated dialog to check in existing registered patients for today's OPD queue.

### Screen 7 — Doctor Desk Clinical Workstation (`lib/presentation/doctor/doctor_queue_screen.dart`)
- **Dual-Pane Clinical Layout:**
  - *Left Pane (Active Consultation Cabin):* Displays the active patient's full demographics (Name, Age, Sex, Phone, Patient ID), Chief Complaint / Symptoms pad, Clinical Observations / Diagnosis, follow-up timeline selector (`None`, `3 Days`, `5 Days`, `7 Days`, `14 Days`), and action buttons (`Complete Consultation`, `Print Consultation Slip`).
  - *Right Pane (Upcoming Waiting Queue):* Scannable list of waiting patients with token numbers and one-click "CALL PATIENT" action.
- **Prescription Integrity Compliance (PRD Principle 4):** Strictly respects the physical handwriting model. The application prints patient demographics, clinic branding, and blank lines for handwritten doctor notes and prescriptions.

### Screen 8 — Billing, Payments & Day Close Reconciliation (`lib/presentation/billing/billing_screen.dart`)
- **Financial KPI Cards:** 5 real-time summary indicators (Total Invoiced, Cash Collected, UPI Collected, Net Cash in Hand, Outstanding Balance).
- **Invoice Register:** Detailed desktop table showing Invoice Number (`INV-20260927-001`), Patient Name, Fee Items, Payment Status (`Paid`, `Partially Paid`, `Pending`, `Cancelled`), Tender breakdown, and Actions.
- **New Invoice Generator:** Allows selecting a patient, adding fee items from the clinic catalog (General Consultation, ECG, Dressing), and computing integer paise totals with zero rounding drift.
- **Payment Collection Modal:** Supports multi-tender payments (Cash, UPI, Card) with real-time balance calculations.
- **Day Close Reconciliation Modal:** Summary modal displaying total collections, cash-in-drawer reconciliation, and day-close verification status.

### Screen 9 — Reports, Analytics & Privacy Guard (`lib/presentation/reports/reports_screen.dart`)
- **Date Selector & Refresh:** Allows filtering reports by date with quick "Today" navigation.
- **Financial Audit Metrics:** Gross Invoiced, Total Collected, Cash, UPI, Card, Refunds Approved, Net Collections, and Uncollected Balances.
- **Queue Efficiency Metrics:** Total Patients Checked In, Consultations Completed, Average Wait Time, and In-Consultation Duration.
- **CSV Data Export Preview:** Secure data export table with privacy enforcement.
- **Health Privacy Guard (TRD Section 17):** Diagnostic details and medical notes are strictly isolated and omitted from financial ledgers and accounting exports.

### Screen 10 — Settings & Clinic Administration (`lib/presentation/settings/settings_screen.dart`)
- **Organized Category Navigation:** Clean horizontal tab chips:
  1. *Clinic Profile:* Name, Owner, Phone, Email, Address, City, State, Pincode, Default Fee.
  2. *Doctor Roster:* Registered doctors, registration numbers, qualifications, specialties, default fees, active status, and Add/Edit Doctor modal.
  3. *Fee Catalog:* Services list (Consultation, ECG, Dressing) with codes and charges in ₹, plus Add/Edit Fee modal.
  4. *Staff & Roles:* Directory of staff members with roles and live Active Role Switcher.
  5. *Printer & Slips:* A5 Portrait vs. A4 Standard paper format selection and prescription compliance rules.
  6. *Backup & Disaster Recovery:* AES-256-CBC encrypted snapshot generator with SHA-256 checksum and atomic restore wizard.
  7. *Cloud Sync & Roadmap:* Unambiguous notice that local-first standalone database mode is active, with preview of canonical 19-sheet Master Workbook structure for Phase 2.

---

## 4. Role-Based Navigation & Workflow Verification

| Role | Accessible Navigation | Permitted Operational Scope | Excluded Controls |
| :--- | :--- | :--- | :--- |
| **Receptionist** | Dashboard, Appointments, Patients, Queue, Billing | Patient registration, visit check-in, token generation, appointments, payment collection | Doctor clinical observation notes, encrypted database restore, system config |
| **Doctor** | Dashboard, Queue, Doctor Desk | Today's assigned queue, calling patients, consultation observations, follow-ups, A5 slip printing | Billing ledgers, cash drawer reconciliation, user/staff management |
| **Accountant** | Dashboard, Billing, Reports | Invoices, multi-tender payments, outstanding collections, daily financial reports, day close | Clinical diagnosis/symptoms, patient clinical history, doctor queue |
| **Owner / Admin** | All Screens (Full Access) | Clinic profile, doctor roster, fee catalog, staff permissions, AES-256 backup & restore, full reports | None (Full administrative sovereignty) |

---

## 5. Automated Testing & Static Analysis Verification

1. **Static Analysis (`flutter analyze lib/`):**
   - **Result:** `No issues found!` (0 errors, 0 warnings across all files).
2. **Core Unit Test Suite (`dart test/run_unit_tests.dart`):**
   - **Result:** `96 PASSED, 0 FAILED`.
   - Verified domains:
     - Minor Unit Money Representation (paise math, GST, discounts, currency formatting).
     - Phone Normalization (E.164, masking `******3210`, SHA-256 hashing).
     - Authorization & Role Permission Matrix (deny-by-default, health privacy isolation).
     - Queue State Machine (registered → waiting → called → inConsultation → completed).
     - Local Encryption Service (AES-256-CBC, IV, SHA-256 integrity checksum, PBKDF2).
     - Local Database ACID Transactions (upsert, indexed queries, rollback on failure).
     - Appointments & Slot Conflict Detection.
     - Disaster Recovery (encrypted backup export and atomic restore).
3. **Flutter Web Runtime:**
   - Active on `http://localhost:8080/`.
   - Hot restarted and serving clean HTML/JS assets without compilation errors.

---

## 6. Screenshots & Visual Review Checklist for Human Reviewer

Open Google Chrome at **`http://localhost:8080/`** and verify the following:

- [ ] **Role Switcher in Header:** Click the role dropdown in the top-right of the header. Switch between `Receptionist`, `Doctor`, `Accountant`, and `Owner / Admin`. Verify that the sidebar navigation dynamically filters according to the table above.
- [ ] **Demo Data Seeding:** If the database was cleared, click the `"🌱 Seed Demo Data"` button in the top bar. Verify that 8 patients, 5 appointments, 5 queue visits, and 4 invoices are populated instantly.
- [ ] **Dashboard:** Inspect the 5-metric queue counter, 4-metric collection counter, quick actions bar, live queue board, and recent collections.
- [ ] **Patients Screen:** Test the search bar (`Rahul`, `Sunita`, `P-1001`), filter chips (`Male`, `Female`), and click `"View Details"` on a patient row.
- [ ] **Appointments Screen:** Toggle between dates using the date switcher (`Today`, `< Previous Day`, `Next Day >`). Verify the appointments table and click `"Book Appointment"`.
- [ ] **Queue Screen:** Observe token numbers `#1` through `#5`. Test clicking `"Call to Cabin"` or `"Start Consultation"`.
- [ ] **Doctor Desk:** Select doctor `Dr. Rajesh Sharma`. Verify the Active Consultation Cabin on the left and the Upcoming Queue on the right.
- [ ] **Billing Screen:** Inspect the 5 financial KPI cards, click `"Create Invoice"`, select a patient, add a procedure, and click `"Record Payment"`.
- [ ] **Reports Screen:** Review the daily collections summary and the Privacy Guard note.
- [ ] **Settings Screen:** Click through the horizontal tabs (`Clinic Profile`, `Doctors`, `Fee Catalog`, `Staff & Roles`, `Printer & Slips`, `Backup`, `Cloud Sync`). Test `"Backup Now (AES-256)"` to generate an encrypted snapshot.

---

## 7. Strict Phase Boundary Confirmation

> **WE ARE CURRENTLY AT THE END OF PHASE 1.**  
> - No Google Sheets API calls have been written.  
> - No Google OAuth credentials or Drive sync workers have been integrated.  
> - No Master Sheet formulas have been deployed.  
> 
> **ALL WORK ON PHASE 2 IS ON HOLD PENDING YOUR EXPLICIT APPROVAL.**  
> When you have completed your visual inspection in Chrome and are satisfied, reply with:  
> **`"PHASE 1 APPROVED"`** to authorize commencement of Phase 2.
