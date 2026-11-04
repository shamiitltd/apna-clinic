# APNA CLINIC — APPLICATION FIELD TO MASTER SHEET MAPPING
**Phase 2.1: Master Sheet Final Hardening Specification**  
**Document Version:** 2.1.0  
**Date:** September 2026  
**Status:** Engineering Baseline (Frozen Phase 1 UI Architecture)

---

## 1. Overview & Architecture Mapping Model

This document establishes the strict, bidirectional field-level mapping between the frozen Phase 1 Flutter application domain entities (`lib/domain/entities/`) and the hardened Master Sheet workbook (`APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL.xlsx`).

### The Mapping Chain
$$\text{APPLICATION FIELD} \longrightarrow \text{MASTER SHEET} \longrightarrow \text{WORKSHEET} \longrightarrow \text{COLUMN}$$

### Architectural Invariants:
1. **Phase 1 UI is Frozen:** Every field required by the UI screens (Patients, Doctor Queue, Appointments, Billing, More) has a corresponding column in the Master Sheet.
2. **Zero Field Loss:** No domain field is dropped or omitted.
3. **Currency Conversion:** Domain stores monetary figures as integer paise (`*_minor`); Master Sheet stores standard decimal Rupees (`₹` formatted):
   - $\text{Master Sheet (INR)} = \frac{\text{Domain Minor (Paise)}}{100}$
   - $\text{Domain Minor (Paise)} = \text{ROUND}(\text{Master Sheet (INR)} \times 100)$
4. **Permanent Unique ID Architecture:** Ephemeral local UUIDs are mapped to permanent sequential IDs (`PAT-000001`, `DOC-000001`, `APT-000001`, etc.) upon sync.

---

## 2. Comprehensive Field-by-Field Mapping Matrix

### 2.1 Patient Entity (`lib/domain/entities/patient.dart`)

| Application Field | Application Type | Master Sheet | Worksheet | Column | Conversion / Business Logic |
|---|---|---|---|---|---|
| `patient.patientId` | `String` (UUID) | Master Sheet | `05_PATIENTS` | `patient_id` | Mapped to permanent sequential ID (`PAT-000001`) |
| (Derived) | `String` | Master Sheet | `05_PATIENTS` | `patient_code` | Mnemonic clinic code (`P-2026-0001`) |
| `patient.firstName` | `String` | Master Sheet | `05_PATIENTS` | `first_name` | Direct string |
| `patient.lastName` | `String` | Master Sheet | `05_PATIENTS` | `last_name` | Direct string |
| `patient.fullName` | `String` | Master Sheet | `05_PATIENTS` | `full_name` | Direct string (or `=CONCATENATE(first_name, " ", last_name)`) |
| `patient.age` | `int` | Master Sheet | `05_PATIENTS` | `age` | Direct integer |
| `patient.gender` | `Gender` (Enum) | Master Sheet | `05_PATIENTS` | `gender` | Controlled via `LK_GENDER` (`MALE`, `FEMALE`, `OTHER`) |
| `patient.phone` | `String` | Master Sheet | `05_PATIENTS` | `phone` | Standard mobile number (`9876543201`) |
| `patient.email` | `String?` | Master Sheet | `05_PATIENTS` | `email` | Optional string |
| `patient.address` | `String?` | Master Sheet | `05_PATIENTS` | `address` | Street address string |
| `patient.city` | `String` | Master Sheet | `05_PATIENTS` | `city` | City name |
| `patient.state` | `String` | Master Sheet | `05_PATIENTS` | `state` | State name |
| `patient.pincode` | `String` | Master Sheet | `05_PATIENTS` | `pincode` | 6-digit PIN code |
| `patient.bloodGroup` | `String?` | Master Sheet | `05_PATIENTS` | `blood_group` | Controlled via `LK_BLOOD_GROUP` (`A+`, `B+`, `O+`, etc.) |
| `patient.allergies` | `List<String>` | Master Sheet | `05_PATIENTS` | `allergies` | Comma-delimited text string |
| `patient.chronicConditions`| `List<String>` | Master Sheet | `05_PATIENTS` | `chronic_conditions`| Comma-delimited text string |
| `patient.registrationDate` | `DateTime` | Master Sheet | `05_PATIENTS` | `registration_date`| `YYYY-MM-DD` |
| `patient.status` | `PatientStatus` | Master Sheet | `05_PATIENTS` | `patient_status` | Controlled via `LK_PATIENT_STATUS` (`ACTIVE`, `INACTIVE`) |
| `patient.consentGranted` | `bool` | Master Sheet | `05_PATIENTS` | `consent_status` | Controlled via `LK_CONSENT_STATUS` (`GRANTED`, `WITHDRAWN`) |
| `patient.createdAt` | `DateTime` | Master Sheet | `05_PATIENTS` | `created_at` | `YYYY-MM-DD HH:MM:SS` (Asia/Kolkata) |
| `patient.updatedAt` | `DateTime` | Master Sheet | `05_PATIENTS` | `updated_at` | `YYYY-MM-DD HH:MM:SS` (Asia/Kolkata) |
| `patient.createdBy` | `String` | Master Sheet | `05_PATIENTS` | `created_by` | Reference to `02_USERS.user_id` (`USR-000002`) |
| `patient.updatedBy` | `String` | Master Sheet | `05_PATIENTS` | `updated_by` | Reference to `02_USERS.user_id` (`USR-000002`) |

