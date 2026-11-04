# APNA CLINIC — TECHNICAL REQUIREMENTS DOCUMENT (TRD)

> **Final platform decision:** Flutter Web (responsive, desktop-first reception and mobile-friendly doctor/owner).  
> **Storage model:** Browser-local operational database + clinic-owned Google Sheets and Google Drive.  
> **Clinical boundary:** Paper prescription only; the app stores no medicines or treatment history.  
> **Scale ambition:** Up to 50,000 clinics with aggressively minimized Google API calls; capacity and cost must be validated, not assumed.

**Contents:** 17 sections including complete workbook/tab names, exact CSV header schemas, PDF/printing requirements, billing, synchronization, privacy, API budgets, testing and delivery.

---

## 1. Document control and scope

**Product:** Apna Clinic  
**Document:** Technical Requirements Document (TRD)  
**Version:** 1.0 | **Date:** 22 September 2026 | **Status:** Engineering baseline  
**Launch platform:** Responsive Flutter web application, desktop-first for reception and mobile-friendly for doctor/owner.  
**Primary market:** Independent Indian outpatient clinics, initially one clinic and one primary reception device.  
**Commercial hypothesis:** ₹3,999 per clinic per year, subject to pilot validation.  
**Source baseline:** Apna Clinic PRD v1.0.

**In scope:** Clinic onboarding; patient registration; short reason for visit; walk-in tokens and appointments; queue; printable consultation slip with blank handwriting area; billing, refunds and cash reconciliation; follow-up appointments; owner dashboard; staff roles; spreadsheet exports; encrypted local storage and clinic-owned Google Drive backups.

**Out of scope:** Digital prescriptions, electronic treatment history, AI diagnosis, pharmacy, lab, inpatient workflows, medical advice, insurance claims, and real-time multi-device coordination in MVP. **Do not scan or store handwritten prescriptions.** The short illness description remains sensitive health data.

**Non-negotiable:** No claims of guaranteed zero operating cost at 50,000 active clinics. Quotas, privacy, data loss, browser storage eviction, and multi-device conflicts must be monitored and addressed.


## 2. Technology stack and deployment

| Layer | Selected technology | Technical requirements |
|---|---|---|
| Web UI | Flutter stable + Dart stable | Responsive desktop/tablet/mobile; Material 3; accessible Hindi/English localization |
| State | Riverpod (or equivalent consistent provider) | Explicit loading, error, offline, syncing and conflict states |
| Navigation | go_router | Deep links, authenticated routes, role-based navigation |
| Data models | freezed + json_serializable | Typed DTOs, schema versioning and deterministic serialization |
| Local operational store | Drift backed by IndexedDB-compatible web persistence, or a proven IndexedDB repository | Verify browser compatibility before locking library; atomic transactions and schema migrations |
| Sensitive data encryption | Audited Web Crypto-based AES-GCM wrapper | Non-extractable keys where feasible; key lifecycle and recovery documented; do not embed master key in JavaScript |
| Authentication | Google OAuth 2.0 Authorization Code + PKCE through Google Identity Services | Minimal scopes, no service-account secrets in frontend |
| Cloud records | Clinic-owned Google Sheets | Batched incremental sync; sheet is **not** live transactional database |
| Cloud files | Clinic-owned Google Drive | PDFs, encrypted backups, configuration and exported reports |
| PDF/printing | Flutter PDF generation + browser print / PDF preview | A4 and A5, supported Hindi font rendering, printer margin test |
| Hosting | HTTPS static web hosting + CDN | Custom domain, caching, secure headers, separate marketing site |
| Monitoring | Privacy-preserving client telemetry | No patient names, illness descriptions, phone numbers or tokens in analytics/logs |
| Tests | flutter_test, integration_test, browser E2E, mocked Sheets/Drive | CI test/build, Chrome/Edge/Android browser compatibility |
| CI/CD | GitHub Actions | Format, analyze, tests, security scan, build, staging, controlled release |
| Optional later backend | Minimal subscription/auth service and transactional coordination service | Required for secure server-enforced subscriptions or simultaneous devices |

**Deployment domains (illustrative):** `clinic.example.com` for the Flutter app and `www.example.com` for the marketing website. Do not treat the frontend as a secure place to store API secrets or license verification keys.


