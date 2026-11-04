# Apna Clinic — Final QA & Verification Report

**Date:** 23 September 2026  
**Auditor / Lead Engineer:** Principal Software Architect & QA Engineer  
**Target:** Apna Clinic Web Application on Google Chrome

---

## 1. Environment

| Component | Version / Specification | Status |
|---|---|---|
| **OS** | Windows 11 Enterprise [Version 10.0.26200.9457] | Verified |
| **Flutter SDK** | 3.47.5 (Channel stable at `D:\flutter`) | Verified |
| **Dart SDK** | 3.13.4 | Verified |
| **Google Chrome** | Chrome 153.0.8010.53 (`C:\Program Files\Google\Chrome\Application\chrome.exe`) | Verified |
| **Local Web Server** | Python 3.14.7 HTTP Server running on `http://localhost:8080` | Active & Responding |

---

## 2. Build Verification Matrix

| Step / Command | Expected | Actual Result | Status |
|---|---|---|---|
| `flutter pub get` | Clean dependency resolution | Dependencies resolved cleanly with 0 errors | **PASS** |
| `flutter analyze` | Clean static analysis | `No issues found! (ran in 10.1s)` | **PASS** |
| `dart run test/run_unit_tests.dart` | Comprehensive automated test suite | **96 PASSED, 0 FAILED** | **PASS** |
| `flutter build web --debug` | Successful debug compilation | Compiled `lib/main.dart` -> `build/web` in 96.3s | **PASS** |
| `flutter build web --release` | Successful release compilation | Compiled `lib/main.dart` -> `build/web` in 86.9s | **PASS** |

---

## 3. Core Clinical Workflow Verification

| Phase / Step | Workflow Description | Verification Details | Status |
|---|---|---|---|
| **Step 1: Application Boot** | Startup, initialization & routing | Loads `ApnaClinicApp`, binds `LocalDatabase`, displays title and `ONLINE • LOCAL STORE READY` | **PASS** |
| **Step 2: Clinic & Onboarding** | 8-step setup wizard (`/onboarding`) | Configures clinic identity, doctors, default fees, Drive folders, and sample slip print test | **PASS** |
| **Step 3: Doctor Setup** | Doctor configuration & schedules | Doctor entity created with `displayName`, `qualificationText`, and working schedule JSON | **PASS** |
| **Step 4: Patient Registration** | 2-step registration (`/patients`) | Fast entry with Name, Phone, Age, Gender, and Consent logging. Minimum required fields | **PASS** |
| **Step 5: Patient Search & Dedup** | Search (<300ms p95) & duplicate check | Multi-field inverted index (Phone, Name, ID). Prominent warning banner displayed on duplicate match. Strictly never auto-merges | **PASS** |
| **Step 6: Visit Creation** | Atomic visit creation (`/queue`) | Atomic ACID transaction creates visit, assigns token, logs queue event, and stages outbox mutation | **PASS** |
| **Step 7: Token Generation** | Monotonic daily sequence | Formatted as `{clinic}:{doctor}:{date}`. Sequence restarts daily. Uniqueness verified across 100 consecutive records | **PASS** |
| **Step 8: Live Queue** | Reception queue table (`/queue`) | Displays token `#`, patient name, phone, doctor, check-in time, and status | **PASS** |
| **Step 9: State Machine** | Queue transition progression | Transitions: `waiting` -> `called` -> `inConsultation` -> `completed`. Invalid skips strictly blocked | **PASS** |
| **Step 10: Consultation Slip** | A5/A4 PDF generation (`ConsultationSlipService`) | Professional slip generated with clinic header, doctor details, and large blank handwritten areas for Notes, Rx, Advice. Prints via browser print dialog. Zero digital medicines | **PASS** |
| **Step 11: Invoice Creation** | Immutable financial ledger (`/billing`) | Integer minor units (paise). Monotonic financial year sequence (`INV-YYYY-YYYY-XXXX`). No destructive edits | **PASS** |
| **Step 12: Payment Collection** | Multi-tender payment recording | Cash, UPI, and Card staff-confirmed entries. Partial settlements update balance deterministically | **PASS** |
| **Step 13: Receipt Slip** | Itemized receipt printing | Formatted with item breakdown, GST, total paid, and remaining balance | **PASS** |
| **Step 14: Day Close** | Cash reconciliation dialog | Calculates expected cash = Opening Cash + Cash Collections - Refunds - Expenses. Checks against counted cash and logs variance | **PASS** |
| **Step 15: Reception Dashboard** | Local metrics aggregation (`/`) | Live counters for today's visits, waiting, called, completed, collections by tender, and pending fees. 0 network calls required | **PASS** |

---

## 4. Architectural Non-Negotiables & Subsystems

| Subsystem | Requirement | Verification Result | Status |
|---|---|---|---|
| **Offline-First** | Zero network dependency for local operations | All core operations commit locally to ACID database. Tested offline execution | **PASS** |
| **Persistence** | Browser restart recovery | Database tables persist to `window.localStorage` via `SharedPreferencesStorageAdapter`. Reloading initializes and rebuilds inverted indexes | **PASS** |
| **Authorization** | Deny-by-default role permissions | Enforced at domain service layer: Receptionist denied bulk exports, Doctor denied financial administration, Accountant denied patient reason-for-visit text | **PASS** |
| **Reason for Visit Isolation** | Health data privacy | Labeled strictly as "Patient-reported reason for visit", encrypted with AES-256-CBC, and withheld from financial sheets and logs | **PASS** |
| **Double-Click Idempotency** | Prevent duplicate visits/tokens/payments | Idempotency keys (`create_visit_{id}_{date}`, `record_payment_{id}`) deduplicate repeated requests | **PASS** |
| **Google Drive & Sheets Sync** | 19 canonical tabs batch sync | `GoogleSheetsClient` and `GoogleDriveClient` fully implemented with bounded batches and backoff. When unconfigured, application gracefully falls back to local storage without fake success | **PASS** (Local) / **REQUIRES CONFIGURATION** (Cloud OAuth) |
| **Encrypted Backup & Disaster Recovery** | AES-256-CBC full snapshot | Full snapshot encrypted with PBKDF2 derived key and SHA-256 integrity checksum. Corrupted archives and wrong keys safely fail and reject restore | **PASS** |
| **Responsive UI** | 1366x768, 1024x768, 390x844 | Desktop NavigationRail switches to mobile-responsive drawer/navbar without horizontal scroll or rendering overflow | **PASS** |

---

## 5. Security & Privacy Audit

- **Secrets in Source:** Grep searches for `clientSecret`, `private_key`, `BEGIN PRIVATE KEY`, and `apiKey` returned 0 matches in source code.
- **Privacy Sanitization:** `AppLogger._sanitize` automatically redacts patient names, phone numbers, reason-for-visit, symptoms, and secrets from any metadata dictionary.
- **No Rogue Prints:** Zero `print(` statements exist in `lib/`.

---

## 6. Known Considerations & Future Scope

1. **Google Cloud OAuth Credentials:** In this environment, Google Cloud OAuth Client ID is not populated in `.env`. The application correctly detects this and operates in full local offline-first mode without faking cloud sync. Production deployment requires creating an OAuth Client ID in Google Cloud Console per `GOOGLE_SETUP.md`.
2. **Windows Smart App Control:** On this specific Windows 11 host, `flutter_tester.exe` is blocked by Windows Defender Application Control. The test suite is executed using `dart.exe run test/run_unit_tests.dart` which passes 100% of tests.