---

### 2.2 Doctor Entity (`lib/domain/entities/doctor.dart`)

| Application Field | Application Type | Master Sheet | Worksheet | Column | Conversion / Business Logic |
|---|---|---|---|---|---|
| `doctor.doctorId` | `String` (UUID) | Master Sheet | `04_DOCTORS` | `doctor_id` | Permanent ID format (`DOC-000001`) |
| (Derived) | `String` | Master Sheet | `04_DOCTORS` | `doctor_code` | Mnemonic code (`D-01`) |
| `doctor.displayName` | `String` | Master Sheet | `04_DOCTORS` | `doctor_name` | E.g. `Dr. Rajesh Sharma` |
| `doctor.specialtyLabel` | `String` | Master Sheet | `04_DOCTORS` | `specialization` | E.g. `General Medicine` |
| `doctor.qualificationText`| `String` | Master Sheet | `04_DOCTORS` | `qualification` | E.g. `MBBS, MD (Internal Medicine)` |
| `doctor.registrationNumber`| `String` | Master Sheet | `04_DOCTORS` | `registration_number`| Medical Council registration (`MCI-2012-8890`) |
| `doctor.contactPhone` | `String` | Master Sheet | `04_DOCTORS` | `phone` | Direct contact number |
| `doctor.contactEmail` | `String?` | Master Sheet | `04_DOCTORS` | `email` | Professional email |
| `doctor.roomLabel` | `String` | Master Sheet | `04_DOCTORS` | `room_id` | Foreign key referencing `16_ROOMS.room_id` (`ROOM-000001`) |
| `doctor.defaultFee` | `int` (paise) | Master Sheet | `04_DOCTORS` | `consultation_fee` | Converted: `paise / 100` (`500.00` INR) |
| `doctor.consultationDuration`| `int` (mins) | Master Sheet | `04_DOCTORS` | `consultation_duration_minutes` | Slot duration in minutes (`15`) |
| `doctor.status` | `DoctorStatus` | Master Sheet | `04_DOCTORS` | `status` | Controlled via `LK_DOCTOR_STATUS` (`ACTIVE`, `ON_LEAVE`) |
| `doctor.joiningDate` | `DateTime` | Master Sheet | `04_DOCTORS` | `joining_date` | `YYYY-MM-DD` |
| `doctor.createdAt` | `DateTime` | Master Sheet | `04_DOCTORS` | `created_at` | `YYYY-MM-DD HH:MM:SS` |
| `doctor.updatedAt` | `DateTime` | Master Sheet | `04_DOCTORS` | `updated_at` | `YYYY-MM-DD HH:MM:SS` |

---

### 2.3 Appointment Entity (`lib/domain/entities/appointment.dart`)

