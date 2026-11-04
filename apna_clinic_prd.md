# APNA CLINIC — PRODUCT REQUIREMENTS DOCUMENT (PRD)

**Version:** 1.0  
**Date:** 22 September 2026  
**Status:** Proposed / requirements baseline  
**Product:** Apna Clinic  
**Initial market:** Independent doctors and small outpatient clinics in India  
**Platforms:** Flutter web (responsive, desktop-first reception experience); optional Android packaging in a later release  
**Commercial assumption:** ₹3,999 per clinic/year, subject to customer validation  
**Storage strategy:** Offline-first local store + clinic-owned Google Sheets/Drive for synchronization, exports and backup

> **Product boundary:** Apna Clinic is an administrative system, not an electronic prescribing, diagnosis, treatment recommendation, telemedicine, pharmacy, laboratory or hospital information system. Doctors write medicines and treatment instructions by hand on the printed consultation slip. The application does not capture or retain the handwritten prescription or longitudinal treatment history. A short, user-entered reason for visit / illness description is still sensitive health data and requires appropriate protection.

---

## 1. Executive summary

Apna Clinic helps a small clinic register patients, issue visit tokens, organize the queue, print a doctor-ready consultation slip, record consultation charges and payments, manage follow-up scheduling, and see basic business reports. The doctor receives a paper slip with identifying and visit information and blank writing space for clinical notes and medicines. Clinic staff do not need to enter prescriptions into the application.

The product's differentiation is simplicity, offline resilience, quick printing, predictable pricing and clinic ownership of its cloud records. The initial release prioritizes **one clinic, one reception workstation and one or more doctors sharing a local queue**; simultaneous multi-device live operation is a separate architecture and product milestone.

### 1.1 Product goals

1. Register a returning patient and print a consultation slip in under 60 seconds under normal conditions.
2. Support walk-in registration and scheduled appointments with clear token and queue states.
3. Enable fast, accurate cash/UPI/card fee collection, refunds and end-of-day reconciliation.
4. Keep billing and printing available when internet access is interrupted, subject to local printer/browser support.
5. Minimize cloud API traffic by storing operational changes locally and synchronizing in batches.
6. Allow the clinic owner to export their own administrative data and restore verified backups.
7. Support accessible Hindi and English UI at launch if pilot validation confirms both are required.
8. Deliver an MVP that a small clinic can learn without dedicated IT staff.

### 1.2 Explicit non-goals for MVP

- No digital prescriptions, medicine suggestions, AI diagnosis, treatment history or prescription scanning.
- No pharmacy, lab, imaging, inpatient, insurance-claim or ABDM integration in MVP.
- No medical decision support or emergency triage recommendations.
- No automatic SMS/WhatsApp campaigns without appropriate consent and separately configured services.
- No promise of free, real-time Google Sheets synchronization for 50,000 simultaneously active clinics.

## 2. Users and permissions

| Role | Responsibilities | Access boundaries |
|---|---|---|
| Clinic owner / administrator | Clinic configuration, users, fees, audit, exports, subscription, reporting | Full administrative access; clinical reason-for-visit access only when needed and authorized |
| Receptionist | Patient registration, appointments, queue, consultation-slip printing, payment collection | No bulk export by default; cannot change audit events or access backup credentials |
| Doctor | View assigned queue, patient identity and stated reason for visit; update visit status | No unrestricted access to financial reports or other doctors' queues unless authorized |
| Accountant (optional) | Collections, refunds with approval, expenses, reconciliation | No access to illness descriptions by default |
| Support operator | Troubleshooting via diagnostics and explicit owner authorization | No default access to identifiable patient or illness data |

**Authorization:** Deny by default. Every sensitive action requires an authenticated session, clinic scope and role permission. Audit patient record views and exports as well as edits where feasible.

## 3. Customer segments and operating assumptions

**Initial customers:** single-doctor practices, neighborhood general outpatient clinics and small multi-doctor clinics with a shared reception. Support clinics using printed slips and manual prescriptions. A basic receptionist workflow must function with one laptop or desktop, browser and printer.

**Operating assumptions to validate:** typical daily visits, repeat-visit frequency, appointment versus walk-in share, number of reception devices, printer models, internet reliability, Hindi/English needs, typical consultation charges and willingness to pay ₹3,999 annually.

