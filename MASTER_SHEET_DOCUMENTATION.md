# APNA CLINIC — MASTER SHEET ARCHITECTURE & SPECIFICATION
**Phase 2: Master Sheet Template Documentation**  
**Document Version:** 2.0.0  
**Date:** September 2026  
**Status:** Engineering Baseline (Frozen UI Architecture)

---

## 1. Executive Summary & Objective

The **Apna Clinic Master Sheet** is the centralized, normalized relational data management specification for the entire Apna Clinic ecosystem. Designed with enterprise-grade relational database principles, the Master Sheet provides complete operational data persistence, auditable state transitions, referential integrity, and reporting across outpatient workflows.

### Architectural Principles
1. **Relational Normalization:** Structured as 20 distinct, single-responsibility worksheets (3NF normalized). No monolithic unpartitioned spreadsheets.
2. **Permanent Unique ID Architecture:** Immutable, human-readable, collision-resistant primary keys (e.g., `PAT-000001`, `DOC-000001`, `APT-000001`) ensure that references remain stable across sorting, filtering, row deletion, and sheet archiving. **Row numbers are NEVER used as identifiers.**
3. **Controlled Vocabulary via Centralized Lookups:** All status codes, payment methods, medical frequencies, and roles are maintained centrally in `20_LOOKUPS` and strictly enforced via spreadsheet data validations.
4. **Automated Formula-Driven Computations:** Financial balances (`total_amount = subtotal - discount + tax`, `due_amount = total_amount - paid_amount`) and operational KPIs are computed dynamically without brittle hardcoded values.
5. **Decoupled Architecture:** Strict separation between the Presentation Layer (UI is frozen), Business Logic, Data Adapters, and the Google Sheets / Excel persistence layer.
6. **Privacy & Security by Design:** Zero plaintext passwords, API keys, or unencrypted sensitive diagnostic narratives in the spreadsheet. Strict compliance with India's Digital Personal Data Protection Act (DPDPA 2023).

---

## 2. Master Workbook Inventory

The Master Workbook (`ApnaClinic_Master_Template.xlsx`) contains 20 canonical worksheets:

| Sheet Name | Category | Primary Purpose | Primary Key Format |
|---|---|---|---|
| `01_SETTINGS` | System | Global clinic parameters, operating hours, prefixes, formats | `SET-000001` |
| `02_USERS` | Identity | Clinic staff, doctors, receptionists, billing personnel | `USR-000001` |
| `03_ROLES` | Access Control | Role definitions, permissions, operational authorizations | `ROLE-000001` |
| `04_DOCTORS` | Clinical Roster | Doctor credentials, specialties, consultation fees, rooms | `DOC-000001` |
| `05_PATIENTS` | Demographics | Patient profiles, contacts, emergency contacts, consent | `PAT-000001` |
| `06_APPOINTMENTS` | Scheduling | Bookings, time slots, channels, status transitions | `APT-000001` |
| `07_DOCTOR_SCHEDULES`| Scheduling | Recurring weekly availability, session hours, slot capacity | `SCH-000001` |
| `08_QUEUE` | Operations | Real-time daily queue tokens, waiting times, calling order | `TOK-000001` |
| `09_CONSULTATIONS` | Clinical | Clinical encounter summaries, complaints, diagnoses, advice | `CON-000001` |
| `10_BILLING` | Finance | Invoices, itemized charges, subtotals, tax, balances | `INV-000001` |
| `11_PAYMENTS` | Finance | Payment ledger transactions (Cash, UPI, Card), receipts | `PAY-000001` |
| `12_SERVICES` | Master Catalog | Service master, procedure catalog, standard tariffs, taxes | `SRV-000001` |
| `13_MEDICAL_RECORDS`| Clinical Metadata| External lab reports, diagnostic attachments, drive URLs | `MED-000001` |
| `14_PRESCRIPTIONS` | Clinical | Itemized medication lines, dosage, frequency, routes | `RX-000001` |
| `15_FOLLOW_UPS` | Continuity | Administrative follow-up scheduling and reminder tracking | `FOL-000001` |
| `16_ROOMS` | Infrastructure | Consultation chambers, procedure rooms, waiting lounges | `ROOM-000001` |
| `17_AUDIT_LOG` | Compliance | Comprehensive audit trail of data modifications and access | `AUD-000001` |
| `18_NOTIFICATIONS` | Communications | WhatsApp/SMS reminder dispatch log, delivery confirmations | `NOT-000001` |
| `19_REPORTING` | Analytics | Real-time executive dashboards, operational KPIs, revenue | `KPI-001` |
| `20_LOOKUPS` | Controlled Lists | System enumerations, categories, status vocabularies | `LKP-000001` |

---

## 3. Entity Relationship Architecture

