# APNA CLINIC — PHASE 3 PRE-IMPLEMENTATION ARCHITECTURE PLAN
**Production-Grade Architecture Specification: Local-First Outbox Synchronization & Google Drive Integration**  
**Document Version:** 3.0.0-AUDIT  
**Date:** September 2026  
**Status:** Engineering Architecture Baseline (Phase 1 & Phase 2 Frozen)  
**Target Workbook:** `APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL.xlsx` (20 Canonical Worksheets)

---

## 1. Current Architecture Audit

A comprehensive, read-only architectural inspection of the Apna Clinic codebase was conducted across all 5 architectural layers (`core`, `domain`, `infrastructure`, `application`, `presentation`).

```
┌────────────────────────────────────────────────────────────────────────┐
│                        PHASE 1 FROZEN UI LAYER                         │
│   (Dashboard, Patients, Queue, Appointments, Doctor, Billing, Reports) │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Riverpod State Providers
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        APPLICATION LAYER                               │
│        (SessionNotifier, SyncHealthNotifier, Use Cases/Seeders)        │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Domain Repositories & Entities
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        DOMAIN LAYER                                    │
│   (19 Domain Entities, Enums, Roles, Value Objects, ISyncRepository)   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Concrete Implementations
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        INFRASTRUCTURE LAYER                            │
│  - LocalDatabase (In-Memory + ACID Transactions + StorageAdapter)      │
│  - LocalEncryptionService (AES-256-CBC, PBKDF2-HMAC-SHA256)            │
│  - GoogleDriveClient (Google Drive v3 REST Client - Folder/Backups)    │
│  - GoogleSheetsClient (Google Sheets v4 REST Client - Outdated Schema) │
│  - SyncRepository & BackupRepository (Outbox Pattern Implementations)  │
└────────────────────────────────────────────────────────────────────────┘
```

### Detailed Subsystem Audit Findings

| Subsystem | Existing Implementation | Architectural Audit Assessment |
|---|---|---|
| **1. Project Directory Structure** | `lib/` cleanly partitioned into `application/`, `core/`, `domain/`, `infrastructure/`, `presentation/`. | Conforms to strict Clean Architecture and Domain-Driven Design (DDD). Presentation layer is cleanly separated from infrastructure. |
| **2. Existing Data Models** | 19 rich entities in `lib/domain/entities/` (`patient.dart`, `appointment.dart`, `visit.dart`, `invoice.dart`, `payment.dart`, `sync_models.dart`, etc.). | Complete domain models with immutable properties, `toMap()`, `fromMap()`, and domain logic. Fully aligned with clinic workflows. |
| **3. Local Storage / Database** | `LocalDatabase` in `lib/infrastructure/database/local_database.dart` backed by `SharedPreferencesStorageAdapter` (`IStorageAdapter`). | Operates in-memory with ACID transactions, rollback snapshots (`DbTransaction`), and phone/patient number inverted indexes. Persists tables as serialized JSON keys. |
| **4. Data-Access / Repository Layer** | 9 repository interfaces in `lib/domain/repositories/` and concrete classes in `lib/infrastructure/repositories/`. | Methods accept domain entities and clinic IDs. Repositories automatically stage events to `sync_outbox` within transactions. |
| **5. Authentication Abstractions** | `SessionState` and `SessionNotifier` in `lib/application/providers.dart`. UI buttons in `login_screen.dart`. | **Placeholder / Abstraction Only.** Tracks in-memory session (`isGoogleAuthenticated`, `role`, `deviceId`), but lacks Google OAuth 2.0 PKCE flow, token lifecycle, and secure credential storage. |
| **6. State Management** | Riverpod 2.6.1 (`ProviderScope`, `StateNotifierProvider`, `Provider`). | Well-structured reactive state. UI watches domain repositories and state notifiers. Minimal boilerplate, no widget pollution. |
| **7. API / Service Abstractions** | `GoogleDriveClient` and `GoogleSheetsClient` in `lib/infrastructure/google/`. | Direct HTTP REST clients using `http.Client`. Functional for raw REST calls, but Sheets client uses an outdated 19-tab TRD schema instead of the approved 20-tab Master Sheet. |
| **8. Error Handling** | `Failure` hierarchy in `lib/core/errors/failures.dart` (`DatabaseFailure`, `NetworkFailure`, `QuotaExceededFailure`, `CryptoFailure`). | Robust typed exceptions. Distinguishes transient network errors from terminal crypto or validation failures. |
| **9. Backup & Disaster Recovery** | `BackupRepository`, `LocalDatabase.exportFullSnapshot`, and AES-256 backup wizard in `SettingsScreen`. | Generates PBKDF2/AES-256 encrypted JSON backups with SHA-256 integrity checksums. Fully functional in offline standalone mode. |
| **10. Encryption / Security** | `LocalEncryptionService` (`encrypt: ^5.0.3`, `crypto: ^3.0.6`). | Implements AES-256-CBC, secure IV nonces, PBKDF2 10,000-round key derivation, and SHA-256 payload integrity validation. DPDPA 2023 compliant. |
| **11. Synchronization Code** | `SyncOutboxEvent`, `SyncManifest`, `ISyncRepository`, and `SyncRepository`. | Outbox pattern with bounded batching (limit 50), in-flight state tracking, failure recording, and retry count. **Missing: Active background sync daemon / worker.** |
| **12. Master Sheet Code** | `GoogleSheetsClient` has `canonicalTabHeaders`. | Outdated: headers reflect early draft (19 sheets) rather than the frozen `APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL.xlsx` (20 sheets). Requires alignment. |
| **13. Environment Configuration** | `AppConfig` in `lib/core/config/app_config.dart` and `.env.example`. | Basic configuration model present. Missing secure runtime injection for OAuth client secrets / IDs across Web and Desktop targets. |
| **14. Dependency Configuration** | `pubspec.yaml` with Riverpod, GoRouter, Drift, Crypto, Encrypt, Http, Pdf. | Solid baseline. Missing Google OAuth libraries (`google_sign_in` or specialized OAuth2 packages) and Drive/Sheets client SDKs or typed wrappers. |
| **15. Test Architecture** | Comprehensive unit test suite in `test/run_unit_tests.dart` (911 lines) verifying Money, Roles, Encryption, and DB transactions. | 100% passing core unit tests. Missing mock HTTP integration tests for Google Drive and Google Sheets outbox sync flows. |