**Exclusions at launch:** emergency departments, inpatient facilities, high-volume hospital OPDs requiring centralized real-time queuing, specialist practices requiring longitudinal clinical records, and clinics expecting automatic integration with external hospital systems.

## 4. End-to-end patient journey

1. **Open clinic:** authorized receptionist opens the application; dashboard shows local data, queue and last successful backup/sync status.
2. **Find or register:** search by patient ID, name or phone (with privacy-preserving display). Confirm identity before selecting a record. Create patient when no match exists.
3. **Capture visit:** select doctor, visit type, appointment slot if applicable, and optional brief patient-reported illness / reason for visit. Do not ask staff to diagnose or code disease.
4. **Assign token:** generate a unique clinic/day/doctor-scoped token; prevent duplication across retries. Show queue position and estimated waiting time only if reliable.
5. **Collect fee:** select consultation fee and any approved discount; accept cash, UPI, card or a combination; mark pending where applicable. Store payment transaction identifiers and audit reversals.
6. **Print slip:** produce an A5/A4 configurable PDF/print layout with clinic identity, patient details, visit date, token, doctor, brief reason for visit and blank space for handwritten clinical notes, medicines and instructions. Optional separate receipt.
7. **Doctor consultation:** doctor calls patient; writes prescription on the physical slip. App may mark visit called / in consultation / completed, without storing treatment details.
8. **Follow-up:** receptionist may schedule a date if the patient/doctor requests one; do not infer medical necessity.
9. **Close day:** reconcile payments, view visit counts and export daily reports; sync and back up when online.

### 4.1 Visit states

`registered → waiting → called → in_consultation → completed` with separate `cancelled` and `no_show` states. Payment status is independent: `unpaid`, `partially_paid`, `paid`, `refunded`, `voided`. Reopening and editing a completed visit require explicit permission and an audit event.

### 4.2 Repeat patients

Patient master data is reusable, but each visit receives its own immutable visit ID and token. Prior visit metadata can be visible to authorized staff for administrative lookup; **do not present a longitudinal treatment history**. Retain reason-for-visit data only as long as necessary for the stated administrative purpose and legal requirements.

## 5. MVP modules and requirements

### M01 — Clinic onboarding and settings (P0)
- Google sign-in, clinic identity verification workflow, logo, contact, address, operating days/hours, doctors, fees, printer settings and receipt preferences.
- Consent/notice for patient data collection, role invitation, timezone `Asia/Kolkata`, and subscription state.
- Create clinic-owned Drive folder and approved Sheets templates only after authorization; show setup and sync health.
- Acceptance: owner can finish guided setup and print a sample consultation slip without entering a real patient.

### M02 — Patient registration and lookup (P0)
- Patient ID, full name, optional phone, age or DOB, sex only if operationally necessary, address optional, guardian/contact for minors where needed, registration timestamp.
- Duplicate warnings using normalized phone and name/DOB where available; never auto-merge without confirmation.
- Explicitly label illness field as **patient-reported reason for visit**, not a diagnosis.
- Search with partial name, patient ID and authorized phone; mask phone on shared displays.
- Edit with change history; controlled deletion and export.
- Acceptance: no duplicate patient IDs; registration works offline; sensitive fields are not exposed in financial exports.

### M03 — Appointments and walk-ins (P0)
- Doctor schedules, available slots, walk-in registration, rescheduling, cancellation, no-show and optional follow-up booking.
- Avoid double-booking through local transactional checks; concurrent multi-device booking requires a coordinating backend or explicit single-writer mode.
- Acceptance: overlapping slots and stale changes produce visible conflict handling rather than silent overwrite.

### M04 — Token and queue (P0)
- Configurable per-doctor/day token numbering, priority overrides only by authorized staff, waiting/called/in-consultation/completed status, visible queue on reception and doctor view.
- Printed slip contains both globally unique visit ID and human-readable token.
- Acceptance: retries and offline operation do not duplicate visit IDs or issued tokens on the primary device.

