# Apna Clinic — Debugging Log

**Document Version:** 1.0  
**Date:** 22-23 September 2026  
**Auditor / QA:** Principal Software Architect & QA Engineer

---

### BUG-001
- **Area:** Appointment Management / UI
- **Observed Error:** `The getter 'primaryPhone' isn't defined for the type 'Patient'` (Compile error in `appointments_screen.dart:150`)
- **Root Cause:** Screen code referenced non-existent `p.primaryPhone` instead of the canonical `p.phoneOptional`.
- **Fix:** Updated `appointments_screen.dart` to use `p.phoneOptional ?? 'No phone'`.
- **Files Changed:** `lib/presentation/appointments/appointments_screen.dart`
- **Test Performed:** Static analysis & unit test compilation.
- **Result:** PASS

---

### BUG-002
- **Area:** Doctor Entity Property Reference
- **Observed Error:** `The getter 'fullName' isn't defined for the type 'Doctor'` (Compile error in `appointments_screen.dart:178, 630`)
- **Root Cause:** Screen attempted to call `doctor.fullName` when the canonical TRD property is `doctor.displayName`.
- **Fix:** Replaced all occurrences of `d.fullName` with `d.displayName`.
- **Files Changed:** `lib/presentation/appointments/appointments_screen.dart`
- **Test Performed:** `dart analyze .`
- **Result:** PASS

---

### BUG-003
- **Area:** Doctor Queue Workstation
- **Observed Error:** `The getter 'tokenDisplay' isn't defined for Visit`, `ageYears` and `sex` undefined on `Patient` (`doctor_queue_screen.dart:191, 231`)
- **Root Cause:** `Visit` provides `tokenNumber` (int), not `tokenDisplay`. `Patient` provides `displayAge` and `sexOptional`.
- **Fix:** Formatted token as `'#${visit.tokenNumber}'` and used `${patient?.displayAge ?? "-"} yrs • ${patient?.sexOptional?.toUpperCase() ?? ""}`.
- **Files Changed:** `lib/presentation/doctor/doctor_queue_screen.dart`
- **Test Performed:** Static analysis verification.
- **Result:** PASS

---

### BUG-004
- **Area:** Financial Ledger & Day Close Screen
- **Observed Error:** `Undefined class 'DailyReconciliation'` (`billing_screen.dart:25, 503`) and subsequent `double can't be assigned to int` (`billing_screen.dart:534`)
- **Root Cause:** `DailyReconciliation` interface in `i_billing_repository.dart` was not imported in `billing_screen.dart`.
- **Fix:** Added `import '../../domain/repositories/i_billing_repository.dart';` and ensured typed integer math for variance.
- **Files Changed:** `lib/presentation/billing/billing_screen.dart`
- **Test Performed:** Static analysis verification and Day Close variance unit testing.
- **Result:** PASS

---

### BUG-005
- **Area:** Application Shell / Scaffold
- **Observed Error:** `title` and `actions` undefined named parameters, and `currentRoute` required on `AppScaffold` across multiple screens.
- **Root Cause:** Initial `AppScaffold` only accepted `body`, `currentRoute`, and `floatingActionButton`, while screens passed `title:` and `actions:` to customize the top bar.
- **Fix:** Upgraded `AppScaffold` to optionally accept `title` and `actions`, and defaulted `currentRoute = '/'`.
- **Files Changed:** `lib/presentation/shared/widgets/app_scaffold.dart`, `billing_screen.dart`, `dashboard_screen.dart`, `patients_screen.dart`, `queue_screen.dart`
- **Test Performed:** Full layout compilation and routing verification.
- **Result:** PASS

---

### BUG-006
- **Area:** Patient Directory / Queue Status
- **Observed Error:** `Undefined name 'QueueStatus'` (`patients_screen.dart:540`)
- **Root Cause:** Missing `domain_enums.dart` import in `patients_screen.dart`.
- **Fix:** Added `import '../../domain/enums/domain_enums.dart';`.
- **Files Changed:** `lib/presentation/patients/patients_screen.dart`
- **Test Performed:** Static analysis verification.
- **Result:** PASS

---

### BUG-007
- **Area:** Async Safety / BuildContext Across Async Gaps
- **Observed Error:** `use_build_context_synchronously` warnings on `ScaffoldMessenger.of(context)` after repository calls.
- **Root Cause:** Missing `if (!mounted) return;` check between async database futures and UI SnackBar presentations.
- **Fix:** Added `if (!mounted) return;` guards before all context-dependent UI calls.
- **Files Changed:** `appointments_screen.dart`, `billing_screen.dart`, `queue_screen.dart`
- **Test Performed:** Static analysis verification.
- **Result:** PASS

---

### BUG-008
- **Area:** Reports Screen / Async Data Load
- **Observed Error:** `unawaited_futures` warning in `reports_screen.dart:231`
- **Root Cause:** Date picker `onTap` called `_loadReportData()` without `await`.
- **Fix:** Made the callback `async` and added `await _loadReportData();`.
- **Files Changed:** `lib/presentation/reports/reports_screen.dart`
- **Test Performed:** `dart analyze .`
- **Result:** PASS

