# Apna Clinic — Master Implementation Plan

**Version:** 1.0  
**Date:** 22 September 2026  
**Status:** Approved Architectural Plan  
**Target:** Production-Grade Flutter Web Application  
**Primary Standards:** [apna_clinic_prd.md](file:///d:/Apna%20Clinic/apna_clinic_prd.md) & [apna_clinic_trd.md](file:///d:/Apna%20Clinic/apna_clinic_trd.md)

---

## 1. Architectural Strategy

Apna Clinic is engineered strictly as an **offline-first administrative platform** for outpatient clinics.
- Doctor handwritten notes and medicines on printed slips are the clinical medium.
- The software stores **zero** prescriptions, medical diagnoses, treatment instructions, or longitudinal EHR data.
- The browser local operational database (Drift + IndexedDB) is the single source of truth for un-synced operations.
- Google Sheets is strictly an **append-only / batched administrative mirror**, never a live transactional lock.
- Google Drive stores encrypted database snapshots, exported PDF slips, and clinic branding.

---

## 2. Technology Stack & Directory Structure

- **Framework:** Flutter Web (desktop-first 1366×768, responsive tablet & mobile doctor view), Material 3.
- **State Management:** Riverpod (`flutter_riverpod`).
- **Routing:** `go_router` with declarative domain-level route guards.
- **Data Models:** `freezed` + `json_serializable`.
- **Identifiers:** UUIDv7 / ULID collision-resistant identifiers.
- **Financial Arithmetic:** Integer minor units (paise) with deterministic rounding.
- **Local Persistence:** Drift with Web IndexedDB persistence behind a clean repository interface (`Repository Pattern`).
- **Encryption:** Web Crypto AES-GCM for sensitive fields and full database snapshots.
- **Printing:** Client-side PDF generation via `pdf` package (A5 portrait default, A4 optional, Noto Sans Devanagari Hindi font).
- **Cloud Integration:** Google Identity Services (OAuth 2.0 PKCE, `drive.file`, `spreadsheets` scopes).

### Directory Layout
```text
lib/
├── core/
│   ├── config/             # App environment, constants, feature flags
│   ├── constants/          # UI tokens, paper sizes, Indian formats
│   ├── errors/             # Failure types, domain exceptions, user-facing error messages
│   ├── logging/            # Privacy-safe structured logger (no PII / health data)
│   ├── security/           # WebCrypto AES-GCM encryption wrapper, key lifecycle
│   ├── permissions/        # Roles (Owner, Receptionist, Doctor, Accountant), Permission matrix
│   ├── localization/       # l10n delegates, Hindi/English strings, formatters
│   ├── routing/            # go_router configuration, auth guards, route paths
│   └── utils/              # Money (paise), date/time (Asia/Kolkata), phone normalizer, UUIDv7
├── domain/
│   ├── entities/           # Clinic, Doctor, Staff, Patient, Appointment, Visit, TokenCounter,
│   │                       # QueueEvent, FeeCatalog, Invoice, InvoiceItem, Payment, Refund,
│   │                       # Expense, Followup, ConsentEvent, AuditEvent, SyncManifest, DailySummary
│   ├── value_objects/      # Money, PhoneNumber, TokenScope, InvoiceNumber, AuditMetadata
│   ├── repositories/       # Abstract repository interfaces (pure Dart)
│   ├── services/           # AuthorizationService, TokenAllocationService, BillingService,
│   │                       # QueueStateMachine, DeduplicationService
│   └── policies/           # RetentionPolicy, SyncPolicy, DayClosePolicy
├── infrastructure/
│   ├── database/           # Drift schema, tables, DAOs, migrations, web IndexedDB connector
│   ├── repositories/       # Concrete Drift repository implementations
│   ├── google/
│   │   ├── oauth/          # Google Identity Services / OAuth 2.0 PKCE client
│   │   ├── drive/          # Google Drive client (folders, encrypted backups, file uploads)
│   │   └── sheets/         # Google Sheets client (batchUpdate, canonical tabs)
│   ├── outbox/             # Outbox worker, batch aggregator, sync checkpointing
│   ├── backup/             # Snapshot serializer, AES-GCM packager, checksum validator
│   └── pdf/                # Consultation slip PDF generator (A5/A4), receipt generator
├── application/            # Riverpod providers, controllers, use cases
│   ├── auth/
│   ├── onboarding/
│   ├── patients/
│   ├── appointments/
│   ├── visits/
│   ├── queue/
│   ├── billing/
│   ├── printing/
│   ├── reports/
│   ├── backup/
│   └── sync/
└── presentation/           # Material 3 UI widgets and screens
    ├── auth/
    ├── onboarding/
    ├── dashboard/
    ├── patients/
    ├── appointments/
    ├── queue/
    ├── billing/
    ├── reports/
    ├── settings/
    ├── doctor/
    └── shared/widgets/
```

---

## 3. Development Phases

- **Phase 0 — Repository Foundation**: SDK setup, package configuration, linting, formatting, environment config, CI workflow.
- **Phase 1 — Domain Foundation**: Typed entities, Money value object, TokenScope, AuthorizationService, DeduplicationService, unit tests.
- **Phase 2 — Local Database**: Drift schema, IndexedDB connector, atomic transactions, repositories, WebCrypto encryption.
- **Phase 3 — Authentication & Onboarding**: Google OAuth 2.0 PKCE, clinic onboarding wizard, canonical 19 tabs setup, sample slip test.
- **Phase 4 — Patient Registration & Lookup**: 2-step registration, <300ms p95 local search, duplicate warning dialog, phone masking.
- **Phase 5 — Appointments & Visits**: Slot booking, walk-in check-in, atomic monotonic token generation, idempotency handling.
- **Phase 6 — Queue Management**: Queue state machine, immutable `QueueEvent` log, receptionist and doctor queue views.
- **Phase 7 — Consultation Slip & Printing**: Client-side A5/A4 PDF generation, handwritten doctor areas, reprint tracking, Hindi font rendering.
- **Phase 8 — Billing, Payments & Ledger**: Fee catalog, invoice lifecycle, cash/UPI/card tender, staff confirmation tag, refunds, day close cash reconciliation.
- **Phase 9 — Dashboard & Reports**: Receptionist & doctor dashboard, local aggregates, privacy-preserving CSV/Excel/PDF exports.
- **Phase 10 — Sync Engine & Outbox**: Append-only outbox worker, bounded batch sync to Sheets, exponential backoff with jitter, 429 quota handling.
- **Phase 11 — Encrypted Backup & Restore**: AES-GCM snapshot creation, SHA-256 checksum manifest, Drive upload, safe-abort restore wizard.
- **Phase 12 — Security Hardening & Privacy**: Audit logging, DPDP Act compliance, reception session auto-lock.
- **Phase 13 — Performance & Reliability**: 20,000 patient benchmark, browser crash/restart recovery tests.
- **Phase 14 — Pilot Readiness**: Synthetic demo clinic, operational guides, deployment & rollback manuals.

---

## 4. Key Engineering Risks & Mitigations

| Risk | Impact | Mitigation Strategy |
|---|---|---|
| Browser storage eviction (IndexedDB) | Data loss if browser evicts storage | Request `navigator.storage.persist()`; mandatory daily encrypted Drive backup; clear user warning on unverified backups |
| Google Sheets 429 quota exhaustion | Sync interruption | Bounded batch uploads (50-100 events/batch); jittered exponential backoff; local operations never block on sync |
| Accidental duplicate billing or tokens | Financial/queue corruption | Transactional local counter in IndexedDB; idempotency keys on all write operations; strict monotonic numbering |
| Sensitive reason-for-visit data exposure | Privacy breach | Local encryption; isolated from financial reports, logs, analytics, and ordinary Sheets tabs; encrypted envelope refs |
| Printer formatting / clipping on clinic printers | Unusable consultation slip | Configurable A5/A4 margins; client-side PDF preview; explicit reprint counter watermark |