```
                    ┌─────────────────────────┐
                    │       01_SETTINGS       │
                    └─────────────────────────┘
                                 │
     ┌───────────────────────────┴───────────────────────────┐
     │                                                       │
┌──────────────┐                                    ┌────────────────┐
│   03_ROLES   │                                    │    16_ROOMS    │
└──────┬───────┘                                    └───────┬────────┘
       │ 1                                                  │ 1
       │ has                                                │ assigned
       ▼ *                                                  ▼ *
┌──────────────┐                                    ┌────────────────┐
│   02_USERS   │                                    │   04_DOCTORS   │
└──────────────┘                                    └───────┬────────┘
                                                            │ 1
       ┌────────────────────────────────────────────────────┼─────────────────────┐
       │                                                    │                     │
       ▼ *                                                  ▼ *                   ▼ *
┌────────────────┐                                  ┌────────────────┐    ┌─────────────────┐
│ 05_PATIENTS    │                                  │ 07_DOC_SCHED   │    │ 06_APPOINTMENTS │
└──────┬─────────┘                                  └────────────────┘    └────────┬────────┘
       │                                                                           │
       ├─────────────────────────────────┬───────────────────┬─────────────────────┤
       │ 1                               │ 1                 │ 1                   │ 1
       │                                 │                   │                     │
       ▼ *                               ▼ *                 ▼ *                   ▼ *
┌────────────────┐               ┌────────────────┐  ┌────────────────┐    ┌────────────────┐
│ 08_QUEUE       │               │ 09_CONSULT     │  │   10_BILLING   │    │  15_FOLLOW_UPS │
│ (TOK-000001)   │               │ (CON-000001)   │  │  (INV-000001)  │    │  (FOL-000001)  │
└────────────────┘               └───────┬────────┘  └───────┬────────┘    └────────────────┘
                                         │ 1                 │ 1
                                         │                   │
                                         ▼ *                 ▼ *
                                 ┌────────────────┐  ┌────────────────┐
                                 │14_PRESCRIPTIONS│  │  11_PAYMENTS   │
                                 │  (RX-000001)   │  │  (PAY-000001)  │
                                 └────────────────┘  └────────────────┘
```

---

## 4. Comprehensive Worksheet Documentation

### 4.1 Sheet: `01_SETTINGS`
* **Purpose:** Stores global clinic configurations, legal entity metadata, operating hours, formatting preferences, and unique ID prefixes.
* **Columns:**
  1. `setting_id` (PK, String, Required): Unique identifier (`SET-000001`).
  2. `setting_category` (String, Required): Category grouping (`Identity`, `Operations`, `Prefixes`, `Formatting`, `Compliance`, `System`).
  3. `setting_key` (String, Required, Unique): Canonical parameter key (e.g. `clinic_name`, `timezone`, `currency`, `default_appointment_duration`, `patient_code_prefix`, `schema_version`).
  4. `setting_value` (String, Required): Value configured for the clinic.
  5. `data_type` (Enum, Required): Type definition (`STRING`, `INTEGER`, `DECIMAL`, `TIME`, `DATE_FORMAT`).
  6. `description` (String, Required): Plain-text operational explanation.
  7. `is_system` (Boolean, Required): `TRUE` for system-immutable keys; `FALSE` for user-configurable settings.
  8. `updated_at` (Timestamp, Required): ISO-8601 timestamp (`YYYY-MM-DD HH:MM:SS`).

---

### 4.2 Sheet: `02_USERS`
* **Purpose:** Stores clinic staff profiles, user identities, roles, and assigned doctor relationships.
* **Columns:**
  1. `user_id` (PK, String, Required): Unique identifier (`USR-000001`).
  2. `username` (String, Required, Unique): Unique system login username.
  3. `display_name` (String, Required): Full human name of the staff member.
  4. `role_id` (FK -> `03_ROLES.role_id`, Required): Assigned role identifier (`ROLE-000001` to `ROLE-000005`).
  5. `phone` (String, Required): Mobile phone number (`+91 98XXXXXXXX`).
  6. `email` (String, Optional): Professional work email.
  7. `status` (Enum, Required): Controlled lookup (`ACTIVE`, `INACTIVE`, `SUSPENDED`).
  8. `assigned_doctor_ids` (String, Optional): Comma-separated list of `doctor_id`s managed by this staff member.
  9. `created_at` (Timestamp, Required): Record creation timestamp.
  10. `updated_at` (Timestamp, Required): Record update timestamp.

---

### 4.3 Sheet: `03_ROLES`
* **Purpose:** Defines granular role-based access control (RBAC) classifications and operational permission sets.
* **Columns:**
  1. `role_id` (PK, String, Required): Unique identifier (`ROLE-000001`).
  2. `role_code` (Enum, Required, Unique): Machine code (`ADMIN`, `RECEPTIONIST`, `DOCTOR`, `BILLING`, `MANAGER`).
  3. `role_name` (String, Required): Human-readable display label.
  4. `description` (String, Required): Scope of functional responsibilities.
  5. `permissions_summary` (String, Required): Comma-delimited list of granted permissions.
  6. `status` (Enum, Required): Controlled lookup (`ACTIVE`, `INACTIVE`).
  7. `created_at` (Timestamp, Required): Record creation timestamp.
  8. `updated_at` (Timestamp, Required): Record update timestamp.

---