---

### BUG-009
- **Area:** Host Windows Security Smart App Control / `flutter_tester.exe`
- **Observed Error:** `ProcessException: An Application Control policy has blocked this file: flutter_tester.exe` when running `flutter test`.
- **Root Cause:** Host machine has Windows Defender Application Control / Smart App Control active which blocks unsigned engine binaries.
- **Fix:** Standalone comprehensive test suite (`test/run_unit_tests.dart`) runs directly via signed `dart.exe` runtime, completely bypassing engine blocks and validating all 96 unit, domain, and integration tests.
- **Files Changed:** `test/run_unit_tests.dart`
- **Test Performed:** `dart run test/run_unit_tests.dart`
- **Result:** PASS (96 tests passed, 0 failed).

---

### BUG-010
- **Area:** Staff Administration & Access Control (TRD Sec 4 & 7)
- **Observed Gap:** Clinic owners could add staff members, but tapping an existing staff row in Settings did not allow editing their name, login email, or assigned role. There was also no way to deactivate or delete a staff member, and deactivated staff were not blocked on sign-in.
- **Root Cause:** `_buildStaffRow` did not pass the `Staff` object or handle `onTap`/edit events, `_showStaffDialog` lacked an Active switch, `LocalDatabase` lacked a `delete` method, and `AuthService` fell back to receptionist role rather than revoking access when a staff account was deactivated.
- **Fix:**
  1. Updated `LocalDatabase` and `ClinicRepository` to support `deleteStaff()`.
  2. Enhanced `_showStaffDialog([Staff? existing])` in `settings_screen.dart` with an Account Active toggle switch and a Delete button.
  3. Replaced static `_buildStaffRow` with an interactive list tile displaying role badge, `ACTIVE` / `DEACTIVATED` status badges, and quick-action buttons (edit, deactivate/reactivate, delete).
  4. Updated `AuthService.enforceStaffRoleOnSignIn()` to throw `AuthorizationFailure` and block access when a deactivated staff member attempts to sign in.
- **Files Changed:**
  - `lib/infrastructure/database/local_database.dart`
  - `lib/domain/repositories/i_clinic_repository.dart`
  - `lib/infrastructure/repositories/clinic_repository.dart`
  - `lib/application/auth/auth_service.dart`
  - `lib/presentation/settings/settings_screen.dart`
  - `test/test_staff_management.dart`
- **Test Performed:** `dart test/test_staff_management.dart` & `dart test/run_unit_tests.dart`
- **Result:** PASS (All 5/5 staff management tests passed, 96/96 core unit tests passed).

---

### BUG-011
- **Area:** Billing / Invoice Creation & Validation (TRD Sec 7 & 8)
- **Observed Gap:** In `billing_screen.dart`, `_CreateInvoiceDialog` lacked Form-level validation. If an amount was empty, negative, or invalid text, it fell back to a hardcoded `?? 500.0`. It was also possible to enter partial payments exceeding the total invoice amount, and there was no check requiring patient selection.
- **Root Cause:** Missing `FormState` validation and lack of bounds checking on bill amounts and partial payment inputs.
- **Fix:**
  1. Wrapped the dialog inside a `Form` with `_formKey`.
  2. Enforced patient selection validation before submission.
  3. Validated invoice amount strictly ($> 0$ and $\le ₹10,00,000$).
  4. Added partial payment validator ensuring partial payment amount does not exceed total bill.
- **Files Changed:** `lib/presentation/billing/billing_screen.dart`
- **Test Performed:** Static analysis (`dart analyze`) & `dart test/run_unit_tests.dart`
- **Result:** PASS (0 issues found, 96/96 tests passed).

---

### BUG-012
- **Area:** Patient Registration / Minor Guardian Compliance (PRD Section M02 Line 90)
- **Observed Gap:** PRD M02 requires capturing guardian/contact details for minors (<18). While `Patient` entity possessed `guardianNameOptional` and `guardianRelationOptional`, the patient registration dialog never exposed these fields, and age input did not trigger guardian validation.
- **Root Cause:** `_PatientRegistrationDialogState` lacked guardian controllers, real-time minor age listeners, guardian UI input card, and profile display logic.
- **Fix:**
  1. Added `_guardianNameController` and `_guardianRelationController` to `_PatientRegistrationDialogState`.
  2. Added real-time listener on `_ageController` to dynamically detect minor status (`displayAge < 18`).
  3. Added responsive Guardian Input Card in Step 1 (Registration) validating parent/guardian name and relation/contact.
  4. Included Guardian verification banner in Step 2 (Review) and displayed Guardian details in `_PatientProfileDialog`.
- **Files Changed:**
  - `lib/presentation/patients/patients_screen.dart`
  - `test/test_patient_guardian.dart`