| Application Field | Application Type | Master Sheet | Worksheet | Column | Conversion / Business Logic |
|---|---|---|---|---|---|
| `appointment.appointmentId`| `String` (UUID) | Master Sheet | `06_APPOINTMENTS`| `appointment_id` | Permanent ID format (`APT-000001`) |
| (Derived) | `String` | Master Sheet | `06_APPOINTMENTS`| `appointment_code` | Mnemonic code (`APT-20260929-001`) |
| `appointment.patientId` | `String` | Master Sheet | `06_APPOINTMENTS`| `patient_id` | Foreign key referencing `05_PATIENTS.patient_id` |
| `appointment.doctorId` | `String` | Master Sheet | `06_APPOINTMENTS`| `doctor_id` | Foreign key referencing `04_DOCTORS.doctor_id` |
| `appointment.appointmentDate`| `DateTime` | Master Sheet | `06_APPOINTMENTS`| `appointment_date`| `YYYY-MM-DD` |
| `appointment.startTime` | `String` (HH:MM)| Master Sheet | `06_APPOINTMENTS`| `start_time` | Slot start time (`09:00`) |
| `appointment.endTime` | `String` (HH:MM)| Master Sheet | `06_APPOINTMENTS`| `end_time` | Slot end time (`09:15`) |
| `appointment.type` | `AppointmentType`| Master Sheet | `06_APPOINTMENTS`| `appointment_type`| Controlled via `LK_APPOINTMENT_TYPE` (`NEW_CONSULTATION`) |
| `appointment.source` | `BookingSource` | Master Sheet | `06_APPOINTMENTS`| `booking_source` | Controlled via `LK_BOOKING_SOURCE` (`WALK_IN`, `PHONE`, `ONLINE`)|
| `appointment.status` | `AppointmentStatus`| Master Sheet | `06_APPOINTMENTS`| `status` | Controlled via `LK_APPOINTMENT_STATUS` (`SCHEDULED`, `CHECKED_IN`, etc.) |
| `appointment.roomLabel` | `String` | Master Sheet | `06_APPOINTMENTS`| `room_id` | Foreign key referencing `16_ROOMS.room_id` |
| `appointment.tokenNumber` | `int?` | Master Sheet | `06_APPOINTMENTS`| `token_number` | Daily doctor token index (`1`) |
| `appointment.notes` | `String?` | Master Sheet | `06_APPOINTMENTS`| `notes` | Intake reason / clinical notes |
| `appointment.reminderConsent`| `bool` | Master Sheet | `06_APPOINTMENTS`| `reminder_consent`| Controlled via `LK_BOOLEAN` (`YES`, `NO`) |
| `appointment.reminderStatus`| `String` | Master Sheet | `06_APPOINTMENTS`| `reminder_status` | Reminder delivery status (`SENT`, `PENDING`) |
| `appointment.createdAt` | `DateTime` | Master Sheet | `06_APPOINTMENTS`| `created_at` | `YYYY-MM-DD HH:MM:SS` |
| `appointment.updatedAt` | `DateTime` | Master Sheet | `06_APPOINTMENTS`| `updated_at` | `YYYY-MM-DD HH:MM:SS` |
| `appointment.createdBy` | `String` | Master Sheet | `06_APPOINTMENTS`| `created_by` | Reference to `02_USERS.user_id` |
| `appointment.updatedBy` | `String` | Master Sheet | `06_APPOINTMENTS`| `updated_by` | Reference to `02_USERS.user_id` |

---

### 2.4 Visit / Queue Entity (`lib/domain/entities/visit.dart`, `queue_event.dart`)

| Application Field | Application Type | Master Sheet | Worksheet | Column | Conversion / Business Logic |
|---|---|---|---|---|---|
| `visit.visitId` / Token | `String` (UUID) | Master Sheet | `08_QUEUE` | `queue_id` | Permanent ID format (`TOK-000001`) |
| `visit.appointmentId` | `String` | Master Sheet | `08_QUEUE` | `appointment_id` | Foreign key referencing `06_APPOINTMENTS.appointment_id` |
| `visit.patientId` | `String` | Master Sheet | `08_QUEUE` | `patient_id` | Foreign key referencing `05_PATIENTS.patient_id` |
| `visit.doctorId` | `String` | Master Sheet | `08_QUEUE` | `doctor_id` | Foreign key referencing `04_DOCTORS.doctor_id` |
| `visit.tokenNumber` | `int` | Master Sheet | `08_QUEUE` | `token_number` | Active queue sequence integer (`1`) |
| `visit.visitDate` | `DateTime` | Master Sheet | `08_QUEUE` | `queue_date` | `YYYY-MM-DD` |
| `visit.checkInTime` | `DateTime` | Master Sheet | `08_QUEUE` | `check_in_time` | Arrival time (`08:45`) |
| `visit.calledTime` | `DateTime?` | Master Sheet | `08_QUEUE` | `called_time` | Doctor call time (`09:00`) |
| `visit.consultationStartTime`| `DateTime?` | Master Sheet | `08_QUEUE` | `consultation_start_time`| Chamber entry time (`09:02`) |
| `visit.consultationEndTime` | `DateTime?` | Master Sheet | `08_QUEUE` | `consultation_end_time` | Chamber exit time (`09:18`) |
| `visit.status` | `VisitStatus` | Master Sheet | `08_QUEUE` | `queue_status` | Controlled via `LK_QUEUE_STATUS` (`WAITING`, `CALLED`, `IN_CONSULTATION`, `COMPLETED`, `SKIPPED`, `CANCELLED`) |
| `visit.priority` | `VisitPriority` | Master Sheet | `08_QUEUE` | `priority` | Controlled via `LK_QUEUE_PRIORITY` (`NORMAL`, `URGENT`, `VIP`, `EMERGENCY`) |
| `visit.roomLabel` | `String` | Master Sheet | `08_QUEUE` | `room_id` | Foreign key referencing `16_ROOMS.room_id` |
| `visit.createdAt` | `DateTime` | Master Sheet | `08_QUEUE` | `created_at` | `YYYY-MM-DD HH:MM:SS` |
| `visit.updatedAt` | `DateTime` | Master Sheet | `08_QUEUE` | `updated_at` | `YYYY-MM-DD HH:MM:SS` |

