# APNA CLINIC — COMPREHENSIVE DATA DICTIONARY
**Phase 2: Master Sheet Schema Data Dictionary**  
**Document Version:** 2.0.0  
**Date:** September 2026  
**Status:** Engineering Baseline (Frozen UI Architecture)

---

## 1. Overview

This document provides a comprehensive, field-by-field Data Dictionary for the 20 canonical worksheets comprising the **Apna Clinic Master Sheet Architecture**. Every data entity, attribute, technical constraint, foreign key relationship, and default behavior is detailed below.

---

## 2. Table Dictionaries

### 2.1 Table: `01_SETTINGS`
Global configuration parameters, clinic profile metadata, operational hours, prefixes, and formatting tokens.

| Field Name | Type | Nullable | Key | Default | Foreign Key | Description | Allowed Values / Format |
|---|---|---|---|---|---|---|---|
| `setting_id` | STRING(32) | NO | PK | - | - | Unique identifier for configuration row | `SET-000001` format |
| `setting_category` | STRING(64) | NO | - | 'General' | - | Configuration functional group | `Identity`, `Operations`, `Prefixes`, `Formatting`, `Compliance`, `System` |
| `setting_key` | STRING(128) | NO | UQ | - | - | Canonical lookup configuration key | Alphanumeric lower snake_case (e.g. `clinic_name`, `timezone`) |
| `setting_value` | STRING(512) | NO | - | - | - | Configured runtime value | Any valid string representation |
| `data_type` | STRING(32) | NO | - | 'STRING' | - | Semantic data type of value | `STRING`, `INTEGER`, `DECIMAL`, `TIME`, `DATE_FORMAT` |
| `description` | STRING(512) | NO | - | '' | - | Operational explanation of parameter | Free text |
| `is_system` | BOOLEAN | NO | - | FALSE | - | Immutable system configuration flag | `TRUE`, `FALSE` |
| `updated_at` | TIMESTAMP | NO | - | NOW() | - | Timestamp of last modification | `YYYY-MM-DD HH:MM:SS` (IST) |

---

### 2.2 Table: `02_USERS`
Staff directory, credentials metadata (non-secret), role assignments, and managed doctor associations.

| Field Name | Type | Nullable | Key | Default | Foreign Key | Description | Allowed Values / Format |
|---|---|---|---|---|---|---|---|
| `user_id` | STRING(32) | NO | PK | - | - | Unique identifier for user | `USR-000001` format |
| `username` | STRING(64) | NO | UQ | - | - | Unique system username | Lowercase alphanumeric, dot/underscore allowed |
| `display_name` | STRING(128) | NO | - | - | - | Human full name of staff member | Free text (e.g. `Sunita Sharma`) |
| `role_id` | STRING(32) | NO | FK | - | `03_ROLES.role_id` | Assigned role reference | Valid `ROLE-XXXXXX` |
| `phone` | STRING(20) | NO | - | - | - | Primary contact phone number | `+91 98XXXXXXXX` |
| `email` | STRING(128) | YES | - | NULL | - | Professional email address | Valid email syntax |
| `status` | STRING(32) | NO | - | 'ACTIVE' | `20_LOOKUPS` | Account operational status | `ACTIVE`, `INACTIVE`, `SUSPENDED` |
| `assigned_doctor_ids`| STRING(256) | YES | - | '' | `04_DOCTORS.doctor_id`| Comma-separated list of doctors managed | Comma-delimited `DOC-XXXXXX` |
| `created_at` | TIMESTAMP | NO | - | NOW() | - | User creation timestamp | `YYYY-MM-DD HH:MM:SS` |
| `updated_at` | TIMESTAMP | NO | - | NOW() | - | User last update timestamp | `YYYY-MM-DD HH:MM:SS` |

---

### 2.3 Table: `03_ROLES`
Access control roles, operational permissions, and administrative responsibilities.

| Field Name | Type | Nullable | Key | Default | Foreign Key | Description | Allowed Values / Format |
|---|---|---|---|---|---|---|---|
| `role_id` | STRING(32) | NO | PK | - | - | Unique identifier for role | `ROLE-000001` format |
| `role_code` | STRING(32) | NO | UQ | - | `20_LOOKUPS` | Machine-readable role code | `ADMIN`, `RECEPTIONIST`, `DOCTOR`, `BILLING`, `MANAGER` |
| `role_name` | STRING(64) | NO | - | - | - | Display title of role | Free text |
| `description` | STRING(256) | NO | - | - | - | Scope of responsibilities | Free text |
| `permissions_summary`| STRING(512) | NO | - | '' | - | Comma-delimited list of permissions | E.g. `PATIENT_WRITE,BILLING_CREATE` |
| `status` | STRING(32) | NO | - | 'ACTIVE' | `20_LOOKUPS` | Operational role status | `ACTIVE`, `INACTIVE` |
| `created_at` | TIMESTAMP | NO | - | NOW() | - | Creation timestamp | `YYYY-MM-DD HH:MM:SS` |
| `updated_at` | TIMESTAMP | NO | - | NOW() | - | Modification timestamp | `YYYY-MM-DD HH:MM:SS` |

---

### 2.4 Table: `04_DOCTORS`
Doctor profiles, professional council registrations, standard consultation fees, and assigned rooms.