## 3. Architecture and transaction boundaries

```text
Browser (Flutter Web)
  ├─ UI: Reception / Doctor / Owner
  ├─ Domain services: Registration, Queue, Billing, Printing
  ├─ IndexedDB operational database
  │   ├─ patient, visit, appointment, token, invoice, payment
  │   ├─ append-only audit and sync_outbox
  │   └─ schema_version and sync_cursor
  ├─ PDF renderer → print dialog / save PDF
  └─ Sync worker (when authenticated and online)
       ├─ Google Sheets API: batched, append-only records
       └─ Google Drive API: encrypted snapshots, PDFs and exports
```

**Write path:** Validate input → commit all related local records in one transaction → assign immutable UUID/event ID → enqueue outbox event → show success → optionally print → asynchronously upload in batches. Never block consultation-slip printing on Google API availability.

**Read path:** Load local database first. Cloud reconciliation is asynchronous; show last-sync timestamp and pending events. A fresh browser/device must restore from a verified backup before enabling edits to existing records.

**Single-writer MVP:** One designated reception device owns authoritative writes for patients, visits and billing. Doctor/owner mobile access may be read-only unless a transactional coordination backend is deployed. Two browsers editing the same Sheets file are NOT safe simply because each has local storage.

**Storage warning:** Browser IndexedDB is not a guaranteed permanent or encrypted filesystem. Request persistent storage where supported; detect unavailable/private-mode storage; maintain tested encrypted Drive backups and manual export. Never advertise offline safety until crash/recovery tests pass.


## 4. Roles and permission matrix

| Operation | Owner | Receptionist | Doctor | Accountant |
|---|---|---|---|---|
| Clinic setup, staff permissions, exports | Full | No | No | No |
| Patient register/search | Full | Full | Limited | Limited |
| Reason for visit | View per policy | Enter/edit before consultation | View | No |
| Appointments/tokens | Full | Full | View/update queue state | No |
| Print consultation slip | Full | Full | Optional | No |
| Consultation outcome | Administrative status only | Status only | Status only | No |
| Billing/payment/refund | Full | Bill and payment; restricted refunds | No | Reconcile/report |
| Reports | Full | Shift-level | Personal queue only | Finance reports |
| Cloud restore and key rotation | Full with reauthentication | No | No | No |

Enforce permissions in every domain action and in cloud/export access; hiding UI controls alone is insufficient. In a pure browser + clinic-owned Drive architecture, secure independent employee access requires additional identity/authorization infrastructure or a carefully constrained single-account operating model. Never distribute the owner's refresh token to staff.


## 5. Modules, feasibility and exact working

| Module | MVP | Working behavior | Feasibility / dependency |
|---|---|---|---|
| Onboarding | Yes | Google sign-in; clinic profile; minimal OAuth; create/select Drive folder and template; verify printer | High; OAuth verification and consent required |
| Dashboard | Yes | Today's tokens, waiting/completed, collection, unpaid, appointments, last sync | High; local aggregates |
| Patients | Yes | Create/search/update; duplicate warning; consent and minimal demographics | High; sensitive data safeguards |
| Appointments | Yes | Date/time/doctor; overlap warning; reschedule/cancel; walk-in conversion | High; single-writer MVP |
| Walk-in queue | Yes | Per-doctor daily token; waiting/called/in-consultation/completed/no-show | High; atomic local counters |
| Consultation slip | Yes | Print clinic header, token, patient, date, reason for visit and blank handwriting space | High; A4/A5 printer validation |
| Billing | Yes | Consultation fees, discounts, receipt, payment, partial/unpaid, void/refund | High; immutable ledger |
| Follow-up | Yes | Date, reminder status, new appointment; no treatment notes | High; opt-in messaging later |
| Staff | Basic | Staff identity and permission configuration | Medium; secure multi-login needs backend |
| Reporting | Yes | Daily collection, token counts, refunds, receivables and exports | High; derived locally |
| Backup/restore | Yes | Incremental Sheets sync and encrypted full Drive snapshot; checksum verify | Medium; recovery testing critical |
| Subscription | Yes | Trial and annual entitlement display | Medium; secure server-side verification required |
| SMS/WhatsApp | Later | Explicit-consent reminders | Medium; provider charges, opt-in and templates |
| Multiple doctors | Limited | Separate queues on same primary device | Medium; simultaneous devices deferred |
| Multi-branch | No | Separate clinic tenancy and consolidated view | Requires transactional backend |
| ABDM integration | No | Optional future health ecosystem integration | Separate consent/compliance project |