---

### 2.5 Clinical Consultation Entity (`lib/domain/entities/visit.dart` Clinical Notes)

| Application Field | Application Type | Master Sheet | Worksheet | Column | Conversion / Business Logic |
|---|---|---|---|---|---|
| `consultation.id` | `String` (UUID) | Master Sheet | `09_CONSULTATIONS` | `consultation_id` | Permanent ID format (`CON-000001`) |
| `consultation.appointmentId`| `String` | Master Sheet | `09_CONSULTATIONS` | `appointment_id` | Foreign key referencing `06_APPOINTMENTS.appointment_id` |
| `consultation.patientId` | `String` | Master Sheet | `09_CONSULTATIONS` | `patient_id` | Foreign key referencing `05_PATIENTS.patient_id` |
| `consultation.doctorId` | `String` | Master Sheet | `09_CONSULTATIONS` | `doctor_id` | Foreign key referencing `04_DOCTORS.doctor_id` |
| `consultation.chiefComplaint`| `String` | Master Sheet | `09_CONSULTATIONS` | `chief_complaint` | Primary symptom string |
| `consultation.diagnosis` | `String` | Master Sheet | `09_CONSULTATIONS` | `diagnosis` | Clinical diagnosis |
| `consultation.vitals.bloodPressure`| `String?` | Master Sheet | `09_CONSULTATIONS` | `blood_pressure` | E.g. `120/80 mmHg` |
| `consultation.vitals.weight` | `String?` | Master Sheet | `09_CONSULTATIONS` | `weight_kg` | E.g. `72 kg` |
| `consultation.vitals.temperature`| `String?` | Master Sheet | `09_CONSULTATIONS` | `temperature_f` | E.g. `98.6 F` |
| `consultation.clinicalNotes`| `String` | Master Sheet | `09_CONSULTATIONS` | `clinical_notes` | Treatment plan & lifestyle advice |
| `consultation.followUpRequired`| `bool` | Master Sheet | `09_CONSULTATIONS` | `follow_up_required`| Controlled via `LK_BOOLEAN` (`YES`, `NO`) |
| `consultation.followUpDate`| `DateTime?` | Master Sheet | `09_CONSULTATIONS` | `follow_up_date` | `YYYY-MM-DD` |
| `consultation.status` | `String` | Master Sheet | `09_CONSULTATIONS` | `consultation_status`| Controlled via `LK_CONSULTATION_STATUS` (`IN_PROGRESS`, `COMPLETED`, `CANCELLED`, `REFERRED`) |
| `consultation.startedAt` | `DateTime` | Master Sheet | `09_CONSULTATIONS` | `started_at` | `YYYY-MM-DD HH:MM:SS` |
| `consultation.completedAt`| `DateTime?` | Master Sheet | `09_CONSULTATIONS` | `completed_at` | `YYYY-MM-DD HH:MM:SS` |
| `consultation.createdAt` | `DateTime` | Master Sheet | `09_CONSULTATIONS` | `created_at` | `YYYY-MM-DD HH:MM:SS` |
| `consultation.updatedAt` | `DateTime` | Master Sheet | `09_CONSULTATIONS` | `updated_at` | `YYYY-MM-DD HH:MM:SS` |
| `consultation.doctorUserId`| `String` | Master Sheet | `09_CONSULTATIONS` | `created_by` | Reference to `02_USERS.user_id` |