| Field Name | Type | Nullable | Key | Default | Foreign Key | Description | Allowed Values / Format |
|---|---|---|---|---|---|---|---|
| `doctor_id` | STRING(32) | NO | PK | - | - | Unique identifier for doctor | `DOC-000001` format |
| `doctor_code` | STRING(32) | NO | UQ | - | - | Short mnemonic identifier | E.g. `DR-SHARMA`, `DR-VERMA` |
| `doctor_name` | STRING(128) | NO | - | - | - | Complete medical name | E.g. `Dr. Rajesh Sharma` |
| `specialization` | STRING(128) | NO | - | - | - | Medical specialty area | E.g. `General Physician`, `Gynecology` |
| `qualification` | STRING(128) | NO | - | - | - | Degrees and medical certifications | E.g. `MBBS, MD (Medicine)` |
| `registration_number`| STRING(64) | NO | - | - | - | State/National Medical Council Reg No | E.g. `MCI-48291`, `DMC-39182` |
| `phone` | STRING(20) | NO | - | - | - | Contact telephone | `+91 98XXXXXXXX` |
| `email` | STRING(128) | NO | - | - | - | Professional email address | Valid email format |
| `room_id` | STRING(32) | NO | FK | - | `16_ROOMS.room_id` | Primary chamber assignment | Valid `ROOM-XXXXXX` |
| `consultation_fee` | DECIMAL(10,2)| NO | - | 500.00 | - | Standard consultation charge (INR) | `>= 0.00` |
| `consultation_duration_minutes`| INT | NO | - | 15 | - | Standard appointment slot length | Positive integer (e.g. `10, 15, 20`) |
| `status` | STRING(32) | NO | - | 'ACTIVE' | `20_LOOKUPS` | Doctor availability status | `ACTIVE`, `ON_LEAVE`, `INACTIVE` |
| `joining_date` | DATE | NO | - | CURRENT_DATE | - | Association start date | `YYYY-MM-DD` |
| `created_at` | TIMESTAMP | NO | - | NOW() | - | Creation timestamp | `YYYY-MM-DD HH:MM:SS` |
| `updated_at` | TIMESTAMP | NO | - | NOW() | - | Modification timestamp | `YYYY-MM-DD HH:MM:SS` |

---

### 2.5 Table: `05_PATIENTS`
Master demographic records, emergency contact points, and DPDPA consent metadata.

| Field Name | Type | Nullable | Key | Default | Foreign Key | Description | Allowed Values / Format |
|---|---|---|---|---|---|---|---|
| `patient_id` | STRING(32) | NO | PK | - | - | Permanent unique patient identifier | `PAT-000001` format |
| `patient_code` | STRING(32) | NO | UQ | - | - | Card/Display identification code | E.g. `P-2026-0001` |
| `first_name` | STRING(64) | NO | - | - | - | Patient given name | Free text |
| `middle_name` | STRING(64) | YES | - | '' | - | Optional middle name | Free text |
| `last_name` | STRING(64) | NO | - | - | - | Patient family/surname | Free text |
| `full_name` | STRING(192) | NO | - | - | - | Concatenated complete name | E.g. `Aarav Kumar` |
| `date_of_birth` | DATE | YES | - | NULL | - | Date of birth | `YYYY-MM-DD` |
| `age` | INT | NO | - | - | - | Age in completed years | Integer between `0` and `125` |
| `gender` | STRING(16) | NO | - | - | `20_LOOKUPS` | Gender classification | `MALE`, `FEMALE`, `OTHER` |
| `phone` | STRING(20) | NO | - | - | - | Primary 10-digit mobile number | `+91 98XXXXXXXX` |
| `alternate_phone` | STRING(20) | YES | - | '' | - | Backup contact phone number | `+91 98XXXXXXXX` or blank |
| `email` | STRING(128) | YES | - | '' | - | Patient email address | Valid email or blank |
| `address` | STRING(256) | YES | - | '' | - | Street address | Free text |
| `city` | STRING(64) | NO | - | 'New Delhi' | - | City of residence | Free text |
| `state` | STRING(64) | NO | 'Delhi' | - | - | State or Union Territory | Free text |
| `pincode` | STRING(10) | NO | - | - | - | 6-digit postal code | `^[1-9][0-9]{5}$` |
| `emergency_contact_name`| STRING(128)| YES| - | '' | - | Kin/Emergency contact name | Free text |
| `emergency_contact_phone`| STRING(20)| YES| - | '' | - | Emergency contact phone | `+91 98XXXXXXXX` |
| `blood_group` | STRING(16) | NO | - | 'UNKNOWN'| `20_LOOKUPS` | ABO and Rh blood group | `A+`, `A-`, `B+`, `B-`, `AB+`, `AB-`, `O+`, `O-`, `UNKNOWN` |
| `registration_date`| DATE | NO | - | CURRENT_DATE | - | First registration date | `YYYY-MM-DD` |
| `patient_status` | STRING(32) | NO | - | 'ACTIVE' | `20_LOOKUPS` | Patient activity status | `ACTIVE`, `INACTIVE`, `ARCHIVED` |
| `consent_status` | STRING(32) | NO | - | 'GRANTED'| `20_LOOKUPS` | Privacy & communication consent | `GRANTED`, `WITHDRAWN`, `PENDING` |
| `consent_version`| STRING(32) | NO | - | 'v1.0' | - | Version of privacy notice agreed to | E.g. `v1.0` |
| `created_at` | TIMESTAMP | NO | - | NOW() | - | Creation timestamp | `YYYY-MM-DD HH:MM:SS` |
| `updated_at` | TIMESTAMP | NO | - | NOW() | - | Modification timestamp | `YYYY-MM-DD HH:MM:SS` |
| `created_by` | STRING(32) | NO | FK | - | `02_USERS.user_id` | User recording patient | Valid `USR-XXXXXX` |
| `updated_by` | STRING(32) | NO | FK | - | `02_USERS.user_id` | User updating record | Valid `USR-XXXXXX` |

---

### 2.6 Table: `06_APPOINTMENTS`
Bookings, scheduled consultation slots, booking source channels, and workflow states.