### 4.4 Sheet: `04_DOCTORS`
* **Purpose:** Doctor master directory, medical credentials, specializations, consultation fees, and chamber assignments.
* **Columns:**
  1. `doctor_id` (PK, String, Required): Unique identifier (`DOC-000001`).
  2. `doctor_code` (String, Required, Unique): Short identifier code (`DR-SHARMA`).
  3. `doctor_name` (String, Required): Complete doctor name with honorific.
  4. `specialization` (String, Required): Clinical specialty area.
  5. `qualification` (String, Required): Medical degrees (`MBBS, MD (Medicine)`).
  6. `registration_number` (String, Required): State/National Medical Council registration number.
  7. `phone` (String, Required): Professional contact phone.
  8. `email` (String, Required): Doctor email address.
  9. `room_id` (FK -> `16_ROOMS.room_id`, Required): Primary consultation chamber.
  10. `consultation_fee` (Decimal, Required): Default consultation charge in INR.
  11. `consultation_duration_minutes` (Integer, Required): Standard slot duration (e.g. `15`).
  12. `status` (Enum, Required): Controlled lookup (`ACTIVE`, `ON_LEAVE`, `INACTIVE`).
  13. `joining_date` (Date, Required): Employment/association start date (`YYYY-MM-DD`).
  14. `created_at` (Timestamp, Required): Record creation timestamp.
  15. `updated_at` (Timestamp, Required): Record update timestamp.

---

### 4.5 Sheet: `05_PATIENTS`
* **Purpose:** Core patient demographic directory, emergency contacts, blood group, and DPDPA consent tracking.
* **Columns:**
  1. `patient_id` (PK, String, Required): Unique identifier (`PAT-000001`).
  2. `patient_code` (String, Required, Unique): Formatted patient card code (`P-2026-0001`).
  3. `first_name` (String, Required): Patient first name.
  4. `middle_name` (String, Optional): Patient middle name.
  5. `last_name` (String, Required): Patient last name.
  6. `full_name` (String, Required): Concatenated complete name.
  7. `date_of_birth` (Date, Optional): Patient birth date (`YYYY-MM-DD`).
  8. `age` (Integer, Required): Age in years (calculated or entered if DOB unknown).
  9. `gender` (Enum, Required): Controlled lookup (`MALE`, `FEMALE`, `OTHER`).
  10. `phone` (String, Required): Primary contact phone number.
  11. `alternate_phone` (String, Optional): Backup contact phone.
  12. `email` (String, Optional): Patient email address.
  13. `address` (String, Optional): Street address line.
  14. `city` (String, Required): City name.
  15. `state` (String, Required): State / Union Territory.
  16. `pincode` (String, Required): 6-digit postal code.
  17. `emergency_contact_name` (String, Optional): Kin / emergency contact person.
  18. `emergency_contact_phone` (String, Optional): Emergency phone number.
  19. `blood_group` (Enum, Required): Controlled lookup (`A+`, `A-`, `B+`, `B-`, `AB+`, `AB-`, `O+`, `O-`, `UNKNOWN`).
  20. `registration_date` (Date, Required): Date of first registration (`YYYY-MM-DD`).
  21. `patient_status` (Enum, Required): Controlled lookup (`ACTIVE`, `INACTIVE`, `ARCHIVED`).
  22. `consent_status` (Enum, Required): Controlled lookup (`GRANTED`, `WITHDRAWN`, `PENDING`).
  23. `consent_version` (String, Required): Privacy notice version agreed to (e.g. `v1.0`).
  24. `created_at` (Timestamp, Required): Record creation timestamp.
  25. `updated_at` (Timestamp, Required): Record update timestamp.
  26. `created_by` (FK -> `02_USERS.user_id`, Required): User creating patient.
  27. `updated_by` (FK -> `02_USERS.user_id`, Required): User modifying patient.

---

### 4.6 Sheet: `06_APPOINTMENTS`
* **Purpose:** Appointment bookings, schedules, appointment types, booking sources, and status workflows.
* **Columns:**
  1. `appointment_id` (PK, String, Required): Unique identifier (`APT-000001`).
  2. `appointment_code` (String, Required, Unique): Formatted booking code (`APT-2026-0001`).
  3. `patient_id` (FK -> `05_PATIENTS.patient_id`, Required): Reference to patient.
  4. `doctor_id` (FK -> `04_DOCTORS.doctor_id`, Required): Reference to doctor.
  5. `appointment_date` (Date, Required): Scheduled appointment date (`YYYY-MM-DD`).
  6. `start_time` (Time, Required): Slot start time (`HH:MM`).
  7. `end_time` (Time, Required): Slot end time (`HH:MM`).
  8. `appointment_type` (Enum, Required): Controlled lookup (`NEW_CONSULTATION`, `FOLLOW_UP`, `EMERGENCY`, `ROUTINE_CHECKUP`).
  9. `booking_source` (Enum, Required): Controlled lookup (`WALK_IN`, `PHONE`, `RECEPTION`, `ONLINE`).
  10. `status` (Enum, Required): Controlled lookup (`SCHEDULED`, `CHECKED_IN`, `IN_CONSULTATION`, `COMPLETED`, `CANCELLED`, `NO_SHOW`).
  11. `token_number` (Integer, Optional): Daily sequential queue token number (if checked in).
  12. `room_id` (FK -> `16_ROOMS.room_id`, Required): Assigned chamber.
  13. `notes` (String, Optional): Administrative scheduling notes.
  14. `cancel_reason` (String, Optional): Explanation if status is `CANCELLED`.
  15. `reminder_consent` (Boolean, Required): `TRUE` or `FALSE`.
  16. `reminder_status` (Enum, Required): `PENDING`, `SENT`, `FAILED`, `NOT_REQUESTED`.
  17. `created_at` (Timestamp, Required): Record creation timestamp.
  18. `updated_at` (Timestamp, Required): Record update timestamp.
  19. `created_by` (FK -> `02_USERS.user_id`, Required): User creating appointment.
  20. `updated_by` (FK -> `02_USERS.user_id`, Required): User modifying appointment.