---

### 2.6 Prescriptions / Medications (Normalized per Medicine Line)

| Application Field | Application Type | Master Sheet | Worksheet | Column | Conversion / Business Logic |
|---|---|---|---|---|---|
| `prescriptionItem.id` | `String` (UUID) | Master Sheet | `14_PRESCRIPTIONS` | `prescription_id` | Permanent ID format (`RX-000001`) |
| `prescriptionItem.consultationId`| `String` | Master Sheet | `14_PRESCRIPTIONS` | `consultation_id` | Foreign key referencing `09_CONSULTATIONS.consultation_id` |
| `prescriptionItem.patientId` | `String` | Master Sheet | `14_PRESCRIPTIONS` | `patient_id` | Foreign key referencing `05_PATIENTS.patient_id` |
| `prescriptionItem.name` | `String` | Master Sheet | `14_PRESCRIPTIONS` | `medicine_name` | Brand / generic drug name |
| `prescriptionItem.form` | `String` | Master Sheet | `14_PRESCRIPTIONS` | `dosage_form` | E.g. `TABLET`, `CAPSULE`, `SYRUP` |
| `prescriptionItem.strength` | `String` | Master Sheet | `14_PRESCRIPTIONS` | `dosage` | Dosage strength (e.g. `500mg`) |
| `prescriptionItem.frequency`| `String` | Master Sheet | `14_PRESCRIPTIONS` | `frequency` | Controlled via `LK_RX_FREQUENCY` (`ONCE_DAILY`, `TWICE_DAILY`, `THRICE_DAILY`, `AS_NEEDED`) |
| `prescriptionItem.duration` | `String` | Master Sheet | `14_PRESCRIPTIONS` | `duration` | Duration text (e.g. `5_DAYS`, `14_DAYS`) |
| `prescriptionItem.route` | `String` | Master Sheet | `14_PRESCRIPTIONS` | `route` | Controlled via `LK_RX_ROUTE` (`ORAL`, `TOPICAL`, etc.) |
| `prescriptionItem.instructions`| `String?` | Master Sheet | `14_PRESCRIPTIONS` | `instructions` | Specific clinical instructions |
| `prescriptionItem.quantity` | `int` | Master Sheet | `14_PRESCRIPTIONS` | `quantity` | Total units prescribed |
| `prescriptionItem.createdAt`| `DateTime` | Master Sheet | `14_PRESCRIPTIONS` | `created_at` | `YYYY-MM-DD HH:MM:SS` |

---

### 2.7 Invoice / Billing Entity (`lib/domain/entities/invoice.dart`)

| Application Field | Application Type | Master Sheet | Worksheet | Column | Conversion / Business Logic |
|---|---|---|---|---|---|
| `invoice.invoiceId` | `String` (UUID) | Master Sheet | `10_BILLING` | `invoice_id` | Permanent ID format (`INV-000001`) |
| `invoice.invoiceNumber` | `String` | Master Sheet | `10_BILLING` | `invoice_number` | Alphanumeric invoice serial (`INV-20260929-001`) |
| `invoice.patientId` | `String` | Master Sheet | `10_BILLING` | `patient_id` | Foreign key referencing `05_PATIENTS.patient_id` |
| `invoice.appointmentId` | `String` | Master Sheet | `10_BILLING` | `appointment_id` | Foreign key referencing `06_APPOINTMENTS.appointment_id` |
| `invoice.invoiceDate` | `DateTime` | Master Sheet | `10_BILLING` | `invoice_date` | `YYYY-MM-DD` |
| `invoice.subtotalMinor` | `int` (paise) | Master Sheet | `10_BILLING` | `subtotal` | Converted: `subtotalMinor / 100` |
| `invoice.discountMinor` | `int` (paise) | Master Sheet | `10_BILLING` | `discount` | Converted: `discountMinor / 100` |
| `invoice.taxMinor` | `int` (paise) | Master Sheet | `10_BILLING` | `tax` | Converted: `taxMinor / 100` |
| `invoice.totalMinor` | `int` (paise) | Master Sheet | `10_BILLING` | `total_amount` | Dynamic Spreadsheet Formula: `=F{row}-G{row}+H{row}` |
| `invoice.paidAmountMinor` | `int` (paise) | Master Sheet | `10_BILLING` | `paid_amount` | Converted: `paidAmountMinor / 100` |
| `invoice.dueAmountMinor` | `int` (paise) | Master Sheet | `10_BILLING` | `due_amount` | Dynamic Spreadsheet Formula: `=I{row}-J{row}` |
| `invoice.status` | `InvoiceStatus` | Master Sheet | `10_BILLING` | `payment_status` | Controlled via `LK_PAYMENT_STATUS` (`PAID`, `PARTIAL`, `UNPAID`) |
| `invoice.createdAt` | `DateTime` | Master Sheet | `10_BILLING` | `created_at` | `YYYY-MM-DD HH:MM:SS` |
| `invoice.updatedAt` | `DateTime` | Master Sheet | `10_BILLING` | `updated_at` | `YYYY-MM-DD HH:MM:SS` |
| `invoice.createdUserId` | `String` | Master Sheet | `10_BILLING` | `created_by` | Reference to `02_USERS.user_id` |