| Field Name | Type | Nullable | Key | Default | Foreign Key | Description | Allowed Values / Format |
|---|---|---|---|---|---|---|---|
| `appointment_id` | STRING(32) | NO | PK | - | - | Unique appointment identifier | `APT-000001` format |
| `appointment_code`| STRING(32) | NO | UQ | - | - | Booking reference code | E.g. `APT-2026-0001` |
| `patient_id` | STRING(32) | NO | FK | - | `05_PATIENTS.patient_id` | Patient reference | Valid `PAT-XXXXXX` |
| `doctor_id` | STRING(32) | NO | FK | - | `04_DOCTORS.doctor_id` | Doctor reference | Valid `DOC-XXXXXX` |
| `appointment_date`| DATE | NO | - | - | - | Date of scheduled visit | `YYYY-MM-DD` |
| `start_time` | TIME | NO | - | - | - | Slot start time | `HH:MM` |
| `end_time` | TIME | NO | - | - | - | Slot end time | `HH:MM` |
| `appointment_type`| STRING(32) | NO | - | 'NEW_CONSULTATION'| `20_LOOKUPS` | Nature of clinical visit | `NEW_CONSULTATION`, `FOLLOW_UP`, `EMERGENCY`, `ROUTINE_CHECKUP` |
| `booking_source` | STRING(32) | NO | - | 'RECEPTION'| `20_LOOKUPS` | Channel through which booked | `WALK_IN`, `PHONE`, `RECEPTION`, `ONLINE` |
| `status` | STRING(32) | NO | - | 'SCHEDULED'| `20_LOOKUPS` | Appointment workflow state | `SCHEDULED`, `CHECKED_IN`, `IN_CONSULTATION`, `COMPLETED`, `CANCELLED`, `NO_SHOW` |
| `token_number` | INT | YES | - | 0 | - | Allocated queue token number | Positive integer or `0` |
| `room_id` | STRING(32) | NO | FK | - | `16_ROOMS.room_id` | Chamber reference | Valid `ROOM-XXXXXX` |
| `notes` | STRING(256) | YES | - | '' | - | Administrative visit notes | Free text |
| `cancel_reason` | STRING(256) | YES | - | '' | - | Reason if cancelled | Free text |
| `reminder_consent`| BOOLEAN | NO | - | TRUE | - | Patient consent for reminder | `TRUE`, `FALSE` |
| `reminder_status` | STRING(32) | NO | - | 'PENDING' | `20_LOOKUPS` | SMS/WhatsApp dispatch status | `PENDING`, `SENT`, `FAILED`, `NOT_REQUESTED` |
| `created_at` | TIMESTAMP | NO | - | NOW() | - | Booking timestamp | `YYYY-MM-DD HH:MM:SS` |
| `updated_at` | TIMESTAMP | NO | - | NOW() | - | Modification timestamp | `YYYY-MM-DD HH:MM:SS` |
| `created_by` | STRING(32) | NO | FK | - | `02_USERS.user_id` | Staff booking appointment | Valid `USR-XXXXXX` |
| `updated_by` | STRING(32) | NO | FK | - | `02_USERS.user_id` | Staff modifying booking | Valid `USR-XXXXXX` |

---

### 2.7 Table: `07_DOCTOR_SCHEDULES`
Weekly doctor shifts, consultation durations, break periods, and patient capacity limits.

| Field Name | Type | Nullable | Key | Default | Foreign Key | Description | Allowed Values / Format |
|---|---|---|---|---|---|---|---|
| `schedule_id` | STRING(32) | NO | PK | - | - | Unique schedule slot identifier | `SCH-000001` format |
| `doctor_id` | STRING(32) | NO | FK | - | `04_DOCTORS.doctor_id` | Doctor reference | Valid `DOC-XXXXXX` |
| `day_of_week` | STRING(16) | NO | - | - | `20_LOOKUPS` | Day of week | `MONDAY` through `SUNDAY` |
| `start_time` | TIME | NO | - | - | - | Shift start time | `HH:MM` |
| `end_time` | TIME | NO | - | - | - | Shift end time | `HH:MM` |
| `slot_duration` | INT | NO | - | 15 | - | Minutes allocated per patient | E.g. `10, 15, 20` |
| `break_start` | TIME | YES | - | NULL | - | Rest break start time | `HH:MM` or empty |
| `break_end` | TIME | YES | - | NULL | - | Rest break end time | `HH:MM` or empty |
| `room_id` | STRING(32) | NO | FK | - | `16_ROOMS.room_id` | Chamber reference | Valid `ROOM-XXXXXX` |
| `maximum_patients`| INT | NO | - | 20 | - | Cap on patients per session | Positive integer |
| `status` | STRING(32) | NO | - | 'ACTIVE' | `20_LOOKUPS` | Schedule active flag | `ACTIVE`, `INACTIVE` |
| `effective_from` | DATE | NO | - | CURRENT_DATE | - | Validity start date | `YYYY-MM-DD` |
| `effective_to` | DATE | NO | - | '2099-12-31'| - | Validity end date | `YYYY-MM-DD` |
| `created_at` | TIMESTAMP | NO | - | NOW() | - | Creation timestamp | `YYYY-MM-DD HH:MM:SS` |
| `updated_at` | TIMESTAMP | NO | - | NOW() | - | Modification timestamp | `YYYY-MM-DD HH:MM:SS` |

---

### 2.8 Table: `08_QUEUE`
Daily token queue, patient check-in events, triage priority, calling sequence, and chamber transit.

| Field Name | Type | Nullable | Key | Default | Foreign Key | Description | Allowed Values / Format |
|---|---|---|---|---|---|---|---|
| `queue_id` | STRING(32) | NO | PK | - | - | Unique queue token identifier | `TOK-000001` format |
| `appointment_id` | STRING(32) | YES | FK | NULL | `06_APPOINTMENTS.appointment_id` | Linked appointment (if any) | Valid `APT-XXXXXX` or empty |
| `patient_id` | STRING(32) | NO | FK | - | `05_PATIENTS.patient_id` | Patient reference | Valid `PAT-XXXXXX` |
| `doctor_id` | STRING(32) | NO | FK | - | `04_DOCTORS.doctor_id` | Doctor reference | Valid `DOC-XXXXXX` |
| `token_number` | INT | NO | - | - | - | Daily serial token per doctor | `>= 1` monotonic |
| `queue_date` | DATE | NO | - | CURRENT_DATE | - | Queue operating date | `YYYY-MM-DD` |
| `check_in_time` | TIMESTAMP | NO | - | NOW() | - | Reception arrival timestamp | `YYYY-MM-DD HH:MM:SS` |
| `called_time` | TIMESTAMP | YES | - | NULL | - | Token display/call timestamp | `YYYY-MM-DD HH:MM:SS` |
| `consultation_start_time`| TIMESTAMP | YES | - | NULL | - | Chamber entry timestamp | `YYYY-MM-DD HH:MM:SS` |
| `consultation_end_time` | TIMESTAMP | YES | - | NULL | - | Chamber exit timestamp | `YYYY-MM-DD HH:MM:SS` |
| `queue_status` | STRING(32) | NO | - | 'WAITING' | `20_LOOKUPS` | Real-time queue state | `WAITING`, `CALLED`, `IN_CONSULTATION`, `COMPLETED`, `SKIPPED`, `CANCELLED` |
| `priority` | STRING(32) | NO | - | 'NORMAL' | `20_LOOKUPS` | Triage priority | `NORMAL`, `URGENT`, `VIP`, `EMERGENCY` |
| `room_id` | STRING(32) | NO | FK | - | `16_ROOMS.room_id` | Chamber reference | Valid `ROOM-XXXXXX` |
| `created_at` | TIMESTAMP | NO | - | NOW() | - | Creation timestamp | `YYYY-MM-DD HH:MM:SS` |
| `updated_at` | TIMESTAMP | NO | - | NOW() | - | State update timestamp | `YYYY-MM-DD HH:MM:SS` |