---

### 4.7 Sheet: `07_DOCTOR_SCHEDULES`
* **Purpose:** Recurring weekly shift schedules, break intervals, slot lengths, and patient caps per doctor.
* **Columns:**
  1. `schedule_id` (PK, String, Required): Unique identifier (`SCH-000001`).
  2. `doctor_id` (FK -> `04_DOCTORS.doctor_id`, Required): Reference to doctor.
  3. `day_of_week` (Enum, Required): Controlled lookup (`MONDAY` through `SUNDAY`).
  4. `start_time` (Time, Required): Shift start (`HH:MM`).
  5. `end_time` (Time, Required): Shift end (`HH:MM`).
  6. `slot_duration` (Integer, Required): Consultation interval in minutes (e.g. `15`).
  7. `break_start` (Time, Optional): Break start time.
  8. `break_end` (Time, Optional): Break end time.
  9. `room_id` (FK -> `16_ROOMS.room_id`, Required): Scheduled chamber.
  10. `maximum_patients` (Integer, Required): Maximum patient intake cap for shift.
  11. `status` (Enum, Required): Controlled lookup (`ACTIVE`, `INACTIVE`).
  12. `effective_from` (Date, Required): Schedule effective start date (`YYYY-MM-DD`).
  13. `effective_to` (Date, Required): Schedule expiration date (`2099-12-31`).
  14. `created_at` (Timestamp, Required): Record creation timestamp.
  15. `updated_at` (Timestamp, Required): Record update timestamp.

---

### 4.8 Sheet: `08_QUEUE`
* **Purpose:** Real-time patient flow management, daily sequential token allocation, and calling status.
* **Columns:**
  1. `queue_id` (PK, String, Required): Unique identifier (`TOK-000001`).
  2. `appointment_id` (FK -> `06_APPOINTMENTS.appointment_id`, Optional): Linked appointment (optional for walk-ins).
  3. `patient_id` (FK -> `05_PATIENTS.patient_id`, Required): Reference to patient.
  4. `doctor_id` (FK -> `04_DOCTORS.doctor_id`, Required): Reference to doctor.
  5. `token_number` (Integer, Required): Monotonic daily token sequence per doctor.
  6. `queue_date` (Date, Required): Date of queue entry (`YYYY-MM-DD`).
  7. `check_in_time` (Timestamp, Required): Timestamp patient arrived at clinic.
  8. `called_time` (Timestamp, Optional): Timestamp doctor called the token.
  9. `consultation_start_time` (Timestamp, Optional): Timestamp patient entered chamber.
  10. `consultation_end_time` (Timestamp, Optional): Timestamp consultation concluded.
  11. `queue_status` (Enum, Required): Controlled lookup (`WAITING`, `CALLED`, `IN_CONSULTATION`, `COMPLETED`, `SKIPPED`, `CANCELLED`).
  12. `priority` (Enum, Required): Controlled lookup (`NORMAL`, `URGENT`, `VIP`, `EMERGENCY`).
  13. `room_id` (FK -> `16_ROOMS.room_id`, Required): Chamber where patient is seen.
  14. `created_at` (Timestamp, Required): Record creation timestamp.
  15. `updated_at` (Timestamp, Required): Record update timestamp.

---

### 4.9 Sheet: `09_CONSULTATIONS`
* **Purpose:** Clinical consultation encounters, chief complaints, physical findings, diagnosis, and advice.
* **Columns:**
  1. `consultation_id` (PK, String, Required): Unique identifier (`CON-000001`).
  2. `appointment_id` (FK -> `06_APPOINTMENTS.appointment_id`, Required): Linked appointment.
  3. `patient_id` (FK -> `05_PATIENTS.patient_id`, Required): Reference to patient.
  4. `doctor_id` (FK -> `04_DOCTORS.doctor_id`, Required): Reference to doctor.
  5. `chief_complaint` (String, Required): Primary reason for seeking care.
  6. `clinical_summary` (String, Optional): Vitals, physical examination findings.
  7. `diagnosis` (String, Required): Clinician's diagnostic assessment.
  8. `advice` (String, Optional): Lifestyle guidance, dietary, general advice.
  9. `follow_up_required` (Boolean, Required): `TRUE` or `FALSE`.
  10. `follow_up_date` (Date, Optional): Recommended review date (`YYYY-MM-DD`).
  11. `consultation_status` (Enum, Required): Controlled lookup (`IN_PROGRESS`, `COMPLETED`, `CANCELLED`, `REFERRED`).
  12. `started_at` (Timestamp, Required): Consultation initiation timestamp.
  13. `completed_at` (Timestamp, Optional): Consultation completion timestamp.
  14. `created_at` (Timestamp, Required): Record creation timestamp.
  15. `updated_at` (Timestamp, Required): Record update timestamp.