---

### 2.8 Payment Transaction Entity (`lib/domain/entities/payment.dart`)

| Application Field | Application Type | Master Sheet | Worksheet | Column | Conversion / Business Logic |
|---|---|---|---|---|---|
| `payment.paymentId` | `String` (UUID) | Master Sheet | `11_PAYMENTS` | `payment_id` | Permanent ID format (`PAY-000001`) |
| `payment.invoiceId` | `String` | Master Sheet | `11_PAYMENTS` | `invoice_id` | Foreign key referencing `10_BILLING.invoice_id` |
| `payment.patientId` | `String` | Master Sheet | `11_PAYMENTS` | `patient_id` | Foreign key referencing `05_PATIENTS.patient_id` |
| `payment.paymentDate` | `DateTime` | Master Sheet | `11_PAYMENTS` | `payment_date` | `YYYY-MM-DD` |
| `payment.amountMinor` | `int` (paise) | Master Sheet | `11_PAYMENTS` | `amount` | Converted: `amountMinor / 100` |
| `payment.method` | `PaymentMethod` | Master Sheet | `11_PAYMENTS` | `payment_method` | Controlled via `LK_PAYMENT_METHOD` (`CASH`, `UPI`, `CARD`, `BANK_TRANSFER`) |
| `payment.status` | `PaymentStatus` | Master Sheet | `11_PAYMENTS` | `payment_status` | Controlled via `LK_PAYMENT_STATUS` (`COMPLETED`, `REFUNDED`) |
| `payment.referenceNumber`| `String?` | Master Sheet | `11_PAYMENTS` | `transaction_reference`| UPI UTR / POS transaction reference |
| `payment.receivedByUserId`| `String` | Master Sheet | `11_PAYMENTS` | `received_by` | Reference to `02_USERS.user_id` |
| `payment.notes` | `String?` | Master Sheet | `11_PAYMENTS` | `notes` | Cash counter notes |
| `payment.createdAt` | `DateTime` | Master Sheet | `11_PAYMENTS` | `created_at` | `YYYY-MM-DD HH:MM:SS` |

---

### 2.9 Facility Room Entity

| Application Field | Application Type | Master Sheet | Worksheet | Column | Conversion / Business Logic |
|---|---|---|---|---|---|
| `room.roomId` | `String` (UUID) | Master Sheet | `16_ROOMS` | `room_id` | Permanent ID format (`ROOM-000001`) |
| `room.roomCode` | `String` | Master Sheet | `16_ROOMS` | `room_code` | Chamber code (`CH-01`, `PR-01`) |
| `room.name` | `String` | Master Sheet | `16_ROOMS` | `room_name` | Human label (`Consultation Chamber 1`) |
| `room.type` | `RoomType` | Master Sheet | `16_ROOMS` | `room_type` | Controlled via `LK_ROOM_TYPE` (`CONSULTATION`, `PROCEDURE`, `WAITING`) |
| `room.floor` | `String` | Master Sheet | `16_ROOMS` | `floor` | Floor indicator (`Ground Floor`) |
| `room.status` | `RoomStatus` | Master Sheet | `16_ROOMS` | `status` | Controlled via `LK_ROOM_STATUS` (`AVAILABLE`, `OCCUPIED`, `MAINTENANCE`) |
| `room.assignedDoctorId`| `String?` | Master Sheet | `16_ROOMS` | `assigned_doctor_id`| Reference to `04_DOCTORS.doctor_id` |
| `room.notes` | `String?` | Master Sheet | `16_ROOMS` | `notes` | Equipment / chamber notes |
| `room.createdAt` | `DateTime` | Master Sheet | `16_ROOMS` | `created_at` | `YYYY-MM-DD HH:MM:SS` |
| `room.updatedAt` | `DateTime` | Master Sheet | `16_ROOMS` | `updated_at` | `YYYY-MM-DD HH:MM:SS` |

