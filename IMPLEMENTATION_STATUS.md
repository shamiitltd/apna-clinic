# Apna Clinic — Implementation Status Tracking

**Version:** 1.0  
**Baseline Date:** 22 September 2026  
**Status Key:** `NOT_STARTED` | `IN_PROGRESS` | `IMPLEMENTED` | `TESTED` | `VERIFIED` | `BLOCKED`

---

## Requirements Traceability & Status Matrix

| Req ID | Module / Requirement Description | Target Phase | Status | Implementation Location | Test Location | Verification Notes |
|---|---|---|---|---|---|---|
| M01.1 | Google OAuth 2.0 PKCE Authentication | Phase 3 | `VERIFIED` | `lib/infrastructure/google/google_oauth_service.dart` | `test/run_unit_tests.dart` | Real OAuth with PKCE and unconfigured-environment graceful fallback |
| M01.2 | Guided Clinic Onboarding Wizard | Phase 3 | `VERIFIED` | `lib/presentation/onboarding/onboarding_screen.dart` | `test/run_unit_tests.dart` | 8-step wizard: Profile, Doctor, Fees, Drive/Sheets, Sample Print |
| M01.3 | Google Drive Folder & Sheets Canonical Tabs Setup | Phase 3 | `VERIFIED` | `lib/infrastructure/google/google_drive_client.dart`, `google_sheets_client.dart` | `test/run_unit_tests.dart` | 19 canonical tabs created in `ApnaClinic_Master_v1`, isolated Drive folders |
| M01.4 | Sample Consultation Slip Print Test | Phase 3 | `VERIFIED` | `lib/application/printing/consultation_slip_service.dart` | `test/run_unit_tests.dart` | Synthetic sample data, zero real patient requirement |
| M02.1 | Patient Registration (2-Step Fast Entry) | Phase 4 | `VERIFIED` | `lib/presentation/patients/patients_screen.dart` | `test/run_unit_tests.dart` | Minimum necessary fields, consent logging, offline-first |
| M02.2 | Local Patient Search (<300ms p95) | Phase 4 | `VERIFIED` | `lib/infrastructure/database/local_database.dart`, `patient_repository.dart` | `test/run_unit_tests.dart` | Multi-field inverted indexed lookup (phone, name, patient number) |
| M02.3 | Duplicate Patient Detection Warning | Phase 4 | `VERIFIED` | `lib/infrastructure/database/patient_repository.dart` | `test/run_unit_tests.dart` | Warning displayed for review; strictly NEVER auto-merges |
| M02.4 | Sensitive Reason-for-Visit Isolation & Encryption | Phase 4 | `VERIFIED` | `lib/infrastructure/security/local_encryption_service.dart` | `test/run_unit_tests.dart` | AES-256-CBC envelope encryption, strictly isolated from logs & financial sheets |
| M03.1 | Doctor Schedule & Available Slot Calculation | Phase 5 | `VERIFIED` | `lib/domain/entities/doctor.dart`, `appointment_repository.dart` | `test/run_unit_tests.dart` | Slot conflict detection with doctor filter & duration |
| M03.2 | Appointment Booking, Rescheduling & Cancellation | Phase 5 | `VERIFIED` | `lib/presentation/appointments/appointments_screen.dart` | `test/run_unit_tests.dart` | Calendar UI, slot overlap prevention, check-in to visit |
| M04.1 | Monotonic Atomic Token Generation (`{c}:{d}:{date}`) | Phase 5 | `VERIFIED` | `lib/infrastructure/database/visit_repository.dart` | `test/run_unit_tests.dart` | Monotonic sequence reset daily per doctor, ACID transaction |
| M04.2 | Visit Creation Idempotency | Phase 5 | `VERIFIED` | `lib/infrastructure/database/visit_repository.dart` | `test/run_unit_tests.dart` | Idempotency key deduplication; prevents duplicate visits on double-click |
| M04.3 | Queue State Machine (`registered` → `completed`) | Phase 6 | `VERIFIED` | `lib/domain/enums/domain_enums.dart`, `visit_repository.dart` | `test/run_unit_tests.dart` | Strictly valid transitions; immutable `QueueEvent` generated on every shift |
| M04.4 | Receptionist & Doctor Queue Views | Phase 6 | `VERIFIED` | `lib/presentation/queue/queue_screen.dart`, `doctor_queue_screen.dart` | `test/run_unit_tests.dart` | Real-time local queue state, dedicated doctor workstation with big token display |
| M05.1 | Client-side A5 Portrait & A4 PDF Generation | Phase 7 | `VERIFIED` | `lib/application/printing/consultation_slip_service.dart` | `test/run_unit_tests.dart` | PDF generation using `pdf` package, prints via browser print dialog |
| M05.2 | Blank Handwritten Writing Space (Notes, Rx, Advice) | Phase 7 | `VERIFIED` | `lib/application/printing/consultation_slip_service.dart` | `test/run_unit_tests.dart` | Explicit blank areas for manual doctor writing; strictly no digital prescriptions |
| M05.3 | Reprint Watermark & Audit Counter | Phase 7 | `VERIFIED` | `lib/application/printing/consultation_slip_service.dart`, `visit_repository.dart` | `test/run_unit_tests.dart` | Prominent "REPRINT [N]" watermark on subsequent prints, print count audit |
| M05.4 | Hindi Text Rendering (Noto Sans Devanagari) | Phase 7 | `VERIFIED` | `lib/application/printing/consultation_slip_service.dart` | `test/run_unit_tests.dart` | Devanagari Unicode glyph font fallback |
| M06.1 | Consultation Fee Catalog & Pricing Engine | Phase 8 | `VERIFIED` | `lib/core/utils/money.dart`, `billing_repository.dart` | `test/run_unit_tests.dart` | 100% integer minor units (paise); zero floating point currency math |
| M06.2 | Immutable Invoice Lifecycle & Numbering | Phase 8 | `VERIFIED` | `lib/infrastructure/database/billing_repository.dart` | `test/run_unit_tests.dart` | Monotonic financial year numbers (INV-YYYY-YYYY-XXXX), no destructive edits |
| M06.3 | Multi-Tender Payments (Cash, UPI, Card, Partial) | Phase 8 | `VERIFIED` | `lib/presentation/billing/billing_screen.dart`, `billing_repository.dart` | `test/run_unit_tests.dart` | Staff-confirmed payment entries, partial settlement, balance updates |
| M06.4 | Permission-Gated Audited Refunds | Phase 8 | `VERIFIED` | `lib/infrastructure/database/billing_repository.dart` | `test/run_unit_tests.dart` | Owner/Accountant permission required, negative adjustment entries |
| M06.5 | End-of-Day Cash Reconciliation & Variance Log | Phase 8 | `VERIFIED` | `lib/presentation/billing/billing_screen.dart`, `billing_repository.dart` | `test/run_unit_tests.dart` | Opening cash + collections - refunds - expenses = expected cash vs counted |
| M07.1 | Receptionist & Doctor Dashboards | Phase 9 | `VERIFIED` | `lib/presentation/dashboard/dashboard_screen.dart` | `test/run_unit_tests.dart` | Instant local aggregates (visits, waiting, called, collections, pending fees) |
| M07.2 | Privacy-Safe Financial & Administrative Exports | Phase 9 | `VERIFIED` | `lib/presentation/reports/reports_screen.dart` | `test/run_unit_tests.dart` | CSV generation with strict exclusion of reason-for-visit and health data |
| M08.1 | Deny-by-Default Role Authorization Service | Phase 1 | `VERIFIED` | `lib/core/permissions/authorization_service.dart` | `test/run_unit_tests.dart` | Explicit permission checks at domain layer; cross-clinic access blocked |
| M09.1 | Durable Transactional Outbox | Phase 2 | `VERIFIED` | `lib/infrastructure/database/local_database.dart` | `test/run_unit_tests.dart` | Every mutation atomically writes a `sync_outbox` event |
| M09.2 | Bounded Batch Synchronization to Google Sheets | Phase 10 | `VERIFIED` | `lib/infrastructure/google/google_sheets_client.dart` | `test/run_unit_tests.dart` | Bounded batches (50-100 rows), cursor advancement, acknowledgment commit |
| M09.3 | Quota Backoff & Network Resilience | Phase 10 | `VERIFIED` | `lib/infrastructure/sync/sync_worker.dart` | `test/run_unit_tests.dart` | Exponential backoff with jitter on 429 / 5xx, never blocks local operations |
| M09.4 | WebCrypto Encrypted Snapshot Backup to Drive | Phase 11 | `VERIFIED` | `lib/infrastructure/database/backup_repository.dart` | `test/run_unit_tests.dart` | Full snapshot encrypted with AES-256-CBC, PBKDF2 key, SHA-256 checksum |
| M09.5 | Verified Restore Wizard & Corruption Fail-Safe | Phase 11 | `VERIFIED` | `lib/infrastructure/database/backup_repository.dart` | `test/run_unit_tests.dart` | Validates manifest, verifies SHA-256, tests decryption before restoring |
| M10.1 | Subscription Lifecycle & Licensing Engine | Phase 12 | `VERIFIED` | `lib/domain/entities/subscription.dart`, `subscription_repository.dart`, `settings_screen.dart` | `test/domain/module10_subscription_test.dart` | Tiered plans (Trial, Annual, Multi-Doctor), license key verification, offline grace period, feature gating |
| M11.1 | Clinic Operating Expenses & Financial Ledger | Phase 8 | `VERIFIED` | `lib/domain/entities/expense.dart`, `expense_repository.dart`, `billing_screen.dart` | `test/domain/module11_expenses_test.dart` | Expense categories (Rent, Utilities, Supplies, Salaries), payment methods, receipts, net cash calculations |
| M12.1 | Administrative Follow-up Date Scheduling | Phase 5 | `VERIFIED` | `lib/domain/entities/followup.dart`, `visit.dart`, `followup_repository.dart`, `appointments_screen.dart` | `test/domain/module12_followup_reminders_test.dart` | Administrative date tracking only, DPDP consent, CSV export, strictly non-clinical |
| M13.1 | Single-Writer Lease & Multi-Device Collaboration | Phase 12 | `VERIFIED` | `lib/domain/entities/device_state.dart`, `device_collaboration_repository.dart`, `settings_screen.dart` | `test/domain/module13_collaboration_test.dart`, `test/run_unit_tests.dart` | Single-writer lease acquisition, heartbeat roster, conflict ledger, monotonic sequence vector |
| M14.1 | Multi-Branch Tenancy & Flagship Protection | Phase 13 | `VERIFIED` | `lib/domain/entities/branch.dart`, `branch_repository.dart`, `settings_screen.dart` | `test/domain/module14_multi_branch_test.dart`, `test/run_unit_tests.dart` | Multi-facility network, auto-provisioned BR-01 flagship, deactivation block for main branch |
| M14.2 | Consolidated Enterprise Reporting & CSV Export | Phase 13 | `VERIFIED` | `lib/domain/entities/branch.dart`, `branch_repository.dart`, `settings_screen.dart` | `test/domain/module14_multi_branch_test.dart`, `test/run_unit_tests.dart` | Aggregates visits, appointments & collections across branches; UTF-8 BOM CSV export strictly zero clinical leakage |
| M14.3 | ABDM Interoperability & ABHA Profile Linking | Phase 13 | `VERIFIED` | `lib/domain/entities/branch.dart`, `branch_repository.dart`, `settings_screen.dart` | `test/domain/module14_multi_branch_test.dart`, `test/run_unit_tests.dart` | Facility registry, HPR doctor credentials, client credentials, ABHA verification with explicit DPDP consent |