### M05 — Consultation slip and printing (P0)
- Configurable A5/A4 print layout: clinic name/logo/address/contact, date/time, doctor name, patient name/ID, age if recorded, token, short reason for visit and blank handwritten areas.
- Separate fields for doctor's handwritten medicines, advice and signature; no application-generated treatment content.
- Generate print-ready PDF client-side, preview, reprint with `DUPLICATE` indicator when required, and log print attempts without storing a scanned prescription.
- Printer compatibility: browser print dialogue first; direct thermal printing only after platform-specific testing.
- Acceptance: correctly aligned on tested printer/paper configurations; usable without internet once app assets are cached.

### M06 — Billing and payments (P0)
- Consultation fee catalogue by doctor/visit type; discounts with reason and approval threshold; cash, UPI, card, mixed tender, outstanding balance and refund audit.
- Separate bill/invoice and consultation slip. Configurable tax fields subject to accountant review; do not hard-code tax assumptions.
- Sequential display numbers with immutable UUID transaction IDs; no deletion of paid invoices, only reversal/credit events.
- Acceptance: daily cash/UPI/card totals reconcile to transaction ledger and refunds.

### M07 — Dashboard and reports (P0)
- Visits today, waiting queue, completed visits, collections by method, pending fees, doctor-wise counts and day-close summary.
- Export CSV/XLSX/PDF without exposing illness descriptions in ordinary financial reports.
- Acceptance: reports reconcile to source ledger; offline totals are labeled local/un-synced where applicable.

### M08 — Staff and access (P0)
- Owner, receptionist, doctor and optional accountant; role-based route guards and action authorization; auto-lock and logout.
- On a single shared workstation, require distinct staff sign-in or PIN backed by authenticated sessions and secure recovery.
- Acceptance: unauthorized roles cannot access exports, billing reversals or another doctor's sensitive visit details.

### M09 — Offline storage, sync and backup (P0)
- Local-first transactional writes, durable outbox, batch Sheets updates, Drive backups, status indicators, retry/backoff, restore wizard and corruption checks.
- Never represent a local save as a completed cloud backup; show timestamp of last verified backup.
- Acceptance: complete interrupted-sync, browser restart, duplicate-retry and restore tests.

### M10 — Subscription and licensing (P1 for commercial launch)
- Proposed ₹3,999/year per clinic; trial and renewal rules to be validated; owner-only billing controls.
- Server-verified entitlements and signed cached offline grace tokens. Never store universal unlock keys in frontend code or Google Sheets.
- Expired subscription must not trap patient data: permit secure export and legally required access, with a clearly documented limited mode.

### M11 — Expenses (P1)
- Rent, salaries, utilities, supplies, printer consumables and other operating expenses; optional receipt attachment in Drive.
- Acceptance: expense summaries exclude patient data and are exportable.

### M12 — Follow-up reminders (P2)
- Optional follow-up date, consent and notification preference; staff-visible reminder list.
- Paid SMS/WhatsApp integration only when separately enabled; no automated medical content or treatment instructions.

### M13 — Multi-doctor and multi-device live collaboration (P2)
- Shared queue, simultaneous updates and per-doctor schedules.
- Requires explicit coordination, authoritative event ordering and conflict handling; Sheets alone is not a safe real-time transactional backend.

### M14 — Multi-branch and integrations (P3)
- Branch-scoped records, consolidated reporting, optional ABDM interoperability after separate privacy/security and technical assessment.

## 6. Data model and spreadsheet templates

**Important:** Sheets are cloud administrative records, not the only live transactional engine. Store normalized operational data locally, use separate tabs for each entity, and keep sensitive illness descriptions in a restricted, encrypted dataset rather than ordinary broadly shared spreadsheets. For the initial privacy-minimizing MVP, synchronize only the minimum necessary illness field in an encrypted backup; do not include it in ordinary Sheets reports.

### 6.1 Suggested clinic-owned Drive structure

```text
ApnaClinic_<clinic_id>/
  Configuration/
    Clinic_Master (Google Sheet)
  Operations/
    Patient_Admin (Google Sheet; restricted)
    Visits_Queue (Google Sheet; restricted)
    Finance (Google Sheet; restricted by role)
  Reports/
    Daily_Summaries/
    Exports/
  Encrypted_Backups/
    backup_manifest.json
    clinic_backup_<timestamp>.enc
  Templates/
    consultation_slip_template.json
  Attachments/
    clinic_logo/
```