---

## 2. Existing Components That Can Be Reused

The existing codebase contains high-quality, production-ready modules that directly accelerate Phase 3 implementation without modification:

1. **`LocalEncryptionService` (`lib/infrastructure/security/local_encryption_service.dart`)**
   - 256-bit AES cryptographic encryption with IV nonces and SHA-256 checksums.
   - PBKDF2-HMAC-SHA256 key derivation.
   - Reusable for encrypting cached OAuth refresh tokens and clinical secrets before local storage.
2. **`SyncOutboxEvent` & `SyncManifest` Entities (`lib/domain/entities/sync_models.dart`)**
   - Outbox model with `idempotencyKey`, `status` (`pending`, `in_flight`, `acknowledged`, `failed`), `retryCount`, and `payloadJson`.
   - Manifest entity tracking batch ranges (`firstEventId`, `lastEventId`), checksums, and sync status.
3. **`ISyncRepository` & `SyncRepository` (`lib/domain/repositories/i_sync_repository.dart`, `lib/infrastructure/repositories/sync_repository.dart`)**
   - Complete outbox lifecycle management: `getPendingOutboxEvents(limit: 50)`, `markEventsInFlight`, `acknowledgeEvents`, `recordEventFailure`.
4. **`LocalDatabase` Transaction Pipeline (`lib/infrastructure/database/local_database.dart`)**
   - ACID transaction wrappers (`DbTransaction`) ensuring local updates and outbox staging commit or rollback atomically.
5. **Typed Failure Architecture (`lib/core/errors/failures.dart`)**
   - `QuotaExceededFailure` (HTTP 429), `AuthorizationFailure` (HTTP 401), `NetworkFailure`, and `ConcurrencyConflictFailure` ready for sync engine backoff.
6. **Riverpod Session & Sync State Containers (`lib/application/providers.dart`)**
   - `SessionState` and `SyncHealthState` providers already subscribed to by the frozen UI.

---

## 3. Components Missing for Phase 3

To establish the complete, live synchronization pipeline between the Local Database, Google Drive, and the canonical Master Sheet, the following components must be designed and implemented in Phase 3:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        COMPONENTS TO BE CREATED                        │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Google OAuth 2.0 Client & Token Vault (PKCE, Refresh Daemon)        │
│ 2. Drive Sheet Discovery & Binding Service (Locate / Provision Sheet)  │
│ 3. Master Sheet Schema Adapter (20 Worksheets Aligned to XLSX Final)   │
│ 4. Outbox Synchronization Engine Daemon (Queue Worker, Backoff, Retry) │
│ 5. Bi-Directional Delta Sync Resolver (Inbound Downstream Hydration)   │
│ 6. Three-Tier Conflict Resolution Engine (Clinical / Financial Rules)  │
│ 7. Network Connectivity Monitor (Browser Navigator Online / Offline)   │
└────────────────────────────────────────────────────────────────────────┘
```

1. **Google OAuth 2.0 Web Client (`IOAuthService` & `GoogleOAuthService`)**
   - RFC 7636 PKCE (Proof Key for Code Exchange) authentication flow for single-page web applications.
   - Encrypted token storage vault (`TokenVault`) protecting refresh tokens in browser storage.
   - Automatic silent token refresh daemon to acquire fresh access tokens without user interruption.
2. **Master Sheet Discovery & Provisioning Service (`DriveSheetService`)**
   - Locates existing `APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL.xlsx` (or Google Sheets equivalent) in the user's Google Drive.
   - Validates worksheet structure and binds the unique `spreadsheetId` to the local clinic session.
3. **Canonical 20-Sheet Adapter (`MasterSheetAdapter`)**
   - Replaces outdated 19-tab headers in `google_sheets_client.dart` with the approved 20 canonical worksheets:
     `01_SETTINGS`, `02_USERS`, `03_ROLES`, `04_DOCTORS`, `05_PATIENTS`, `06_APPOINTMENTS`, `07_DOCTOR_SCHEDULES`, `08_QUEUE`, `09_CONSULTATIONS`, `10_BILLING`, `11_PAYMENTS`, `12_SERVICES`, `13_MEDICAL_RECORDS`, `14_PRESCRIPTIONS`, `15_FOLLOW_UPS`, `16_ROOMS`, `17_AUDIT_LOG`, `18_NOTIFICATIONS`, `19_REPORTING`, `20_LOOKUPS`.
   - Serializes domain entity models into ordered row arrays matching exact column definitions.
4. **Outbox Synchronization Engine (`SyncEngineService`)**
   - Background worker executing periodically (e.g., every 30 seconds) or on trigger.
   - Bounded batch processor (max 50 events per HTTP payload).
   - Exponential backoff with decorrelated jitter to handle Google API rate limits (HTTP 429).
5. **Inbound Delta Sync Service (`InboundSyncService`)**
   - Polls Master Sheet for remote administrative changes made in Google Drive (e.g., new lookup items in `20_LOOKUPS`, fee changes in `12_SERVICES`, or schedule adjustments in `07_DOCTOR_SCHEDULES`) and hydrates local storage.
6. **Network Connectivity Monitor (`NetworkConnectivityService`)**
   - Reactive stream detecting online/offline transitions via browser `window.onOnline` / `window.onOffline` events.

---

## 4. Proposed Phase 3 Architecture

The integrated architecture establishes a strict unidirectional data flow for writes, combined with an outbox sync worker and secure cloud gateway:

```
[ USER INTERACTION (Frozen UI) ]
               │
               ▼