**MVP rule:** No medical diagnosis inference, no automatic medicine suggestions, no storing prescriptions, and no longitudinal clinical history.


## 6. Master spreadsheet design

**Google Drive folder:** `ApnaClinic/{clinic_id}/`  
**Primary workbook:** `ApnaClinic_Master_v1` (Google Sheets; not an `.xlsx` file used for live writes).  
**Other folders:** `Backups/Encrypted/`, `Exports/Excel/`, `Exports/PDF/`, `Branding/`, `AuditExports/`.  
**Sheet/tab names below are canonical and case-sensitive in application code.** Each tab has row 1 frozen, a stable `schema_version`, explicit IDs, UTC ISO timestamps and soft-delete fields where applicable. The local database is authoritative for unsynced work.

**Core tabs (first workbook):**

| Tab | Purpose | Estimated growth |
|---|---|---|
| `Clinic_Config` | One row per clinic | Tiny |
| `Doctors` | Doctors and consultation settings | Low |
| `Staff` | Non-secret staff metadata; never OAuth tokens | Low |
| `Patients` | Minimal patient registration | Medium |
| `Appointments` | Bookings, rescheduling and no-shows | High |
| `Visits` | One row per patient consultation visit | High |
| `Token_Counters` | Cloud reconciliation snapshots only, not live lock | Low |
| `Queue_Events` | Append-only status transitions | High |
| `Fee_Catalog` | Consultation fee types and tax settings | Low |
| `Invoices` | Invoice header and balances | High |
| `Invoice_Items` | Charge lines | High |
| `Payments` | Payments and reversals | High |
| `Refunds` | Refund authorizations and settlement | Low |
| `Expenses` | Clinic operating expenses | Medium |
| `Followups` | Administrative follow-up scheduling | Medium |
| `Consent_Log` | Consent notices and recorded responses | Medium |
| `Audit_Events` | Sensitive record access and administrative mutations | High |
| `Sync_Manifest` | Batch ID, checkpoint, checksum and schema | Medium |
| `Daily_Summary` | Compact materialized aggregate | One row/day/doctor |
| `Lookup_Config` | Optional configurable lists | Tiny |

**Avoid one mega-sheet with hundreds of mixed-purpose columns.** High-volume tabs may be rolled into annual or monthly archival workbooks, referenced in `Sync_Manifest`. No formula should be the only source of truth for an invoice or token number.


## 7. Exact spreadsheet column headers (canonical templates)

### `Clinic_Config`

```csv
clinic_id,legal_name,display_name,owner_name,contact_phone,contact_email,address_line1,address_line2,city,district,state,pincode,timezone,currency,language,logo_drive_file_id,default_paper_size,consultation_slip_template_id,receipt_template_id,default_consultation_fee,tax_registration_number,tax_configuration_json,working_days_json,opening_time,closing_time,subscription_plan,subscription_expiry_at,created_at,updated_at,schema_version
```

### `Doctors`

```csv
doctor_id,clinic_id,display_name,qualification_text,registration_number,specialty_label,contact_phone,active,consultation_duration_minutes,default_fee,working_schedule_json,room_label,created_at,updated_at,deleted_at
```

### `Staff`

```csv
staff_id,clinic_id,display_name,role,phone,email,active,assigned_doctor_ids_json,created_at,updated_at,deleted_at
```

### `Patients`

```csv
patient_id,clinic_id,patient_number,full_name,preferred_name,date_of_birth,age_if_dob_unknown,sex_optional,phone_optional,alternate_phone_optional,guardian_name_optional,guardian_relation_optional,address_optional,city_optional,pincode_optional,preferred_language,consent_status,consent_version,created_at,updated_at,deleted_at
```

### `Appointments`

```csv
appointment_id,clinic_id,patient_id,doctor_id,scheduled_start_at,scheduled_end_at,appointment_type,booking_source,status,reason_for_visit_encrypted_ref,created_by_staff_id,reminder_consent,reminder_status,rescheduled_from_id,cancel_reason,created_at,updated_at,deleted_at
```