The application should request narrow Drive access, preferably to files it creates or files the owner explicitly selects. **Do not create public links to patient records.** Google Drive folder permissions alone are not a substitute for app-level authorization and encryption.

### 6.2 Sheet/tab schema (proposed)

Use snake_case column identifiers; every mutable row has `created_at`, `updated_at`, `version`, `is_deleted` and `last_event_id` where relevant. Dates use ISO 8601 with explicit offset; monetary amounts use integer paise to avoid floating-point errors.

| Spreadsheet / tab | Columns |
|---|---|
| Clinic_Master / `clinics` | clinic_id, clinic_name, registration_identifier_optional, logo_file_id, phone, email, address_line1, address_line2, city, state, postal_code, timezone, language, currency, operating_days, opening_time, closing_time, receipt_footer, slip_template_id, created_at, updated_at, version |
| Clinic_Master / `doctors` | doctor_id, clinic_id, display_name, qualification_display, registration_number_optional, specialty_display, consultation_fee_paise, slot_duration_min, active, created_at, updated_at, version |
| Clinic_Master / `staff` | staff_id, clinic_id, display_name, role, doctor_id_optional, auth_subject_id, active, last_login_at, created_at, updated_at, version |
| Clinic_Master / `fee_catalog` | fee_id, clinic_id, doctor_id_optional, visit_type, label, amount_paise, active_from, active_to, active, created_at, updated_at, version |
| Clinic_Master / `settings` | clinic_id, key, value_json, sensitivity, updated_at, version |
| Patient_Admin / `patients` | patient_id, clinic_id, full_name, phone_optional, normalized_phone_hash_optional, dob_optional, age_at_registration_optional, sex_optional, address_optional, guardian_name_optional, guardian_phone_optional, registration_at, consent_notice_version, consent_recorded_at_optional, active, created_at, updated_at, version |
| Visits_Queue / `appointments` | appointment_id, clinic_id, patient_id, doctor_id, scheduled_start_at, scheduled_end_at, appointment_type, status, booking_channel, cancellation_reason_optional, created_by, created_at, updated_at, version |
| Visits_Queue / `visits` | visit_id, clinic_id, patient_id, doctor_id, appointment_id_optional, visit_date, checkin_at, token_scope, token_number, visit_type, queue_status, reason_present_boolean, fee_id_optional, billing_id_optional, completed_at_optional, created_by, created_at, updated_at, version |
| Visits_Queue / `queue_events` | event_id, visit_id, clinic_id, doctor_id, event_type, from_status, to_status, actor_id, occurred_at, device_id, sync_status |
| Finance / `invoices` | invoice_id, clinic_id, visit_id, invoice_number, issued_at, subtotal_paise, discount_paise, tax_paise, total_paise, payment_status, created_by, voided_at_optional, void_reason_optional, created_at, updated_at, version |
| Finance / `payments` | payment_id, clinic_id, invoice_id, method, amount_paise, paid_at, external_reference_optional, collected_by, status, reversal_of_payment_id_optional, created_at, updated_at, version |
| Finance / `expenses` | expense_id, clinic_id, expense_date, category, description, amount_paise, payment_method, payee_optional, receipt_file_id_optional, created_by, created_at, updated_at, version |
| Finance / `day_close` | close_id, clinic_id, business_date, opened_by, closed_by, closed_at, opening_cash_paise, expected_cash_paise, counted_cash_paise, variance_paise, upi_total_paise, card_total_paise, refund_total_paise, notes_optional, version |
| Reports / `daily_summary` | clinic_id, business_date, doctor_id_optional, total_visits, completed_visits, no_shows, cancellations, gross_billed_paise, discounts_paise, refunds_paise, net_collections_paise, cash_paise, upi_paise, card_paise, outstanding_paise, generated_at, source_cursor |
| Configuration / `sync_manifest` | clinic_id, device_id, schema_version, last_uploaded_event_id, last_download_cursor, last_successful_sync_at, last_verified_backup_at, backup_checksum, sync_health, updated_at |
| Configuration / `audit_metadata` | audit_event_id, clinic_id, actor_id, action, entity_type, entity_id, occurred_at, device_id, outcome, correlation_id |