[ REPOSITORY WRITE (ACID Transaction) ]
  ├── 1. Writes to Local Storage (Immediate UI feedback <50ms)
  └── 2. Stages SyncOutboxEvent to 'sync_outbox' table
               │
               ▼
[ LOCAL DATABASE (Authoritative for Workstation) ]
               │
               ▼
[ SYNC ENGINE WORKER (Background Loop) ]
  ├── Check Network Connectivity (Online?)
  ├── Check OAuth Status (Token Valid?)
  ├── Dequeue Bounded Batch (<= 50 pending events)
  ├── Mark Events 'in_flight'
  │
  ├── [ MASTER SHEET ADAPTER ]
  │     └── Transform Entity Map -> 20-Sheet Ordered Row Vector
  │
  ├── [ GOOGLE SHEETS / DRIVE GATEWAY ]
  │     ├── HTTPS POST sheets.googleapis.com/...:append
  │     └── Verify Row Hash & HTTP 200 Response
  │
  ├── Success: Mark Outbox Events 'acknowledged' & Record SyncManifest
  └── Failure: Record Error, Increment Retry, Exponential Backoff
```

### Core Architecture Axioms:
1. **Local-First Supremacy:** The UI *never* awaits network responses from Google Drive or Google Sheets. All operations execute immediately against `LocalDatabase`.
2. **Outbox Durability:** Every mutation that must reach the Master Sheet is captured in the transactional outbox (`sync_outbox`) before the repository method returns.
3. **Bounded Idempotent Batches:** Outbox processing occurs in discrete, bounded batches (maximum 50 events) with unique idempotency keys, preventing partial payload memory spikes and duplicate row creation.
4. **Zero UI Disruption:** Network drops, quota exhaustion, or OAuth expiration never trigger UI crash dialogs; they gracefully transition `SyncHealthState` to `offline` or `syncError`.

---

## 5. Authentication Architecture

Google Authentication must operate securely in a web browser without compromising clinical data or hardcoding client secrets.

```
┌──────────────────┐       1. Auth Request + Code Challenge (PKCE)       ┌────────────────────────┐
│                  ├────────────────────────────────────────────────────►│                        │
│                  │       2. User Consent & Redirection with Auth Code  │  Google Accounts       │
│                  │◄────────────────────────────────────────────────────┤  OAuth 2.0 Endpoint    │
│  Apna Clinic     │                                                     └────────────────────────┘
│  Web Application │       3. Exchange Auth Code + Code Verifier                   ▲
│  (Browser)       ├───────────────────────────────────────────────────────┘
│                  │       4. Access Token (1 hr) + Refresh Token
│                  ▼
┌────────────────────────────────────────────────────────┐
│  LOCAL TOKEN VAULT (AES-256 Encrypted In-Memory/Prefs) │
│  - Access Token (Short-lived, memory cache)            │
│  - Refresh Token (Encrypted with clinic hardware key)  │
│  - Token Expiry (UTC Timestamp)                        │
└────────────────────────────────────────────────────────┘
```

### 5.1 OAuth Protocol Specification
- **Flow:** RFC 7636 Authorization Code Flow with Proof Key for Code Exchange (PKCE).
- **Target Audience:** Single-Page Web Applications (SPA). No backend client secrets stored in JavaScript bundles.
- **Client Configuration:**
  - `GOOGLE_CLIENT_ID`: Retrieved at runtime from `.env` / `AppConfig`.
  - `REDIRECT_URI`: Registered clinic web origin (e.g., `http://localhost:8080` or production domain).
  - `SCOPES`:
    - `https://www.googleapis.com/auth/drive.file` (Restricted: grants access *only* to files created or opened by Apna Clinic; never accesses the user's personal Drive).
    - `https://www.googleapis.com/auth/spreadsheets` (Read/write access to clinic workbooks).
    - `openid`, `email`, `profile` (Identity display on workstation header).

### 5.2 Session Persistence & Silent Refresh
1. **Initial Login:** User clicks "Sign in with Google" on `LoginScreen`. Browser launches Google OAuth popup or redirect.
2. **Token Acquisition:** Upon receiving authorization code, exchange for access token and refresh token using PKCE `code_verifier`.
3. **Encrypted Vault Storage:**
   - Access token stored in memory (`SessionState`).
   - Refresh token encrypted with `LocalEncryptionService` (using device-specific salt) and stored in browser storage (`local_keys`).
4. **Silent Refresh Daemon:**
   - An interceptor monitors token expiration. At $T - 5\text{ minutes}$ before expiry, a background request exchanges the refresh token for a fresh access token without user prompt.
5. **Re-Authentication & Offline Grace:**
   - If refresh token expires or is revoked (HTTP 400 `invalid_grant`), the application flags `SessionState.isGoogleAuthenticated = false` and queues sync events locally.
   - The application *never logs the doctor out of local workstation mode* when offline.

---

## 6. Google Drive Architecture

Google Drive serves as the secure cloud document store housing the canonical Master Sheet and encrypted database archives.

### 6.1 Folder Hierarchy on Google Drive
Apna Clinic maintains a deterministic, isolated folder hierarchy within the authorized Google Drive account:

```
Google Drive Root
└── ApnaClinic/
    └── {clinic_id}/
        ├── Master_Workbooks/
        │   └── ApnaClinic_Master_Template_{clinic_id}.xlsx  <-- Canonical Master Sheet
        ├── Backups/
        │   └── Encrypted/
        │       ├── backup_{clinic_id}_2026-09-29T10-00-00Z.enc
        │       └── backup_{clinic_id}_2026-09-30T10-00-00Z.enc
        └── Attachments/
            └── {patient_id}/
                └── lab_report_scan_01.pdf
```

### 6.2 Canonical Sheet Discovery & Binding Algorithm
When Google Drive sync is initiated:
1. **Search Phase:** Query Drive API:
   `mimeType = 'application/vnd.google-apps.spreadsheet' and name contains 'ApnaClinic_Master_' and trashed = false`
2. **Match Evaluation:**
   - If an existing workbook matching the clinic ID is found, bind its `spreadsheetId` to local configuration.
   - Verify that all 20 canonical worksheets exist and header columns match the frozen schema.
3. **Provisioning Fallback:**
   - If no workbook is found, the system uploads/creates a new Google Spreadsheet cloned from the canonical schema of `APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL.xlsx`, initializing all 20 worksheets with exact column headers and named ranges.
4. **Error Handling:**
   - `404 Not Found` (File deleted remotely): Log warning, preserve outbox, prompt Clinic Owner via `SyncHealthNotifier` to re-bind or re-provision.
   - `403 Forbidden` (Insufficient permissions): Flag permission failure, fallback to local standalone mode.

---

## 7. Offline-First Architecture

The offline-first guarantee is the core reliability foundation of Apna Clinic (PRD Principle 1).

### 7.1 Separation of Live Operational Store vs Cloud Sync Target
- **Live Database:** `LocalDatabase` (In-Memory + Web Persistence / IndexedDB). It handles 100% of read queries, appointments, check-ins, queue operations, vitals, billing, and receipts.
- **Latency Guarantee:** Every local UI mutation completes in $<50\text{ ms}$, completely independent of network state.
- **Internet Independence:** The clinic can operate for days without internet connectivity. Tokens are issued, patients are seen, prescriptions are printed, and bills are settled entirely offline.

### 7.2 Outbox Queue Durability
- Whenever a domain entity is saved or updated, the repository creates a `SyncOutboxEvent` within the same ACID transaction:
  ```dart
  await _db.transaction((tx) async {
    await _db.upsert('Patients', patient.patientId, patient.toMap(), tx: tx);
    final outboxEvent = SyncOutboxEvent(
      outboxEventId: 'outbox_patient_${patient.patientId}_${DateTime.now().millisecondsSinceEpoch}',
      clinicId: patient.clinicId,
      entityType: 'Patients',
      entityId: patient.patientId,
      operation: OutboxOperation.insert,
      payloadJson: jsonEncode(patient.toMap()),
      createdAt: DateTime.now().toUtc(),
      idempotencyKey: 'patient_${patient.patientId}_${patient.updatedAt.millisecondsSinceEpoch}',
    );
    await _db.upsert('sync_outbox', outboxEvent.outboxEventId, outboxEvent.toMap(), tx: tx);
  });
  ```
- If the browser tab is closed or the workstation restarts, the outbox events remain safely persisted in local storage and resume syncing upon reload.

---

## 8. Synchronization Architecture

The synchronization engine coordinates bi-directional data flow while respecting Google API quotas and clinical safety invariants.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        SYNC ENGINE EXECUTION CYCLE                     │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   1. WAKEUP (Timer: 30s OR Manual Trigger OR Online Event)             │
│        │                                                               │
│   2. PRE-FLIGHT VERIFICATION                                           │
│        ├── Is Network Available? ──[NO]──► Sleep until online          │
│        ├── Is OAuth Valid?       ──[NO]──► Silent Refresh              │
│        └── Is Sync Busy?         ──[YES]─► Abort (Prevent concurrency) │
│        │                                                               │
│   3. DEQUEUE OUTBOX BATCH                                              │
│        └── Query 'sync_outbox' WHERE status IN ('pending', 'failed')   │
│            ORDER BY created_at ASC LIMIT 50                            │
│        │                                                               │
│   4. MARK IN-FLIGHT                                                    │
│        └── Update batch events status = 'in_flight'                    │
│        │                                                               │
│   5. TRANSFORM & APPEND ROWS                                           │
│        ├── Group events by target worksheet                            │
│        ├── Map JSON payload -> Ordered row cell values                 │
│        └── Call Google Sheets API (appendRows / batchUpdate)           │
│        │                                                               │
│   6. BATCH ACKNOWLEDGEMENT & MANIFEST                                  │
│        ├── Update events status = 'acknowledged'                       │
│        ├── Generate SyncManifest (SHA-256 hash, record counts)         │
│        └── Save manifest to 'Sync_Manifest' local & remote             │
│        │                                                               │
│   7. ERROR RECOVERY (If HTTP 429 / 5xx / Network Drop)                 │
│        ├── Increment retry_count on each failed event                  │
│        ├── Mark status = 'failed'                                      │
│        └── Calculate exponential backoff: min(300s, 2^retry * 1000ms)  │
└────────────────────────────────────────────────────────────────────────┘
```

### 8.1 Google API Rate Limit & Batching Controls
- **Google Sheets API Quota:** 300 requests per minute per project, 60 requests per minute per user.
- **Batch Bounding:** Maximum 50 events per sync batch.
- **Bulk Append Optimization:** Events targeting the same worksheet are aggregated into a single `values.append` or `values.batchUpdate` request, reducing API calls from $N$ to 1 per sheet.
- **Jittered Backoff:** When HTTP 429 (`QuotaExceededFailure`) occurs, the engine pauses for $t = (2^{\text{retryCount}} \times 1.5\text{ s}) + \text{random}(0, 1000\text{ ms})$.

### 8.2 Application Restart Resilience
- If the browser crashes or is closed while events are marked `in_flight`:
  - Upon startup, the engine runs an outbox reconciliation query: any event remaining in `in_flight` for $>5\text{ minutes}$ is reset to `pending`.
  - The `idempotencyKey` prevents duplicate insertion in the Master Sheet even if a previous network response was lost.

---

## 9. Data Mapping Table

Every application domain entity maps precisely to a canonical Master Sheet worksheet in `APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL.xlsx`.

| UI / Domain Entity | Local Table | Master Sheet Worksheet | Primary Key | Key Foreign Keys | Sync Direction | Sync Considerations & Transformations |
|---|---|---|---|---|---|---|
| **Clinic Config** | `Clinic_Config` | `01_SETTINGS` | `setting_id` | N/A | Bidirectional ($\leftrightarrow$) | Global parameters; currency conversions, business date (`$D$23`). |
| **User Identity** | `Staff` | `02_USERS` | `user_id` | `role_id` $\to$ `03_ROLES` | Bidirectional ($\leftrightarrow$) | Multi-device user authentication roster. |
| **Role Permissions**| N/A | `03_ROLES` | `role_id` | N/A | Downstream ($\leftarrow$) | Master Sheet authoritative. Defines RBAC permissions. |
| **Doctor Roster** | `Doctors` | `04_DOCTORS` | `doctor_id` | `room_id` $\to$ `16_ROOMS` | Bidirectional ($\leftrightarrow$) | Consultation fee converted: $\text{INR} = \text{paise} / 100$. |
| **Patient Profile** | `Patients` | `05_PATIENTS` | `patient_id` | `created_by` $\to$ `02_USERS` | Upstream ($\to$) | Demographic master. Normalized phone matching for deduplication. |
| **Appointments** | `Appointments` | `06_APPOINTMENTS` | `appointment_id` | `patient_id` $\to$ `05_PATIENTS`, `doctor_id` $\to$ `04_DOCTORS` | Bidirectional ($\leftrightarrow$) | Token index mapped; slot conflicts detected by doctor schedule. |
| **Doctor Schedules**| N/A | `07_DOCTOR_SCHEDULES`| `schedule_id`| `doctor_id` $\to$ `04_DOCTORS` | Downstream ($\leftarrow$) | Recurring weekly clinic shifts and slot allocations. |
| **Live Queue** | `Visits`, `Queue_Events`| `08_QUEUE` | `queue_id` | `appointment_id` $\to$ `06_APPOINTMENTS`, `doctor_id` $\to$ `04_DOCTORS` | Upstream ($\to$) | Ephemeral daily sequence. Append-only queue status transitions. |
| **Consultations** | `Visits` (Clinical) | `09_CONSULTATIONS` | `consultation_id`| `appointment_id` $\to$ `06_APPOINTMENTS`, `patient_id` $\to$ `05_PATIENTS` | Upstream ($\to$) | Doctor-authored encounter. Clinical notes, vitals, diagnosis. |
| **Billing / Invoice**| `Invoices` | `10_BILLING` | `invoice_id` | `patient_id` $\to$ `05_PATIENTS`, `appointment_id` $\to$ `06_APPOINTMENTS` | Upstream ($\to$) | Financial record. Formulas `=F-G+H` (Total) & `=I-J` (Due) maintained. |
| **Payments** | `Payments` | `11_PAYMENTS` | `payment_id` | `invoice_id` $\to$ `10_BILLING`, `patient_id` $\to$ `05_PATIENTS` | Upstream ($\to$) | Cash/UPI/Card ledger. Append-only; refunds recorded as reversal. |
| **Service Catalog**| `Fee_Catalog` | `12_SERVICES` | `service_id` | N/A | Downstream ($\leftarrow$) | Clinic tariff master. Standard pricing and GST categories. |
| **Medical Records**| N/A | `13_MEDICAL_RECORDS`| `record_id` | `patient_id` $\to$ `05_PATIENTS`, `consultation_id` $\to$ `09_CONSULTATIONS`| Upstream ($\to$) | External PDF/lab attachments stored in Google Drive folder. |
| **Prescriptions** | `Visits` (Rx) | `14_PRESCRIPTIONS` | `prescription_id`| `consultation_id` $\to$ `09_CONSULTATIONS`, `patient_id` $\to$ `05_PATIENTS`| Upstream ($\to$) | Itemized drug lines: name, dosage, frequency, duration, route. |
| **Follow-ups** | `Followups` | `15_FOLLOW_UPS` | `followup_id` | `patient_id` $\to$ `05_PATIENTS`, `doctor_id` $\to$ `04_DOCTORS` | Bidirectional ($\leftrightarrow$) | Recall dates and administrative continuity notes. |
| **Rooms / Chambers**| N/A | `16_ROOMS` | `room_id` | `assigned_doctor_id` $\to$ `04_DOCTORS`| Downstream ($\leftarrow$) | Physical consultation chambers and procedure rooms. |
| **Audit Trail** | `Audit_Events` | `17_AUDIT_LOG` | `audit_id` | `user_id` $\to$ `02_USERS` | Upstream ($\to$) | Immutable security log of all patient and financial operations. |
| **Notifications** | N/A | `18_NOTIFICATIONS` | `notification_id`| `patient_id` $\to$ `05_PATIENTS`, `appointment_id` $\to$ `06_APPOINTMENTS`| Upstream ($\to$) | SMS / WhatsApp reminder delivery status log. |
| **Reporting KPIs** | `Daily_Summary` | `19_REPORTING` | `kpi_id` | Refer to Dynamic Formulas | Downstream ($\leftarrow$) | 22 Dynamic Excel Formulas (`KPI-000` to `KPI-013`). Read-only for app. |
| **Lookup Config** | `Lookup_Config` | `20_LOOKUPS` | `lookup_id` | N/A | Downstream ($\leftarrow$) | 103 canonical lookup values and 23 named validation ranges. |

---

## 10. Conflict Resolution Strategy

When multiple workstations or offline periods cause concurrent mutations, conflicts must be resolved deterministically without human confusion or data loss.

### 10.1 Partitioned Data Ownership Hierarchy
Apna Clinic enforces a **Three-Tier Ownership Model**:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        DATA OWNERSHIP TIERS                            │
├────────────────────────────────────────────────────────────────────────┤
│ TIER 1: CLINICAL & OPERATIONAL DATA (Local Workstation Authoritative)  │
│   - Entities: Patients, Consultations, Prescriptions, Queue            │
│   - Resolution: Workstation Wins + Clinical Safety Override            │
├────────────────────────────────────────────────────────────────────────┤
│ TIER 2: FINANCIAL & AUDIT LEDGERS (Append-Only Invariant)              │
│   - Entities: Billing, Payments, Refunds, Audit Logs                   │
│   - Resolution: Zero Overwrite. Immutable Transaction Log              │
├────────────────────────────────────────────────────────────────────────┤
│ TIER 3: CLINIC CONFIGURATION & CATALOGS (Master Sheet Authoritative)   │
│   - Entities: Lookups, Service Catalog, Roles, Doctor Schedules        │
│   - Resolution: Master Sheet Wins. Hydrates Local Stores Downstream    │
└────────────────────────────────────────────────────────────────────────┘
```

### 10.2 Conflict Resolution Algorithms

#### 1. Tier 1: Clinical Data (Workstation Wins)
- If a patient record or consultation note is modified both locally and remotely:
  - The local workstation consultation note is medically authoritative for that patient encounter.
  - If a patient's demographic details (phone, address) differ, the record with the higher UTC `updated_at` timestamp wins (Last-Write-Wins with field-level merging).

#### 2. Tier 2: Financial Ledgers (Append-Only)
- Financial transactions (`10_BILLING`, `11_PAYMENTS`, `12_REFUNDS`) are **immutable**.
- An existing row in `10_BILLING` or `11_PAYMENTS` is never updated or deleted by a sync conflict.
- Voided invoices or corrected charges must be issued as new reversal rows or adjustments, matching standard Indian accounting standards and preventing receipt tampering.

#### 3. Tier 3: Central Catalogs (Master Sheet Wins)
- When the clinic administrator updates consultation fees in `12_SERVICES` or adds a new lookup value in `20_LOOKUPS` directly in the Master Sheet:
  - During the inbound sync cycle, the local database detects the updated `updated_at` timestamp in the Master Sheet.
  - Local cached catalog rows are overwritten by the canonical Master Sheet values.

---

## 11. Security Model

Security and patient confidentiality are engineered into every layer in strict compliance with the **Digital Personal Data Protection Act (DPDPA 2023)** and clinical data privacy standards.

```
┌────────────────────────────────────────────────────────────────────────┐
│                       SECURITY & DATA PROTECTION                       │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Zero Plaintext Credentials: No API keys, OAuth secrets in source.   │
│ 2. Encrypted Token Vault: Refresh tokens stored via AES-256 + salt.    │
│ 3. Clinical Secret Boundary: Sensitive diagnostic data isolated.       │
│ 4. Least-Privilege OAuth: 'drive.file' scope limits Drive access.      │
│ 5. Immutable Audit Trail: Every read/write logged with actor and role. │
└────────────────────────────────────────────────────────────────────────┘
```

1. **Zero Secret Exposure:**
   - No Google Cloud client secrets, private keys, or passwords are hardcoded in the Flutter source code or git history.
   - Web OAuth utilizes PKCE (Proof Key for Code Exchange), which does not require a client secret.
2. **Local Token Vault Protection:**
   - OAuth tokens cached in browser `localStorage` or `IndexedDB` are encrypted using `LocalEncryptionService` with a deterministic, clinic-scoped key derived from device fingerprinting and PBKDF2.
3. **Sensitive Clinical Boundary (`ReasonForVisitSecret`):**
   - As specified in TRD Section 12, highly sensitive patient diagnostic notes or stigma-sensitive clinical complaints can be stored in the dedicated local table `reason_for_visit_secrets` encrypted under the clinic's local AES key.
   - The Master Sheet stores an opaque cryptographic reference (`reason_for_visit_encrypted_ref`), preventing exposure of sensitive diagnostic narratives to spreadsheet viewers who do not hold the clinic decryption key.
4. **Restricted OAuth Scope (`drive.file`):**
   - The application strictly requests `https://www.googleapis.com/auth/drive.file`. This ensures Apna Clinic *cannot access, list, or tamper with any other user files in Google Drive*, adhering strictly to the principle of least privilege.
5. **Tamper-Evident Audit Logging:**
   - Every login, role change, billing adjustment, patient record deletion, or backup generation is written to `17_AUDIT_LOG` with `user_id`, `user_role`, `device_id`, `action`, `entity_type`, and `timestamp`.

---

## 12. Error & Recovery Model

The integration engine implements resilient failure handling for intermittent network drops, Google Drive outages, and session expiration.

```
┌─────────────────────────┬────────────────────────────┬───────────────────────────────────────┐
│ Failure Mode            │ Detection Mechanism        │ Automated Recovery Strategy           │
├─────────────────────────┼────────────────────────────┼───────────────────────────────────────┤
│ Network Drop (Offline)  │ Browser navigator.onLine / │ Pause sync loop. Continue local UI    │
│                         │ HTTP SocketException       │ operations with zero interruption.    │
├─────────────────────────┼────────────────────────────┼───────────────────────────────────────┤
│ OAuth Token Expired     │ HTTP 401 Unauthorized from │ Trigger Silent Token Refresh via      │
│                         │ Google API                 │ refresh token; retry batch once.      │
├─────────────────────────┼────────────────────────────┼───────────────────────────────────────┤
│ Refresh Token Revoked   │ HTTP 400 'invalid_grant'   │ Set isGoogleAuthenticated = false.    │
│                         │ on token endpoint          │ Preserve outbox; alert Clinic Owner.  │
├─────────────────────────┼────────────────────────────┼───────────────────────────────────────┤
│ Rate Limit Exceeded     │ HTTP 429 Too Many Requests │ Trigger exponential backoff:          │
│                         │ from Google Sheets API     │ t = min(300s, 2^retry * 1.5s + jitter)│
├─────────────────────────┼────────────────────────────┼───────────────────────────────────────┤
│ Drive File Not Found    │ HTTP 404 on spreadsheetId  │ Search Drive for clone; if missing,   │
│                         │                            │ prompt owner to re-provision sheet.   │
├─────────────────────────┼────────────────────────────┼───────────────────────────────────────┤
│ Corrupted Row Data      │ JSON Deserialization error │ Quarantine corrupted event to         │
│                         │ on outbox payload          │ 'sync_quarantine' table; proceed.     │
├─────────────────────────┼────────────────────────────┼───────────────────────────────────────┤
│ Workstation Crash       │ Startup recovery check     │ Reset events stuck in 'in_flight'     │
│                         │                            │ for >5 mins back to 'pending'.        │
└─────────────────────────┴────────────────────────────┴───────────────────────────────────────┘
```

---

## 13. Dependency Changes Required

To implement the Phase 3 architecture, minimal, verified dependencies should be integrated:

```yaml
# Additions to pubspec.yaml for Phase 3 Implementation

dependencies:
  # Official Google Sign-In with Web GIS (Google Identity Services) support
  google_sign_in: ^6.2.2

  # Official Google APIs Client Library (Drive v3 & Sheets v4)
  googleapis: ^13.2.0
  googleapis_auth: ^1.6.0

  # Connectivity Monitoring (Reactive online/offline streams)
  connectivity_plus: ^6.1.1
```

### Dependency Audit & Compatibility Analysis:
- `google_sign_in: ^6.2.2`: Fully supports Flutter Web via Google Identity Services (GIS) without deprecated JavaScript SDKs.
- `googleapis: ^13.2.0`: Fully typed Dart representations for `DriveApi` and `SheetsApi`, eliminating manual JSON/HTTP payload formatting.
- `connectivity_plus: ^6.1.1`: Detects real-time browser network disconnections without polling.
- **Zero Impact on UI:** These libraries operate strictly in the `infrastructure/` and `application/` background services.

---

## 14. Configuration / Environment Requirements

### 14.1 Google Cloud Platform (GCP) Console Setup
1. **GCP Project:** Create a project named `apna-clinic-prod`.
2. **Enabled APIs:**
   - Google Drive API (`drive.googleapis.com`)
   - Google Sheets API (`sheets.googleapis.com`)
3. **OAuth 2.0 Credentials:**
   - Application Type: **Web application**.
   - Authorized JavaScript origins:
     - `http://localhost:8080` (Local development)
     - `https://your-clinic-domain.web.app` (Production web hosting)
   - Authorized redirect URIs:
     - `http://localhost:8080`
     - `https://your-clinic-domain.web.app`

### 14.2 Environment Variables (`.env`)
```bash
# Apna Clinic Production Environment Configuration
APP_ENV=production
APP_BASE_URL=https://app.apnaclinic.in

# Google Cloud OAuth 2.0 Web Client ID
GOOGLE_CLIENT_ID=xxxxxxxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com

# Target Drive Folder Configuration
DRIVE_ROOT_FOLDER_NAME=ApnaClinic
DRIVE_BACKUP_FOLDER_NAME=Backups

# Sync Engine Scheduling
SYNC_INTERVAL_SECONDS=30
SYNC_BATCH_LIMIT=50
SYNC_MAX_RETRY_COUNT=5
```

---

## 15. Testing Strategy

Phase 3 implementation will adhere to a rigorous verification methodology to guarantee zero regressions and offline stability:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        PHASE 3 TESTING MATRIX                          │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Offline Simulation: Disconnect network; verify UI <50ms mutations.  │
│ 2. Outbox Batch Test: Verify limit 50 and bounded FIFO queue ordering. │
│ 3. Mock Sheets Client: Verify HTTP 200 append with row hash matching.  │
│ 4. Token Refresh Test: Inject expired access token; verify auto-renew. │
│ 5. Rate Limit Backoff: Inject HTTP 429; verify exponential retry delay.│
│ 6. Excel Integrity Check: Verify formulas recalculate without errors.  │
│ 7. Phase 1 UI Freeze Check: Verify zero UI pixel/layout modifications. │
└────────────────────────────────────────────────────────────────────────┘
```

1. **Unit Test Suite (`test/infrastructure/`):**
   - `outbox_queue_test.dart`: Verifies staging, in-flight transitions, acknowledgements, and retry count increments.
   - `master_sheet_adapter_test.dart`: Validates serialization of all 19 domain entities into the exact 20-sheet column layout of `APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL.xlsx`.
   - `token_vault_test.dart`: Verifies AES-256 encryption/decryption of cached OAuth tokens.
2. **Integration Test Suite (Mock HTTP):**
   - `google_drive_sync_test.dart`: Mocks Google Drive v3 and Sheets v4 HTTP endpoints to simulate successful sync, rate-limiting (429), and token expiration (401).
3. **Offline Invariant Verification:**
   - Simulate sudden browser disconnect (`navigator.onLine = false`).
   - Create 10 patients, 5 appointments, and 3 invoices.
   - Verify that all records display instantly in the Phase 1 UI and are queued in `sync_outbox`.
   - Reconnect network; verify that all events drain cleanly into the Master Sheet.

---

## 16. Phase 3 Implementation Sequence

To ensure systematic development without disrupting frozen assets, Phase 3 will be executed across 5 strict milestones:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        PHASE 3 ROADMAP MILESTONES                      │
├────────────────────────────────────────────────────────────────────────┤
│ MILESTONE 1: Foundation & Dependencies                                 │
│   - Update pubspec.yaml (google_sign_in, googleapis, connectivity)     │
│   - Configure .env and runtime AppConfig credentials                   │
├────────────────────────────────────────────────────────────────────────┤
│ MILESTONE 2: Master Sheet Schema Alignment                             │
│   - Upgrade GoogleSheetsClient with 20 canonical worksheets            │
│   - Implement MasterSheetAdapter mapping domain entities to rows       │
├────────────────────────────────────────────────────────────────────────┤
│ MILESTONE 3: Google Authentication & Token Vault                       │
│   - Implement GoogleOAuthService with PKCE and silent refresh          │
│   - Wire session provider without modifying UI widgets                │
├────────────────────────────────────────────────────────────────────────┤
│ MILESTONE 4: Outbox Sync Engine Daemon                                 │
│   - Implement SyncEngineService background worker (bounded batch 50)   │
│   - Implement jittered exponential backoff and idempotency protection  │
├────────────────────────────────────────────────────────────────────────┤
│ MILESTONE 5: End-to-End Verification & QA Gate                         │
│   - Execute real Excel recalculation test flow                         │
│   - Run full unit and integration test suites                          │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 17. Risks and Mitigations

| Identified Risk | Severity | Potential Impact | Architectural Mitigation |
|---|---|---|---|
| **Google API Rate Limit (HTTP 429)** | High | Sync stalls during peak clinic hours with high patient volume. | Bounded batches (50 events), bulk row append requests, and jittered exponential backoff ($t = 2^{\text{retry}} \times 1.5\text{s}$). |
| **Silent Token Expiration** | Medium | Outbox sync fails silently after 1 hour of clinic operation. | Proactive background refresh daemon renewing access tokens 5 minutes prior to expiry; zero UI popups. |
| **Master Sheet Structure Tampering** | High | A clinic user manually renames or deletes columns in Google Sheets. | Header validation check during pre-flight discovery. If columns do not match frozen schema, alert owner and log warning. |
| **Concurrent Workstation Edits** | Medium | Two receptionists book overlapping appointments for the same doctor. | Partitioned ownership rules; Doctor Schedule slot validation in local database before staging outbox event. |
| **Accidental UI Regression** | Critical | Modifying UI files during data binding breaks Phase 1 approval. | **Absolute file freeze rule.** UI widgets consume Riverpod providers that already exist. No presentation files are touched. |

---

## 18. Files That WILL Need Modification

When Phase 3 implementation begins, **ONLY** the following infrastructure and application layer files will be created or modified:

### A. Existing Files to Modify (Infrastructure & Config Only)
1. `pubspec.yaml` — Add `google_sign_in`, `googleapis`, `googleapis_auth`, `connectivity_plus`.
2. `lib/core/config/app_config.dart` — Add OAuth client ID and sync interval parameters.
3. `lib/infrastructure/google/google_sheets_client.dart` — Update 19-sheet schema to canonical 20-sheet schema.
4. `lib/infrastructure/repositories/patient_repository.dart` (and sibling repos) — Ensure `payloadJson` utilizes `jsonEncode()` rather than `.toString()`.
5. `lib/application/providers.dart` — Wire `SyncEngineService` and `GoogleOAuthService` into `sessionProvider` and `syncHealthProvider`.

### B. New Files to Create in Phase 3
1. `lib/infrastructure/google/oauth/google_oauth_service.dart` — OAuth 2.0 PKCE client.
2. `lib/infrastructure/google/oauth/token_vault.dart` — Encrypted token storage.
3. `lib/infrastructure/google/sheets/master_sheet_adapter.dart` — Domain-to-Row serializer for 20 canonical worksheets.
4. `lib/infrastructure/google/drive/drive_sheet_service.dart` — Drive folder and file binding.
5. `lib/application/sync/sync_engine_service.dart` — Background outbox sync daemon.
6. `lib/application/sync/network_connectivity_service.dart` — Online/offline stream.

---

## 19. Files That MUST NOT Be Modified

The following files represent frozen engineering assets and **MUST NEVER BE MODIFIED** during Phase 3:

```
⛔ ABSOLUTE FROZEN ASSETS LIST ⛔
================================================================================
1. ALL Phase 1 Presentation Files:
   - lib/presentation/appointments/*
   - lib/presentation/auth/*
   - lib/presentation/billing/*
   - lib/presentation/dashboard/*
   - lib/presentation/doctor/*
   - lib/presentation/onboarding/*
   - lib/presentation/patients/*
   - lib/presentation/queue/*
   - lib/presentation/reports/*
   - lib/presentation/settings/*
   - lib/presentation/shared/*

2. Phase 2 Canonical Master Sheet Workbook & Schema:
   - APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL.xlsx
   - All 20 canonical worksheet names, orders, and column headers.
   - All 23 named validation ranges (LK_*).
   - All 22 dynamic Excel formulas on 19_REPORTING and 10_BILLING.

3. Core Design System & Navigation:
   - lib/core/routing/app_router.dart
   - lib/main.dart (UI theme, colors, typography, AppBar, and Card themes)
================================================================================
```

---

## 20. Explicit Phase 3 Stop Conditions

To maintain strict architectural discipline and protect AI credits, Phase 3 implementation must adhere to the following mandatory stop checkpoints:

1. **Pre-Implementation Sign-off Gate (Current Turn):**
   - STOP immediately upon generating `PHASE_3_ARCHITECTURE_PLAN.md`.
   - Do NOT write production integration code or install dependencies until explicit user authorization is received.
2. **Dependency & Configuration Gate:**
   - When authorized, update `pubspec.yaml` and `.env.example`, then STOP and verify `flutter pub get` and static analysis pass cleanly.
3. **Master Sheet Schema Alignment Gate:**
   - Complete `MasterSheetAdapter` for the 20 worksheets, verify against `APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL.xlsx`, then STOP and run schema unit tests.
4. **Authentication Gate:**
   - Implement `GoogleOAuthService` and `TokenVault`, test token refresh with mock responses, then STOP.
5. **Sync Engine Gate:**
   - Implement `SyncEngineService`, execute end-to-end bounded batch outbox test, verify zero UI modifications, then STOP.