---

### 2.9 Table: `09_CONSULTATIONS`
Clinical encounters, presenting complaints, examination summaries, working diagnoses, and outcome advice.

| Field Name | Type | Nullable | Key | Default | Foreign Key | Description | Allowed Values / Format |
|---|---|---|---|---|---|---|---|
| `consultation_id` | STRING(32) | NO | PK | - | - | Unique consultation identifier | `CON-000001` format |
| `appointment_id` | STRING(32) | NO | FK | - | `06_APPOINTMENTS.appointment_id` | Linked appointment reference | Valid `APT-XXXXXX` |
| `patient_id` | STRING(32) | NO | FK | - | `05_PATIENTS.patient_id` | Patient reference | Valid `PAT-XXXXXX` |
| `doctor_id` | STRING(32) | NO | FK | - | `04_DOCTORS.doctor_id` | Doctor reference | Valid `DOC-XXXXXX` |
| `chief_complaint` | STRING(512) | NO | - | - | - | Primary presenting symptoms | Free text |
| `clinical_summary`| STRING(1024)| YES | - | '' | - | Examination and vitals summary | Free text |
| `diagnosis` | STRING(512) | NO | - | - | - | Working medical diagnosis | Free text |
| `advice` | STRING(1024)| YES | - | '' | - | Non-pharmacological guidance | Free text |
| `follow_up_required`| BOOLEAN | NO | - | FALSE | - | Follow-up recommendation flag | `TRUE`, `FALSE` |
| `follow_up_date` | DATE | YES | - | NULL | - | Recommended review date | `YYYY-MM-DD` |
| `consultation_status`| STRING(32)| NO | - | 'COMPLETED'| `20_LOOKUPS` | Encounter status | `IN_PROGRESS`, `COMPLETED`, `CANCELLED`, `REFERRED` |
| `started_at` | TIMESTAMP | NO | - | NOW() | - | Consultation start timestamp | `YYYY-MM-DD HH:MM:SS` |
| `completed_at` | TIMESTAMP | YES | - | NULL | - | Consultation finish timestamp| `YYYY-MM-DD HH:MM:SS` |
| `created_at` | TIMESTAMP | NO | - | NOW() | - | Creation timestamp | `YYYY-MM-DD HH:MM:SS` |
| `updated_at` | TIMESTAMP | NO | - | NOW() | - | Modification timestamp | `YYYY-MM-DD HH:MM:SS` |

---

### 2.10 Table: `10_BILLING`
Master invoice ledger, tariff aggregations, tax and discount lines, and calculated balances.

| Field Name | Type | Nullable | Key | Default | Foreign Key | Description | Allowed Values / Format |
|---|---|---|---|---|---|---|---|
| `invoice_id` | STRING(32) | NO | PK | - | - | Unique invoice identifier | `INV-000001` format |
| `invoice_number` | STRING(32) | NO | UQ | - | - | Serial invoice reference code | E.g. `INV-2026-0001` |
| `patient_id` | STRING(32) | NO | FK | - | `05_PATIENTS.patient_id` | Patient reference | Valid `PAT-XXXXXX` |
| `appointment_id` | STRING(32) | YES | FK | NULL | `06_APPOINTMENTS.appointment_id` | Appointment reference | Valid `APT-XXXXXX` or empty |
| `invoice_date` | DATE | NO | - | CURRENT_DATE | - | Invoicing date | `YYYY-MM-DD` |
| `subtotal` | DECIMAL(10,2)| NO | - | 0.00 | - | Gross sum of charges before discounts | `>= 0.00` |
| `discount` | DECIMAL(10,2)| NO | - | 0.00 | - | Total discount applied (INR) | `>= 0.00` |
| `tax` | DECIMAL(10,2)| NO | - | 0.00 | - | Total tax applied (INR) | `>= 0.00` |
| `total_amount` | DECIMAL(10,2)| NO | - | - | - | Formula: `=subtotal - discount + tax` | Formula: `=F{row}-G{row}+H{row}` |
| `paid_amount` | DECIMAL(10,2)| NO | - | 0.00 | - | Total settled payments received | `>= 0.00` |
| `due_amount` | DECIMAL(10,2)| NO | - | - | - | Formula: `=total_amount - paid_amount`| Formula: `=I{row}-J{row}` |
| `payment_status` | STRING(32) | NO | - | 'UNPAID' | `20_LOOKUPS` | Invoice settlement status | `UNPAID`, `PARTIAL`, `PAID`, `REFUNDED` |
| `notes` | STRING(256) | YES | - | '' | - | Non-clinical billing remarks | Free text |
| `created_at` | TIMESTAMP | NO | - | NOW() | - | Creation timestamp | `YYYY-MM-DD HH:MM:SS` |
| `updated_at` | TIMESTAMP | NO | - | NOW() | - | Modification timestamp | `YYYY-MM-DD HH:MM:SS` |

---

### 2.11 Table: `11_PAYMENTS`
Cash and electronic transactions, payment instrument references, and cashier accountability.