**Sensitive reason-for-visit storage:** locally store `visit_id`, `reason_for_visit_ciphertext`, `encryption_key_version`, `created_at`, `updated_at`, `retention_until`. If cloud recovery of this field is needed, include it only in authenticated, encrypted backup archives. Avoid copying free-text symptoms into notifications, logs, analytics or financial exports.

### 6.3 Record retention and deletion

Define and publish a retention schedule with qualified Indian legal/privacy review before production. Provide correction, export and deletion request workflows subject to applicable legal retention obligations. Backup deletion must account for encryption-key rotation and expiry; never promise immediate deletion from immutable backups unless implemented and tested.

## 7. Technical architecture

### 7.1 Client
- Flutter/Dart, responsive desktop/tablet/mobile layout; web-first launch.
- Local persistence: IndexedDB-backed durable storage on web, with a Dart repository abstraction permitting SQLite on Android/desktop later.
- Business logic: repository/service layer, typed domain models, local event ledger, sync worker and print/PDF adapter.
- Use a tested state-management approach (e.g., Riverpod) and declarative navigation; package versions selected during technical design.
- Cache application assets for offline operation; explicitly test browser storage eviction and clearing.

### 7.2 Cloud and authentication
- Google OAuth using least-privilege scopes and the official supported browser authentication flow; never embed a client secret in Flutter web.
- Google Sheets batch reads/writes for administrative records; Drive for owned files, exports and encrypted backups.
- A minimal trusted entitlement/auth coordination service may be necessary for paid subscriptions and multi-user access. If strictly no backend is permitted, restrict the initial offering to a single owner-operated device and document the security limitations.
- Use HTTPS, short-lived credentials and proper token lifecycle handling. No sensitive values in client logs or analytics.

### 7.3 Offline-first event flow
1. Validate the user action and authorization locally.
2. Atomically persist domain changes and an immutable outbox event in the local database.
3. Update UI from the local committed state.
4. When online and authenticated, collect bounded event batches, upload them, and record acknowledgements.
5. Reconcile uncertain outcomes by event ID before retrying to prevent duplicate payments or tokens.
6. Download authoritative changes only for allowed clinic scopes and resolve conflicts visibly.
7. Produce encrypted periodic Drive backups with checksums and tested restoration.

**Single-writer MVP rule:** One primary operational device per clinic is authoritative for queue, invoices and token allocation. Secondary devices may have read-only or delayed views until a real coordination backend is introduced.

## 8. API-minimization and 50,000-clinic scalability

### 8.1 Request budget — illustrative engineering targets, not provider guarantees

| Activity | Typical local behavior | Target cloud behavior |
|---|---|---|
| Patient search and lookup | Local indexed query | 0 API calls per search |
| Registration | Local transaction + outbox | Included in batch upload |
| Token issuance / queue movement | Local transaction | Included in batch upload |
| Consultation slip | Client-side PDF and browser print | 0 API calls per print |
| Payment collection | Local ledger | Included in batch upload |
| Dashboard and daily reports | Local aggregates | 0 API calls per refresh |
| Cloud changes | Sync manifest/cursor | Scheduled or manual bounded fetch |
| Backup | Local encrypted snapshot | 1 or more Drive requests per backup |

**Illustrative per-clinic budget:** 2–6 Sheets write requests/day using event batching, 1–4 read requests/day with infrequent checks, and 1–3 Drive requests per backup session. Actual usage depends on tab/range layout, retries, file sizes, number of devices and Google API behavior. Authentication and optional messaging incur separate requests. These figures must be measured with telemetry in a real pilot.

**Scale example:** 50,000 active clinics × 6 Sheets requests/day = 300,000 Sheets requests/day, but peak traffic and separate read/write project quotas matter more than the daily average. Do not promise free, unlimited, near-real-time synchronization for 50,000 active clinics through one Google Cloud project. Build quota dashboards, per-clinic scheduling jitter, exponential backoff, rate limiting and the ability to migrate synchronization architecture without replacing the Flutter app.