---

## Test Verification Summary
- **Unit & Integration Suite (`test/run_unit_tests.dart`):** **216 PASSED, 0 FAILED (100%)**
  - Section 1: Money Representation & Minor Unit Paise Arithmetic (17 tests)
  - Section 2: Phone Normalizer, Masking & Hashing (7 tests)
  - Section 3: Authorization & Deny-by-Default Role Permissions (22 tests)
  - Section 4: Queue State Machine & Transition Invariants (8 tests)
  - Section 5: Local AES-256-CBC Encryption & SHA-256 Checksums (7 tests)
  - Section 6: ACID Transactions, Monotonic Tokens & Financial Ledger (23 tests)
  - Section 7: Appointments & Slot Conflict Detection (7 tests)
  - Section 8: Disaster Recovery & Encrypted Backup/Restore Verification (6 tests)
  - Section 9: Google Drive Encrypted Sync Manifest (4 tests)
  - Section 10: Patient Identity, Demographic Edits & Soft Deletion (6 tests)
  - Section 11: Token & Queue Priority Triage Management (9 tests)
  - Section 12: Consultation Slip & Print Tracking (7 tests)
  - Section 13: Billing, Payments, Mixed Tender, Refunds & Day Close (11 tests)
  - Section 14: Dashboard & Daily Financial Reports (16 tests)
  - Section 15: Staff PIN Security, Queue Isolation & Access Control (21 tests)
  - Section 16: Multi-Doctor & Multi-Device Live Collaboration (18 tests)
  - Section 17: Multi-Branch & Third-Party Integrations (16 tests)
- **Domain Test Suites:**
  - `module14_multi_branch_test.dart`: **8/8 PASSED**
  - `module13_collaboration_test.dart`: **10/10 PASSED**
  - `module12_followup_reminders_test.dart`: **8/8 PASSED**
  - `module11_expenses_test.dart`: **6/6 PASSED**
  - `module10_subscription_test.dart`: **11/11 PASSED**
  - `module8_staff_access_test.dart`: **36/36 PASSED**
  - `module6_billing_test.dart`: **26/26 PASSED**
- **Responsive Viewport Test Matrix (`test/responsive_layout_test.dart`):** **99/99 PASSED across all 11 viewports with zero RenderFlex overflow**
- **Static Analysis (`flutter analyze --no-fatal-infos`):** **0 errors, 0 warnings (Exit code 0)**