### `Visits`

```csv
visit_id,clinic_id,patient_id,doctor_id,appointment_id_optional,visit_date_local,checkin_at,token_number,token_scope_key,visit_type,reason_for_visit_encrypted_ref,queue_status,consultation_started_at,consultation_completed_at,slip_print_count,last_slip_printed_at,invoice_id_optional,followup_due_date_optional,created_by_staff_id,created_at,updated_at,deleted_at
```

### `Token_Counters`

```csv
counter_id,clinic_id,doctor_id,local_date,scope_key,last_issued_token,primary_device_id,checkpoint_event_id,checkpoint_at
```

### `Queue_Events`

```csv
queue_event_id,clinic_id,visit_id,doctor_id,from_status,to_status,changed_by_staff_id,changed_at,device_id,source_event_id
```

### `Fee_Catalog`

```csv
fee_id,clinic_id,fee_code,fee_name,description,default_amount_minor,currency,tax_category,tax_rate_config,active,created_at,updated_at
```

### `Invoices`

```csv
invoice_id,clinic_id,invoice_number,financial_year,patient_id,visit_id,issue_date_local,status,subtotal_minor,discount_minor,tax_minor,total_minor,paid_minor,balance_minor,currency,notes_nonclinical,created_by_staff_id,created_at,updated_at,voided_at,void_reason
```

### `Invoice_Items`

```csv
invoice_item_id,clinic_id,invoice_id,fee_id_optional,description,quantity,unit_price_minor,discount_minor,tax_rate_snapshot,tax_minor,line_total_minor,created_at
```

### `Payments`

```csv
payment_id,clinic_id,invoice_id,amount_minor,currency,method,cash_upi_card_reference_optional,received_at,received_by_staff_id,status,reversal_of_payment_id_optional,created_at
```

### `Refunds`

```csv
refund_id,clinic_id,invoice_id,payment_id_optional,amount_minor,reason,requested_by_staff_id,approved_by_staff_id,status,refunded_at,refund_method,reference_optional,created_at
```

### `Expenses`

```csv
expense_id,clinic_id,expense_date,category,vendor_optional,description,amount_minor,payment_method,payment_reference_optional,receipt_drive_file_id_optional,created_by_staff_id,created_at,updated_at,deleted_at
```

### `Followups`

```csv
followup_id,clinic_id,patient_id,source_visit_id_optional,doctor_id,due_date,administrative_note_optional,status,reminder_consent,reminder_sent_at,converted_appointment_id_optional,created_at,updated_at
```

### `Consent_Log`

```csv
consent_event_id,clinic_id,patient_id,notice_version,purpose_code,consent_action,collection_channel,recorded_by_staff_id,recorded_at,withdrawn_at_optional
```

### `Audit_Events`

```csv
audit_event_id,clinic_id,actor_id,actor_role,device_id,action,entity_type,entity_id,field_names_json,occurred_at,correlation_id,result,reason_optional
```

### `Sync_Manifest`

```csv
sync_batch_id,clinic_id,device_id,schema_version,first_event_id,last_event_id,event_count,checksum_sha256,target_workbook_id,target_tab,status,attempt_count,uploaded_at,confirmed_at,last_error_code
```

### `Daily_Summary`

```csv
summary_id,clinic_id,local_date,doctor_id_optional,registered_count,walkin_count,appointment_count,completed_count,no_show_count,invoiced_minor,paid_cash_minor,paid_upi_minor,paid_card_minor,refunded_minor,outstanding_minor,expenses_minor,generated_at,source_event_checkpoint
```

### `Lookup_Config`

```csv
lookup_id,clinic_id,lookup_type,code,display_label_en,display_label_hi,sort_order,active,created_at,updated_at
```

**Schema constraints:** IDs are UUIDv7/ULID or another collision-resistant identifier. All currency is stored in integer paise (`*_minor`); all UTC timestamps are ISO 8601. Never put raw illness descriptions in plaintext Sheets: `reason_for_visit_encrypted_ref` points to a separately encrypted record or ciphertext envelope; the visible spreadsheet contains only the reference. No Aadhaar requirement, prescription field, medication list or treatment-history tab.

