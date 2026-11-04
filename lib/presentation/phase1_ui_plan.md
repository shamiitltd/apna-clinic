# Apna Clinic — Phase 1 Web UI Transformation Plan

## Objective
Elevate the existing Apna Clinic Flutter Web application into a complete, professional, dense, and production-quality clinic operations interface for desktop browsers, eliminating empty prototype layouts and establishing role-tailored workflows.

---

## Architecture & Design Tokens
1. **Design System Tokens (`lib/presentation/shared/theme/app_theme.dart`)**:
   - Palette: Deep Clinical Teal (`#0D9488`, `#0F766E`), Navy/Slate text (`#0F172A`, `#334155`), Clean card backgrounds (`#FFFFFF`), borders (`#E2E8F0`).
   - Semantic Status Badges:
     - `waiting`: Amber (`#F59E0B` / `#FEF3C7`)
     - `called`: Blue (`#2563EB` / `#DBEAFE`)
     - `inConsultation`: Teal (`#0D9488` / `#CCFBF1`)
     - `completed` / `paid`: Green (`#16A34A` / `#DCFCE7`)
     - `cancelled` / `overdue`: Red (`#DC2626` / `#FEE2E2`)
   - Standardized UI widgets: `AppCard`, `StatusBadge`, `MetricCard`, `EmptyStateWidget`, `SectionHeader`.

2. **Demo Data Seeder (`lib/application/demo/demo_data_seeder.dart`)**:
   - Seeds realistic clinic data on first launch or via demo button:
     - 2 Doctors (Dr. Rajesh Sharma, Dr. Priya Nair)
     - 8 Patients with diverse ages and conditions
     - 5 Live queue visits across all states (`waiting`, `called`, `inConsultation`, `completed`)
     - 5 Appointments for today & tomorrow
     - 4 Invoices with Cash, UPI, and pending payment states
     - Fee catalog items

3. **Application Shell & Role-Based Navigation (`lib/presentation/shared/widgets/app_scaffold.dart`)**:
   - Top Header: Clinic branding, active section breadcrumbs, role switcher dropdown (`Receptionist`, `Doctor`, `Accountant`, `Owner / Admin`), local storage readiness badge, demo seed button.
   - Sidebar NavigationRail: Filtered / emphasized based on the active role.

4. **Screen-by-Screen UI Transformation**:
   - **Screen 1 (Dashboard)**: Full operations view (Visits, Queue, Financial metrics, Today's queue live board, recent collections).
   - **Screen 2 & 3 (Patients & Registration)**: Complete data table with search, filters, details drawer, and rich registration form with duplicate phone detection.
   - **Screen 4 & 5 (Appointments & Booking)**: Schedule grid with time slots, slot conflict detection, check-in to queue action, and appointment creation modal.
   - **Screen 6 (Queue)**: Scannable live queue board with token badges, waiting duration, call controls, and consultation slip print preview.
   - **Screen 7 (Doctor Desk)**: Dedicated consultation workstation with current patient context, next in queue list, follow-up scheduler, and slip printing.
   - **Screen 8 (Billing & Day Close)**: Financial summary, itemized invoicing, fee catalog selection, multi-tender payment recording, receipt preview, and cash reconciliation modal.
   - **Screen 9 (Reports)**: Operational and financial analytics with date filtering, doctor breakdown table, and privacy-safe CSV export.
   - **Screen 10 (Settings)**: Multi-tab layout for Clinic profile, Doctors & Staff, Fee catalog, Role permissions matrix, Encrypted Backup/Restore, and Phase 2 Google Drive placeholder.

5. **Verification & Delivery**:
   - 100% test pass rate (`dart run test/run_unit_tests.dart`).
   - 0 static analysis issues (`flutter analyze .`).
   - Live Chrome verification on `http://localhost:8080/`.
   - Creation of `UI_REVIEW_REPORT.md`.