---

### 4.10 Sheet: `10_BILLING`
* **Purpose:** Master invoice ledger, subtotal, discount, tax, automated total calculation, and outstanding balances.
* **Columns:**
  1. `invoice_id` (PK, String, Required): Unique identifier (`INV-000001`).
  2. `invoice_number` (String, Required, Unique): Serial invoice code (`INV-2026-0001`).
  3. `patient_id` (FK -> `05_PATIENTS.patient_id`, Required): Reference to patient.
  4. `appointment_id` (FK -> `06_APPOINTMENTS.appointment_id`, Optional): Linked appointment.
  5. `invoice_date` (Date, Required): Billing date (`YYYY-MM-DD`).
  6. `subtotal` (Decimal, Required): Gross amount before deductions in INR.
  7. `discount` (Decimal, Required): Total concession applied in INR (default `0.00`).
  8. `tax` (Decimal, Required): Applicable tax amount in INR (default `0.00`).
  9. `total_amount` (Decimal, Required): Formula: `=subtotal - discount + tax` (`=F2-G2+H2`).
  10. `paid_amount` (Decimal, Required): Total payments settled against invoice.
  11. `due_amount` (Decimal, Required): Formula: `=total_amount - paid_amount` (`=I2-J2`).
  12. `payment_status` (Enum, Required): Controlled lookup (`UNPAID`, `PARTIAL`, `PAID`, `REFUNDED`).
  13. `notes` (String, Optional): Non-clinical billing remarks.
  14. `created_at` (Timestamp, Required): Record creation timestamp.
  15. `updated_at` (Timestamp, Required): Record update timestamp.

---

### 4.11 Sheet: `11_PAYMENTS`
* **Purpose:** Payment transaction log, payment methods (Cash, UPI, Card), transaction references, and cashier accountability.
* **Columns:**
  1. `payment_id` (PK, String, Required): Unique identifier (`PAY-000001`).
  2. `invoice_id` (FK -> `10_BILLING.invoice_id`, Required): Reference to invoice.
  3. `patient_id` (FK -> `05_PATIENTS.patient_id`, Required): Reference to patient.
  4. `payment_date` (Date, Required): Transaction date (`YYYY-MM-DD`).
  5. `amount` (Decimal, Required): Payment received in INR.
  6. `payment_method` (Enum, Required): Controlled lookup (`CASH`, `UPI`, `CARD`, `BANK_TRANSFER`, `OTHER`).
  7. `transaction_reference` (String, Optional): UPI reference number, Card POS auth code, or receipt number.
  8. `payment_status` (Enum, Required): Controlled lookup (`COMPLETED`, `PENDING`, `REVERSED`, `FAILED`).
  9. `received_by` (FK -> `02_USERS.user_id`, Required): Staff receiving payment.
  10. `notes` (String, Optional): Settlement or reconciliation notes.
  11. `created_at` (Timestamp, Required): Record creation timestamp.

---

### 4.12 Sheet: `12_SERVICES`
* **Purpose:** Clinical fee catalog, procedures, diagnostic tests, standard rates, and GST tax percentages.
* **Columns:**
  1. `service_id` (PK, String, Required): Unique identifier (`SRV-000001`).
  2. `service_code` (String, Required, Unique): Short billing code (`CONS-GEN`, `PROC-ECG`).
  3. `service_name` (String, Required): Full clinical service title.
  4. `category` (Enum, Required): Controlled lookup (`CONSULTATION`, `PROCEDURE`, `DIAGNOSTIC`, `CERTIFICATE`, `OTHER`).
  5. `description` (String, Required): Detailed service description.
  6. `default_fee` (Decimal, Required): Standard tariff in INR.
  7. `tax_rate` (Decimal, Required): Tax rate percentage (e.g. `0.0` or `18.0`).
  8. `status` (Enum, Required): Controlled lookup (`ACTIVE`, `INACTIVE`).
  9. `created_at` (Timestamp, Required): Record creation timestamp.
  10. `updated_at` (Timestamp, Required): Record update timestamp.

---