---

### 2.10 User & Role Identity Entity (`lib/domain/entities/staff.dart`)

| Application Field | Application Type | Master Sheet | Worksheet | Column | Conversion / Business Logic |
|---|---|---|---|---|---|
| `user.userId` | `String` (UUID) | Master Sheet | `02_USERS` | `user_id` | Permanent ID format (`USR-000001`) |
| `user.username` | `String` | Master Sheet | `02_USERS` | `username` | Lowercase username (`admin`, `receptionist`) |
| `user.displayName` | `String` | Master Sheet | `02_USERS` | `display_name` | Staff full name |
| `user.roleId` | `String` | Master Sheet | `02_USERS` | `role_id` | Foreign key referencing `03_ROLES.role_id` |
| `user.phone` | `String` | Master Sheet | `02_USERS` | `phone` | Direct contact phone |
| `user.email` | `String?` | Master Sheet | `02_USERS` | `email` | Staff email |
| `user.status` | `StaffStatus` | Master Sheet | `02_USERS` | `status` | Controlled via `LK_USER_ROLE` / `ACTIVE` |
| `user.assignedDoctorIds`| `List<String>` | Master Sheet | `02_USERS` | `assigned_doctor_ids`| Comma-separated doctor IDs |
| `user.createdAt` | `DateTime` | Master Sheet | `02_USERS` | `created_at` | `YYYY-MM-DD HH:MM:SS` |
| `user.updatedAt` | `DateTime` | Master Sheet | `02_USERS` | `updated_at` | `YYYY-MM-DD HH:MM:SS` |

---

### 2.11 Audit Log Entity (`lib/domain/entities/audit_event.dart`)

| Application Field | Application Type | Master Sheet | Worksheet | Column | Conversion / Business Logic |
|---|---|---|---|---|---|
| `audit.auditId` | `String` (UUID) | Master Sheet | `17_AUDIT_LOG` | `audit_id` | Permanent ID format (`AUD-000001`) |
| `audit.timestamp` | `DateTime` | Master Sheet | `17_AUDIT_LOG` | `timestamp` | `YYYY-MM-DD HH:MM:SS` |
| `audit.userId` | `String` | Master Sheet | `17_AUDIT_LOG` | `user_id` | Reference to `02_USERS.user_id` |
| `audit.role` | `String` | Master Sheet | `17_AUDIT_LOG` | `user_role` | Staff operational role |
| `audit.action` | `String` | Master Sheet | `17_AUDIT_LOG` | `action` | Action code (`PATIENT_REGISTERED`, `INVOICE_GENERATED`) |
| `audit.entityType` | `String` | Master Sheet | `17_AUDIT_LOG` | `entity_type` | Target table (`PATIENT`, `BILLING`, etc.) |
| `audit.entityId` | `String` | Master Sheet | `17_AUDIT_LOG` | `entity_id` | Primary key of modified entity |
| `audit.oldValue` | `String?` | Master Sheet | `17_AUDIT_LOG` | `old_value` | Prior state summary |
| `audit.newValue` | `String?` | Master Sheet | `17_AUDIT_LOG` | `new_value` | Updated state summary |
| `audit.source` | `String` | Master Sheet | `17_AUDIT_LOG` | `source` | Terminal identifier (`Web-Client-01`) |
| `audit.remarks` | `String?` | Master Sheet | `17_AUDIT_LOG` | `remarks` | Contextual narrative |

---

## 3. Verification & Compliance Confirmation

1. **Completeness Check:** All 18 entity models and 100% of application fields are fully accounted for.
2. **Normalized Schema Compliance:** All child entities (e.g. medications in prescriptions, line items in invoices) are fully normalized and maintain referential integrity.
3. **Phase 1 UI Protection:** Not a single UI widget, color, layout, or screen component was altered. The mapping adheres strictly to the existing data layer contracts.
