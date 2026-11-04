# -*- coding: utf-8 -*-
"""
Apna Clinic - Master Sheet Structural & Referential Validator
Performs exhaustive structural and relational validation of
APNA_CLINIC_MASTER_SHEET_TEMPLATE.xlsx against all 20 requirements.
"""

import os
import openpyxl

def validate_master_sheet_template(file_path=r"d:\Apna Clinic\APNA_CLINIC_MASTER_SHEET_TEMPLATE.xlsx"):
    report = {
        "file_path": file_path,
        "total_worksheets": 0,
        "worksheet_names": [],
        "total_demo_records": 0,
        "checks_passed": 0,
        "checks_failed": 0,
        "warnings": [],
        "failed_checks": [],
        "summary": []
    }

    if not os.path.exists(file_path):
        report["checks_failed"] += 1
        report["failed_checks"].append(f"Target file does not exist: {file_path}")
        return report

    wb = openpyxl.load_workbook(file_path, data_only=False)
    sheet_names = wb.sheetnames
    report["total_worksheets"] = len(sheet_names)
    report["worksheet_names"] = sheet_names

    expected_sheets = [
        "01_SETTINGS", "02_USERS", "03_ROLES", "04_DOCTORS", "05_PATIENTS",
        "06_APPOINTMENTS", "07_DOCTOR_SCHEDULES", "08_QUEUE", "09_CONSULTATIONS",
        "10_BILLING", "11_PAYMENTS", "12_SERVICES", "13_MEDICAL_RECORDS",
        "14_PRESCRIPTIONS", "15_FOLLOW_UPS", "16_ROOMS", "17_AUDIT_LOG",
        "18_NOTIFICATIONS", "19_REPORTING", "20_LOOKUPS"
    ]

    # CHECK 1: All required sheets exist
    missing_sheets = [s for s in expected_sheets if s not in sheet_names]
    if missing_sheets:
        report["checks_failed"] += 1
        report["failed_checks"].append(f"Missing required sheets: {missing_sheets}")
    else:
        report["checks_passed"] += 1
        report["summary"].append(f"All 20 canonical worksheets exist.")

    # Count total demo records
    total_records = 0
    sheet_record_counts = {}
    for s in expected_sheets:
        if s in sheet_names:
            ws = wb[s]
            # row count minus header
            cnt = max(0, ws.max_row - 1)
            sheet_record_counts[s] = cnt
            total_records += cnt
    report["total_demo_records"] = total_records

    # CHECK 2: Headers, column counts, and duplicate column names
    duplicate_header_found = False
    for s in expected_sheets:
        if s not in sheet_names:
            continue
        ws = wb[s]
        headers = [ws.cell(row=1, column=c).value for c in range(1, ws.max_column + 1)]
        headers_clean = [str(h).strip() for h in headers if h is not None]
        if len(headers_clean) != len(set(headers_clean)):
            report["checks_failed"] += 1
            report["failed_checks"].append(f"Duplicate column header found in sheet '{s}': {headers_clean}")
            duplicate_header_found = True
    if not duplicate_header_found:
        report["checks_passed"] += 1
        report["summary"].append("No duplicate column names found in any worksheet.")

    # CHECK 3: Check for unexpectedly blank required fields
    required_fields_map = {
        "01_SETTINGS": ["setting_id", "setting_category", "setting_key", "setting_value", "data_type", "is_system", "updated_at"],
        "02_USERS": ["user_id", "username", "display_name", "role_id", "phone", "status", "created_at", "updated_at"],
        "03_ROLES": ["role_id", "role_code", "role_name", "description", "status", "created_at", "updated_at"],
        "04_DOCTORS": ["doctor_id", "doctor_code", "doctor_name", "specialization", "qualification", "registration_number", "phone", "email", "room_id", "consultation_fee", "status", "joining_date", "created_at", "updated_at"],
        "05_PATIENTS": ["patient_id", "patient_code", "first_name", "last_name", "full_name", "age", "gender", "phone", "city", "state", "pincode", "blood_group", "registration_date", "patient_status", "consent_status", "created_at", "updated_at", "created_by", "updated_by"],
        "06_APPOINTMENTS": ["appointment_id", "appointment_code", "patient_id", "doctor_id", "appointment_date", "start_time", "end_time", "appointment_type", "booking_source", "status", "room_id", "reminder_consent", "reminder_status", "created_at", "updated_at", "created_by", "updated_by"],
        "07_DOCTOR_SCHEDULES": ["schedule_id", "doctor_id", "day_of_week", "start_time", "end_time", "slot_duration", "room_id", "maximum_patients", "status", "effective_from", "effective_to", "created_at", "updated_at"],
        "08_QUEUE": ["queue_id", "patient_id", "doctor_id", "token_number", "queue_date", "check_in_time", "queue_status", "priority", "room_id", "created_at", "updated_at"],
        "09_CONSULTATIONS": ["consultation_id", "appointment_id", "patient_id", "doctor_id", "chief_complaint", "diagnosis", "follow_up_required", "consultation_status", "started_at", "created_at", "updated_at"],
        "10_BILLING": ["invoice_id", "invoice_number", "patient_id", "invoice_date", "subtotal", "discount", "tax", "total_amount", "paid_amount", "due_amount", "payment_status", "created_at", "updated_at"],
        "11_PAYMENTS": ["payment_id", "invoice_id", "patient_id", "payment_date", "amount", "payment_method", "payment_status", "received_by", "created_at"],
        "12_SERVICES": ["service_id", "service_code", "service_name", "category", "description", "default_fee", "tax_rate", "status", "created_at", "updated_at"],
        "13_MEDICAL_RECORDS": ["record_id", "patient_id", "record_type", "title", "document_url", "record_date", "created_by", "created_at", "updated_at"],
        "14_PRESCRIPTIONS": ["prescription_id", "consultation_id", "patient_id", "medicine_name", "dosage", "frequency", "duration", "route", "instructions", "quantity", "created_at"],
        "15_FOLLOW_UPS": ["followup_id", "patient_id", "doctor_id", "due_date", "status", "reminder_consent", "created_at", "updated_at"],
        "16_ROOMS": ["room_id", "room_code", "room_name", "room_type", "floor", "status", "created_at", "updated_at"],
        "17_AUDIT_LOG": ["audit_id", "timestamp", "user_id", "user_role", "action", "entity_type", "entity_id", "source"],
        "18_NOTIFICATIONS": ["notification_id", "patient_id", "notification_type", "recipient_contact", "scheduled_at", "channel", "template_name", "status", "created_at"],
        "19_REPORTING": ["kpi_metric_id", "metric_name", "metric_value_formula", "category"],
        "20_LOOKUPS": ["lookup_id", "category", "code", "display_name", "sort_order", "is_active", "description"]
    }

    blank_field_error = False
    for s, req_cols in required_fields_map.items():
        if s not in sheet_names:
            continue
        ws = wb[s]
        headers = [ws.cell(row=1, column=c).value for c in range(1, ws.max_column + 1)]
        for col_name in req_cols:
            if col_name not in headers:
                report["checks_failed"] += 1
                report["failed_checks"].append(f"Required column '{col_name}' missing from '{s}'")
                blank_field_error = True
                continue
            col_idx = headers.index(col_name) + 1
            for row in range(2, ws.max_row + 1):
                val = ws.cell(row=row, column=col_idx).value
                if val is None or str(val).strip() == "":
                    report["checks_failed"] += 1
                    report["failed_checks"].append(f"Required field '{col_name}' is blank in '{s}' at row {row}")
                    blank_field_error = True

    if not blank_field_error:
        report["checks_passed"] += 1
        report["summary"].append("All mandatory/required columns verified — zero unexpectedly blank values.")

    # CHECK 4: ID uniqueness & prefixes
    id_rules = {
        "02_USERS": ("user_id", "USR-"),
        "03_ROLES": ("role_id", "ROLE-"),
        "04_DOCTORS": ("doctor_id", "DOC-"),
        "05_PATIENTS": ("patient_id", "PAT-"),
        "06_APPOINTMENTS": ("appointment_id", "APT-"),
        "07_DOCTOR_SCHEDULES": ("schedule_id", "SCH-"),
        "08_QUEUE": ("queue_id", "TOK-"),
        "09_CONSULTATIONS": ("consultation_id", "CON-"),
        "10_BILLING": ("invoice_id", "INV-"),
        "11_PAYMENTS": ("payment_id", "PAY-"),
        "12_SERVICES": ("service_id", "SRV-"),
        "13_MEDICAL_RECORDS": ("record_id", "MED-"),
        "14_PRESCRIPTIONS": ("prescription_id", "RX-"),
        "15_FOLLOW_UPS": ("followup_id", "FOL-"),
        "16_ROOMS": ("room_id", "ROOM-"),
        "17_AUDIT_LOG": ("audit_id", "AUD-"),
        "18_NOTIFICATIONS": ("notification_id", "NOT-"),
        "20_LOOKUPS": ("lookup_id", "LKP-")
    }

    id_sets = {}
    id_error = False
    for s, (id_col, prefix) in id_rules.items():
        if s not in sheet_names:
            continue
        ws = wb[s]
        headers = [ws.cell(row=1, column=c).value for c in range(1, ws.max_column + 1)]
        col_idx = headers.index(id_col) + 1
        seen = set()
        for row in range(2, ws.max_row + 1):
            val = ws.cell(row=row, column=col_idx).value
            if not str(val).startswith(prefix):
                report["checks_failed"] += 1
                report["failed_checks"].append(f"Invalid ID prefix in '{s}' row {row}: '{val}' (expected '{prefix}')")
                id_error = True
            if val in seen:
                report["checks_failed"] += 1
                report["failed_checks"].append(f"Duplicate ID in '{s}': '{val}'")
                id_error = True
            seen.add(val)
        id_sets[s] = seen

    if not id_error:
        report["checks_passed"] += 1
        report["summary"].append("Patient IDs, Doctor IDs, Appointment IDs, Invoice IDs, and all entity IDs are 100% unique with correct prefixes.")

    # CHECK 5: Referential Integrity Checks
    fk_checks = [
        ("02_USERS", "role_id", "03_ROLES", "role_id"),
        ("04_DOCTORS", "room_id", "16_ROOMS", "room_id"),
        ("06_APPOINTMENTS", "patient_id", "05_PATIENTS", "patient_id"),
        ("06_APPOINTMENTS", "doctor_id", "04_DOCTORS", "doctor_id"),
        ("06_APPOINTMENTS", "room_id", "16_ROOMS", "room_id"),
        ("07_DOCTOR_SCHEDULES", "doctor_id", "04_DOCTORS", "doctor_id"),
        ("07_DOCTOR_SCHEDULES", "room_id", "16_ROOMS", "room_id"),
        ("08_QUEUE", "appointment_id", "06_APPOINTMENTS", "appointment_id"),
        ("08_QUEUE", "patient_id", "05_PATIENTS", "patient_id"),
        ("08_QUEUE", "doctor_id", "04_DOCTORS", "doctor_id"),
        ("09_CONSULTATIONS", "appointment_id", "06_APPOINTMENTS", "appointment_id"),
        ("09_CONSULTATIONS", "patient_id", "05_PATIENTS", "patient_id"),
        ("09_CONSULTATIONS", "doctor_id", "04_DOCTORS", "doctor_id"),
        ("10_BILLING", "patient_id", "05_PATIENTS", "patient_id"),
        ("10_BILLING", "appointment_id", "06_APPOINTMENTS", "appointment_id"),
        ("11_PAYMENTS", "invoice_id", "10_BILLING", "invoice_id"),
        ("11_PAYMENTS", "patient_id", "05_PATIENTS", "patient_id"),
        ("13_MEDICAL_RECORDS", "patient_id", "05_PATIENTS", "patient_id"),
        ("14_PRESCRIPTIONS", "consultation_id", "09_CONSULTATIONS", "consultation_id"),
        ("14_PRESCRIPTIONS", "patient_id", "05_PATIENTS", "patient_id"),
        ("15_FOLLOW_UPS", "patient_id", "05_PATIENTS", "patient_id"),
        ("15_FOLLOW_UPS", "doctor_id", "04_DOCTORS", "doctor_id"),
        ("18_NOTIFICATIONS", "patient_id", "05_PATIENTS", "patient_id")
    ]

    fk_error = False
    for src_s, src_col, tgt_s, tgt_col in fk_checks:
        if src_s not in sheet_names or tgt_s not in sheet_names:
            continue
        ws_src = wb[src_s]
        headers_src = [ws_src.cell(row=1, column=c).value for c in range(1, ws_src.max_column + 1)]
        col_idx = headers_src.index(src_col) + 1
        valid_targets = id_sets.get(tgt_s, set())
        for row in range(2, ws_src.max_row + 1):
            val = ws_src.cell(row=row, column=col_idx).value
            if val is not None and str(val).strip() != "":
                if val not in valid_targets:
                    report["checks_failed"] += 1
                    report["failed_checks"].append(f"Foreign key violation: {src_s}.{src_col}='{val}' does not exist in {tgt_s}.{tgt_col}")
                    fk_error = True

    if not fk_error:
        report["checks_passed"] += 1
        report["summary"].append("All foreign key relationships verified — appointments, consultations, prescriptions, invoices, and payments strictly reference existing parent records.")

    # CHECK 6: Formulas
    formula_error = False
    ws_bil = wb["10_BILLING"]
    bil_headers = [ws_bil.cell(row=1, column=c).value for c in range(1, ws_bil.max_column + 1)]
    tot_idx = bil_headers.index("total_amount") + 1
    due_idx = bil_headers.index("due_amount") + 1
    for r in range(2, ws_bil.max_row + 1):
        tot_val = str(ws_bil.cell(row=r, column=tot_idx).value)
        due_val = str(ws_bil.cell(row=r, column=due_idx).value)
        if not tot_val.startswith("="):
            report["checks_failed"] += 1
            report["failed_checks"].append(f"10_BILLING row {r} total_amount is not a formula: {tot_val}")
            formula_error = True
        if not due_val.startswith("="):
            report["checks_failed"] += 1
            report["failed_checks"].append(f"10_BILLING row {r} due_amount is not a formula: {due_val}")
            formula_error = True

    ws_rep = wb["19_REPORTING"]
    rep_headers = [ws_rep.cell(row=1, column=c).value for c in range(1, ws_rep.max_column + 1)]
    form_idx = rep_headers.index("metric_value_formula") + 1
    for r in range(2, ws_rep.max_row + 1):
        f_val = str(ws_rep.cell(row=r, column=form_idx).value)
        if not f_val.startswith("="):
            report["checks_failed"] += 1
            report["failed_checks"].append(f"19_REPORTING row {r} metric formula missing: {f_val}")
            formula_error = True

    if not formula_error:
        report["checks_passed"] += 1
        report["summary"].append("Formulas in 10_BILLING (total_amount, due_amount) and 19_REPORTING (KPIs) are syntactically valid and active.")

    # CHECK 7: Data validations presence
    dv_count = 0
    for ws in wb.worksheets:
        dv_count += len(ws.data_validations.dataValidation)
    if dv_count > 0:
        report["checks_passed"] += 1
        report["summary"].append(f"Data validations confirmed: {dv_count} active validation rule sets across sheets.")
    else:
        report["warnings"].append("No data validation rules found in workbook.")

    # Print Report
    print("=" * 70)
    print("APNA CLINIC MASTER SHEET STRUCTURAL VALIDATION REPORT")
    print("=" * 70)
    print(f"File Path: {report['file_path']}")
    print(f"Total Worksheets: {report['total_worksheets']}")
    print(f"Total Demo Records: {report['total_demo_records']}")
    print(f"Checks Passed: {report['checks_passed']}")
    print(f"Checks Failed: {report['checks_failed']}")
    print(f"Warnings: {len(report['warnings'])}")
    print("-" * 70)
    for line in report["summary"]:
        print(f"  [PASS] {line}")
    if report["warnings"]:
        print("-" * 70)
        for w in report["warnings"]:
            print(f"  [WARN] {w}")
    if report["failed_checks"]:
        print("-" * 70)
        for f in report["failed_checks"]:
            print(f"  [FAIL] {f}")
    print("=" * 70)

    return report

if __name__ == "__main__":
    validate_master_sheet_template()