### 4.13 Sheet: `13_MEDICAL_RECORDS`
* **Purpose:** Index of external lab test reports, radiology scans, and document URLs linked to patient consultations.
* **Columns:**
  1. `record_id` (PK, String, Required): Unique identifier (`MED-000001`).
  2. `patient_id` (FK -> `05_PATIENTS.patient_id`, Required): Reference to patient.
  3. `consultation_id` (FK -> `09_CONSULTATIONS.consultation_id`, Optional): Linked consultation encounter.
  4. `record_type` (Enum, Required): Controlled lookup (`LAB_REPORT`, `RADIOLOGY`, `DISCHARGE_SUMMARY`, `IMMUNIZATION`, `OTHER`).
  5. `title` (String, Required): Title of the diagnostic report.
  6. `description` (String, Optional): Key clinical report summary values.
  7. `document_url` (String, Required): Secured Google Drive file link.
  8. `record_date` (Date, Required): Test/document creation date (`YYYY-MM-DD`).
  9. `created_by` (FK -> `02_USERS.user_id`, Required): Staff uploading document.
  10. `created_at` (Timestamp, Required): Record creation timestamp.
  11. `updated_at` (Timestamp, Required): Record update timestamp.

---

### 4.14 Sheet: `14_PRESCRIPTIONS`
* **Purpose:** Normalized prescription items. Supports multiple medication rows per consultation encounter.
* **Columns:**
  1. `prescription_id` (PK, String, Required): Unique identifier (`RX-000001`).
  2. `consultation_id` (FK -> `09_CONSULTATIONS.consultation_id`, Required): Reference to consultation.
  3. `patient_id` (FK -> `05_PATIENTS.patient_id`, Required): Reference to patient.
  4. `medicine_name` (String, Required): Medicine formulation and brand/generic name (e.g. `Tab Paracetamol 650mg`).
  5. `dosage` (String, Required): Specific strength per dose (e.g. `1 tablet`, `5 ml`).
  6. `frequency` (Enum, Required): Controlled lookup (`ONCE_DAILY`, `TWICE_DAILY`, `THRICE_DAILY`, `FOUR_TIMES_DAILY`, `AS_NEEDED`).
  7. `duration` (String, Required): Treatment course period (e.g. `3 days`, `30 days`).
  8. `route` (Enum, Required): Controlled lookup (`ORAL`, `TOPICAL`, `INHALATION`, `INJECTION`, `DROPS`).
  9. `instructions` (String, Required): Administration timing (e.g. `Take after food with warm water`).
  10. `quantity` (Integer, Required): Total count of units to dispense (e.g. `10`).
  11. `created_at` (Timestamp, Required): Record creation timestamp.

---

### 4.15 Sheet: `15_FOLLOW_UPS`
* **Purpose:** Administrative tracking of recommended patient follow-up appointments and reminders.
* **Columns:**
  1. `followup_id` (PK, String, Required): Unique identifier (`FOL-000001`).
  2. `patient_id` (FK -> `05_PATIENTS.patient_id`, Required): Reference to patient.
  3. `consultation_id` (FK -> `09_CONSULTATIONS.consultation_id`, Optional): Source consultation encounter.
  4. `doctor_id` (FK -> `04_DOCTORS.doctor_id`, Required): Treating doctor.
  5. `due_date` (Date, Required): Expected review date (`YYYY-MM-DD`).
  6. `status` (Enum, Required): Controlled lookup (`SCHEDULED`, `COMPLETED`, `CANCELLED`, `MISSED`).
  7. `reminder_consent` (Boolean, Required): `TRUE` or `FALSE`.
  8. `reminder_sent_at` (Timestamp, Optional): Timestamp reminder was dispatched.
  9. `converted_appointment_id` (FK -> `06_APPOINTMENTS.appointment_id`, Optional): Booking created from this follow-up.
  10. `notes` (String, Optional): Administrative scheduling notes.
  11. `created_at` (Timestamp, Required): Record creation timestamp.
  12. `updated_at` (Timestamp, Required): Record update timestamp.

---

### 4.16 Sheet: `16_ROOMS`
* **Purpose:** Clinic facility directory, consultation chambers, procedure rooms, and active doctor occupancy.
* **Columns:**
  1. `room_id` (PK, String, Required): Unique identifier (`ROOM-000001`).
  2. `room_code` (String, Required, Unique): Short chamber identifier (`CHAMBER-1`, `PROC-ROOM`).
  3. `room_name` (String, Required): Display name of chamber.
  4. `room_type` (Enum, Required): Controlled lookup (`CONSULTATION`, `EXAMINATION`, `PROCEDURE`, `WAITING`, `PHARMACY`).
  5. `floor` (String, Required): Building floor level (`Ground Floor`).
  6. `status` (Enum, Required): Controlled lookup (`AVAILABLE`, `OCCUPIED`, `MAINTENANCE`, `RESERVED`).
  7. `assigned_doctor_id` (FK -> `04_DOCTORS.doctor_id`, Optional): Current doctor occupant.
  8. `notes` (String, Optional): Chamber equipment details.
  9. `created_at` (Timestamp, Required): Record creation timestamp.
  10. `updated_at` (Timestamp, Required): Record update timestamp.

---