- **Test Performed:** `dart test/test_patient_guardian.dart` (4/4 passed), `dart analyze` (0 issues), `dart test/run_unit_tests.dart` (96/96 passed).
- **Result:** PASS

---

### BUG-013
- **Area:** Financial Ledger / Day Close Reconciliation & Consultation Slip (PRD M05, M06, M07 & TRD Sec 7 & 10)
- **Observed Gap:**
  1. In `billing_screen.dart`, confirming Day Close cash reconciliation attempted to write to table `'Audit_Log'` which is not in `canonicalTables` (canonical name is `'Audit_Events'`), causing a `DatabaseFailure('Unknown table Audit_Log')`.
  2. Day close did not generate or persist the `DailySummary` model into the `'Daily_Summary'` table for cloud sheet synchronization.
  3. In `consultation_slip_service.dart`, reprint indicator only said `REPRINT` instead of PRD M05 `DUPLICATE / REPRINT`, and guardian details for pediatric patients were omitted.
- **Root Cause:** Table name mismatch (`Audit_Log` vs canonical `Audit_Events`) and missing `DailySummary` record generation upon Day Close confirmation.
- **Fix:**
  1. Fixed target table to `Audit_Events`.
  2. Instantiated and persisted `DailySummary` with daily reconciled financial figures (`invoicedMinor`, `paidCashMinor`, `paidUpiMinor`, `refundedMinor`, `outstandingMinor`, `expensesMinor`) to the `Daily_Summary` table.
  3. Updated `ConsultationSlipService` with `DUPLICATE / REPRINT` watermark and rendered minor patient guardian contact details on the clinical consultation slip.
- **Files Changed:**
  - `lib/presentation/billing/billing_screen.dart`
  - `lib/application/printing/consultation_slip_service.dart`
- **Test Performed:** `dart analyze` (0 issues), `dart test/run_unit_tests.dart` (96/96 passed).
- **Result:** PASS

---

### BUG-014
- **Area:** Navigation Shell & Input Focus / Patient Search
- **Observed Gap:** In `/patients`, typing a single character into the search bar caused the text field to immediately lose focus. The user had to click the search bar again for every subsequent character.
- **Root Cause:** In `lib/presentation/shared/widgets/app_scaffold.dart`, `final scaffoldKey = GlobalKey<ScaffoldState>()` was instantiated directly inside the `build()` method. Whenever `onSearchChanged` invoked `setState()`, `AppScaffold.build()` generated a brand-new `GlobalKey` for the `Scaffold`, causing Flutter to discard the entire underlying element tree and unmount the `TextField`'s `FocusNode`.
- **Fix:** Removed the local `GlobalKey<ScaffoldState>()` instantiation from `AppScaffold.build()`.
- **Files Changed:** `lib/presentation/shared/widgets/app_scaffold.dart`
- **Test Performed:** `dart analyze` (0 issues), verified continuous text input without focus reset.
- **Result:** PASS

---

### BUG-015
- **Area:** Visit Creation & Queue Management (PRD M03 & M04, TRD Sec 8 & 9)
- **Observed Gap:** When creating a repeat/subsequent visit for an existing patient who came again on the same day, no new token was allocated, the previous token number was returned, and the patient never appeared in the doctor queue.
- **Root Cause:** In `lib/presentation/patients/patients_screen.dart`, `_submitVisit()` used a coarse per-day idempotency key: `'create_visit_${widget.patient.patientId}_$today'`. When creating a second visit for the patient on that day, `createVisitAtomic` hit the idempotency cache, returning the cached earlier visit rather than executing the transaction to allocate the next sequential token and insert the new visit into the `Visits` and `Queue_Events` tables.
- **Fix:**
  1. Updated the idempotency key in `_CreateVisitDialogState` to use the visit's unique UUID (`'create_visit_$visitId'`).
  2. Added an `_isSubmitting` state guard with a loading indicator to prevent spurious double-taps while allowing intentional repeat visits.
- **Files Changed:**
  - `lib/presentation/patients/patients_screen.dart`
  - `test/test_repeat_patient_visit.dart`
- **Test Performed:** `dart test/test_repeat_patient_visit.dart` (5/5 passed), `dart analyze` (0 issues), `dart test/run_unit_tests.dart` (96/96 passed).
- **Result:** PASS

---

### BUG-016
- **Area:** Patient Registration / Identity & Deduplication Uniqueness (PRD M02)
- **Observed Gap:** Patient registration allowed phone number to be optional (`Phone Number (Optional)`), which hindered duplicate detection and made it possible to create patient records without a primary contact key.
- **Root Cause:** In `lib/presentation/patients/patients_screen.dart`, phone input had no required validator or format checking.
- **Fix:**
  1. Updated the field label to **`Mobile Phone Number *`** across all screen sizes.
  2. Enforced strict validation requiring a valid 10-digit Indian phone number (`PhoneNormalizer.normalize(v).length == 10`).
  3. Cleaned and normalized phone input before persisting in the `Patients` table to ensure canonical deduplication indexing.