| Field Name | Type | Nullable | Key | Default | Foreign Key | Description | Allowed Values / Format |
|---|---|---|---|---|---|---|---|
| `payment_id` | STRING(32) | NO | PK | - | - | Unique payment transaction identifier | `PAY-000001` format |
| `invoice_id` | STRING(32) | NO | FK | - | `10_BILLING.invoice_id` | Linked invoice reference | Valid `INV-XXXXXX` |
| `patient_id` | STRING(32) | NO | FK | - | `05_PATIENTS.patient_id` | Patient reference | Valid `PAT-XXXXXX` |
| `payment_date` | DATE | NO | - | CURRENT_DATE | - | Settlement transaction date | `YYYY-MM-DD` |
| `amount` | DECIMAL(10,2)| NO | - | 0.00 | - | Amount received in INR | `> 0.00` |
| `payment_method` | STRING(32) | NO | - | 'CASH' | `20_LOOKUPS` | Payment instrument | `CASH`, `UPI`, `CARD`, `BANK_TRANSFER`, `OTHER` |
| `transaction_reference`| STRING(128)| YES| - | '' | - | Gateway / UPI reference / Cheque No | E.g. `UPI/428192019283` |
| `payment_status` | STRING(32) | NO | - | 'COMPLETED'| `20_LOOKUPS` | Transaction state | `COMPLETED`, `PENDING`, `REVERSED`, `FAILED` |
| `received_by` | STRING(32) | NO | FK | - | `02_USERS.user_id` | Cashier user reference | Valid `USR-XXXXXX` |
| `notes` | STRING(256) | YES | - | '' | - | Transaction notes | Free text |
| `created_at` | TIMESTAMP | NO | - | NOW() | - | Payment timestamp | `YYYY-MM-DD HH:MM:SS` |

---

### 2.12 Table: `12_SERVICES`
Standard tariffs, medical procedures, diagnostic tests, and tax rates.

| Field Name | Type | Nullable | Key | Default | Foreign Key | Description | Allowed Values / Format |
|---|---|---|---|---|---|---|---|
| `service_id` | STRING(32) | NO | PK | - | - | Unique service item identifier | `SRV-000001` format |
| `service_code` | STRING(32) | NO | UQ | - | - | Mnemonic charge code | E.g. `CONS-GEN`, `PROC-ECG` |
| `service_name` | STRING(128) | NO | - | - | - | Official display name of service | Free text |
| `category` | STRING(32) | NO | - | 'CONSULTATION'| `20_LOOKUPS` | Service department classification | `CONSULTATION`, `PROCEDURE`, `DIAGNOSTIC`, `CERTIFICATE`, `OTHER` |
| `description` | STRING(256) | YES | - | '' | - | Service specifications | Free text |
| `default_fee` | DECIMAL(10,2)| NO | - | 0.00 | - | Standard service tariff (INR) | `>= 0.00` |
| `tax_rate` | DECIMAL(5,2) | NO | - | 0.00 | - | Applicable tax percentage | E.g. `0.00`, `18.00` |
| `status` | STRING(32) | NO | - | 'ACTIVE' | `20_LOOKUPS` | Catalog availability | `ACTIVE`, `INACTIVE` |
| `created_at` | TIMESTAMP | NO | - | NOW() | - | Creation timestamp | `YYYY-MM-DD HH:MM:SS` |
| `updated_at` | TIMESTAMP | NO | - | NOW() | - | Modification timestamp | `YYYY-MM-DD HH:MM:SS` |

---

### 2.13 Table: `13_MEDICAL_RECORDS`
External diagnostic reports, lab attachments, radiology links, and document metadata.

| Field Name | Type | Nullable | Key | Default | Foreign Key | Description | Allowed Values / Format |
|---|---|---|---|---|---|---|---|
| `record_id` | STRING(32) | NO | PK | - | - | Unique diagnostic record identifier | `MED-000001` format |
| `patient_id` | STRING(32) | NO | FK | - | `05_PATIENTS.patient_id` | Patient reference | Valid `PAT-XXXXXX` |
| `consultation_id` | STRING(32) | YES | FK | NULL | `09_CONSULTATIONS.consultation_id` | Linked encounter | Valid `CON-XXXXXX` or empty |
| `record_type` | STRING(32) | NO | - | 'LAB_REPORT' | `20_LOOKUPS` | Diagnostic document type | `LAB_REPORT`, `RADIOLOGY`, `DISCHARGE_SUMMARY`, `IMMUNIZATION`, `OTHER` |
| `title` | STRING(128) | NO | - | - | - | Title of document | Free text (e.g. `Complete Blood Count`) |
| `description` | STRING(512) | YES | - | '' | - | Brief findings summary | Free text |
| `document_url` | STRING(512) | NO | - | - | - | Secured Google Drive file URL | Valid URL syntax |
| `record_date` | DATE | NO | - | CURRENT_DATE | - | Test / Report date | `YYYY-MM-DD` |
| `created_by` | STRING(32) | NO | FK | - | `02_USERS.user_id` | Uploading staff member | Valid `USR-XXXXXX` |
| `created_at` | TIMESTAMP | NO | - | NOW() | - | Creation timestamp | `YYYY-MM-DD HH:MM:SS` |
| `updated_at` | TIMESTAMP | NO | - | NOW() | - | Modification timestamp | `YYYY-MM-DD HH:MM:SS` |

---

### 2.14 Table: `14_PRESCRIPTIONS`
Itemized medications, dosages, administration frequencies, treatment durations, and routes.

| Field Name | Type | Nullable | Key | Default | Foreign Key | Description | Allowed Values / Format |
|---|---|---|---|---|---|---|---|
| `prescription_id` | STRING(32) | NO | PK | - | - | Unique prescription line identifier | `RX-000001` format |
| `consultation_id` | STRING(32) | NO | FK | - | `09_CONSULTATIONS.consultation_id` | Source consultation encounter | Valid `CON-XXXXXX` |
| `patient_id` | STRING(32) | NO | FK | - | `05_PATIENTS.patient_id` | Patient reference | Valid `PAT-XXXXXX` |
| `medicine_name` | STRING(128) | NO | - | - | - | Medicine brand/generic and strength | E.g. `Tab Paracetamol 650mg` |
| `dosage` | STRING(64) | NO | - | - | - | Strength or unit per dose | E.g. `1 tablet`, `5 ml` |
| `frequency` | STRING(32) | NO | - | 'ONCE_DAILY' | `20_LOOKUPS` | Administration timing | `ONCE_DAILY`, `TWICE_DAILY`, `THRICE_DAILY`, `FOUR_TIMES_DAILY`, `AS_NEEDED` |
| `duration` | STRING(64) | NO | - | '5 days' | - | Total duration of course | E.g. `3 days`, `5 days`, `30 days` |
| `route` | STRING(32) | NO | - | 'ORAL' | `20_LOOKUPS` | Mode of administration | `ORAL`, `TOPICAL`, `INHALATION`, `INJECTION`, `DROPS` |
| `instructions` | STRING(256) | YES | - | '' | - | Specific meal timing and warnings | E.g. `Take after food with water` |
| `quantity` | INT | NO | - | 1 | - | Total medication units | Positive integer |
| `created_at` | TIMESTAMP | NO | - | NOW() | - | Prescription creation timestamp | `YYYY-MM-DD HH:MM:SS` |