**Recommended local-only tables:** `local_keys`, `sync_outbox`, `sync_inbox`, `pending_print_jobs`, `browser_device_state`, `local_migrations`, `auth_session_metadata`. These must not be uploaded as ordinary Sheets tabs.


## 8. Registration, token and queue algorithms

1. Search locally by normalized phone/name/patient number; show possible duplicates, never auto-merge.
2. Collect minimal identity, optional phone and brief reason for visit. Provide an understandable privacy notice.
3. Save patient + visit + queue event atomically in IndexedDB; if local commit fails, show failure and do not issue a token.
4. Token scope = `{clinic_id}:{doctor_id}:{local_YYYY-MM-DD}`. On the designated primary device, increment a persisted counter transactionally. Token numbers may restart daily; `visit_id` is globally unique.
5. Assign `waiting`; receptionist can move to `called`, doctor to `in_consultation`, then `completed`. Record immutable transitions.
6. Cancelled/no-show visits remain auditable. Do not recycle token numbers or invoice numbers.
7. Appointments convert to visits at check-in; duplicate clicks must reuse the same `visit_id` through an idempotency key.
8. Two simultaneously writing devices cannot use a Sheets-based token counter safely. Block secondary writers until a coordination backend is deployed.


## 9. Consultation slip and printing specification

**Purpose:** Paper handed to the doctor; doctor manually writes medicines and clinical instructions. The application does not retain the handwritten contents.

**A5 portrait default; A4 optional.** Configurable margins and clinic logo. Include clinic name/address/contact; doctor name/qualification/registration number (if supplied); visit date/time; patient name and age/sex only if provided; patient number; visit ID or short code; daily token; brief reason for visit (configurable to omit for privacy); blank areas labelled `Doctor's Notes`, `Medicines / Prescription`, `Advice / Follow-up`; optional signature line.

**Printing workflow:** Preview → choose A5/A4 → render print-safe PDF → browser print dialog → record print attempt/success confirmation as feasible. Browsers generally cannot guarantee a physical printer actually printed; show explicit `Mark printed` action and permit controlled reprints. Include `REPRINT` watermark or print counter when applicable.

**Billing receipt:** Separate printable A5/80mm-friendly layout with clinic details, sequential invoice number, itemized fees, discounts, applicable taxes, payment method, total, balance, timestamp and refund/void reference. Validate Indian tax treatment with qualified advisers; do not assume all clinic fees attract GST.

**Browser limitations:** No silent printing or universal Bluetooth/USB thermal printer support. Use OS-installed printer via Chrome/Edge print dialog for MVP. Optional local print bridge/native desktop packaging is a later integration and requires security review.

**Acceptance:** Hindi text renders correctly; 100 sample PDFs contain no clipped text; A4/A5 print alignment verified on at least two real printer models; offline generation works after app assets are cached.


## 10. Billing, payments and reconciliation

**Billing states:** draft → issued → partially_paid/paid → refunded/voided (as applicable). Invoice number allocation must be monotonic per clinic/financial year on primary writer and never reused. `invoice_id` is immutable.

**Amount calculation:** line subtotal = quantity × unit price; discount applied according to clinic configuration; tax applied only where legally applicable and configured; round consistently to paise. Preserve historical fee/tax snapshots on each invoice line. Invoice total = sum line totals; balance = total − successful payments + successful refunds or reversals as appropriate.

**Payments:** cash, UPI, card and mixed tenders; partial payments and duplicate reference detection. Payment success means staff-confirmed payment for manual UPI/card entry, not verified bank settlement. Do not claim automatic verification without a gateway or bank integration.

**Refunds:** permission-gated, immutable reversal/credit event and printable receipt. Never delete original payment. Daily close reconciles opening cash + cash receipts − cash refunds − cash expenses against counted closing cash; discrepancy is recorded with explanation.

**Exports:** invoice register, payment register, refund register, daily collection, doctor-wise revenue, outstanding amounts and expense register. Use locally calculated aggregates; sync compact daily summaries.


## 11. Google OAuth, Sheets/Drive access and backup

**OAuth:** Public web OAuth client, Authorization Code with PKCE where supported, narrow Drive scopes (prefer `drive.file`), least-privilege Sheets access needed for app-created files, consent-screen verification and explicit account-revocation handling. Do not store long-lived refresh tokens unencrypted in browser storage. Do not ship client secrets or service-account JSON in web assets.