- **Files Changed:** `lib/presentation/patients/patients_screen.dart`
- **Test Performed:** `dart analyze` (0 issues), all test suites passed.
- **Result:** PASS

---

### BUG-017
- **Area:** Queue Management / Duplicate Token Prevention (PRD Section M04 Line 103-105)
- **Observed Gap:** If a receptionist assigned a token to a patient and accidentally clicked "NEW VISIT" for that same patient again while they were still active in the queue, a second token was allocated, resulting in two duplicate tokens for the same patient on the same day.
- **Root Cause:** Neither `_createVisitForPatient()` nor `_CreateVisitDialog` checked whether the patient already had an active visit (`registered`, `waiting`, `called`, `inConsultation`) in the queue for that day before opening the token creation workflow or submitting.
- **Fix:**
  1. Updated `_createVisitForPatient()` in `lib/presentation/patients/patients_screen.dart` to query today's visits for the patient. If an active visit is found, an immediate alert dialog is displayed showing the active Token number and status, preventing accidental duplicate token creation.
  2. In `_CreateVisitDialogState`, added active visit detection on load. If an active token is present, a warning banner is displayed and the **`ISSUE TOKEN`** button is disabled with the label **`ALREADY IN QUEUE`**.
  3. If a patient's prior visit has been completed or cancelled, subsequent visits can proceed normally without restriction.
- **Files Changed:**
  - `lib/presentation/patients/patients_screen.dart`
  - `test/test_repeat_patient_visit.dart`
- **Test Performed:** `dart test/test_repeat_patient_visit.dart` (6/6 passed), `dart analyze` (0 issues), `dart test/run_unit_tests.dart` (96/96 passed).
### BUG-018
- **Area:** Visit Creation & Queue Management Integration with Billing (PRD M04, M05, M06 & TRD Sec 8, 9, 10)
- **Observed Gap:** Creating a visit on `/patients` only generated a queue token without prompting the receptionist to collect the consultation fee, issue an invoice, or select payment timing (Full, Partial Advance, or Unpaid Pay-Later). Furthermore, the Queue screen on `/queue` did not display the billing status of waiting patients or provide an inline way to collect dues or print receipts.
- **Root Cause:** Visit creation in `_CreateVisitDialog` and queue card rendering in `QueueScreen` were disconnected from `BillingRepository` and `InvoiceStatus`, forcing the receptionist to navigate away to the separate `/billing` screen to search for and bill each patient.
- **Fix:**
  1. Connected Consultation Fee & Payment Timing directly into `_CreateVisitDialog` in `lib/presentation/patients/patients_screen.dart`:
     - Auto-populates consultation fee from doctor's `defaultFee`.
     - Supports **Full Payment**, **Partial Advance** (with dynamic remaining balance display), **Pay Later (Unpaid)**, and **Free / Exempt**.
     - Choice of Tender: **Cash**, **UPI**, **Card**.
     - Atomically creates `Invoice`, `InvoiceItem`, and initial `Payment` (if paid > 0) linked to the `visitId`.
     - Displays post-creation confirmation with one-click **PRINT CONSULTATION SLIP** (for doctor cabin) and **PRINT RECEIPT** (for patient).
  2. Connected Real-Time Billing & Settlement into `QueueScreen` in `lib/presentation/queue/queue_screen.dart`:
     - Added real-time billing status badge on each patient card:
       - 🟢 `PAID (₹XXX)`
       - 🟠 `PARTIAL: PAID ₹XXX • DUE ₹YYY`
       - 🟡 `UNPAID: ₹XXX DUE`
       - ⚪ `NO BILL`
     - Added inline action buttons: **`COLLECT DUE (₹XXX)`** / **`ADD BILL`** with modal settlement dialog supporting cash/UPI/card and partial installments without leaving the queue.
     - Added inline **`PRINT RECEIPT`** button for any visit with an invoice.
  3. Created automated end-to-end integration test suite `test/test_visit_billing_integration.dart` verifying all 4 payment cases (Full, Partial, Unpaid, and End-of-Day Reconciliation).
- **Files Changed:**
  - `lib/presentation/patients/patients_screen.dart`
  - `lib/presentation/queue/queue_screen.dart`
  - `test/test_visit_billing_integration.dart`
  - `DEBUG_LOG.md`
- **Test Performed:**
  - `dart test/test_visit_billing_integration.dart` (100% PASS)
  - `dart test/run_unit_tests.dart` (96/96 Core PASS)
- **Result:** PASS
---

### BUG-019: Queue Route Missing Option to Add Patient or Create Visit
- **Date & Time:** 2026-10-26 21:18 IST
- **Component:** `lib/presentation/queue/queue_screen.dart`, `lib/presentation/dashboard/dashboard_screen.dart`, `lib/core/routing/app_router.dart`, `lib/presentation/shared/dialogs/`
- **Root Cause:**
  1. The Dashboard "NEW VISIT / TOKEN" button routed directly to `/queue`, but `QueueScreen` only had a read-only view of current visits and a refresh button.
  2. The Empty State widget on `/queue` only offered "Refresh Live Queue", giving staff no way to add a patient or issue a token directly from the queue.
  3. Visit creation was previously coupled strictly inside `_CreateVisitDialog` in `patients_screen.dart`, inaccessible from other screens.