### 4.17 Sheet: `17_AUDIT_LOG`
* **Purpose:** Immutable append-only audit trail capturing every state change, transaction, and access event.
* **Columns:**
  1. `audit_id` (PK, String, Required): Unique identifier (`AUD-000001`).
  2. `timestamp` (Timestamp, Required): Event timestamp (`YYYY-MM-DD HH:MM:SS`).
  3. `user_id` (FK -> `02_USERS.user_id`, Required): Acting user.
  4. `user_role` (Enum, Required): User role during action (`ADMIN`, `RECEPTIONIST`, `DOCTOR`, `BILLING`).
  5. `action` (Enum, Required): Action code (`PATIENT_CREATED`, `PATIENT_UPDATED`, `APPOINTMENT_CREATED`, `APPOINTMENT_CANCELLED`, `PATIENT_CHECKED_IN`, `CONSULTATION_STARTED`, `CONSULTATION_COMPLETED`, `INVOICE_GENERATED`, `PAYMENT_RECEIVED`, `REFUND_ISSUED`).
  6. `entity_type` (Enum, Required): Target entity (`PATIENT`, `APPOINTMENT`, `VISIT`, `CONSULTATION`, `INVOICE`, `PAYMENT`, `DOCTOR`, `SETTINGS`).
  7. `entity_id` (String, Required): Primary key of the affected entity.
  8. `old_value` (String, Optional): State snapshot prior to mutation (sanitized of sensitive health data).
  9. `new_value` (String, Optional): State snapshot after mutation.
  10. `source` (String, Required): Device/Terminal identifier (e.g. `Reception-PC-01`).
  11. `remarks` (String, Optional): Explanatory operational context.

---

### 4.18 Sheet: `18_NOTIFICATIONS`
* **Purpose:** Log of automated and manual notifications dispatched to patients via SMS, WhatsApp, and Email.
* **Columns:**
  1. `notification_id` (PK, String, Required): Unique identifier (`NOT-000001`).
  2. `patient_id` (FK -> `05_PATIENTS.patient_id`, Required): Target patient.
  3. `notification_type` (Enum, Required): Controlled lookup (`APPOINTMENT_REMINDER`, `FOLLOW_UP_REMINDER`, `QUEUE_ALERT`, `BILLING_RECEIPT`, `CONSENT_CONFIRMATION`).
  4. `recipient_contact` (String, Required): Destination phone number or email.
  5. `scheduled_at` (Timestamp, Required): Desired delivery time.
  6. `sent_at` (Timestamp, Optional): Actual gateway dispatch time.
  7. `channel` (Enum, Required): Controlled lookup (`WHATSAPP`, `SMS`, `EMAIL`).
  8. `template_name` (String, Required): Notification template identifier (e.g. `apt_reminder_v1`).
  9. `status` (Enum, Required): Controlled lookup (`PENDING`, `SENT`, `DELIVERED`, `FAILED`).
  10. `delivery_status` (String, Optional): Gateway transmission acknowledgment code.
  11. `remarks` (String, Optional): Operational notes.
  12. `created_at` (Timestamp, Required): Record creation timestamp.

---

### 4.19 Sheet: `19_REPORTING`
* **Purpose:** Real-time derived analytics dashboard delivering executive summaries and operational metrics without duplicating source data.
* **Columns:**
  1. `kpi_metric_id` (PK, String, Required): Metric identifier (`KPI-001`).
  2. `metric_name` (String, Required): Human label for the indicator.
  3. `metric_value_formula` (Formula, Required): Dynamic Excel/Sheets formula referencing source tables.
  4. `category` (Enum, Required): Indicator grouping (`EXECUTIVE_SUMMARY`, `PATIENT_METRICS`, `DOCTOR_METRICS`, `APPOINTMENT_METRICS`, `QUEUE_METRICS`, `CLINICAL_METRICS`, `FINANCIAL_METRICS`, `FACILITIES_METRICS`).
  5. `notes` (String, Optional): Analytical context and calculation logic.

  5. `notes` (String, Optional): Analytical context and calculation logic.