### 8.2 Cost control
- No Sheets calls per keystroke, print, queue update or dashboard refresh.
- Batch by operation type and bounded payload size; use incremental sync rather than downloading entire workbooks.
- Prefer daily cloud summary rows over exporting every UI event to ordinary Sheets; encrypted backups retain full recoverable state.
- Stagger sync windows; avoid synchronized midnight jobs and login-time full downloads.
- Archive old operational tabs; separate monthly/annual exports if growth requires it.
- Keep images, logos and backups in Drive, not as base64 spreadsheet cells.
- Monitor quota failures, sync lag, data volume and restore success; provide local-only operation during quota exhaustion.

## 9. Privacy, safety and security

Even a short illness description is health-related personal information. Treat all patient data as confidential. Obtain India-specific legal advice on applicable DPDP obligations, commencement dates, notice, consent or other lawful basis, security safeguards, processor agreements and breach response before launch.

Required controls: clear privacy notice; collect minimum necessary fields; role-scoped access; encrypted local sensitive records where platform permits; encryption of backup archives before upload; secure key management and recovery; HTTPS; audit logs; secure session expiry; access revocation; masked identifiers on shared screens; separate support diagnostics from patient data; verified export/deletion workflows; security review of Google OAuth and Drive scopes.

**Clinical boundary:** the app prints patient-supplied reasons for visiting but does not validate symptoms, suggest diagnosis, generate medication instructions or claim to replace a clinician. Provide an obvious emergency-care disclaimer only where appropriate; do not turn it into an automated triage feature.

## 10. UI and experience requirements

- Reception-first desktop dashboard: large universal search, `New Patient`, `New Visit`, `Print Slip`, current queue and collection summary.
- Patient form in two short steps: identity/contact; visit details. Make nonessential fields optional.
- Doctor view: assigned queue, token, patient name, patient-reported reason for visit and status actions.
- Print preview before final print; configurable A5/A4 layout and clear handwritten areas.
- Large controls and high-contrast status labels; keyboard shortcuts for frequent actions.
- Hindi/English localization, Indian date/time and currency formats; test with actual reception staff.
- Persistent offline/sync indicator; never hide an unbacked-up state.
- Responsive at 1366×768, common tablets and mobile widths; avoid horizontal overflow.

## 11. Performance and reliability targets

Proposed pilot targets, not existing measurements:
- Local patient search response: under 500 ms for a 20,000-patient local dataset on reference hardware.
- New visit + token: under 2 seconds after valid submission, excluding print-dialog time.
- Consultation slip PDF generation: under 2 seconds for standard layout on reference hardware.
- No duplicate visit IDs, invoice IDs or payment events under retry tests.
- Local operation remains available during at least an 8-hour simulated network outage.
- Full verified backup restore passes on a clean supported browser/device.
- Clearly display any feature limitations when browser storage is unavailable or blocked.

## 12. Feasibility and dependencies

| Feature | MVP feasibility with Flutter web + local store + Drive/Sheets | Main caveat |
|---|---|---|
| Patient registration/search | High | Privacy, deduplication and browser persistence |
| Appointments / single-device queue | High | Concurrent devices require coordination |
| Client-side consultation slip PDF | High | Printer-specific layout and browser print behavior |
| Basic billing and reports | High | Financial audit and tax configuration |
| Offline primary workstation | Medium–high | Storage eviction, device loss and recovery |
| Encrypted Drive backup | Medium | Key recovery and verified restore |
| Google Sheets batched admin sync | Medium–high | Shared project quotas and conflict handling |
| Secure multi-employee access | Medium | Trusted auth/authorization coordination required |
| Live multi-device queue | Low without backend | Sheets not a transactional realtime store |
| 50,000 active clinics, zero infrastructure cost | Not guaranteed | Peak quotas, support, auth, hosting and billing |
| Automated messaging | Later | Consent, provider fees and deliverability |

## 13. Monetization and customer support

**Proposed launch price:** ₹3,999/year per clinic, subject to paid pilot. Define whether taxes are included, device limits, doctor count, support hours, refund rules, renewal reminders and what happens after expiry. Do not block lawful access to existing patient data on subscription expiry.

**Initial support:** onboarding wizard, sample clinic mode with synthetic data, printable quick-start guide, in-app diagnostics without sensitive content, guided restore and a clear support contact. Printer configuration and Google account recovery will likely drive support workload; track actual time per clinic.

## 14. MVP delivery plan