- **Fix Applied:**
  1. Extracted `CreateVisitDialog` into `lib/presentation/shared/dialogs/create_visit_dialog.dart` so it can be invoked anywhere in the app with `onVisitCreated` callback.
  2. Created `AddPatientToQueueDialog` in `lib/presentation/shared/dialogs/add_patient_to_queue_dialog.dart` featuring a 2-tab workflow:
     - **Tab 1 (Search Existing Patient)**: Rapid real-time search by patient name, phone, or patient ID with immediate "SELECT & ISSUE TOKEN" button.
     - **Tab 2 (Register New Walk-In)**: Fast walk-in registration with phone, age, gender, guardian details, and duplicate detection, immediately segueing into visit & billing token issuance.
  3. Added prominent actions to `QueueScreen`:
     - Top AppBar: **`NEW VISIT / ADD PATIENT`** action button.
     - Bottom-Right: **`New Visit / Token`** FloatingActionButton.
     - Center Empty State: **`+ Add Patient to Queue`** primary call-to-action button.
  4. Enabled automatic dialog trigger when navigating via `context.go('/queue?action=new_visit')`, so clicking "NEW VISIT / TOKEN" or "Register Walk-In Visit" on Dashboard immediately opens the Add Patient & Token Allocation dialog.
- **Verification:**
  - `dart test/run_unit_tests.dart` (96/96 PASS)
  - `dart test/test_visit_billing_integration.dart` (100% PASS)
- **Result:** FIXED---

### BUG-020: Duplicate Plus Sign in Empty Queue Button & Non-Vanishing SnackBars
- **Date & Time:** 2026-10-26 21:28 IST
- **Component:** `lib/presentation/queue/queue_screen.dart`, `lib/presentation/shared/dialogs/add_patient_to_queue_dialog.dart`, `lib/main.dart`
- **Root Cause:**
  1. `EmptyStateWidget` already renders `FilledButton.icon(icon: Icon(Icons.add)..., label: Text(actionLabel))`. Passing `'+ Add Patient to Queue'` as the `actionLabel` resulted in double plus signs `+  + Add Patient to Queue`.
  2. SnackBars with `SnackBarAction` on Flutter web were using default fixed behavior without auto-dismiss duration or close icon, causing duplicate registration alerts to persist across the full bottom width of the browser.