**Hardened Dynamic Reporting Formula Implementations (Phase 2.1):**
- **KPI-000 (Active Clinic Business Date):** `='01_SETTINGS'!$D$23`
- **KPI-001 (Total Registered Patients):** `=COUNTA('05_PATIENTS'!A:A)-1`
- **KPI-002 (Total Active Doctors):** `=COUNTIF('04_DOCTORS'!L:L, "ACTIVE")`
- **KPI-003 (Total Appointments Today):** `=COUNTIF('06_APPOINTMENTS'!E:E, $C$2)`
- **KPI-004 (Scheduled Appointments Today):** `=COUNTIFS('06_APPOINTMENTS'!E:E, $C$2, '06_APPOINTMENTS'!J:J, "SCHEDULED")`
- **KPI-005 (Checked-In Waiting Queue):** `=COUNTIFS('08_QUEUE'!F:F, $C$2, '08_QUEUE'!K:K, "WAITING") + COUNTIFS('08_QUEUE'!F:F, $C$2, '08_QUEUE'!K:K, "CALLED")`
- **KPI-006 (In Consultation Now):** `=COUNTIFS('08_QUEUE'!F:F, $C$2, '08_QUEUE'!K:K, "IN_CONSULTATION")`
- **KPI-007 (Completed Consultations Today):** `=COUNTIFS('08_QUEUE'!F:F, $C$2, '08_QUEUE'!K:K, "COMPLETED")`
- **KPI-008 (Cancelled Appointments Today):** `=COUNTIFS('06_APPOINTMENTS'!E:E, $C$2, '06_APPOINTMENTS'!J:J, "CANCELLED")`
- **KPI-009 (No-Show Appointments Today):** `=COUNTIFS('06_APPOINTMENTS'!E:E, $C$2, '06_APPOINTMENTS'!J:J, "NO_SHOW")`
- **KPI-010 (Today Invoiced Gross Revenue):** `=SUMIF('10_BILLING'!E:E, $C$2, '10_BILLING'!I:I)`
- **KPI-011 (Today Collected Net Revenue):** `=SUMIFS('11_PAYMENTS'!E:E, '11_PAYMENTS'!D:D, $C$2, '11_PAYMENTS'!H:H, "COMPLETED")`
- **KPI-012 (Total Outstanding Receivables):** `=SUM('10_BILLING'!K:K)`
- **KPI-013 (Active Chambers in Use):** `=COUNTIF('16_ROOMS'!F:F, "OCCUPIED")`

---

### 4.20 Sheet: `20_LOOKUPS`
* **Purpose:** Central repository of 103 controlled enum values across 23 categories with display labels, sequence sorting, and active status flags. Controlled via 23 Excel Named Ranges (`LK_GENDER`, `LK_APPOINTMENT_STATUS`, etc.) bound to dropdown validations across rows 2 to 5000.
* **Columns:**
  1. `lookup_id` (PK, String, Required): Unique identifier (`LKP-000001` to `LKP-000103`).
  2. `category` (String, Required): Category grouping.
  3. `code` (String, Required): Machine-readable programmatic token.
  4. `display_name` (String, Required): Human-readable UI label.
  5. `sort_order` (Integer, Required): Numerical display priority in dropdowns.
  6. `is_active` (Boolean, Required): `TRUE` or `FALSE`.
  7. `description` (String, Required): Contextual explanation.

---

## 5. Data Integrity & Validation Rules

To prevent data corruption, orphaned records, and invalid values, the following safeguards are implemented:

1. **Unique ID Architecture:**
   - Every entity contains a permanent primary key with a standardized alphanumeric prefix.
   - Keys are completely independent of row indices and sheet sorting.
2. **Referential Integrity:**
   - Foreign key values must match an existing primary key in the parent worksheet.
   - Appointments and queues reference valid `patient_id` and `doctor_id` entries.
   - Payments must reference an existing `invoice_id`.
   - Prescription items must reference an active `consultation_id`.
3. **Data Validation Dropdowns:**
   - Enforced on all enum columns using Excel/Google Sheets data validation rules.
   - Invalid status entries produce immediate warnings.
4. **Formula Calculation Safeguards:**
   - Financial balances are calculated automatically via spreadsheet formulas to eliminate manual entry errors:
     $$\text{total\_amount} = \text{subtotal} - \text{discount} + \text{tax}$$
     $$\text{due\_amount} = \text{total\_amount} - \text{paid\_amount}$$
5. **Timestamp Consistency:**
   - All datetime values conform strictly to ISO-8601 (`YYYY-MM-DD HH:MM:SS`) in Indian Standard Time (`Asia/Kolkata`).

---

## 6. Scalability & Performance Strategy

1. **Partitioning & Normalization:**
   - High-volume transaction logs (`17_AUDIT_LOG`, `18_NOTIFICATIONS`) are kept in separate worksheets from operational master tables.
   - Tables can scale beyond 10,000+ appointments and 1,000+ patients without worksheet bloat.
2. **Lean Formula Design:**
   - Avoided whole-column volatile formulas (`INDIRECT`, `OFFSET`).
   - Reporting queries rely on index-friendly `SUMIFS` and `COUNTIFS`.
3. **Archival Strategy:**
   - Invoices and queue logs older than 12 months can be archived to fiscal-year workbooks (`ApnaClinic_Archive_FY2526.xlsx`) without breaking ongoing operations.

---

## 7. Security, Privacy & DPDPA Compliance

1. **Zero Secret Storage:**
   - Passwords, Google OAuth client secrets, and refresh tokens are strictly forbidden in the spreadsheet.
2. **Sensitive Health Data Protection:**
   - The Master Sheet contains administrative metadata, diagnoses, and non-sensitive consultation notes.
   - Detailed handwritten clinical records remain paper-based or encrypted in local device storage.
3. **Auditability:**
   - Every patient modification, invoice generation, and payment event produces an immutable audit record in `17_AUDIT_LOG`.
4. **Consent Recording:**
   - Patient consent status (`GRANTED`, `WITHDRAWN`, `PENDING`) and notice versions are permanently tracked in `05_PATIENTS`.