**First-run sequence:** Authenticate → choose clinic account → consent notice → create `ApnaClinic/{clinic_id}` → create workbook and canonical tabs → store workbook IDs and schema version in local configuration → create encrypted initial snapshot → verify write/read permission.

**Backup:** Sync append-only events to Sheets in bounded batches; create an encrypted full snapshot at least daily and after major schema migrations; retain configurable recent snapshots. Upload SHA-256 manifest and test restore against checksum. Patient identifiers and illness descriptions must be encrypted in backups and not exposed in public/shareable folders.

**Recovery:** Owner reauthenticates → chooses clinic folder → validates workbook/schema/checksum → downloads and decrypts snapshot → replays verified incremental events → shows reconciliation report → enables writes only after integrity checks. Document what happens if encryption key is lost; do not claim recovery is possible without a recoverable key.

**Export:** Owner can download patient administrative register and financial Excel/CSV exports with privacy warnings; exports containing personal information must be access controlled, watermarked where appropriate and auditable.


## 12. API-call budget and 50,000-clinic scaling

**No network call for:** each keystroke, patient search, token generation, visit status, invoice calculation, printing, dashboard refresh, or ordinary local report. All these use local data.

**Calls are driven by:** first-run setup, incremental cloud batch upload, checkpoint/download on device restore, encrypted snapshot upload, explicit export and infrequent permission validation.

**Illustrative target per single-device clinic, not a guaranteed quota:** 1–3 Sheets batch writes/day, 0–2 Sheets reads/day, 0–2 Drive file writes/day, occasional metadata requests. A typical budget is roughly **2–7 Sheets requests/day and 1–4 Drive requests/day**, excluding onboarding, retries, restore and exceptional use. Batches must respect request size and processing-time limits.

**Example:** 50 patient visits/day × 4 operational events = 200 events/day. At 100 events/batch, approximately 2 Sheets batch writes plus 1 daily reconciliation read. A separate encrypted Drive snapshot may add file create/update calls. More granular audit events or multiple workbooks increase this budget.

**Scaling arithmetic:** 50,000 clinics × 3 Sheets requests/day = 150,000 daily requests; × 7 = 350,000. Daily average does not establish feasibility: project quotas are per-minute, and synchronized morning/evening bursts can exceed them. Reads and writes have separate quotas; Google may revise limits or pricing. Review current official Sheets and Drive quotas immediately before launch and monitor both.

**Traffic shaping:** Local-first UI; aggregate event rows; bounded `batchUpdate`/`values.batchUpdate` calls; randomized sync windows; adaptive intervals; exponential backoff + jitter for 429/5xx; upload checkpointing; conditional downloads based on known manifest; no constant polling. A failed sync must never discard local events.

**Capacity policy:** No promise of free 50,000 active clinics on a single Google Cloud project. Conduct staged load testing at 100/1,000/10,000 active clinics; request appropriate quota increases, distribute workloads only within provider terms, or introduce a backend/alternative storage when sustained load requires it. Cloud storage quotas, users' Drive capacity, OAuth verification, support, hosting and monitoring remain real costs.


## 13. Security, privacy and clinical boundaries

- Collect only data required for registration and visit administration. A reason for visit is health information even without prescriptions.
- Do not store or print illness details by default in analytics, crash logs, URLs, browser history, notification payloads or payment references.
- Encrypt illness description before cloud upload; separate key management from cloud data and document rotation, recovery and employee revocation.
- Use HTTPS, CSP, secure cookies where applicable, OAuth state/PKCE, strict redirect URI allowlists, dependency scanning and XSS-safe rendering.
- Auto-lock unattended reception sessions; restrict exports and refunds; audit reads/changes of sensitive records without logging plaintext.
- Provide privacy notice, retention policy, consent/other lawful-basis handling as applicable, correction/export/deletion workflows, and a breach-response plan.
- Verify current Indian DPDP Act/Rules commencement, healthcare record obligations and applicable state/professional requirements with counsel before release; do not assume Google Drive ownership alone satisfies compliance.
- Printed consultation slips contain personal information: include handling instructions, restrict unattended printer trays and provide secure disposal guidance.
- Clinical safety boundary: no automated diagnosis, triage, medication recommendation or prescription generation.