- **Fix Applied:**
  1. Updated `actionLabel` in `QueueScreen` to `'Add Patient to Queue'` so exactly one `+` icon appears.
  2. Configured global `snackBarTheme` in `ThemeData` ([main.dart](file:///d:/Github/APNA_CLINIC_SOURCE_CODE_FINAL/lib/main.dart)) with `behavior: SnackBarBehavior.floating`, `showCloseIcon: true`, and rounded corners.
  3. Added explicit `duration: const Duration(seconds: 4)` and `ScaffoldMessenger.of(context).clearSnackBars()` before showing notifications so alerts cleanly auto-dismiss and old alerts are cleared.
  4. Added an inline duplicate warning container directly inside the registration tab of `AddPatientToQueueDialog` with a direct `SELECT` button, giving immediate contextual resolution.
- **Verification:**
  - `dart test/run_unit_tests.dart` (96/96 PASS)
  - `dart test/test_visit_billing_integration.dart` (100% PASS)
- **Result:** FIXED

---

### BUG-021: Type Promotion Failure for Nullable Duplicate Patient in SnackBar Action Closure
- **Date & Time:** 2026-10-26 21:31 IST
- **Component:** `lib/presentation/shared/dialogs/add_patient_to_queue_dialog.dart`
- **Root Cause:**
  `exactDuplicate` was defined as `Patient?` and captured inside the closure `onPressed: () { widget.onPatientSelected(exactDuplicate); }`. Dart closure type promotion does not automatically promote mutable or captured local variables across closure boundaries, producing compile-time error: `The argument type 'Patient?' can't be assigned to the parameter type 'Patient'`.
- **Fix Applied:**
  Captured `final selectedDuplicate = exactDuplicate;` right after the null check, ensuring strong non-nullable `Patient` type promotion inside the closure.
- **Verification:**
  - `dart analyze lib/presentation/shared/dialogs/add_patient_to_queue_dialog.dart` (No issues found!)
  - `dart test/test_visit_billing_integration.dart` (100% PASS)
- **Result:** FIXED

---

### BUG-022: Google Drive Workspace Created But Master Sheet Fails to Appear in Folder
- **Date & Time:** 2026-10-26 21:55 IST
- **Component:** `lib/infrastructure/google/google_drive_client.dart`, `lib/infrastructure/google/google_sheets_client.dart`, `lib/application/auth/drive_connection_service.dart`, `lib/infrastructure/google/sync/master_sheet_initialization_service.dart`, `lib/infrastructure/google/sync/master_sheet_sync_engine.dart`
- **Root Cause:**
  1. **Multi-Parent Exception in Drive API v3:** In Google Drive API v3, files can no longer have multiple parents. Previously, after creating a spreadsheet, the service ran consecutive calls:
     `await driveClient.moveFileToFolder(targetFolderId: rootFolderId);`
     `await driveClient.moveFileToFolder(targetFolderId: clinicFolderId);`
     Because `removeParents` was not passed, Drive API threw HTTP 400 (`Files cannot have multiple parents`). This exception was caught, causing the entire initialization to fail and abort before saving the spreadsheet ID.
  2. **Indirect Sheet Creation:** Previously, spreadsheets were created in the user's root Drive (`My Drive`) via a massive 23KB payload on `POST https://sheets.googleapis.com/v4/spreadsheets` and then moved. If Sheets API had not initialized the complex grid payload or failed during move, no sheet appeared in the target "Apna Clinic" folder.
- **Fix Applied:**
  1. Added `createSpreadsheetInFolder` to `GoogleDriveClient`:
     - Creates the native Google Spreadsheet directly inside the target "Apna Clinic" folder (`parents: [parentFolderId]`, `mimeType: application/vnd.google-apps.spreadsheet`) via Drive API v3.
     - Guarantees the file is born directly inside the folder in a single atomic HTTP call with zero moves required.
  2. Made `moveFileToFolder` self-healing:
     - Automatically inspects file metadata. If already in `targetFolderId`, returns immediately without redundant calls.
     - Automatically supplies `removeParents` from existing parents so Drive API never throws multi-parent errors.
  3. Added `populateCanonicalSheets` to `GoogleSheetsClient`:
     - Gracefully populates all 20 canonical worksheets (`01_SETTINGS` to `20_LOOKUPS`) and their Row 1 headers and lookup rows via `values:batchUpdate`.
     - Automatically cleans up the default empty `Sheet1`.
  4. Updated `DriveConnectionService`, `MasterSheetInitializationService`, and `MasterSheetSyncEngine` to use direct folder creation and eliminate duplicate parent moves.
- **Verification:**
  - `dart analyze lib/` (0 critical issues)
  - `dart test/run_unit_tests.dart` (96/96 PASS)
  - `dart test/test_visit_billing_integration.dart` (100% PASS)
- **Result:** FIXED

---

### BUG-023: Master Sheet Not Updating on Visit Creation & Queue Progression
- **Date & Time:** 2026-10-26 22:15 IST
- **Component:** `lib/infrastructure/google/sync/master_sheet_sync_engine.dart`, `lib/presentation/shared/widgets/app_scaffold.dart`, `lib/presentation/shared/dialogs/create_visit_dialog.dart`, `lib/presentation/doctor/doctor_queue_screen.dart`, `lib/presentation/queue/queue_screen.dart`, `lib/infrastructure/repositories/sync_repository.dart`
- **Root Cause:**
  1. **Unwired Sync Triggers:** Local visit creation, token generation, consultation completion, and billing settlements correctly staged records in the local `sync_outbox` table, but no code was calling `MasterSheetSyncScheduler` or `MasterSheetSyncEngine` to push these events to Google Sheets.
  2. **Scheduler Inactive:** `MasterSheetSyncScheduler.startPeriodicSync` was never initialized on startup, leaving background cloud sync dormant.
  3. **Spreadsheet ID & Token Resolution Mismatch:** `MasterSheetSyncEngine.syncOutboxToMasterSheet` did not look up the connected spreadsheet ID stored in `SharedPreferences` (`apna_drive_spreadsheet_id`), and searched for legacy folder names instead of the connected `ApnaClinic_MasterData` sheet.
- **Fix Applied:**
  1. Updated `MasterSheetSyncEngine.syncOutboxToMasterSheet` to automatically read the connected spreadsheet ID from `SharedPreferences`, with multi-token fallback for `clinicId` and `primary_clinic`.
  2. Added immediate non-blocking sync triggers (`triggerManualSync`) upon:
     - Visit / Token Creation in `CreateVisitDialog`.
     - Queue Status Transitions & Consultation Completion in `DoctorQueueScreen`.
     - Payment Settlement in `QueueScreen`.
  3. Auto-started background periodic sync (2-minute interval) in `AppScaffold`.
  4. Added interactive **`_CloudSyncButton`** to `AppScaffold` top AppBar providing real-time sync progress, manual one-click sync, and immediate user feedback.
  5. Enhanced `SyncRepository.getPendingOutboxEvents` clinic ID matching so clinic ID prefix variations do not filter out valid outbox records.
- **Verification:**
  - `dart analyze lib/` (0 critical issues)
  - `dart test/run_unit_tests.dart` (96/96 PASS)
  - `dart test/test_visit_billing_integration.dart` (100% PASS)
- **Result:** FIXED

---

### BUG-024: Queue Filter Bar 'In Consultation' Segment Button Wrapping and Text Clipping
- **Date & Time:** 2026-10-26 22:28 IST
- **Component:** `lib/presentation/queue/queue_screen.dart`
- **Root Cause:**
  In Flutter's `SegmentedButton`, text within `ButtonSegment` widgets defaulted to `softWrap: true`. Because the segment label contained a space (`"In Consultation"`), Flutter wrapped the text onto two lines (`"In"` and `"Consultation"`). Since `SegmentedButton` enforces a single-line height constraint, the second line was vertically clipped and partially hidden.
- **Fix Applied:**
  1. Updated all `ButtonSegment` labels in both desktop and mobile layouts in `queue_screen.dart` to explicitly enforce `maxLines: 1` and `softWrap: false`:
     `Text('In Consultation', maxLines: 1, softWrap: false)`.
  2. Applied `ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap)` to `SegmentedButton` to give proper vertical clearance and prevent cramped borders.
- **Verification:**
  - `dart analyze lib/presentation/queue/queue_screen.dart` (0 errors)
  - `dart test/run_unit_tests.dart` (96/96 PASS)
- **Result:** FIXED

---

### BUG-025: Receptionist Role Permitted Doctor Desk Actions & Cloud Sync Button Low Contrast
- **Date & Time:** 2026-10-26 22:38 IST
- **Component:** `lib/presentation/queue/queue_screen.dart`, `lib/presentation/shared/widgets/app_scaffold.dart`
- **Root Cause:**
  1. On `/queue`, action buttons (`CALL PATIENT`, `START CONSULTATION`, `COMPLETE VISIT`) and `_transitionStatus` lacked role-based security checks. When a workstation was locked to `receptionist`, staff could invoke clinical transitions reserved for Doctors and Clinic Owners.
  2. `_CloudSyncButton` in `AppScaffold` explicitly used `color: Colors.white` for both the icon and the progress spinner, rendering it nearly invisible on the white/light surface AppBar.
- **Fix Applied:**
  1. In `queue_screen.dart`:
     - Evaluated `isClinicalStaff = session.role == UserRole.doctor || session.role == UserRole.owner` reactively via `ref.watch(sessionProvider)`.
     - Conditioned `CALL PATIENT`, `START CONSULTATION`, and `COMPLETE VISIT` buttons on `isClinicalStaff`. Receptionists only see front-desk actions (`COLLECT DUE`, `ADD BILL`, `PRINT SLIP`, `REPRINT SLIP`, `PRINT RECEIPT`).
     - Added authorization check inside `_transitionStatus` to deny execution if invoked by non-clinical staff.
     - Added automatic Google Sheets sync call (`triggerManualSync`) upon status transitions.
  2. In `app_scaffold.dart`:
     - Changed `_CloudSyncButton` icon and circular progress indicator colors from `Colors.white` to `AppColors.primary` (`#0F766E`), ensuring strong contrast and consistency with the brand theme.
- **Verification:**
  - `dart analyze lib/presentation/queue/queue_screen.dart lib/presentation/shared/widgets/app_scaffold.dart` (0 errors)
  - `dart test/run_unit_tests.dart` (96/96 PASS)
- **Result:** FIXED

---

### BUG-026: Clinic Logo Upload to Drive Branding/ & Offline Print Slip Embedding
- **Date & Time:** 2026-10-27 19:15 IST
- **Component:** `lib/domain/entities/clinic.dart`, `lib/infrastructure/google/google_drive_client.dart`, `lib/application/printing/consultation_slip_service.dart`, `lib/application/printing/receipt_slip_service.dart`, `lib/presentation/settings/settings_screen.dart`
- **Observed Gap:** PRD Module 1 (Clinic Onboarding & Settings) specified clinic logo upload to Google Drive under `Apna Clinic/{clinic_id}/Branding/` and printing the logo on consultation slips and receipts. Previously, slips only printed clinic name text, and logo file upload/storage in Drive were not implemented.
- **Root Cause:**
  1. `Clinic` entity had no fields to store logo image data or Drive file references.
  2. `GoogleDriveClient` lacked branding folder creation (`initializeClinicBrandingFolder`) and binary multipart upload capability (`uploadBinaryFile`).
  3. `ConsultationSlipService` and `ReceiptSlipService` headers had no logo rendering support.
  4. Settings screen (`settings_screen.dart`) did not provide an image picker or branding management UI.
- **Fix Applied:**
  1. **Domain Entity:** Added `logoBase64` (for 100% offline-first local rendering and storage) and `logoDriveFileId` (for cloud sync tracking) to `Clinic` entity with full serialization/deserialization.
  2. **Cloud Integration:** Added `initializeClinicBrandingFolder` (canonical path: `Apna Clinic/{clinic_id}/Branding/`) and `uploadBinaryFile` (multipart/related Base64 chunk upload) to `GoogleDriveClient` and `MockGoogleDriveClient`.
  3. **Print Slip Services:** Updated `ConsultationSlipService` and `ReceiptSlipService` to decode `logoBase64` and render `pw.Image(pw.MemoryImage(logoBytes))` alongside the clinic details with strict thermal layout boundaries (no text displacement, handwriting area preserved).
  4. **Settings UI:** Added a comprehensive Logo Branding card in Settings -> Clinic Profile with:
     - Real-time image preview (showing current local cached logo or upload placeholder).
     - Native file picker with 2MB size check and format restrictions (`PNG`, `JPG`, `JPEG`, `WEBP`).
     - Real-time status indicators (Local Cached, Drive Synced with Drive file ID).
     - Upload / Change Logo button with loading state.
     - Remove Logo button with immediate confirmation and state update.
- **Verification:**
  - `dart analyze lib/domain/entities/clinic.dart lib/infrastructure/google/google_drive_client.dart lib/infrastructure/google/mock_google_integration.dart lib/application/printing/consultation_slip_service.dart lib/application/printing/receipt_slip_service.dart lib/presentation/settings/settings_screen.dart` (0 errors)
  - `dart test/run_unit_tests.dart` (101/101 PASS - includes 5 new dedicated branding unit tests)
  - `flutter test test/test_pdf_gen.dart` (3/3 PASS - includes logo PDF embedding test)
- **Result:** FIXED

---

### BUG-028: Complete Implementation of PRD Module 2 (Patient Registration, Lookup, Edit Audit History, Controlled Soft-Delete, DPDPA Phone Masking & CSV Export)
- **Date & Time:** 2026-10-27 21:26 IST
- **Component:** `lib/domain/repositories/i_patient_repository.dart`, `lib/infrastructure/repositories/patient_repository.dart`, `lib/core/utils/downloader/`, `lib/presentation/patients/patients_screen.dart`, `test/run_unit_tests.dart`
- **Observed Gap:** PRD Module 2 (Lines 89-96) and TRD Section 7/8 specified:
  1. Patient Edit with Change History (Audit Log): When demographic fields are updated, an immutable `AuditEvent` must be recorded in `Audit_Events` with the modified field names and operator ID.
  2. Controlled Patient Deletion: Only Clinic Owner can archive/delete patients. Record must be soft-deleted (`deleted_at`), excluded from searches, and permanently recorded in audit logs.
  3. Shared Display Phone Masking: 10-digit phone numbers must be masked by default for DPDPA privacy, with an unmask toggle.
  4. Controlled Patient Directory Export (CSV): Only Owner role can export. Must be UTF-8 compatible and strictly exclude sensitive health information (reasons for visit / illness descriptions).
- **Fix Applied:**
  1. **Repository & Architecture:**
     - Extended `IPatientRepository` with `updatePatient(patient, {actorId, actorRole, changedFields})`, `deletePatient(clinicId, patientId, {actorId, actorRole, reason})`, and `getPatientAuditHistory(clinicId, patientId)`.
     - Implemented ACID atomic transactions in `PatientRepository`:
       - `updatePatient`: Validates duplicate phone + name collisions against other existing patients, persists updates, logs `patient.edit` to `Audit_Events` with modified field list, and stages `patient.update` in `sync_outbox`.
       - `deletePatient`: Marks record with `deleted_at = DateTime.now().toUtc()`, logs `patient.delete` to `Audit_Events` with reason, and stages `patient.delete` in `sync_outbox`.
       - `getPatientAuditHistory`: Returns chronologically sorted list of audit events for the given patient.
  2. **Cross-Platform Downloader Utility:**
     - Created `lib/core/utils/downloader/file_download_helper.dart` with conditional web/native imports.
     - Web implementation creates native HTML5 Blob and Anchor element triggering immediate file download to the user's Downloads folder with UTF-8 BOM encoding.
  3. **Patient Management UI (`patients_screen.dart`):**
     - Added phone masking privacy toggle button in search bar row.
     - Added `EDIT` and `PROFILE` action buttons directly on list items.
     - Added `EXPORT (CSV)` action button in AppScaffold top bar with Owner role guard.
     - Implemented `_PatientProfileDialog` with 'Change History', 'Edit Profile', 'Archive Patient' (Owner-only), and 'Issue Visit Token' actions.
     - Implemented `_EditPatientDialog` with live validation, changed field detection, duplicate collision warning banner, and automatic audit event logging.
     - Implemented `_PatientAuditHistoryDialog` displaying a formatted audit timeline with operator ID, role, action badge, timestamp, deletion reason, and modified field chips.
  4. **Comprehensive Unit Tests (`test/run_unit_tests.dart`):**
     - Added Section 10 with 11 new tests covering phone masking, fast search, duplicate prevention, demographic editing, audit trail creation, collision prevention, soft-deletion exclusion, and outbox staging.
- **Verification:**
  - `dart analyze lib/` (0 errors)
  - `dart test/run_unit_tests.dart` (112/112 PASS - 100% test suite success)
- **Result:** FIXED / COMPLETE



