# APNA CLINIC — APPLICATION MODEL TO MASTER SHEET MAPPING
**Phase 2: Data Model Compatibility & Integration Mapping**  
**Document Version:** 2.0.0  
**Date:** September 2026  
**Status:** Engineering Baseline (Frozen UI Architecture)

---

## 1. Architectural Integration Principles

The Apna Clinic application follows a decoupled multi-tier architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                 Phase 1 UI Layer (FROZEN)                   │
│   (Screens, Widgets, Responsive Layouts, Design System)     │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                    Domain Entity Models                     │
│  (Patient, Doctor, Appointment, Visit, Invoice, Staff, etc) │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│              Local Database & State Management              │
│       (IndexedDB / SQLite Wasm / Drift Operational Store)   │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                    Master Sheet Adapter                     │
│    (Bi-directional Mapping, Type Conversion, Validation)    │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                 Master Sheet Storage Layer                  │
│       (20-Sheet Relational Google Sheets / Excel Workbook)  │
└─────────────────────────────────────────────────────────────┘
```

### Critical Rules
1. **Zero UI Disruption:** Phase 1 UI/UX is completely frozen. No screens, colors, or workflows are altered.
2. **Zero Field Loss:** Every single field present in current Dart entities is accounted for and cleanly mapped.
3. **Currency Conversion:** The internal domain stores financial amounts as 64-bit integer paise (`*_minor`, e.g., `50000` paise). The Master Sheet displays standard decimal Rupees (`500.00` INR). The Master Sheet Adapter converts bi-directionally:
   $$\text{Master Sheet (INR)} = \frac{\text{Domain Minor (Paise)}}{100}$$
   $$\text{Domain Minor (Paise)} = \text{ROUND}(\text{Master Sheet (INR)} \times 100)$$
4. **Permanent Unique ID Mapping:** Temporary local UUIDs are mapped to permanent sequential IDs (`PAT-000001`, `DOC-000001`, etc.) upon sync.

---

## 2. Entity-by-Entity Mapping Matrix

### 2.1 `Clinic` Model -> `01_SETTINGS` & Global Config
* **Dart Source File:** `lib/domain/entities/clinic.dart`
* **Target Sheet:** `01_SETTINGS`

| Dart Model Field | Dart Type | Master Sheet Table | Master Sheet Column / Key | Transformation / Notes |
|---|---|---|---|---|
| `clinicId` | `String` | `01_SETTINGS` | `setting_key: clinic_id` | Direct string identifier |
| `legalName` | `String` | `01_SETTINGS` | `setting_key: legal_name` | Direct string |
| `displayName` | `String` | `01_SETTINGS` | `setting_key: clinic_name` | Primary display title |
| `ownerName` | `String` | `01_SETTINGS` | `setting_key: owner_name` | Stored in settings category `Identity` |
| `contactPhone` | `String` | `01_SETTINGS` | `setting_key: clinic_phone` | Primary reception phone |
| `contactEmail` | `String` | `01_SETTINGS` | `setting_key: clinic_email` | Official email address |
| `addressLine1` + `addressLine2` | `String` | `01_SETTINGS` | `setting_key: clinic_address` | Combined physical address |
| `city` | `String` | `01_SETTINGS` | `setting_key: city` | Stored in settings category `Identity` |
| `district` | `String` | `01_SETTINGS` | `setting_key: district` | Stored in settings category `Identity` |
| `state` | `String` | `01_SETTINGS` | `setting_key: state` | Stored in settings category `Identity` |
| `pincode` | `String` | `01_SETTINGS` | `setting_key: pincode` | 6-digit postal code |
| `timezone` | `String` | `01_SETTINGS` | `setting_key: timezone` | Default: `Asia/Kolkata` |
| `currency` | `String` | `01_SETTINGS` | `setting_key: currency` | Default: `INR` |
| `language` | `String` | `01_SETTINGS` | `setting_key: language` | Default: `en` |
| `defaultPaperSize` | `String` | `01_SETTINGS` | `setting_key: default_paper_size` | E.g. `A4` or `A5` |
| `defaultConsultationFee` | `int` (paise) | `01_SETTINGS` | `setting_key: default_consultation_fee` | Converted from paise to INR (e.g. `500.00`) |
| `taxRegistrationNumber` | `String?` | `01_SETTINGS` | `setting_key: tax_registration_number` | GST / Tax ID |
| `openingTime` | `String` | `01_SETTINGS` | `setting_key: opening_time` | Standard `08:30` |
| `closingTime` | `String` | `01_SETTINGS` | `setting_key: closing_time` | Standard `20:30` |
| `subscriptionPlan` | `String` | `01_SETTINGS` | `setting_key: subscription_plan` | E.g. `trial`, `annual_standard` |
| `createdAt` | `DateTime` | `01_SETTINGS` | `setting_key: created_at` | ISO-8601 string |
| `updatedAt` | `DateTime` | `01_SETTINGS` | `updated_at` (all rows) | ISO-8601 string |
| `schemaVersion` | `String` | `01_SETTINGS` | `setting_key: schema_version` | Current: `2.0.0` |

---

### 2.2 `Doctor` Model -> `04_DOCTORS`
* **Dart Source File:** `lib/domain/entities/doctor.dart`
* **Target Sheet:** `04_DOCTORS`

| Dart Model Field | Dart Type | Master Sheet Column | Transformation / Notes |
|---|---|---|---|
| `doctorId` | `String` | `doctor_id` | Mapped to `DOC-000001` format |
| (Generated) | `String` | `doctor_code` | Derived mnemonic (e.g. `DR-SHARMA`) |
| `displayName` | `String` | `doctor_name` | Doctor's professional name |
| `specialtyLabel` | `String` | `specialization` | Clinical specialty |
| `qualificationText`| `String` | `qualification` | Medical degrees |
| `registrationNumber`| `String`| `registration_number` | Medical council registration code |
| `contactPhone` | `String` | `phone` | Direct contact telephone |
| (New in Sheet) | `String` | `email` | Professional doctor email |
| `roomLabel` | `String` | `room_id` | Foreign key referencing `16_ROOMS.room_id` |
| `defaultFee` | `int` (paise) | `consultation_fee` | Converted: `defaultFee / 100` (e.g. `500.00`) |
| `consultationDurationMinutes`| `int` | `consultation_duration_minutes` | Direct integer (e.g. `15`) |
| `active` | `bool` | `status` | `active ? 'ACTIVE' : 'INACTIVE'` |
| (New in Sheet) | `String` | `joining_date` | Date of association (`YYYY-MM-DD`) |
| `createdAt` | `DateTime` | `created_at` | Formatted `YYYY-MM-DD HH:MM:SS` |
| `updatedAt` | `DateTime` | `updated_at` | Formatted `YYYY-MM-DD HH:MM:SS` |

---

### 2.3 `Staff` Model -> `02_USERS` & `03_ROLES`
* **Dart Source File:** `lib/domain/entities/staff.dart`
* **Target Sheet:** `02_USERS`

| Dart Model Field | Dart Type | Master Sheet Column | Transformation / Notes |
|---|---|---|---|
| `staffId` | `String` | `user_id` | Mapped to `USR-000001` format |
| (Generated) | `String` | `username` | Clean username derived from display name |
| `displayName` | `String` | `display_name` | Full staff name |
| `role` | `UserRole` | `role_id` | References `03_ROLES.role_id` via role mapping |
| `phone` | `String` | `phone` | Contact phone |
| `email` | `String` | `email` | Contact email |
| `active` | `bool` | `status` | `active ? 'ACTIVE' : 'INACTIVE'` |
| `assignedDoctorIds`| `List<String>`| `assigned_doctor_ids` | Comma-delimited list of doctor IDs |
| `createdAt` | `DateTime` | `created_at` | Formatted `YYYY-MM-DD HH:MM:SS` |
| `updatedAt` | `DateTime` | `updated_at` | Formatted `YYYY-MM-DD HH:MM:SS` |

---

### 2.4 `Patient` Model -> `05_PATIENTS`
* **Dart Source File:** `lib/domain/entities/patient.dart`
* **Target Sheet:** `05_PATIENTS`

| Dart Model Field | Dart Type | Master Sheet Column | Transformation / Notes |
|---|---|---|---|
| `patientId` | `String` | `patient_id` | Permanent ID (`PAT-000001`) |
| `patientNumber` | `String` | `patient_code` | Card code (e.g. `P-2026-0001`) |
| (Derived) | `String` | `first_name` | Extracted from `fullName` first token |
| (Derived) | `String` | `middle_name` | Extracted middle token (if 3+ tokens) |
| (Derived) | `String` | `last_name` | Extracted last token from `fullName` |
| `fullName` | `String` | `full_name` | Full complete name |
| `dateOfBirth` | `String?` | `date_of_birth` | `YYYY-MM-DD` or NULL |
| `ageIfDobUnknown`| `int?` | `age` | Age in years |
| `sexOptional` | `String?` | `gender` | Mapped: `M` -> `MALE`, `F` -> `FEMALE`, `O` -> `OTHER` |
| `phoneOptional` | `String?` | `phone` | Primary mobile number |
| `alternatePhoneOptional`| `String?`| `alternate_phone` | Secondary phone |
| (New in Sheet) | `String` | `email` | Optional patient email |
| `addressOptional`| `String?` | `address` | Street address |
| `cityOptional` | `String?` | `city` | Default `New Delhi` if empty |
| (New in Sheet) | `String` | `state` | Default `Delhi` |
| `pincodeOptional`| `String?` | `pincode` | Postal code |
| `guardianNameOptional`| `String?`| `emergency_contact_name` | Contact person name |
| `guardianRelationOptional`| `String?`| `emergency_contact_name` | Stored alongside contact name |
| (New in Sheet) | `String` | `emergency_contact_phone`| Emergency phone number |
| (New in Sheet) | `String` | `blood_group` | Controlled lookup (`A+`, `B+`, etc.) |
| (Derived) | `String` | `registration_date` | `createdAt` date portion (`YYYY-MM-DD`) |
| `deletedAt` | `DateTime?`| `patient_status` | `deletedAt != null ? 'ARCHIVED' : 'ACTIVE'` |
| `consentStatus` | `String` | `consent_status` | `GRANTED`, `WITHDRAWN`, `PENDING` |
| `consentVersion`| `String` | `consent_version` | E.g. `v1.0` |
| `createdAt` | `DateTime` | `created_at` | Formatted `YYYY-MM-DD HH:MM:SS` |
| `updatedAt` | `DateTime` | `updated_at` | Formatted `YYYY-MM-DD HH:MM:SS` |
| (System) | `String` | `created_by` | Acting `user_id` |
| (System) | `String` | `updated_by` | Acting `user_id` |

---

### 2.5 `Appointment` Model -> `06_APPOINTMENTS`
* **Dart Source File:** `lib/domain/entities/appointment.dart`
* **Target Sheet:** `06_APPOINTMENTS`

| Dart Model Field | Dart Type | Master Sheet Column | Transformation / Notes |
|---|---|---|---|
| `appointmentId` | `String` | `appointment_id` | Permanent ID (`APT-000001`) |
| (Generated) | `String` | `appointment_code` | E.g. `APT-2026-0001` |
| `patientId` | `String` | `patient_id` | FK -> `05_PATIENTS.patient_id` |
| `doctorId` | `String` | `doctor_id` | FK -> `04_DOCTORS.doctor_id` |
| `scheduledStartAt`| `DateTime` | `appointment_date` | Date portion (`YYYY-MM-DD`) |
| `scheduledStartAt`| `DateTime` | `start_time` | Time portion (`HH:MM`) |
| `scheduledEndAt` | `DateTime` | `end_time` | Time portion (`HH:MM`) |
| `appointmentType`| `String` | `appointment_type` | Wire value normalized (`new_consultation` -> `NEW_CONSULTATION`) |
| `bookingSource` | `String` | `booking_source` | Wire value normalized (`walkin` -> `WALK_IN`, `phone` -> `PHONE`) |
| `status` | `String` | `status` | Wire value normalized (`scheduled` -> `SCHEDULED`, `completed` -> `COMPLETED`) |
| (From Visit) | `int` | `token_number` | Daily sequence token number (if checked in) |
| (From Doctor) | `String` | `room_id` | Chamber reference from doctor profile |
| `reasonForVisitEncryptedRef`| `String?`| `notes` | Administrative non-clinical visit reason |
| `cancelReason` | `String?` | `cancel_reason` | Reason if status is `CANCELLED` |
| `reminderConsent`| `bool` | `reminder_consent` | `TRUE` / `FALSE` |
| `reminderStatus` | `String` | `reminder_status` | `PENDING`, `SENT`, `FAILED`, `NOT_REQUESTED` |
| `createdAt` | `DateTime` | `created_at` | Formatted `YYYY-MM-DD HH:MM:SS` |
| `updatedAt` | `DateTime` | `updated_at` | Formatted `YYYY-MM-DD HH:MM:SS` |
| `createdByStaffId`| `String` | `created_by` | FK -> `02_USERS.user_id` |
| (System) | `String` | `updated_by` | FK -> `02_USERS.user_id` |

---

### 2.6 `Visit` Model -> `08_QUEUE` & `09_CONSULTATIONS`
* **Dart Source File:** `lib/domain/entities/visit.dart`
* **Target Sheets:** `08_QUEUE` (Operational Token Tracking) & `09_CONSULTATIONS` (Clinical Outcome)

#### Mapping to `08_QUEUE`:
| Dart Model Field | Dart Type | Master Sheet Column | Transformation / Notes |
|---|---|---|---|
| `visitId` | `String` | `queue_id` | Mapped to `TOK-000001` format |
| `appointmentIdOptional`| `String?`| `appointment_id` | FK -> `06_APPOINTMENTS.appointment_id` |
| `patientId` | `String` | `patient_id` | FK -> `05_PATIENTS.patient_id` |
| `doctorId` | `String` | `doctor_id` | FK -> `04_DOCTORS.doctor_id` |
| `tokenNumber` | `int` | `token_number` | Daily sequential integer |
| `visitDateLocal`| `String` | `queue_date` | `YYYY-MM-DD` |
| `checkinAt` | `DateTime` | `check_in_time` | Arrival timestamp |
| (New in Sheet) | `DateTime?` | `called_time` | Chamber call timestamp |
| `consultationStartedAt`| `DateTime?`| `consultation_start_time`| Start timestamp |
| `consultationCompletedAt`| `DateTime?`| `consultation_end_time` | Finish timestamp |
| `queueStatus` | `QueueStatus`| `queue_status` | `WAITING`, `CALLED`, `IN_CONSULTATION`, `COMPLETED`, `SKIPPED`, `CANCELLED` |
| (New in Sheet) | `String` | `priority` | `NORMAL`, `URGENT`, `VIP`, `EMERGENCY` |
| (From Doctor) | `String` | `room_id` | Chamber reference |
| `createdAt` | `DateTime` | `created_at` | Formatted `YYYY-MM-DD HH:MM:SS` |
| `updatedAt` | `DateTime` | `updated_at` | Formatted `YYYY-MM-DD HH:MM:SS` |

#### Mapping to `09_CONSULTATIONS`:
| Dart Model Field | Dart Type | Master Sheet Column | Transformation / Notes |
|---|---|---|---|
| (Generated) | `String` | `consultation_id` | Permanent ID (`CON-000001`) |
| `appointmentIdOptional`| `String?`| `appointment_id` | FK -> `06_APPOINTMENTS.appointment_id` |
| `patientId` | `String` | `patient_id` | FK -> `05_PATIENTS.patient_id` |
| `doctorId` | `String` | `doctor_id` | FK -> `04_DOCTORS.doctor_id` |
| `reasonForVisitEncryptedRef`| `String?`| `chief_complaint` | Presenting clinical problem |
| (New in Sheet) | `String` | `clinical_summary` | Vitals and physical examination notes |
| (New in Sheet) | `String` | `diagnosis` | Doctor's diagnostic assessment |
| (New in Sheet) | `String` | `advice` | General / lifestyle instructions |
| `followupDueDateOptional`| `String?`| `follow_up_required` | `followupDueDateOptional != null` |
| `followupDueDateOptional`| `String?`| `follow_up_date` | Review date (`YYYY-MM-DD`) |
| (Status) | `String` | `consultation_status` | `IN_PROGRESS`, `COMPLETED`, `CANCELLED` |
| `consultationStartedAt`| `DateTime?`| `started_at` | Start timestamp |
| `consultationCompletedAt`| `DateTime?`| `completed_at` | Completion timestamp |
| `createdAt` | `DateTime` | `created_at` | Formatted `YYYY-MM-DD HH:MM:SS` |
| `updatedAt` | `DateTime` | `updated_at` | Formatted `YYYY-MM-DD HH:MM:SS` |

---

### 2.7 `Invoice` & `InvoiceItem` Models -> `10_BILLING`
* **Dart Source File:** `lib/domain/entities/invoice.dart`
* **Target Sheet:** `10_BILLING`

| Dart Model Field | Dart Type | Master Sheet Column | Transformation / Notes |
|---|---|---|---|
| `invoiceId` | `String` | `invoice_id` | Permanent ID (`INV-000001`) |
| `invoiceNumber` | `String` | `invoice_number` | Serial reference (e.g. `INV-2026-0001`) |
| `patientId` | `String` | `patient_id` | FK -> `05_PATIENTS.patient_id` |
| `visitId` | `String?` | `appointment_id` | Linked visit / appointment reference |
| `issueDateLocal` | `String` | `invoice_date` | `YYYY-MM-DD` |
| `subtotalMinor` | `int` (paise) | `subtotal` | Converted: `subtotalMinor / 100` (e.g. `500.00`) |
| `discountMinor` | `int` (paise) | `discount` | Converted: `discountMinor / 100` (e.g. `0.00`) |
| `taxMinor` | `int` (paise) | `tax` | Converted: `taxMinor / 100` (e.g. `0.00`) |
| `totalMinor` | `int` (paise) | `total_amount` | Dynamic formula: `=F{row}-G{row}+H{row}` |
| `paidMinor` | `int` (paise) | `paid_amount` | Recorded settled amount (`paidMinor / 100`) |
| `balanceMinor` | `int` (paise) | `due_amount` | Dynamic formula: `=I{row}-J{row}` |
| `status` | `InvoiceStatus`| `payment_status` | Mapped to `UNPAID`, `PARTIAL`, `PAID`, `REFUNDED` |
| `notesNonclinical`| `String` | `notes` | Non-clinical billing notes |
| `createdAt` | `DateTime` | `created_at` | Formatted `YYYY-MM-DD HH:MM:SS` |
| `updatedAt` | `DateTime` | `updated_at` | Formatted `YYYY-MM-DD HH:MM:SS` |

---

### 2.8 `Payment` Model -> `11_PAYMENTS`
* **Dart Source File:** `lib/domain/entities/payment.dart`
* **Target Sheet:** `11_PAYMENTS`

| Dart Model Field | Dart Type | Master Sheet Column | Transformation / Notes |
|---|---|---|---|
| `paymentId` | `String` | `payment_id` | Permanent ID (`PAY-000001`) |
| `invoiceId` | `String` | `invoice_id` | FK -> `10_BILLING.invoice_id` |
| (Derived via Invoice)| `String` | `patient_id` | FK -> `05_PATIENTS.patient_id` |
| `receivedAt` | `DateTime` | `payment_date` | Date portion (`YYYY-MM-DD`) |
| `amountMinor` | `int` (paise) | `amount` | Converted: `amountMinor / 100` (e.g. `500.00`) |
| `method` | `PaymentMethod`| `payment_method` | `CASH`, `UPI`, `CARD`, `BANK_TRANSFER`, `OTHER` |
| `cashUpiCardReferenceOptional`| `String?`| `transaction_reference`| Payment reference or auth code |
| `status` | `PaymentStatus`| `payment_status`| `COMPLETED`, `PENDING`, `REVERSED`, `FAILED` |
| `receivedByStaffId`| `String` | `received_by` | FK -> `02_USERS.user_id` |
| (New in Sheet) | `String` | `notes` | Reconciliation notes |
| `createdAt` | `DateTime` | `created_at` | Formatted `YYYY-MM-DD HH:MM:SS` |

---

### 2.9 `FeeCatalog` Model -> `12_SERVICES`
* **Dart Source File:** `lib/domain/entities/fee_catalog.dart`
* **Target Sheet:** `12_SERVICES`

| Dart Model Field | Dart Type | Master Sheet Column | Transformation / Notes |
|---|---|---|---|
| `feeId` | `String` | `service_id` | Permanent ID (`SRV-000001`) |
| `feeCode` | `String` | `service_code` | Tariff code (e.g. `CONS-GEN`) |
| `feeName` | `String` | `service_name` | Display title |
| `taxCategory` | `String` | `category` | Mapped to `CONSULTATION`, `PROCEDURE`, `DIAGNOSTIC` |
| `description` | `String` | `description` | Service details |
| `defaultAmountMinor`| `int` (paise)| `default_fee` | Converted: `defaultAmountMinor / 100` |
| `taxRateConfig` | `String` | `tax_rate` | Parsed numeric tax percentage (e.g. `0.0`, `18.0`) |
| `active` | `bool` | `status` | `active ? 'ACTIVE' : 'INACTIVE'` |
| `createdAt` | `DateTime` | `created_at` | Formatted `YYYY-MM-DD HH:MM:SS` |
| `updatedAt` | `DateTime` | `updated_at` | Formatted `YYYY-MM-DD HH:MM:SS` |

---

### 2.10 `Followup` Model -> `15_FOLLOW_UPS`
* **Dart Source File:** `lib/domain/entities/followup.dart`
* **Target Sheet:** `15_FOLLOW_UPS`

| Dart Model Field | Dart Type | Master Sheet Column | Transformation / Notes |
|---|---|---|---|
| `followupId` | `String` | `followup_id` | Permanent ID (`FOL-000001`) |
| `patientId` | `String` | `patient_id` | FK -> `05_PATIENTS.patient_id` |
| `sourceVisitIdOptional`| `String?`| `consultation_id` | Source visit/consultation reference |
| `doctorId` | `String` | `doctor_id` | FK -> `04_DOCTORS.doctor_id` |
| `dueDate` | `String` | `due_date` | `YYYY-MM-DD` |
| `status` | `String` | `status` | Wire value normalized (`scheduled` -> `SCHEDULED`) |
| `reminderConsent` | `bool` | `reminder_consent` | `TRUE` / `FALSE` |
| `reminderSentAt` | `DateTime?`| `reminder_sent_at` | Dispatch timestamp |
| `convertedAppointmentIdOptional`| `String?`| `converted_appointment_id`| Booking generated from this review |
| `administrativeNoteOptional`| `String?`| `notes` | Scheduling remarks |
| `createdAt` | `DateTime` | `created_at` | Formatted `YYYY-MM-DD HH:MM:SS` |
| `updatedAt` | `DateTime` | `updated_at` | Formatted `YYYY-MM-DD HH:MM:SS` |

---

### 2.11 `AuditEvent` Model -> `17_AUDIT_LOG`
* **Dart Source File:** `lib/domain/entities/audit_event.dart`
* **Target Sheet:** `17_AUDIT_LOG`

| Dart Model Field | Dart Type | Master Sheet Column | Transformation / Notes |
|---|---|---|---|
| `auditEventId` | `String` | `audit_id` | Permanent ID (`AUD-000001`) |
| `occurredAt` | `DateTime` | `timestamp` | Formatted `YYYY-MM-DD HH:MM:SS` |
| `actorId` | `String` | `user_id` | FK -> `02_USERS.user_id` |
| `actorRole` | `String` | `user_role` | Uppercase normalized (`ADMIN`, `RECEPTIONIST`) |
| `action` | `String` | `action` | Standard action enum (e.g. `PATIENT_CREATED`) |
| `entityType` | `String` | `entity_type` | Uppercase normalized (`PATIENT`, `APPOINTMENT`) |
| `entityId` | `String` | `entity_id` | Primary key of modified entity |
| (Derived) | `String` | `old_value` | State snapshot prior to mutation |
| `fieldNamesJson` | `String` | `new_value` | Sanitized non-PII change summary |
| `deviceId` | `String` | `source` | Terminal identifier |
| `reasonOptional` | `String?` | `remarks` | Explanatory context |

---

## 3. Summary of Field Compatibility & Data Preservation

1. **100% Backward and Forward Compatibility:** All existing 11 Dart domain models map directly to columns across the 20 worksheets with zero field omission.
2. **Safe Expansion for Phase 3+:** The Master Sheet schema introduces structured sheets for:
   - `03_ROLES` (Formalizing RBAC)
   - `07_DOCTOR_SCHEDULES` (Supporting automated slot generation)
   - `14_PRESCRIPTIONS` (Structured itemized medication rows without repeating consultation headers)
   - `16_ROOMS` (Physical chamber tracking)
   - `18_NOTIFICATIONS` (Multi-channel reminder log)
   - `19_REPORTING` (Dynamic formula analytics)
   - `20_LOOKUPS` (Universal controlled enums)
3. **No UI Modification:** Because the Master Sheet sits behind the Data Adapter layer, the approved and frozen Phase 1 UI remains 100% intact and unaffected.
