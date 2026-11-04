# Apna Clinic — Architecture Decision Records (ADRs)

**Version:** 1.0  
**Baseline Date:** 22 September 2026  
**Status:** Approved  

---

## ADR-001: Flutter Web for Primary Reception and Clinic Workstations

### Context
Outpatient clinics in India need a zero-install or quick-install experience on reception desktops/laptops (predominantly Windows 1366×768 or 1920×1080) with responsive usability for doctor/owner mobile devices.

### Decision
We use Flutter Web (Material 3) as the initial primary delivery platform.
- Provides desktop-first density, responsive layouts, native-feeling keyboard navigation, and high-performance canvas/HTML rendering.
- Codebase can be cleanly packaged for Android or desktop in subsequent phases without rewriting domain or presentation layers.

### Consequences
- Browser storage persistence and memory limits must be explicitly managed.
- Browser print dialog must be utilized for printing rather than raw socket printing.

---

## ADR-002: Local-First Architecture with IndexedDB Persistence

### Context
Internet connectivity in small Indian clinics is frequently intermittent. Receptionists cannot tolerate blocking latency, slow page loads, or failed registrations due to network dropouts.

### Decision
All operational transactions (patient registration, visit creation, token allocation, queue transitions, billing, and printing) commit first to a browser-local database (Drift backed by IndexedDB).
- The local operational database is the primary source of truth for current operational state.
- Local operations require 0 network API calls.

### Consequences
- Browser storage is not guaranteed permanent. The app must request persistent storage (`navigator.storage.persist()`) and mandate regular encrypted backups to Google Drive.

---

## ADR-003: Single-Writer Primary Operational Device for MVP

### Context
Google Sheets does not provide row-level distributed locking or ACID transaction semantics for concurrent writers across multiple devices.

### Decision
For MVP, each clinic designates exactly one **Primary Operational Device** (receptionist workstation) that holds write authority for token allocation, visit creation, and invoice issuance.
- Secondary devices (e.g. doctor mobile or owner dashboard) operate in read-only mode or submit requests via coordinated local queue states.
- Simultaneous multi-device concurrent writes to Google Sheets are explicitly blocked until a backend coordination service is introduced.

### Consequences
- Eliminates split-brain token counters and race conditions in financial numbering without requiring expensive backend infrastructure.

---

## ADR-004: Google Sheets as an Administrative Mirror, NOT a Transactional Database

### Context
Using Google Sheets as a real-time transactional database causes race conditions, token conflicts, and rapid 429 quota exhaustion (Sheets limits read/write requests per project and per user).

### Decision
Google Sheets is used strictly as an **append-only, batched administrative record**.
- Mutations are written to a durable local outbox and synced to Google Sheets in bounded batches (50–100 events) using `batchUpdate`.
- Searches, token generations, queue movements, invoice calculations, and slip printing NEVER read or write directly to Sheets synchronously.

### Consequences
- Keeps cloud API consumption well within free Google project quotas (~2–7 Sheets requests/clinic/day).

---

## ADR-005: Google Drive Encrypted Snapshots for Backup & Disaster Recovery

### Context
Because browser storage can be cleared or evicted, clinic data must be backed up durably to clinic-owned cloud storage.

### Decision
Full database snapshots are serialized, encrypted client-side using WebCrypto AES-GCM, hashed with SHA-256, and uploaded to the clinic's own Google Drive (`ApnaClinic/{clinic_id}/Backups/Encrypted/`) along with a tamper-evident `backup_manifest.json`.
- Restore requires checksum verification and decryption before writing to local storage.
- If checksum or decryption fails, the restore immediately aborts with zero database overwrite.

### Consequences
- Total protection against browser data loss while preserving clinic data ownership.

---

## ADR-006: Sensitive Reason-for-Visit Isolation & Encryption

### Context
Even in an administrative system, a patient-reported symptom or reason for visit is sensitive health personal data under Indian DPDP Act.

### Decision
- Reason for visit is stored locally in an encrypted envelope (`reason_for_visit_ciphertext`).
- In Google Sheets, only an opaque reference (`reason_for_visit_encrypted_ref`) is synchronized. Plaintext illness descriptions are NEVER written to ordinary Sheets tabs, URLs, payment references, logs, or analytics.
- Full text is recoverable only through the authenticated, encrypted Drive backup.

### Consequences
- Complete compliance with privacy-by-design principles.

---

## ADR-007: Scoped Monotonic Token Allocation

### Context
Token numbers must be human-readable, easily announced in clinic waiting areas, and reset daily per doctor, while remaining globally unique across the system.

### Decision
- Human-facing token scope: `{clinic_id}:{doctor_id}:{local_date}` (e.g., `clinic1:doc1:2026-09-22`).
- Token counter increments monotonically in a local transaction on the primary writer.
- Globally unique system identity is an immutable UUIDv7 `visit_id`.
- Cancelled or no-show tokens are never recycled.

### Consequences
- Guarantees zero duplicate tokens even during network outages, retries, or browser refreshes.

---

## ADR-008: Immutable Financial Ledger & Integer Minor Units

### Context
Floating point arithmetic leads to rounding errors in invoices, discounts, taxes, and refunds. Mutating historical financial records corrupts audits.

### Decision
- All monetary amounts are stored strictly as integer paise (`amount_minor`). Zero floating-point money.
- Paid invoices and payments are NEVER deleted.
- Adjustments, voids, and refunds produce immutable reversal records (`Refund`, `AuditEvent`) linked to the original transaction ID.
- End-of-day cash reconciliation calculates opening cash + cash receipts − cash refunds − cash expenses against counted closing cash, logging any variance with mandatory explanation.

### Consequences
- Deterministic, auditable financial accounting that reconciles perfectly to the paise.

---

## ADR-009: Client-Side PDF Generation & Paper Consultation Slips

### Context
Small Indian outpatient clinics rely on handwritten notes and prescriptions. Fast printing must work even during internet outages.

### Decision
- Consultation slips are generated entirely client-side as PDFs (A5 portrait default, A4 optional) and handed to the doctor via the browser print dialog.
- The slip provides pre-printed administrative headers and large, structured blank boxes: `Doctor's Notes`, `Medicines / Prescription`, `Advice / Follow-up`, and `Signature`.
- The software NEVER generates or stores prescriptions or treatment details.
- Reprints are watermarked with `REPRINT (Copy N)` and logged in audit events.

### Consequences
- Slip printing takes <2 seconds, requires 0 internet traffic, and enforces the non-clinical product boundary.

---

## ADR-010: Configurable Entitlement & Subscription Grace Period

### Context
The commercial hypothesis is ₹3,999/year/clinic. However, network disconnection or subscription expiration must never trap patient data or disrupt acute clinic operations.

### Decision
- Entitlements are validated via a signed cache token with an offline grace period.
- Expired subscriptions transition to a read-and-export mode, allowing the clinic owner to download all patient and financial records as legally mandated.

### Consequences
- Data is never held hostage, ensuring compliance with legal and ethical standards.

---

## ADR-011: Migration Path to Multi-Device Realtime Backend

### Context
Future clinic growth will require simultaneous live queue updates from doctor consultation rooms and multiple reception counters.

### Decision
The frontend uses a clean Repository Pattern and event-driven state models.
- When multi-device live operation is required, the local repository can connect to a lightweight real-time coordination service (e.g. WebSocket or server-sent events) without rewriting UI or domain entities.
- Google Sheets remains the permanent long-term archival mirror.

### Consequences
- Modular architecture with clean separation of concerns and zero technical debt.