## 14. Performance, availability and operational SLOs

| Measure | Pilot target |
|---|---|
| Returning-patient registration to printable slip | <60 seconds under normal operation |
| Local search p95 | <300 ms on target reception hardware |
| Save patient + visit transaction p95 | <500 ms on target browser/device |
| PDF generation p95 | <3 seconds for standard slip |
| Offline create/print | Works after verified PWA installation/caching |
| Duplicate tokens/invoice IDs | Zero in single-writer stress tests |
| Unrecoverable confirmed local transaction loss | Zero in defined fault-injection tests |
| Last-sync visibility | Always visible to authorized owner/receptionist |
| Backup verification | Daily automatic integrity check; periodic restore drill |
| Accessibility | Keyboard-accessible reception flow, readable Hindi/English typography |

Targets are engineering acceptance criteria, not claims of achieved performance.


## 15. Detailed testing and release gates

**Unit:** patient deduplication; date/age handling; token counters across midnight; invoice paise arithmetic; partial payments/refunds; permission checks; serialization and schema migrations.

**Integration:** local atomic transactions; outbox replay after browser crash; Google 401/403/404/429/5xx; partial batch upload; checksum mismatch; OAuth revocation; duplicate button clicks; offline queue; restore from snapshot + events.

**Browser/device:** Chrome and Edge desktop; Android Chrome; narrow mobile viewport; low-memory device; offline/PWA behavior; incognito and disabled IndexedDB; browser storage eviction simulation; printer disconnected/unsupported; Hindi font output.

**Security:** unauthorized role access, export controls, injection/XSS, leaked secrets in build output, unencrypted illness descriptions, token reuse, lost-device and revoked-employee scenarios.

**Load:** 500 patients in local search; 200 visit events in a day; 10,000-record restore; API traffic peaks across simulated clinics; measure real requests in Google Cloud console. No launch on synthetic tests alone.

**Release gate:** pilot in at least five real clinics; confirmed paper-slip print flow; zero duplicate invoices/tokens; verified offline recovery and encrypted restore; privacy review; documented support and rollback procedure.


## 16. Development phases and deliverables

| Phase | Duration estimate | Deliverables |
|---|---|---|
| 0. Discovery and privacy design | 1 week | Doctor/reception interviews, printer inventory, data minimization, threat model |
| 1. Foundation | 1–2 weeks | Flutter responsive shell, routes, state, local DB, Google OAuth, onboarding |
| 2. Registration and queue | 2 weeks | Patient forms/search, appointments, atomic tokens, queue and role views |
| 3. Printing and billing | 2 weeks | A4/A5 slip, receipt, fees, payments, refunds, reconciliation |
| 4. Sheets/Drive sync | 2 weeks | Workbook creator, outbox batching, encryption, snapshots, restore |
| 5. Reports and subscription | 1 week | Dashboard, exports, annual entitlement, owner settings |
| 6. Hardening and pilot | 2–3 weeks | Browser/printer testing, privacy review, load tests, pilot fixes |

**Estimate:** ~11–13 weeks with an experienced small team and no complex multi-device backend. Scope or team capacity can change this significantly.

**Deliverables:** source code; architecture decision records; schema registry; generated workbook template; environment setup; Google Cloud/OAuth checklist; PDF print templates; automated test suite; staging and production deployment; operational runbook; backup/restore playbook.


## 17. Open architecture decisions

1. **Single writer:** Confirm whether only one reception device may create/update records in MVP. If not, add a transactional backend before release.
2. **Doctor access:** Decide whether doctor mobile access is read-only or requires live queue updates.
3. **Encryption key recovery:** Choose clinic-controlled recovery method and test owner-account loss.
4. **Offline guarantees:** Confirm supported browsers, storage persistence and backup cadence.
5. **Pricing:** Decide whether ₹3,999 includes GST, number of doctors/devices and support limits.
6. **Printing:** Validate A5 printer compatibility at pilot clinics and decide whether 80mm receipts are necessary.
7. **Reason for visit:** Decide whether to show it on paper slips by default; minimum necessary disclosure.
8. **Data retention:** Define retention/deletion schedule after legal review and customer consultation.
9. **Scale migration:** Define thresholds for adding coordination backend and changing sync architecture.