---

### 2.15 Table: `15_FOLLOW_UPS`
Administrative follow-up scheduling, clinical review dates, reminder dispatches, and appointment conversion.

| Field Name | Type | Nullable | Key | Default | Foreign Key | Description | Allowed Values / Format |
|---|---|---|---|---|---|---|---|
| `followup_id` | STRING(32) | NO | PK | - | - | Unique follow-up identifier | `FOL-000001` format |
| `patient_id` | STRING(32) | NO | FK | - | `05_PATIENTS.patient_id` | Patient reference | Valid `PAT-XXXXXX` |
| `consultation_id` | STRING(32) | YES | FK | NULL | `09_CONSULTATIONS.consultation_id` | Source consultation encounter | Valid `CON-XXXXXX` or empty |
| `doctor_id` | STRING(32) | NO | FK | - | `04_DOCTORS.doctor_id` | Doctor reference | Valid `DOC-XXXXXX` |
| `due_date` | DATE | NO | - | - | - | Recommended follow-up date | `YYYY-MM-DD` |
| `status` | STRING(32) | NO | - | 'SCHEDULED' | `20_LOOKUPS` | Administrative follow-up status | `SCHEDULED`, `COMPLETED`, `CANCELLED`, `MISSED` |
| `reminder_consent`| BOOLEAN | NO | - | TRUE | - | Reminder communication consent | `TRUE`, `FALSE` |
| `reminder_sent_at`| TIMESTAMP | YES | - | NULL | - | Dispatch timestamp of reminder | `YYYY-MM-DD HH:MM:SS` or empty |
| `converted_appointment_id`| STRING(32)| YES| FK| NULL| `06_APPOINTMENTS.appointment_id`| Booking generated from this review | Valid `APT-XXXXXX` or empty |
| `notes` | STRING(256) | YES | - | '' | - | Administrative scheduling notes | Free text |
| `created_at` | TIMESTAMP | NO | - | NOW() | - | Creation timestamp | `YYYY-MM-DD HH:MM:SS` |
| `updated_at` | TIMESTAMP | NO | - | NOW() | - | Modification timestamp | `YYYY-MM-DD HH:MM:SS` |

---

### 2.16 Table: `16_ROOMS`
Clinic consultation chambers, minor procedure rooms, waiting lounges, and physical infrastructure.

| Field Name | Type | Nullable | Key | Default | Foreign Key | Description | Allowed Values / Format |
|---|---|---|---|---|---|---|---|
| `room_id` | STRING(32) | NO | PK | - | - | Unique room identifier | `ROOM-000001` format |
| `room_code` | STRING(32) | NO | UQ | - | - | Short physical chamber code | E.g. `CHAMBER-1`, `PROC-ROOM` |
| `room_name` | STRING(128) | NO | - | - | - | Official display name of room | Free text |
| `room_type` | STRING(32) | NO | - | 'CONSULTATION'| `20_LOOKUPS` | Architectural purpose of space | `CONSULTATION`, `EXAMINATION`, `PROCEDURE`, `WAITING`, `PHARMACY` |
| `floor` | STRING(32) | NO | - | 'Ground Floor'| - | Facility floor level | E.g. `Ground Floor`, `First Floor` |
| `status` | STRING(32) | NO | - | 'AVAILABLE' | `20_LOOKUPS` | Operational occupancy state | `AVAILABLE`, `OCCUPIED`, `MAINTENANCE`, `RESERVED` |
| `assigned_doctor_id`| STRING(32)| YES | FK | NULL | `04_DOCTORS.doctor_id` | Current doctor occupant | Valid `DOC-XXXXXX` or empty |
| `notes` | STRING(256) | YES | - | '' | - | Facility equipment notes | Free text |
| `created_at` | TIMESTAMP | NO | - | NOW() | - | Creation timestamp | `YYYY-MM-DD HH:MM:SS` |
| `updated_at` | TIMESTAMP | NO | - | NOW() | - | Modification timestamp | `YYYY-MM-DD HH:MM:SS` |

---

### 2.17 Table: `17_AUDIT_LOG`
Append-only immutable event log tracking all creations, updates, cancellations, and access actions.

| Field Name | Type | Nullable | Key | Default | Foreign Key | Description | Allowed Values / Format |
|---|---|---|---|---|---|---|---|
| `audit_id` | STRING(32) | NO | PK | - | - | Unique audit event identifier | `AUD-000001` format |
| `timestamp` | TIMESTAMP | NO | - | NOW() | - | Event timestamp | `YYYY-MM-DD HH:MM:SS` |
| `user_id` | STRING(32) | NO | FK | - | `02_USERS.user_id` | User performing action | Valid `USR-XXXXXX` |
| `user_role` | STRING(32) | NO | - | - | `20_LOOKUPS` | Role of acting user | `ADMIN`, `RECEPTIONIST`, `DOCTOR`, `BILLING` |
| `action` | STRING(64) | NO | - | - | `20_LOOKUPS` | System action code | `PATIENT_CREATED`, `PATIENT_UPDATED`, `APPOINTMENT_CREATED`, `APPOINTMENT_CANCELLED`, `PATIENT_CHECKED_IN`, `CONSULTATION_STARTED`, `CONSULTATION_COMPLETED`, `INVOICE_GENERATED`, `PAYMENT_RECEIVED`, `REFUND_ISSUED` |
| `entity_type` | STRING(32) | NO | - | - | - | Target entity affected | `PATIENT`, `APPOINTMENT`, `VISIT`, `CONSULTATION`, `INVOICE`, `PAYMENT`, `DOCTOR`, `SETTINGS` |
| `entity_id` | STRING(32) | NO | - | - | - | Primary key of modified entity | Valid PK string |
| `old_value` | STRING(512) | YES | - | '' | - | Sanitized state before modification | Non-PII JSON / string |
| `new_value` | STRING(512) | YES | - | '' | - | Sanitized state after modification | Non-PII JSON / string |
| `source` | STRING(64) | NO | - | 'Web' | - | Originating client terminal | E.g. `Reception-PC-01`, `Doctor-Chamber-01` |
| `remarks` | STRING(256) | YES | - | '' | - | Explanatory context | Free text |