| Phase | Deliverables | Exit criteria |
|---|---|---|
| 0 — Discovery (1–2 weeks) | Interview 15–30 clinics; collect sample blank slips; test printers and willingness to pay | Signed-off workflows, minimal field list and pilot cohort |
| 1 — Foundation (2 weeks) | Flutter shell, auth, clinic setup, local store, roles, templates | End-to-end test on target browsers |
| 2 — Core workflow (2–3 weeks) | Patients, appointments, queue, token, print slip | Offline register → token → print passes |
| 3 — Finance and reports (1–2 weeks) | Billing, payments, refunds, day-close, exports | Reconciliation tests pass |
| 4 — Sync/security (2–3 weeks) | Batching, Drive backup, encryption, restore, audit, privacy notice | Interrupted sync and recovery tests pass |
| 5 — Pilot and launch (2–4 weeks) | Real clinic pilot, printer testing, bug fixes, subscriptions | Pilot acceptance and release gates passed |

Estimates overlap where a capable team works in parallel; actual schedule depends on staffing, security review and field testing.

## 15. Acceptance test matrix

1. Register a new patient while offline, print slip, restart browser and find the patient.
2. Re-register a likely duplicate and show a warning without auto-merging.
3. Issue 100 tokens, interrupt network and retry; verify uniqueness.
4. Change doctor and reschedule an appointment without losing audit history.
5. Print A5 and A4 slips on at least three representative printers; check blank writing space.
6. Confirm no medication or treatment history is stored or uploaded.
7. Verify reason-for-visit does not appear in financial exports, logs or ordinary cloud sheets.
8. Test receptionist denial for bulk patient export and subscription settings.
9. Test accountant denial for illness description and doctor notes.
10. Record mixed payment, partial payment, refund and void; reconcile day-close.
11. Retry an acknowledged batch after simulated lost response; verify no duplicate event application.
12. Revoke Google access; local billing still works and cloud status shows action needed.
13. Reach API quota and simulate 429; confirm backoff without blocking local operations.
14. Restore encrypted backup on a clean device with correct authorization; compare checksums and record counts.
15. Try restoring with wrong key and corrupted archive; fail safely without partial overwrite.
16. Simulate browser storage eviction and document user-facing recovery behavior.
17. Verify subscription expiry permits safe export and any required record access.
18. Test data export and deletion request flow, including audit and backup retention handling.
19. Test 20,000 local patient records for lookup performance on reference hardware.
20. Validate accessibility, Hindi/English labels and small-screen layout with reception staff.

## 16. Launch gates and metrics

**Launch gates:** privacy/security review completed; printer and offline test matrix passed; real clinic pilot completed; no known critical data-loss, identity-mixup, duplicate-billing or authorization bugs; backup restoration independently tested; published subscription terms and support procedures.

**Pilot KPIs:** registration-to-print median time, daily active clinics, percentage of visits handled end-to-end, printing failure rate, backup freshness, average Sheets/Drive requests per active clinic/day, synchronization error rate, support minutes per clinic/week, trial-to-paid conversion, 30/90-day retention and renewal intent.

**Proposed pilot:** 10 clinics for 30 days, including one clinic with unreliable connectivity and one using a shared reception workstation. Interview staff weekly and observe actual workflows rather than relying on self-reported satisfaction alone.

## 17. Open decisions

1. Single doctor or multiple doctors in the ₹3,999 plan?
2. Exactly which patient fields are necessary on the consultation slip?
3. Should reason-for-visit be retained after the visit, or removed from routine records after a short retention period?
4. Is Google sign-in required for all staff, or only the clinic owner?
5. Which printers and paper sizes must be supported at launch?
6. Does the MVP require one operational workstation only, or true simultaneous doctor/reception devices?
7. What is the required cloud-backup frequency versus the API-cost target?
8. Will ₹3,999 include GST, and what is the refund/renewal policy?
9. Which Indian languages are needed beyond Hindi and English?
10. Who is responsible for clinic-level privacy administration and encryption-key recovery?

---

**Implementation principle:** Start with a fast, privacy-conscious registration → token → printed consultation slip → payment workflow. Preserve patient confidentiality, make local operations reliable, and measure actual Google API consumption before promising economics at 50,000 clinics.
