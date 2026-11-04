# Apna Clinic (अपना क्लिनिक)

> **Production-grade, offline-first administrative clinic management platform for independent doctors and outpatient clinics in India.**

---

## 1. Product Boundaries & Non-Negotiables

Apna Clinic is strictly an **administrative** workflow application. It manages:
- **Patient Registration & Lookup** (Local multi-field indexing, <300ms p95 response time)
- **Appointments & Walk-ins** (Conflict detection, slot scheduling)
- **Token Generation** (Monotonic daily sequence per doctor `{clinic}:{doctor}:{date}`)
- **Queue Management** (Reception and Doctor workstations, strict state machine transitions)
- **Consultation Slip Printing** (A5/A4 PDF generation with large, clear blank handwritten writing areas for Doctor's Notes, Rx/Medicines, and Advice)
- **Billing & Cash Reconciliation** (100% integer minor-unit paise calculations, multi-tender payments, auditable refunds, Day Close)
- **Synchronization & Disaster Recovery** (Google Drive AES-256-CBC encrypted backups with SHA-256 integrity checksums, and 19-canonical-tab Google Sheets batch sync)

### Strict Clinical Boundary
The application **DOES NOT**:
- Generate prescriptions
- Suggest medicines or dosages
- Diagnose diseases or provide clinical decision support
- Store handwritten or scanned prescriptions
- Store longitudinal medical/treatment history
- Function as a pharmacy or laboratory management system

Any reason for visit entered is strictly labeled and treated as **"Patient-reported reason for visit"**, encrypted locally with an envelope key, and excluded from logs and financial exports.

---

## 2. Core Engineering Principles

1. **Offline-First & Local-First:** All transactional operations (patient search, visit creation, token allocation, invoice settlement, printing, dashboard metrics) commit to the local ACID database immediately without requiring internet access.
2. **Google Sheets is NOT the Transactional Database:** Google Sheets receives bounded batch sync events from the local outbox. Sheets availability is never required for front-desk operations.
3. **Integer Minor Units (Paise):** Money is represented strictly as integer minor units (`Money` class). Zero floating-point drift.
4. **Deny-by-Default Role Authorization:** Domain operations enforce role permissions (`Owner`, `Receptionist`, `Doctor`, `Accountant`) and clinic scoping at the service layer, not just by hiding UI buttons.
5. **No Duplicate Financial Records:** Retries, network interruptions, and double-clicks are deduplicated via idempotency keys.

---

## 3. Technology Stack

- **Framework:** Flutter 3.47.5 (Web Desktop-First & Mobile-Responsive)
- **Language:** Dart 3.13.4
- **Architecture:** Clean Layered Architecture (`Domain` → `Application` → `Infrastructure` → `Presentation`)
- **State Management:** Riverpod (`flutter_riverpod`)
- **Navigation:** `go_router` with role-based route guards
- **Database:** `LocalDatabase` (ACID transactions, rollback support, inverted search indexes)
- **Security:** `LocalEncryptionService` (AES-256-CBC, PBKDF2 key derivation, SHA-256 integrity checksums)
- **PDF & Printing:** `pdf` package for client-side A5/A4 consultation slips and itemized receipts
- **Cloud Integrations:** Google OAuth 2.0 (PKCE), Google Drive API v3 (encrypted snapshots), Google Sheets API v4 (19 canonical tabs batch append)

---

## 4. Project Structure

```
lib/
├── core/
│   ├── constants/        # Application constants & limits
│   ├── errors/           # Typed error hierarchy (Domain, DB, Crypto, Sync, Auth)
│   ├── localization/     # English & Hindi (en/hi) translation tables
│   ├── permissions/      # Role permissions & AuthorizationService (Deny-by-default)
│   ├── routing/          # AppRouter with authenticated & role-gated routes
│   └── utils/            # Money (integer paise) & PhoneNormalizer (+91, E.164, masking)
├── domain/
│   ├── entities/         # 19 Canonical entities + local models
│   ├── enums/            # QueueStatus, InvoiceStatus, UserRole, SyncStatus, etc.
│   └── repositories/     # Abstract repository interfaces (Clinic, Patient, Visit, Billing, etc.)
├── application/
│   ├── auth/             # SessionProvider & authentication state
│   ├── printing/         # ConsultationSlipService (A5/A4) & ReceiptSlipService
│   ├── providers.dart    # Riverpod dependency injection registry
│   └── sync/             # SyncWorker with exponential backoff & jitter
├── infrastructure/
│   ├── database/         # LocalDatabase, concrete repositories, Outbox table
│   ├── google/           # GoogleOAuthService, GoogleDriveClient, GoogleSheetsClient
│   └── security/         # LocalEncryptionService (AES-256-CBC, PBKDF2, SHA-256)
└── presentation/
    ├── appointments/     # Appointment scheduling & slot conflict detection
    ├── billing/          # Invoices, multi-tender payments, Day Close reconciliation
    ├── dashboard/        # Reception metrics, daily summaries, queue snapshot
    ├── doctor/           # Doctor workstation with big token display & consultation controls
    ├── onboarding/       # 8-step clinic setup & sample slip test
    ├── patients/         # Fast search (<300ms), 2-step registration, duplicate check
    ├── queue/            # Reception queue management & live slip printing
    ├── reports/          # Financial & administrative local reports + CSV exports
    └── shared/widgets/   # AppScaffold, AppNavbar, persistent sync status badge
```

---

## 5. Verification & Test Suite

### Running the Core Test Suite
Apna Clinic includes a comprehensive automated test suite verifying all architectural invariants:

```bash
dart run test/run_unit_tests.dart
```

**Results:**
- **96 PASSED, 0 FAILED**
  1. **Money & Minor Units:** ₹0, ₹1, ₹99.99, ₹100, ₹250.50, tax, discounts, formatting.
  2. **Phone Normalizer:** E.164 Indian format, masking (`******3210`), SHA-256 hashing.
  3. **Role Authorization:** Deny-by-default, 4 roles, clinic scoping, health privacy isolation.
  4. **Queue State Machine:** Linear progression (`registered` → `waiting` → `called` → `inConsultation` → `completed`), terminal states.
  5. **AES-256 Encryption:** PBKDF2 key derivation, IV uniqueness, SHA-256 checksum, wrong-key failure.
  6. **ACID Transactions:** Rollback on error, monotonic tokens (`#1`, `#2`), idempotency, partial payments, invoice settlement, day-close net cash.
  7. **Appointments:** Slot conflict detection, doctor filtering, cancel with reason.
  8. **Disaster Recovery:** Encrypted full database backup, checksum validation, safe wrong-key rejection, atomic restore.

### Running Static Analysis
```bash
dart analyze .
```
- **0 issues found** (Clean analysis across all files).

### Building for Web Production
```bash
flutter build web --no-tree-shake-icons
```
- Built successfully to `build/web/`.

---

## 6. Primary Front-Desk Workflow

1. **Register Patient:** Open *Patients*, enter Name & Phone, review duplicate warnings, save.
2. **Create Visit & Generate Token:** Allocate visit; monotonic token (e.g. `#1`, `#2`) is generated atomically.
3. **Print Consultation Slip:** Click *Print Slip* to preview/print A5 or A4 format with large blank writing spaces for doctor's manual pen notes.
4. **Queue Flow:** Doctor calls patient on *Doctor Workstation* (`waiting` → `called` → `inConsultation` → `completed`).
5. **Collect Payment:** Record cash, UPI, or card payment; itemized receipt printed with zero floating-point arithmetic.
6. **Day Close:** Enter counted cash at reception, compare against expected net cash in hand, record variance explanation.
7. **Sync & Backup:** Background worker syncs outbox events to Google Sheets; encrypted full database snapshot uploaded to Google Drive.