---

### 2.18 Table: `18_NOTIFICATIONS`
Automated patient reminders, communication log, transmission channels, and gateway delivery states.

| Field Name | Type | Nullable | Key | Default | Foreign Key | Description | Allowed Values / Format |
|---|---|---|---|---|---|---|---|
| `notification_id`| STRING(32) | NO | PK | - | - | Unique notification identifier | `NOT-000001` format |
| `patient_id` | STRING(32) | NO | FK | - | `05_PATIENTS.patient_id` | Target patient reference | Valid `PAT-XXXXXX` |
| `notification_type`| STRING(32)| NO | - | - | `20_LOOKUPS` | Communication purpose | `APPOINTMENT_REMINDER`, `FOLLOW_UP_REMINDER`, `QUEUE_ALERT`, `BILLING_RECEIPT`, `CONSENT_CONFIRMATION` |
| `recipient_contact`| STRING(64)| NO | - | - | - | Phone number or email | Valid phone or email syntax |
| `scheduled_at` | TIMESTAMP | NO | - | - | - | Desired transmission time | `YYYY-MM-DD HH:MM:SS` |
| `sent_at` | TIMESTAMP | YES | - | NULL | - | Actual transmission time | `YYYY-MM-DD HH:MM:SS` or empty |
| `channel` | STRING(32) | NO | - | 'WHATSAPP' | `20_LOOKUPS` | Communication channel | `WHATSAPP`, `SMS`, `EMAIL` |
| `template_name` | STRING(64) | NO | - | - | - | Pre-approved template ID | E.g. `apt_reminder_v1`, `receipt_v1` |
| `status` | STRING(32) | NO | - | 'PENDING' | `20_LOOKUPS` | Transmission pipeline state | `PENDING`, `SENT`, `DELIVERED`, `FAILED` |
| `delivery_status`| STRING(64) | YES | - | '' | - | Gateway delivery code / error | E.g. `ACK_MSG_9921` |
| `remarks` | STRING(256) | YES | - | '' | - | Transmission remarks | Free text |
| `created_at` | TIMESTAMP | NO | - | NOW() | - | Record creation timestamp | `YYYY-MM-DD HH:MM:SS` |

---

### 2.19 Table: `19_REPORTING`
Key Performance Indicators (KPIs) calculated in real-time from source operational tables using native spreadsheet whole-column formulas with zero hardcoded dates.

| Field Name | Type | Nullable | Key | Description | Example / Formula |
|---|---|---|---|---|---|
| `kpi_metric_id` | STRING(32) | NO | PK | Unique metric identifier | `KPI-000` to `KPI-013` format |
| `metric_name` | STRING(128) | NO | - | Display name of KPI indicator | E.g. `Total Appointments Today` |
| `metric_value_formula`| FORMULA | NO | - | Dynamic formula referencing source sheets & $C$2 | E.g. `=COUNTIF('06_APPOINTMENTS'!E:E, $C$2)` |
| `category` | STRING(64) | NO | - | Analytical grouping | `SYSTEM_CONTROL`, `PATIENT_METRICS`, `DOCTOR_METRICS`, `APPOINTMENT_METRICS`, `QUEUE_METRICS`, `CLINICAL_METRICS`, `FINANCIAL_METRICS`, `FACILITIES_METRICS` |
| `notes` | STRING(256) | YES | - | Business context and calculation logic | Free text explaining operational definition |

#### Hardened KPI Catalog (Zero Hardcoded Operational Dates):
1. **`KPI-000` (Active Clinic Business Date):** `='01_SETTINGS'!$D$23` (Category: `SYSTEM_CONTROL`)
2. **`KPI-001` (Total Registered Patients):** `=COUNTA('05_PATIENTS'!A:A)-1` (Category: `PATIENT_METRICS`)
3. **`KPI-002` (Total Active Doctors):** `=COUNTIF('04_DOCTORS'!L:L, "ACTIVE")` (Category: `DOCTOR_METRICS`)
4. **`KPI-003` (Total Appointments Today):** `=COUNTIF('06_APPOINTMENTS'!E:E, $C$2)` (Category: `APPOINTMENT_METRICS`)
5. **`KPI-004` (Scheduled Appointments Today):** `=COUNTIFS('06_APPOINTMENTS'!E:E, $C$2, '06_APPOINTMENTS'!J:J, "SCHEDULED")` (Category: `APPOINTMENT_METRICS`)
6. **`KPI-005` (Checked-In Patients Today - Waiting Queue):** `=COUNTIFS('08_QUEUE'!F:F, $C$2, '08_QUEUE'!K:K, "WAITING") + COUNTIFS('08_QUEUE'!F:F, $C$2, '08_QUEUE'!K:K, "CALLED")` (Category: `QUEUE_METRICS`)
7. **`KPI-006` (In Consultation Now):** `=COUNTIFS('08_QUEUE'!F:F, $C$2, '08_QUEUE'!K:K, "IN_CONSULTATION")` (Category: `QUEUE_METRICS`)
8. **`KPI-007` (Completed Consultations Today):** `=COUNTIFS('08_QUEUE'!F:F, $C$2, '08_QUEUE'!K:K, "COMPLETED")` (Category: `CLINICAL_METRICS`)
9. **`KPI-008` (Cancelled Appointments Today):** `=COUNTIFS('06_APPOINTMENTS'!E:E, $C$2, '06_APPOINTMENTS'!J:J, "CANCELLED")` (Category: `APPOINTMENT_METRICS`)
10. **`KPI-009` (No-Show Appointments Today):** `=COUNTIFS('06_APPOINTMENTS'!E:E, $C$2, '06_APPOINTMENTS'!J:J, "NO_SHOW")` (Category: `APPOINTMENT_METRICS`)
11. **`KPI-010` (Today Invoiced Revenue - Gross):** `=SUMIF('10_BILLING'!E:E, $C$2, '10_BILLING'!I:I)` (Category: `FINANCIAL_METRICS`)
12. **`KPI-011` (Today Collected Revenue - Net):** `=SUMIFS('11_PAYMENTS'!E:E, '11_PAYMENTS'!D:D, $C$2, '11_PAYMENTS'!H:H, "COMPLETED")` (Category: `FINANCIAL_METRICS`)
13. **`KPI-012` (Total Outstanding Receivables):** `=SUM('10_BILLING'!K:K)` (Category: `FINANCIAL_METRICS`)
14. **`KPI-013` (Active Chambers in Use):** `=COUNTIF('16_ROOMS'!F:F, "OCCUPIED")` (Category: `FACILITIES_METRICS`)

---

### 2.20 Table: `20_LOOKUPS`
Central controlled vocabulary, status codes, categories, sorting preferences, and active flags. Serves as the single source of truth for 23 Excel Named Ranges (`DefinedName`) binding data validations across rows 2 to 5000.

| Field Name | Type | Nullable | Key | Description | Allowed Values / Format |
|---|---|---|---|---|---|
| `lookup_id` | STRING(32) | NO | PK | Unique lookup identifier | `LKP-000001` to `LKP-000103` |
| `category` | STRING(64) | NO | - | Controlled grouping | `GENDER`, `APPOINTMENT_STATUS`, `PAYMENT_METHOD`, etc. |
| `code` | STRING(64) | NO | - | Programmatic machine token | Upper snake_case (e.g. `SCHEDULED`, `UPI`) |
| `display_name` | STRING(128) | NO | - | Localized / Human-readable display label | Free text |
| `sort_order` | INT | NO | - | Presentation sort order | Positive integer |
| `is_active` | BOOLEAN | NO | - | Active availability flag | `TRUE`, `FALSE` |
| `description` | STRING(256) | YES | - | Contextual definition | Free text |

#### Excel Named Ranges Register (`20_LOOKUPS`):
| Named Range | Category | Cell Range | Target Worksheets & Columns |
|---|---|---|---|
| `LK_GENDER` | `GENDER` | `'20_LOOKUPS'!$C$2:$C$4` | `05_PATIENTS.gender` |
| `LK_APPOINTMENT_STATUS` | `APPOINTMENT_STATUS` | `'20_LOOKUPS'!$C$5:$C$10` | `06_APPOINTMENTS.status` |
| `LK_APPOINTMENT_TYPE` | `APPOINTMENT_TYPE` | `'20_LOOKUPS'!$C$11:$C$14` | `06_APPOINTMENTS.appointment_type` |
| `LK_BOOKING_SOURCE` | `BOOKING_SOURCE` | `'20_LOOKUPS'!$C$15:$C$18` | `06_APPOINTMENTS.booking_source` |
| `LK_QUEUE_STATUS` | `QUEUE_STATUS` | `'20_LOOKUPS'!$C$19:$C$24` | `08_QUEUE.queue_status` |
| `LK_QUEUE_PRIORITY` | `QUEUE_PRIORITY` | `'20_LOOKUPS'!$C$25:$C$28` | `08_QUEUE.priority` |
| `LK_CONSULTATION_STATUS`| `CONSULTATION_STATUS`| `'20_LOOKUPS'!$C$29:$C$32` | `09_CONSULTATIONS.consultation_status` |
| `LK_PAYMENT_STATUS` | `PAYMENT_STATUS` | `'20_LOOKUPS'!$C$33:$C$36` | `10_BILLING.payment_status`, `11_PAYMENTS.payment_status` |
| `LK_PAYMENT_METHOD` | `PAYMENT_METHOD` | `'20_LOOKUPS'!$C$37:$C$41` | `11_PAYMENTS.payment_method` |
| `LK_USER_ROLE` | `USER_ROLE` | `'20_LOOKUPS'!$C$42:$C$46` | `02_USERS.status` |
| `LK_PATIENT_STATUS` | `PATIENT_STATUS` | `'20_LOOKUPS'!$C$47:$C$49` | `05_PATIENTS.patient_status`, `12_SERVICES.status` |
| `LK_DOCTOR_STATUS` | `DOCTOR_STATUS` | `'20_LOOKUPS'!$C$50:$C$52` | `04_DOCTORS.status`, `07_DOCTOR_SCHEDULES.status` |
| `LK_SERVICE_CATEGORY` | `SERVICE_CATEGORY` | `'20_LOOKUPS'!$C$53:$C$57` | `12_SERVICES.category` |
| `LK_ROOM_TYPE` | `ROOM_TYPE` | `'20_LOOKUPS'!$C$58:$C$62` | `16_ROOMS.room_type` |
| `LK_ROOM_STATUS` | `ROOM_STATUS` | `'20_LOOKUPS'!$C$63:$C$66` | `16_ROOMS.status` |
| `LK_BLOOD_GROUP` | `BLOOD_GROUP` | `'20_LOOKUPS'!$C$67:$C$75` | `05_PATIENTS.blood_group` |
| `LK_RX_FREQUENCY` | `RX_FREQUENCY` | `'20_LOOKUPS'!$C$76:$C$80` | `14_PRESCRIPTIONS.frequency` |
| `LK_RX_ROUTE` | `RX_ROUTE` | `'20_LOOKUPS'!$C$81:$C$85` | `14_PRESCRIPTIONS.route` |
| `LK_FOLLOWUP_STATUS` | `FOLLOWUP_STATUS` | `'20_LOOKUPS'!$C$86:$C$89` | `15_FOLLOW_UPS.status`, `18_NOTIFICATIONS.status` |
| `LK_NOTIFICATION_CHANNEL`| `NOTIFICATION_CHANNEL`| `'20_LOOKUPS'!$C$90:$C$92` | `18_NOTIFICATIONS.channel` |
| `LK_DAYS_OF_WEEK` | `DAY_OF_WEEK` | `'20_LOOKUPS'!$C$93:$C$99` | `07_DOCTOR_SCHEDULES.day_of_week` |
| `LK_CONSENT_STATUS` | `CONSENT_STATUS` | `'20_LOOKUPS'!$C$100:$C$102`| `05_PATIENTS.consent_status` |
| `LK_BOOLEAN` | `BOOLEAN` | `'20_LOOKUPS'!$C$103:$C$104`| `06_APPOINTMENTS.reminder_consent`, `09_CONSULTATIONS.follow_up_required`, `15_FOLLOW_UPS.reminder_consent` |

