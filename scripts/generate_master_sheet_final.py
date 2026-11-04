# -*- coding: utf-8 -*-
"""
Apna Clinic - Master Sheet Final Hardening Generator (Phase 2.1)
Generates: APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL.xlsx
Features:
- Centralized BUSINESS_DATE concept referencing 01_SETTINGS
- Fully dynamic, scalable whole-column KPI formulas (zero hard-coded dates)
- Refined checked-in reporting logic (distinguishing waiting, called, in_consultation, completed)
- 100% centralized Data Validations backed by Excel Defined Names in 20_LOOKUPS
- Scalable row range support up to row 5000 for all tables
- 100% referentially sound and frozen-UI compatible
"""

import os
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation
from openpyxl.workbook.defined_name import DefinedName

def generate_final_master_sheet(output_path=r"d:\Apna Clinic\APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL.xlsx"):
    wb = openpyxl.Workbook()
    wb.remove(wb.active) # Remove default sheet

    # Visual Styles
    font_header = Font(name="Segoe UI", size=11, bold=True, color="FFFFFF")
    fill_header = PatternFill(start_color="1E3A8A", end_color="1E3A8A", fill_type="solid") # Deep Navy
    align_header = Alignment(horizontal="center", vertical="center", wrap_text=True)

    font_data = Font(name="Segoe UI", size=10)
    align_left = Alignment(horizontal="left", vertical="center")
    align_center = Alignment(horizontal="center", vertical="center")
    align_right = Alignment(horizontal="right", vertical="center")

    thin_border = Border(
        left=Side(style='thin', color='E2E8F0'),
        right=Side(style='thin', color='E2E8F0'),
        top=Side(style='thin', color='E2E8F0'),
        bottom=Side(style='thin', color='E2E8F0')
    )

    header_border = Border(
        left=Side(style='thin', color='CBD5E1'),
        right=Side(style='thin', color='CBD5E1'),
        top=Side(style='medium', color='0F172A'),
        bottom=Side(style='medium', color='0F172A')
    )

    # 20 Sheets Definition
    sheets_def = [
        {
            "name": "01_SETTINGS",
            "headers": ["setting_id", "setting_category", "setting_key", "setting_value", "data_type", "description", "is_system", "updated_at"],
            "data": [
                ["SET-000001", "Identity", "clinic_name", "Apna Clinic", "STRING", "Display name of the medical clinic", "TRUE", "2026-09-29 08:00:00"],
                ["SET-000002", "Identity", "legal_name", "Apna Clinic Healthcare LLP", "STRING", "Registered legal entity name", "TRUE", "2026-09-29 08:00:00"],
                ["SET-000003", "Identity", "clinic_address", "Shop 12-14, Ground Floor, Vardhman Market, Sector 6, Dwarka, New Delhi 110075", "STRING", "Full physical address of the clinic", "TRUE", "2026-09-29 08:00:00"],
                ["SET-000004", "Identity", "clinic_phone", "+91 98765 43210", "STRING", "Primary reception and emergency contact", "TRUE", "2026-09-29 08:00:00"],
                ["SET-000005", "Identity", "clinic_email", "contact@apnaclinic.com", "STRING", "Official clinic contact email", "TRUE", "2026-09-29 08:00:00"],
                ["SET-000006", "Operations", "timezone", "Asia/Kolkata", "STRING", "IANA timezone for Indian Standard Time", "TRUE", "2026-09-29 08:00:00"],
                ["SET-000007", "Operations", "currency", "INR", "STRING", "Operating currency code", "TRUE", "2026-09-29 08:00:00"],
                ["SET-000008", "Operations", "opening_time", "08:30", "TIME", "Standard clinic opening time (HH:MM)", "FALSE", "2026-09-29 08:00:00"],
                ["SET-000009", "Operations", "closing_time", "20:30", "TIME", "Standard clinic closing time (HH:MM)", "FALSE", "2026-09-29 08:00:00"],
                ["SET-000010", "Operations", "default_appointment_duration", "15", "INTEGER", "Default appointment duration in minutes", "FALSE", "2026-09-29 08:00:00"],
                ["SET-000011", "Operations", "default_follow_up_days", "7", "INTEGER", "Default follow-up window in days", "FALSE", "2026-09-29 08:00:00"],
                ["SET-000012", "Operations", "default_consultation_fee", "500.00", "DECIMAL", "Standard general consultation fee in INR", "FALSE", "2026-09-29 08:00:00"],
                ["SET-000013", "Prefixes", "patient_code_prefix", "PAT-", "STRING", "Prefix for patient unique IDs", "TRUE", "2026-09-29 08:00:00"],
                ["SET-000014", "Prefixes", "appointment_code_prefix", "APT-", "STRING", "Prefix for appointment unique IDs", "TRUE", "2026-09-29 08:00:00"],
                ["SET-000015", "Prefixes", "invoice_prefix", "INV-", "STRING", "Prefix for billing invoice numbers", "TRUE", "2026-09-29 08:00:00"],
                ["SET-000016", "Prefixes", "payment_prefix", "PAY-", "STRING", "Prefix for payment transaction IDs", "TRUE", "2026-09-29 08:00:00"],
                ["SET-000017", "Prefixes", "token_prefix", "TOK-", "STRING", "Prefix for queue token IDs", "TRUE", "2026-09-29 08:00:00"],
                ["SET-000018", "Formatting", "date_format", "YYYY-MM-DD", "STRING", "Standard ISO-8601 date display format", "TRUE", "2026-09-29 08:00:00"],
                ["SET-000019", "Formatting", "time_format", "HH:mm", "STRING", "Standard 24-hour time format", "TRUE", "2026-09-29 08:00:00"],
                ["SET-000020", "Compliance", "tax_registration_number", "07AAAAA0000A1Z5", "STRING", "GST / Tax registration identifier (if applicable)", "FALSE", "2026-09-29 08:00:00"],
                ["SET-000021", "System", "schema_version", "2.1.0", "STRING", "Master Sheet Relational Schema Version", "TRUE", "2026-09-29 08:00:00"],
                ["SET-000022", "Operations", "business_date", "2026-09-29", "DATE", "Central active clinic operational business date for daily queue, appointments, and reconciliation", "FALSE", "2026-09-29 08:00:00"]
            ]
        },
        {
            "name": "02_USERS",
            "headers": ["user_id", "username", "display_name", "role_id", "phone", "email", "status", "assigned_doctor_ids", "created_at", "updated_at"],
            "data": [
                ["USR-000001", "dr.rajesh", "Dr. Rajesh Sharma", "ROLE-000003", "+91 9811122233", "dr.rajesh@apnaclinic.com", "ACTIVE", "DOC-000001", "2026-01-10 09:00:00", "2026-09-29 08:00:00"],
                ["USR-000002", "dr.priya", "Dr. Priya Verma", "ROLE-000003", "+91 9822233344", "dr.priya@apnaclinic.com", "ACTIVE", "DOC-000002", "2026-01-10 09:00:00", "2026-09-29 08:00:00"],
                ["USR-000003", "reception.sunita", "Sunita Sharma", "ROLE-000002", "+91 9876543211", "sunita@apnaclinic.com", "ACTIVE", "DOC-000001,DOC-000002,DOC-000003", "2026-01-15 09:00:00", "2026-09-29 08:00:00"],
                ["USR-000004", "billing.ramesh", "Ramesh Gupta", "ROLE-000004", "+91 9876543212", "ramesh@apnaclinic.com", "ACTIVE", "", "2026-01-15 09:00:00", "2026-09-29 08:00:00"],
                ["USR-000005", "admin.vikram", "Vikram Singh", "ROLE-000001", "+91 9876543213", "admin@apnaclinic.com", "ACTIVE", "", "2026-01-01 09:00:00", "2026-09-29 08:00:00"],
                ["USR-000006", "manager.anita", "Anita Desai", "ROLE-000005", "+91 9876543214", "manager@apnaclinic.com", "ACTIVE", "", "2026-02-01 09:00:00", "2026-09-29 08:00:00"]
            ]
        },
        {
            "name": "03_ROLES",
            "headers": ["role_id", "role_code", "role_name", "description", "permissions_summary", "status", "created_at", "updated_at"],
            "data": [
                ["ROLE-000001", "ADMIN", "Administrator", "Full system access, settings, user management, and security audit", "ALL_PERMISSIONS", "ACTIVE", "2026-01-01 09:00:00", "2026-09-29 08:00:00"],
                ["ROLE-000002", "RECEPTIONIST", "Receptionist", "Patient check-in, token generation, appointment scheduling, queue management", "PATIENT_WRITE,APPOINTMENT_WRITE,QUEUE_WRITE,BILLING_READ", "ACTIVE", "2026-01-01 09:00:00", "2026-09-29 08:00:00"],
                ["ROLE-000003", "DOCTOR", "Consulting Doctor", "Queue status, patient consultation notes, prescriptions, medical records", "QUEUE_READ,CONSULTATION_WRITE,PRESCRIPTION_WRITE,RECORDS_WRITE", "ACTIVE", "2026-01-01 09:00:00", "2026-09-29 08:00:00"],
                ["ROLE-000004", "BILLING", "Billing Specialist", "Invoice generation, payment collection, receipts, cash reconciliation", "BILLING_WRITE,PAYMENT_WRITE,REPORT_FINANCE", "ACTIVE", "2026-01-01 09:00:00", "2026-09-29 08:00:00"],
                ["ROLE-000005", "MANAGER", "Clinic Manager", "Operational oversight, doctor schedule allocation, executive reporting", "REPORT_ALL,SCHEDULE_WRITE,AUDIT_READ", "ACTIVE", "2026-01-01 09:00:00", "2026-09-29 08:00:00"]
            ]
        },
        {
            "name": "04_DOCTORS",
            "headers": ["doctor_id", "doctor_code", "doctor_name", "specialization", "qualification", "registration_number", "phone", "email", "room_id", "consultation_fee", "consultation_duration_minutes", "status", "joining_date", "created_at", "updated_at"],
            "data": [
                ["DOC-000001", "DR-SHARMA", "Dr. Rajesh Sharma", "General Physician", "MBBS, MD (Internal Medicine)", "MCI-48291", "+91 9811122233", "dr.rajesh@apnaclinic.com", "ROOM-000001", 500.00, 15, "ACTIVE", "2024-01-15", "2026-01-10 09:00:00", "2026-09-29 08:00:00"],
                ["DOC-000002", "DR-VERMA", "Dr. Priya Verma", "Gynecology & Obstetrics", "MBBS, MS (OB-GYN), DGO", "DMC-39182", "+91 9822233344", "dr.priya@apnaclinic.com", "ROOM-000002", 700.00, 20, "ACTIVE", "2024-03-01", "2026-01-10 09:00:00", "2026-09-29 08:00:00"],
                ["DOC-000003", "DR-PATEL", "Dr. Amit Patel", "Orthopedics", "MBBS, MS (Orthopedics)", "DMC-51029", "+91 9833344455", "dr.amit@apnaclinic.com", "ROOM-000003", 600.00, 15, "ACTIVE", "2024-06-15", "2026-01-10 09:00:00", "2026-09-29 08:00:00"]
            ]
        },
        {
            "name": "05_PATIENTS",
            "headers": ["patient_id", "patient_code", "first_name", "middle_name", "last_name", "full_name", "date_of_birth", "age", "gender", "phone", "alternate_phone", "email", "address", "city", "state", "pincode", "emergency_contact_name", "emergency_contact_phone", "blood_group", "registration_date", "patient_status", "consent_status", "consent_version", "created_at", "updated_at", "created_by", "updated_by"],
            "data": [
                ["PAT-000001", "P-2026-0001", "Aarav", "", "Kumar", "Aarav Kumar", "1988-06-14", 38, "MALE", "+91 9876543201", "", "aarav.kumar@email.com", "Flat 402, Shanti Vihar, Sector 12", "New Delhi", "Delhi", "110075", "Pooja Kumar", "+91 9876543202", "B+", "2026-01-15", "ACTIVE", "GRANTED", "v1.0", "2026-01-15 10:00:00", "2026-09-29 08:00:00", "USR-000003", "USR-000003"],
                ["PAT-000002", "P-2026-0002", "Meena", "", "Devi", "Meena Devi", "1974-03-22", 52, "FEMALE", "+91 9876543203", "+91 9876543204", "", "H.No 124, Gali 3, Palam Colony", "New Delhi", "Delhi", "110045", "Suresh Prasad", "+91 9876543204", "O+", "2026-01-18", "ACTIVE", "GRANTED", "v1.0", "2026-01-18 11:30:00", "2026-09-29 08:00:00", "USR-000003", "USR-000003"],
                ["PAT-000003", "P-2026-0003", "Rohan", "Kumar", "Gupta", "Rohan Kumar Gupta", "2002-11-05", 23, "MALE", "+91 9876543205", "", "rohan.gupta@email.com", "Pocket B, DDA Flats, Bindapur", "New Delhi", "Delhi", "110059", "Kailash Gupta", "+91 9876543206", "A+", "2026-02-01", "ACTIVE", "GRANTED", "v1.0", "2026-02-01 09:15:00", "2026-09-29 08:00:00", "USR-000003", "USR-000003"],
                ["PAT-000004", "P-2026-0004", "Sunita", "", "Verma", "Sunita Verma", "1995-08-19", 31, "FEMALE", "+91 9876543207", "", "sunita.v@email.com", "B-48, Mahavir Enclave", "New Delhi", "Delhi", "110045", "Manish Verma", "+91 9876543208", "AB+", "2026-02-10", "ACTIVE", "GRANTED", "v1.0", "2026-02-10 14:00:00", "2026-09-29 08:00:00", "USR-000003", "USR-000003"],
                ["PAT-000005", "P-2026-0005", "Rajesh", "Nath", "Sharma", "Rajesh Nath Sharma", "1961-01-10", 65, "MALE", "+91 9876543209", "", "", "Plot 18, Block C, Janakpuri", "New Delhi", "Delhi", "110058", "Alok Sharma", "+91 9876543210", "O-", "2026-02-20", "ACTIVE", "GRANTED", "v1.0", "2026-02-20 16:30:00", "2026-09-29 08:00:00", "USR-000003", "USR-000003"],
                ["PAT-000006", "P-2026-0006", "Ananya", "", "Mishra", "Ananya Mishra", "2014-04-12", 12, "FEMALE", "+91 9876543215", "", "", "A-12, Sector 7, Dwarka", "New Delhi", "Delhi", "110075", "Deepak Mishra", "+91 9876543215", "B+", "2026-03-01", "ACTIVE", "GRANTED", "v1.0", "2026-03-01 10:15:00", "2026-09-29 08:00:00", "USR-000003", "USR-000003"],
                ["PAT-000007", "P-2026-0007", "Harish", "", "Chandra", "Harish Chandra", "1981-09-28", 45, "MALE", "+91 9876543216", "", "harish.c@email.com", "C-88, Vikaspuri", "New Delhi", "Delhi", "110018", "Geeta Chandra", "+91 9876543217", "A-", "2026-03-15", "ACTIVE", "GRANTED", "v1.0", "2026-03-15 15:45:00", "2026-09-29 08:00:00", "USR-000003", "USR-000003"],
                ["PAT-000008", "P-2026-0008", "Kavita", "", "Joshi", "Kavita Joshi", "1997-12-03", 28, "FEMALE", "+91 9876543218", "", "kavita.j@email.com", "Flat 101, Golf Links Appt, Sector 18", "New Delhi", "Delhi", "110078", "Nitin Joshi", "+91 9876543219", "O+", "2026-03-20", "ACTIVE", "GRANTED", "v1.0", "2026-03-20 11:00:00", "2026-09-29 08:00:00", "USR-000003", "USR-000003"]
            ]
        },
        {
            "name": "06_APPOINTMENTS",
            "headers": ["appointment_id", "appointment_code", "patient_id", "doctor_id", "appointment_date", "start_time", "end_time", "appointment_type", "booking_source", "status", "token_number", "room_id", "notes", "cancel_reason", "reminder_consent", "reminder_status", "created_at", "updated_at", "created_by", "updated_by"],
            "data": [
                ["APT-000001", "APT-2026-0001", "PAT-000001", "DOC-000001", "2026-09-29", "09:00", "09:15", "NEW_CONSULTATION", "WALK_IN", "COMPLETED", 1, "ROOM-000001", "Fever and cold since 3 days", "", "TRUE", "SENT", "2026-09-29 08:35:00", "2026-09-29 09:20:00", "USR-000003", "USR-000001"],
                ["APT-000002", "APT-2026-0002", "PAT-000002", "DOC-000001", "2026-09-29", "09:15", "09:30", "FOLLOW_UP", "RECEPTION", "COMPLETED", 2, "ROOM-000001", "Hypertension blood pressure check", "", "TRUE", "SENT", "2026-09-28 16:00:00", "2026-09-29 09:35:00", "USR-000003", "USR-000001"],
                ["APT-000003", "APT-2026-0003", "PAT-000003", "DOC-000003", "2026-09-29", "09:30", "09:45", "NEW_CONSULTATION", "PHONE", "IN_CONSULTATION", 1, "ROOM-000003", "Ankle pain after sports injury", "", "TRUE", "SENT", "2026-09-28 17:30:00", "2026-09-29 09:40:00", "USR-000003", "USR-000001"],
                ["APT-000004", "APT-2026-0004", "PAT-000004", "DOC-000002", "2026-09-29", "09:30", "09:50", "ROUTINE_CHECKUP", "PHONE", "CHECKED_IN", 1, "ROOM-000002", "Second trimester antenatal visit", "", "TRUE", "SENT", "2026-09-27 11:00:00", "2026-09-29 09:25:00", "USR-000003", "USR-000003"],
                ["APT-000005", "APT-2026-0005", "PAT-000005", "DOC-000001", "2026-09-29", "09:45", "10:00", "ROUTINE_CHECKUP", "RECEPTION", "CHECKED_IN", 3, "ROOM-000001", "Routine diabetic health checkup", "", "TRUE", "SENT", "2026-09-29 09:10:00", "2026-09-29 09:15:00", "USR-000003", "USR-000003"],
                ["APT-000006", "APT-2026-0006", "PAT-000006", "DOC-000001", "2026-09-29", "10:00", "10:15", "NEW_CONSULTATION", "WALK_IN", "SCHEDULED", 4, "ROOM-000001", "Throat pain and difficulty swallowing", "", "TRUE", "PENDING", "2026-09-29 09:20:00", "2026-09-29 09:20:00", "USR-000003", "USR-000003"],
                ["APT-000007", "APT-2026-0007", "PAT-000007", "DOC-000003", "2026-09-29", "10:15", "10:30", "NEW_CONSULTATION", "PHONE", "SCHEDULED", 2, "ROOM-000003", "Chronic lumbar spine pain", "", "TRUE", "SENT", "2026-09-28 14:00:00", "2026-09-28 14:00:00", "USR-000003", "USR-000003"],
                ["APT-000008", "APT-2026-0008", "PAT-000008", "DOC-000001", "2026-09-29", "10:30", "10:45", "NEW_CONSULTATION", "PHONE", "SCHEDULED", 5, "ROOM-000001", "Severe unilateral headache with aura", "", "TRUE", "SENT", "2026-09-29 08:00:00", "2026-09-29 08:00:00", "USR-000003", "USR-000003"],
                ["APT-000009", "APT-2026-0009", "PAT-000001", "DOC-000001", "2026-09-29", "11:00", "11:15", "NEW_CONSULTATION", "PHONE", "CANCELLED", 0, "ROOM-000001", "Patient called to reschedule for next week", "Patient requested schedule change", "TRUE", "SENT", "2026-09-28 10:00:00", "2026-09-29 08:15:00", "USR-000003", "USR-000003"],
                ["APT-000010", "APT-2026-0010", "PAT-000003", "DOC-000001", "2026-09-28", "16:00", "16:15", "NEW_CONSULTATION", "RECEPTION", "NO_SHOW", 0, "ROOM-000001", "Did not arrive during clinic hours", "Patient did not attend", "FALSE", "NOT_REQUESTED", "2026-09-28 12:00:00", "2026-09-28 17:00:00", "USR-000003", "USR-000003"]
            ]
        },
        {
            "name": "07_DOCTOR_SCHEDULES",
            "headers": ["schedule_id", "doctor_id", "day_of_week", "start_time", "end_time", "slot_duration", "break_start", "break_end", "room_id", "maximum_patients", "status", "effective_from", "effective_to", "created_at", "updated_at"],
            "data": [
                ["SCH-000001", "DOC-000001", "MONDAY", "09:00", "13:00", 15, "11:00", "11:15", "ROOM-000001", 16, "ACTIVE", "2026-01-01", "2099-12-31", "2026-01-01 09:00:00", "2026-09-29 08:00:00"],
                ["SCH-000002", "DOC-000001", "TUESDAY", "09:00", "13:00", 15, "11:00", "11:15", "ROOM-000001", 16, "ACTIVE", "2026-01-01", "2099-12-31", "2026-01-01 09:00:00", "2026-09-29 08:00:00"],
                ["SCH-000003", "DOC-000001", "WEDNESDAY", "09:00", "13:00", 15, "11:00", "11:15", "ROOM-000001", 16, "ACTIVE", "2026-01-01", "2099-12-31", "2026-01-01 09:00:00", "2026-09-29 08:00:00"],
                ["SCH-000004", "DOC-000001", "THURSDAY", "09:00", "13:00", 15, "11:00", "11:15", "ROOM-000001", 16, "ACTIVE", "2026-01-01", "2099-12-31", "2026-01-01 09:00:00", "2026-09-29 08:00:00"],
                ["SCH-000005", "DOC-000001", "FRIDAY", "09:00", "13:00", 15, "11:00", "11:15", "ROOM-000001", 16, "ACTIVE", "2026-01-01", "2099-12-31", "2026-01-01 09:00:00", "2026-09-29 08:00:00"],
                ["SCH-000006", "DOC-000001", "SATURDAY", "09:00", "14:00", 15, "11:30", "12:00", "ROOM-000001", 20, "ACTIVE", "2026-01-01", "2099-12-31", "2026-01-01 09:00:00", "2026-09-29 08:00:00"],
                ["SCH-000007", "DOC-000002", "MONDAY", "09:30", "13:30", 20, "11:30", "11:45", "ROOM-000002", 12, "ACTIVE", "2026-01-01", "2099-12-31", "2026-01-01 09:00:00", "2026-09-29 08:00:00"],
                ["SCH-000008", "DOC-000002", "WEDNESDAY", "09:30", "13:30", 20, "11:30", "11:45", "ROOM-000002", 12, "ACTIVE", "2026-01-01", "2099-12-31", "2026-01-01 09:00:00", "2026-09-29 08:00:00"],
                ["SCH-000009", "DOC-000002", "FRIDAY", "09:30", "13:30", 20, "11:30", "11:45", "ROOM-000002", 12, "ACTIVE", "2026-01-01", "2099-12-31", "2026-01-01 09:00:00", "2026-09-29 08:00:00"],
                ["SCH-000010", "DOC-000003", "TUESDAY", "09:00", "12:00", 15, "10:30", "10:45", "ROOM-000003", 12, "ACTIVE", "2026-01-01", "2099-12-31", "2026-01-01 09:00:00", "2026-09-29 08:00:00"],
                ["SCH-000011", "DOC-000003", "THURSDAY", "09:00", "12:00", 15, "10:30", "10:45", "ROOM-000003", 12, "ACTIVE", "2026-01-01", "2099-12-31", "2026-01-01 09:00:00", "2026-09-29 08:00:00"],
                ["SCH-000012", "DOC-000003", "SATURDAY", "10:00", "13:00", 15, "11:30", "11:45", "ROOM-000003", 12, "ACTIVE", "2026-01-01", "2099-12-31", "2026-01-01 09:00:00", "2026-09-29 08:00:00"]
            ]
        },
        {
            "name": "08_QUEUE",
            "headers": ["queue_id", "appointment_id", "patient_id", "doctor_id", "token_number", "queue_date", "check_in_time", "called_time", "consultation_start_time", "consultation_end_time", "queue_status", "priority", "room_id", "created_at", "updated_at"],
            "data": [
                ["TOK-000001", "APT-000001", "PAT-000001", "DOC-000001", 1, "2026-09-29", "2026-09-29 08:45:00", "2026-09-29 09:00:00", "2026-09-29 09:02:00", "2026-09-29 09:18:00", "COMPLETED", "NORMAL", "ROOM-000001", "2026-09-29 08:45:00", "2026-09-29 09:18:00"],
                ["TOK-000002", "APT-000002", "PAT-000002", "DOC-000001", 2, "2026-09-29", "2026-09-29 09:05:00", "2026-09-29 09:19:00", "2026-09-29 09:20:00", "2026-09-29 09:34:00", "COMPLETED", "NORMAL", "ROOM-000001", "2026-09-29 09:05:00", "2026-09-29 09:34:00"],
                ["TOK-000003", "APT-000003", "PAT-000003", "DOC-000003", 1, "2026-09-29", "2026-09-29 09:20:00", "2026-09-29 09:30:00", "2026-09-29 09:32:00", "", "IN_CONSULTATION", "URGENT", "ROOM-000003", "2026-09-29 09:20:00", "2026-09-29 09:32:00"],
                ["TOK-000004", "APT-000004", "PAT-000004", "DOC-000002", 1, "2026-09-29", "2026-09-29 09:25:00", "", "", "", "WAITING", "NORMAL", "ROOM-000002", "2026-09-29 09:25:00", "2026-09-29 09:25:00"],
                ["TOK-000005", "APT-000005", "PAT-000005", "DOC-000001", 3, "2026-09-29", "2026-09-29 09:30:00", "", "", "", "WAITING", "NORMAL", "ROOM-000001", "2026-09-29 09:30:00", "2026-09-29 09:30:00"],
                ["TOK-000006", "APT-000006", "PAT-000006", "DOC-000001", 4, "2026-09-29", "2026-09-29 09:40:00", "", "", "", "WAITING", "NORMAL", "ROOM-000001", "2026-09-29 09:40:00", "2026-09-29 09:40:00"]
            ]
        },
        {
            "name": "09_CONSULTATIONS",
            "headers": ["consultation_id", "appointment_id", "patient_id", "doctor_id", "chief_complaint", "clinical_summary", "diagnosis", "advice", "follow_up_required", "follow_up_date", "consultation_status", "started_at", "completed_at", "created_at", "updated_at"],
            "data": [
                ["CON-000001", "APT-000001", "PAT-000001", "DOC-000001", "High fever, chills, body ache for 3 days", "Temp 101.4 F, BP 120/80 mmHg, Pulse 88 bpm. Throat mild erythema.", "Acute Upper Respiratory Viral Infection", "Adequate oral hydration, steam inhalation, paracetamol for fever.", "TRUE", "2026-10-06", "COMPLETED", "2026-09-29 09:02:00", "2026-09-29 09:18:00", "2026-09-29 09:02:00", "2026-09-29 09:18:00"],
                ["CON-000002", "APT-000002", "PAT-000002", "DOC-000001", "Routine blood pressure checkup, mild headache", "BP 142/92 mmHg, Heart sounds normal, no peripheral edema.", "Essential Hypertension (Stage 1) - Borderline", "Low sodium diet, brisk walking 30 min daily, continue Telmisartan.", "TRUE", "2026-10-27", "COMPLETED", "2026-09-29 09:20:00", "2026-09-29 09:34:00", "2026-09-29 09:20:00", "2026-09-29 09:34:00"],
                ["CON-000003", "APT-000003", "PAT-000003", "DOC-000003", "Twisted right ankle during football, painful swelling", "Tenderness over anterior talofibular ligament, mild ecchymosis, bearing weight with difficulty.", "Grade 1 Lateral Ankle Sprain (Right)", "RICE protocol (Rest, Ice, Compression, Elevation), crepe bandage.", "TRUE", "2026-10-06", "IN_PROGRESS", "2026-09-29 09:32:00", "", "2026-09-29 09:32:00", "2026-09-29 09:32:00"]
            ]
        },
        {
            "name": "10_BILLING",
            "headers": ["invoice_id", "invoice_number", "patient_id", "appointment_id", "invoice_date", "subtotal", "discount", "tax", "total_amount", "paid_amount", "due_amount", "payment_status", "notes", "created_at", "updated_at"],
            "data": [
                ["INV-000001", "INV-2026-0001", "PAT-000001", "APT-000001", "2026-09-29", 500.00, 0.00, 0.00, "=F2-G2+H2", 500.00, "=I2-J2", "PAID", "General consultation fee", "2026-09-29 09:20:00", "2026-09-29 09:22:00"],
                ["INV-000002", "INV-2026-0002", "PAT-000002", "APT-000002", "2026-09-29", 500.00, 50.00, 0.00, "=F3-G3+H3", 450.00, "=I3-J3", "PAID", "Followup visit discount applied", "2026-09-29 09:35:00", "2026-09-29 09:36:00"],
                ["INV-000003", "INV-2026-0003", "PAT-000003", "APT-000003", "2026-09-29", 850.00, 0.00, 0.00, "=F4-G4+H4", 500.00, "=I4-J4", "PARTIAL", "Consultation (600) + Crepe Bandage Application (250)", "2026-09-29 09:35:00", "2026-09-29 09:38:00"],
                ["INV-000004", "INV-2026-0004", "PAT-000004", "APT-000004", "2026-09-29", 700.00, 0.00, 0.00, "=F5-G5+H5", 0.00, "=I5-J5", "UNPAID", "Gynecology specialist consultation", "2026-09-29 09:26:00", "2026-09-29 09:26:00"]
            ]
        },
        {
            "name": "11_PAYMENTS",
            "headers": ["payment_id", "invoice_id", "patient_id", "payment_date", "amount", "payment_method", "transaction_reference", "payment_status", "received_by", "notes", "created_at"],
            "data": [
                ["PAY-000001", "INV-000001", "PAT-000001", "2026-09-29", 500.00, "UPI", "UPI/428192019283", "COMPLETED", "USR-000004", "GPay payment verified", "2026-09-29 09:22:00"],
                ["PAY-000002", "INV-000002", "PAT-000002", "2026-09-29", 450.00, "CASH", "CASH-REC-101", "COMPLETED", "USR-000004", "Cash received at counter", "2026-09-29 09:36:00"],
                ["PAY-000003", "INV-000003", "PAT-000003", "2026-09-29", 500.00, "CARD", "TXN-CARD-99201", "COMPLETED", "USR-000004", "Visa Debit POS transaction", "2026-09-29 09:38:00"]
            ]
        },
        {
            "name": "12_SERVICES",
            "headers": ["service_id", "service_code", "service_name", "category", "description", "default_fee", "tax_rate", "status", "created_at", "updated_at"],
            "data": [
                ["SRV-000001", "CONS-GEN", "General Physician Consultation", "CONSULTATION", "Standard Outpatient General Physician consultation", 500.00, 0.0, "ACTIVE", "2026-01-01 09:00:00", "2026-09-29 08:00:00"],
                ["SRV-000002", "CONS-SPEC-GYN", "Gynecology Specialist Consultation", "CONSULTATION", "Specialist OB-GYN consultation", 700.00, 0.0, "ACTIVE", "2026-01-01 09:00:00", "2026-09-29 08:00:00"],
                ["SRV-000003", "CONS-SPEC-ORTHO", "Orthopedic Specialist Consultation", "CONSULTATION", "Specialist Orthopedic assessment", 600.00, 0.0, "ACTIVE", "2026-01-01 09:00:00", "2026-09-29 08:00:00"],
                ["SRV-000004", "CONS-FOLLOWUP", "Follow-up Consultation", "CONSULTATION", "Followup visit within 7 days", 250.00, 0.0, "ACTIVE", "2026-01-01 09:00:00", "2026-09-29 08:00:00"],
                ["SRV-000005", "PROC-ECG", "12-Lead Electrocardiogram (ECG)", "DIAGNOSTIC", "Standard 12-lead resting ECG with interpretation", 350.00, 0.0, "ACTIVE", "2026-01-01 09:00:00", "2026-09-29 08:00:00"],
                ["SRV-000006", "PROC-GRBS", "Random Blood Sugar (Glucometer)", "DIAGNOSTIC", "Fingerstick point-of-care blood glucose test", 70.00, 0.0, "ACTIVE", "2026-01-01 09:00:00", "2026-09-29 08:00:00"],
                ["SRV-000007", "PROC-DRESS-SML", "Minor Wound Dressing", "PROCEDURE", "Antiseptic cleaning and sterile gauze dressing", 150.00, 0.0, "ACTIVE", "2026-01-01 09:00:00", "2026-09-29 08:00:00"],
                ["SRV-000008", "PROC-CREPE", "Crepe Bandage / Splint Application", "PROCEDURE", "Immobilization dressing for sprains / strains", 250.00, 0.0, "ACTIVE", "2026-01-01 09:00:00", "2026-09-29 08:00:00"],
                ["SRV-000009", "PROC-INJ-IM", "Intramuscular / IV Injection", "PROCEDURE", "Administration of prescribed injectable medication", 100.00, 0.0, "ACTIVE", "2026-01-01 09:00:00", "2026-09-29 08:00:00"],
                ["SRV-000010", "PROC-NEB", "Nebulization Session", "PROCEDURE", "Bronchodilator aerosol nebulization (single session)", 150.00, 0.0, "ACTIVE", "2026-01-01 09:00:00", "2026-09-29 08:00:00"]
            ]
        },
        {
            "name": "13_MEDICAL_RECORDS",
            "headers": ["record_id", "patient_id", "consultation_id", "record_type", "title", "description", "document_url", "record_date", "created_by", "created_at", "updated_at"],
            "data": [
                ["MED-000001", "PAT-000001", "CON-000001", "LAB_REPORT", "Complete Blood Count (CBC)", "Platelet 2.4L, TLC 7800, Hb 13.8 g/dL", "https://drive.google.com/file/d/apna_cbc_001/view", "2026-09-29", "USR-000001", "2026-09-29 09:15:00", "2026-09-29 09:15:00"],
                ["MED-000002", "PAT-000002", "CON-000002", "LAB_REPORT", "Lipid Profile & Serum Creatinine", "Total Cholesterol 185 mg/dL, Creatinine 0.9 mg/dL", "https://drive.google.com/file/d/apna_lipid_002/view", "2026-09-20", "USR-000001", "2026-09-29 09:25:00", "2026-09-29 09:25:00"],
                ["MED-000003", "PAT-000003", "CON-000003", "RADIOLOGY", "X-Ray Right Ankle AP & Lateral", "No fracture or bony dislocation seen. Soft tissue edema present.", "https://drive.google.com/file/d/apna_xray_003/view", "2026-09-29", "USR-000001", "2026-09-29 09:35:00", "2026-09-29 09:35:00"]
            ]
        },
        {
            "name": "14_PRESCRIPTIONS",
            "headers": ["prescription_id", "consultation_id", "patient_id", "medicine_name", "dosage", "frequency", "duration", "route", "instructions", "quantity", "created_at"],
            "data": [
                ["RX-000001", "CON-000001", "PAT-000001", "Tab Paracetamol 650mg", "650mg (1 Tab)", "THRICE_DAILY", "3 days", "ORAL", "Take after food when fever > 100 F", 10, "2026-09-29 09:15:00"],
                ["RX-000002", "CON-000001", "PAT-000001", "Tab Cetirizine 10mg", "10mg (1 Tab)", "ONCE_DAILY", "5 days", "ORAL", "Take at bedtime", 5, "2026-09-29 09:15:00"],
                ["RX-000003", "CON-000001", "PAT-000001", "Syp Ascoril-D", "10ml", "THRICE_DAILY", "5 days", "ORAL", "Shake well before use", 1, "2026-09-29 09:15:00"],
                ["RX-000004", "CON-000002", "PAT-000002", "Tab Telmisartan 40mg", "40mg (1 Tab)", "ONCE_DAILY", "30 days", "ORAL", "Take in the morning with water", 30, "2026-09-29 09:30:00"],
                ["RX-000005", "CON-000003", "PAT-000003", "Tab Aceclofenac 100mg + Paracetamol 325mg", "1 Tab", "TWICE_DAILY", "5 days", "ORAL", "Take strictly after meals", 10, "2026-09-29 09:35:00"],
                ["RX-000006", "CON-000003", "PAT-000003", "Cap Pantoprazole 40mg", "40mg (1 Cap)", "ONCE_DAILY", "5 days", "ORAL", "Take 30 mins before breakfast", 5, "2026-09-29 09:35:00"]
            ]
        },
        {
            "name": "15_FOLLOW_UPS",
            "headers": ["followup_id", "patient_id", "consultation_id", "doctor_id", "due_date", "status", "reminder_consent", "reminder_sent_at", "converted_appointment_id", "notes", "created_at", "updated_at"],
            "data": [
                ["FOL-000001", "PAT-000001", "CON-000001", "DOC-000001", "2026-10-06", "SCHEDULED", "TRUE", "", "", "Review fever resolution and chest symptoms", "2026-09-29 09:18:00", "2026-09-29 09:18:00"],
                ["FOL-000002", "PAT-000002", "CON-000002", "DOC-000001", "2026-10-27", "SCHEDULED", "TRUE", "", "", "Monthly BP monitoring visit", "2026-09-29 09:34:00", "2026-09-29 09:34:00"],
                ["FOL-000003", "PAT-000003", "CON-000003", "DOC-000003", "2026-10-06", "SCHEDULED", "TRUE", "", "", "Ankle ligament healing review and weight bearing test", "2026-09-29 09:36:00", "2026-09-29 09:36:00"]
            ]
        },
        {
            "name": "16_ROOMS",
            "headers": ["room_id", "room_code", "room_name", "room_type", "floor", "status", "assigned_doctor_id", "notes", "created_at", "updated_at"],
            "data": [
                ["ROOM-000001", "CHAMBER-1", "Doctor Consultation Chamber 1", "CONSULTATION", "Ground Floor", "OCCUPIED", "DOC-000001", "Equipped with exam couch, ophthalmoscope, digital BP", "2026-01-01 09:00:00", "2026-09-29 08:00:00"],
                ["ROOM-000002", "CHAMBER-2", "Doctor Consultation Chamber 2 (OB-GYN)", "CONSULTATION", "Ground Floor", "AVAILABLE", "DOC-000002", "Equipped with privacy curtain, ultrasound bed, fetal Doppler", "2026-01-01 09:00:00", "2026-09-29 08:00:00"],
                ["ROOM-000003", "PROC-ROOM", "Minor OT & Procedure Room", "PROCEDURE", "Ground Floor", "OCCUPIED", "DOC-000003", "Sterile procedural room for dressings, sutures, nebulization, ECG", "2026-01-01 09:00:00", "2026-09-29 08:00:00"],
                ["ROOM-000004", "WAITING-1", "Main Patient Reception & Waiting Lounge", "WAITING", "Ground Floor", "AVAILABLE", "", "Capacity 25 seats with token LED TV screen", "2026-01-01 09:00:00", "2026-09-29 08:00:00"]
            ]
        },
        {
            "name": "17_AUDIT_LOG",
            "headers": ["audit_id", "timestamp", "user_id", "user_role", "action", "entity_type", "entity_id", "old_value", "new_value", "source", "remarks"],
            "data": [
                ["AUD-000001", "2026-09-29 08:35:00", "USR-000003", "RECEPTIONIST", "PATIENT_CHECKED_IN", "APPOINTMENT", "APT-000001", "status:SCHEDULED", "status:CHECKED_IN, token:1", "Reception-PC-01", "Patient arrived for consultation"],
                ["AUD-000002", "2026-09-29 09:02:00", "USR-000001", "DOCTOR", "CONSULTATION_STARTED", "QUEUE", "TOK-000001", "queue_status:CALLED", "queue_status:IN_CONSULTATION", "Doctor-Chamber-01", "Consultation started with Dr. Rajesh Sharma"],
                ["AUD-000003", "2026-09-29 09:18:00", "USR-000001", "DOCTOR", "CONSULTATION_COMPLETED", "CONSULTATION", "CON-000001", "status:IN_PROGRESS", "status:COMPLETED", "Doctor-Chamber-01", "Consultation concluded and prescription created"],
                ["AUD-000004", "2026-09-29 09:20:00", "USR-000004", "BILLING", "INVOICE_GENERATED", "BILLING", "INV-000001", "", "total:500.00, status:UNPAID", "Billing-POS-01", "Invoice raised for consultation"],
                ["AUD-000005", "2026-09-29 09:22:00", "USR-000004", "BILLING", "PAYMENT_RECEIVED", "PAYMENTS", "PAY-000001", "status:UNPAID", "amount:500.00, method:UPI, status:PAID", "Billing-POS-01", "GPay UPI transaction completed"],
                ["AUD-000006", "2026-09-29 09:25:00", "USR-000003", "RECEPTIONIST", "PATIENT_CHECKED_IN", "APPOINTMENT", "APT-000004", "status:SCHEDULED", "status:CHECKED_IN, token:1", "Reception-PC-01", "Patient arrived for Dr. Priya Verma"],
                ["AUD-000007", "2026-09-29 09:32:00", "USR-000001", "DOCTOR", "CONSULTATION_STARTED", "QUEUE", "TOK-000003", "queue_status:WAITING", "queue_status:IN_CONSULTATION", "Doctor-Chamber-03", "Dr. Amit Patel called patient to procedure room"]
            ]
        },
        {
            "name": "18_NOTIFICATIONS",
            "headers": ["notification_id", "patient_id", "notification_type", "recipient_contact", "scheduled_at", "sent_at", "channel", "template_name", "status", "delivery_status", "remarks", "created_at"],
            "data": [
                ["NOT-000001", "PAT-000001", "APPOINTMENT_REMINDER", "+91 9876543201", "2026-09-29 07:30:00", "2026-09-29 07:30:05", "WHATSAPP", "apt_reminder_v1", "DELIVERED", "ACK_MSG_9921", "Reminder sent 1.5h prior to appointment", "2026-09-28 18:00:00"],
                ["NOT-000002", "PAT-000002", "APPOINTMENT_REMINDER", "+91 9876543203", "2026-09-29 07:30:00", "2026-09-29 07:30:08", "SMS", "apt_reminder_v1", "DELIVERED", "DLR_TEL_8820", "SMS delivered via DLT gateway", "2026-09-28 18:00:00"],
                ["NOT-000003", "PAT-000004", "APPOINTMENT_REMINDER", "+91 9876543207", "2026-09-29 07:30:00", "2026-09-29 07:30:10", "WHATSAPP", "apt_reminder_v1", "DELIVERED", "ACK_MSG_9922", "WhatsApp reminder confirmed", "2026-09-28 18:00:00"],
                ["NOT-000004", "PAT-000001", "BILLING_RECEIPT", "+91 9876543201", "2026-09-29 09:23:00", "2026-09-29 09:23:04", "WHATSAPP", "invoice_receipt_v1", "DELIVERED", "ACK_MSG_9925", "PDF receipt link shared via WhatsApp", "2026-09-29 09:22:30"]
            ]
        },
        {
            "name": "19_REPORTING",
            "headers": ["kpi_metric_id", "metric_name", "metric_value_formula", "category", "notes"],
            "data": [
                # Row 2: Centralized dynamic business date reference
                ["KPI-000", "Active Clinic Business Date", "='01_SETTINGS'!$D$23", "SYSTEM_CONTROL", "Central operational business date for clinic reporting"],
                ["KPI-001", "Total Registered Patients", "=COUNTA('05_PATIENTS'!A:A)-1", "PATIENT_METRICS", "All registered patients in master table"],
                ["KPI-002", "Total Active Doctors", "=COUNTIF('04_DOCTORS'!L:L, \"ACTIVE\")", "DOCTOR_METRICS", "Active consulting practitioners on roster"],
                ["KPI-003", "Total Appointments Today", "=COUNTIF('06_APPOINTMENTS'!E:E, $C$2)", "APPOINTMENT_METRICS", "All appointments scheduled for business date"],
                ["KPI-004", "Scheduled Appointments Today", "=COUNTIFS('06_APPOINTMENTS'!E:E, $C$2, '06_APPOINTMENTS'!J:J, \"SCHEDULED\")", "APPOINTMENT_METRICS", "Appointments with business date and status = SCHEDULED"],
                ["KPI-005", "Checked-In Patients Today (Waiting Queue)", "=COUNTIFS('08_QUEUE'!F:F, $C$2, '08_QUEUE'!K:K, \"WAITING\")+COUNTIFS('08_QUEUE'!F:F, $C$2, '08_QUEUE'!K:K, \"CALLED\")", "QUEUE_METRICS", "Active queue tokens waiting or called to chamber today"],
                ["KPI-006", "In Consultation Now", "=COUNTIFS('08_QUEUE'!F:F, $C$2, '08_QUEUE'!K:K, \"IN_CONSULTATION\")", "QUEUE_METRICS", "Queue tokens currently inside consultation chamber"],
                ["KPI-007", "Completed Consultations Today", "=COUNTIFS('08_QUEUE'!F:F, $C$2, '08_QUEUE'!K:K, \"COMPLETED\")", "CLINICAL_METRICS", "Consultations finished on business date"],
                ["KPI-008", "Cancelled Appointments Today", "=COUNTIFS('06_APPOINTMENTS'!E:E, $C$2, '06_APPOINTMENTS'!J:J, \"CANCELLED\")", "APPOINTMENT_METRICS", "Appointments cancelled for business date"],
                ["KPI-009", "No-Show Appointments Today", "=COUNTIFS('06_APPOINTMENTS'!E:E, $C$2, '06_APPOINTMENTS'!J:J, \"NO_SHOW\")", "APPOINTMENT_METRICS", "Appointments marked no-show for business date"],
                ["KPI-010", "Today Invoiced Revenue (Gross)", "=SUMIF('10_BILLING'!E:E, $C$2, '10_BILLING'!I:I)", "FINANCIAL_METRICS", "Total invoice charges billed on business date"],
                ["KPI-011", "Today Collected Revenue (Net)", "=SUMIFS('11_PAYMENTS'!E:E, '11_PAYMENTS'!D:D, $C$2, '11_PAYMENTS'!H:H, \"COMPLETED\")", "FINANCIAL_METRICS", "Actual cash, UPI, card settlements on business date"],
                ["KPI-012", "Total Outstanding Receivables", "=SUM('10_BILLING'!K:K)", "FINANCIAL_METRICS", "Total unpaid balances across all invoices"],
                ["KPI-013", "Active Chambers in Use", "=COUNTIF('16_ROOMS'!F:F, \"OCCUPIED\")", "FACILITIES_METRICS", "Chambers currently occupied"]
            ]
        },
        {
            "name": "20_LOOKUPS",
            "headers": ["lookup_id", "category", "code", "display_name", "sort_order", "is_active", "description"],
            "data": [
                # Gender (rows 2:4)
                ["LKP-000001", "GENDER", "MALE", "Male", 1, "TRUE", "Biological or self-identified male"],
                ["LKP-000002", "GENDER", "FEMALE", "Female", 2, "TRUE", "Biological or self-identified female"],
                ["LKP-000003", "GENDER", "OTHER", "Other / Non-binary", 3, "TRUE", "Other gender identity"],

                # Appointment Status (rows 5:10)
                ["LKP-000004", "APPOINTMENT_STATUS", "SCHEDULED", "Scheduled", 1, "TRUE", "Booked for future date/time"],
                ["LKP-000005", "APPOINTMENT_STATUS", "CHECKED_IN", "Checked In", 2, "TRUE", "Patient arrived at clinic and received token"],
                ["LKP-000006", "APPOINTMENT_STATUS", "IN_CONSULTATION", "In Consultation", 3, "TRUE", "Currently inside doctor consultation chamber"],
                ["LKP-000007", "APPOINTMENT_STATUS", "COMPLETED", "Completed", 4, "TRUE", "Consultation and prescription finished"],
                ["LKP-000008", "APPOINTMENT_STATUS", "CANCELLED", "Cancelled", 5, "TRUE", "Cancelled by patient or clinic"],
                ["LKP-000009", "APPOINTMENT_STATUS", "NO_SHOW", "No Show", 6, "TRUE", "Patient did not attend scheduled slot"],

                # Appointment Type (rows 11:14)
                ["LKP-000010", "APPOINTMENT_TYPE", "NEW_CONSULTATION", "New Consultation", 1, "TRUE", "First visit for acute or new episode"],
                ["LKP-000011", "APPOINTMENT_TYPE", "FOLLOW_UP", "Follow Up", 2, "TRUE", "Review visit within follow-up window"],
                ["LKP-000012", "APPOINTMENT_TYPE", "EMERGENCY", "Emergency", 3, "TRUE", "Urgent / Priority care"],
                ["LKP-000013", "APPOINTMENT_TYPE", "ROUTINE_CHECKUP", "Routine Checkup", 4, "TRUE", "Preventive / Chronic condition review"],

                # Booking Source (rows 15:18)
                ["LKP-000014", "BOOKING_SOURCE", "WALK_IN", "Walk In", 1, "TRUE", "Patient walked in directly without prior booking"],
                ["LKP-000015", "BOOKING_SOURCE", "PHONE", "Phone Call", 2, "TRUE", "Booked over telephone with reception"],
                ["LKP-000016", "BOOKING_SOURCE", "RECEPTION", "Front Desk", 3, "TRUE", "Scheduled in advance at the reception counter"],
                ["LKP-000017", "BOOKING_SOURCE", "ONLINE", "Online Portal", 4, "TRUE", "Booked via clinic website or app"],

                # Queue Status (rows 19:24)
                ["LKP-000018", "QUEUE_STATUS", "WAITING", "Waiting in Lounge", 1, "TRUE", "Checked in, waiting for token call"],
                ["LKP-000019", "QUEUE_STATUS", "CALLED", "Called to Chamber", 2, "TRUE", "Token displayed / called by doctor"],
                ["LKP-000020", "QUEUE_STATUS", "IN_CONSULTATION", "In Consultation", 3, "TRUE", "Consultation currently underway"],
                ["LKP-000021", "QUEUE_STATUS", "COMPLETED", "Consultation Finished", 4, "TRUE", "Encounter completed"],
                ["LKP-000022", "QUEUE_STATUS", "SKIPPED", "Skipped / Absent", 5, "TRUE", "Patient not present when token called"],
                ["LKP-000023", "QUEUE_STATUS", "CANCELLED", "Queue Cancelled", 6, "TRUE", "Visit cancelled before seeing doctor"],

                # Queue Priority (rows 25:28)
                ["LKP-000024", "QUEUE_PRIORITY", "NORMAL", "Normal", 1, "TRUE", "Standard FIFO queue order"],
                ["LKP-000025", "QUEUE_PRIORITY", "URGENT", "Urgent", 2, "TRUE", "Expedited for high fever / severe acute distress"],
                ["LKP-000026", "QUEUE_PRIORITY", "VIP", "Senior / Infant Priority", 3, "TRUE", "Senior citizens, infants, pregnant mothers"],
                ["LKP-000027", "QUEUE_PRIORITY", "EMERGENCY", "Immediate Emergency", 4, "TRUE", "Immediate triage into procedure room"],

                # Consultation Status (rows 29:32)
                ["LKP-000028", "CONSULTATION_STATUS", "IN_PROGRESS", "In Progress", 1, "TRUE", "Active medical consultation"],
                ["LKP-000029", "CONSULTATION_STATUS", "COMPLETED", "Completed", 2, "TRUE", "Doctor finished consultation note and Rx"],
                ["LKP-000030", "CONSULTATION_STATUS", "CANCELLED", "Cancelled", 3, "TRUE", "Doctor aborted consultation session"],
                ["LKP-000031", "CONSULTATION_STATUS", "REFERRED", "Referred Outside", 4, "TRUE", "Referred to tertiary hospital / specialty"],

                # Payment Status (rows 33:36)
                ["LKP-000032", "PAYMENT_STATUS", "UNPAID", "Unpaid", 1, "TRUE", "Invoice generated, zero payment received"],
                ["LKP-000033", "PAYMENT_STATUS", "PARTIAL", "Partially Paid", 2, "TRUE", "Partial payment made, balance due"],
                ["LKP-000034", "PAYMENT_STATUS", "PAID", "Fully Paid", 3, "TRUE", "Paid in full, balance is zero"],
                ["LKP-000035", "PAYMENT_STATUS", "REFUNDED", "Refunded", 4, "TRUE", "Invoice payments reversed/refunded"],

                # Payment Method (rows 37:41)
                ["LKP-000036", "PAYMENT_METHOD", "CASH", "Cash", 1, "TRUE", "Physical currency notes at counter"],
                ["LKP-000037", "PAYMENT_METHOD", "UPI", "UPI (GooglePay/PhonePe/Paytm)", 2, "TRUE", "Direct Unified Payments Interface QR scan"],
                ["LKP-000038", "PAYMENT_METHOD", "CARD", "Debit / Credit Card (POS)", 3, "TRUE", "Card swipe / chip terminal"],
                ["LKP-000039", "PAYMENT_METHOD", "BANK_TRANSFER", "NEFT / IMPS Transfer", 4, "TRUE", "Direct bank account transfer"],
                ["LKP-000040", "PAYMENT_METHOD", "OTHER", "Other / Voucher", 5, "TRUE", "Health camp voucher or institutional credit"],

                # User Roles (rows 42:46)
                ["LKP-000041", "USER_ROLE", "ADMIN", "Administrator", 1, "TRUE", "Clinic owner / Super user"],
                ["LKP-000042", "USER_ROLE", "RECEPTIONIST", "Receptionist", 2, "TRUE", "Front desk reception staff"],
                ["LKP-000043", "USER_ROLE", "DOCTOR", "Doctor", 3, "TRUE", "Medical practitioner"],
                ["LKP-000044", "USER_ROLE", "BILLING", "Billing Specialist", 4, "TRUE", "Cashier and billing operator"],
                ["LKP-000045", "USER_ROLE", "MANAGER", "Clinic Manager", 5, "TRUE", "Operations and clinic manager"],

                # Patient Status (rows 47:49)
                ["LKP-000046", "PATIENT_STATUS", "ACTIVE", "Active", 1, "TRUE", "Active patient eligible for visits"],
                ["LKP-000047", "PATIENT_STATUS", "INACTIVE", "Inactive", 2, "TRUE", "No visits in 3+ years"],
                ["LKP-000048", "PATIENT_STATUS", "ARCHIVED", "Archived", 3, "TRUE", "Archived record"],

                # Doctor Status (rows 50:52)
                ["LKP-000049", "DOCTOR_STATUS", "ACTIVE", "Active", 1, "TRUE", "Available for appointments"],
                ["LKP-000050", "DOCTOR_STATUS", "ON_LEAVE", "On Leave", 2, "TRUE", "Temporarily away on leave"],
                ["LKP-000051", "DOCTOR_STATUS", "INACTIVE", "Inactive", 3, "TRUE", "No longer practicing at clinic"],

                # Service Category (rows 53:57)
                ["LKP-000052", "SERVICE_CATEGORY", "CONSULTATION", "Consultation", 1, "TRUE", "Doctor clinical visit"],
                ["LKP-000053", "SERVICE_CATEGORY", "PROCEDURE", "Minor Procedure", 2, "TRUE", "Dressing, injection, nebulization"],
                ["LKP-000054", "SERVICE_CATEGORY", "DIAGNOSTIC", "Diagnostic Test", 3, "TRUE", "ECG, point-of-care blood sugar"],
                ["LKP-000055", "SERVICE_CATEGORY", "CERTIFICATE", "Medical Certificate", 4, "TRUE", "Fitness / leave certificate"],
                ["LKP-000056", "SERVICE_CATEGORY", "OTHER", "Other Services", 5, "TRUE", "Miscellaneous hospital supplies"],

                # Room Types (rows 58:62)
                ["LKP-000057", "ROOM_TYPE", "CONSULTATION", "Consultation Chamber", 1, "TRUE", "Doctor examination chamber"],
                ["LKP-000058", "ROOM_TYPE", "EXAMINATION", "Examination Room", 2, "TRUE", "Dedicated clinical examination room"],
                ["LKP-000059", "ROOM_TYPE", "PROCEDURE", "Procedure Room / Minor OT", 3, "TRUE", "Surgical and nursing procedures"],
                ["LKP-000060", "ROOM_TYPE", "WAITING", "Waiting Lounge", 4, "TRUE", "Patient waiting area"],
                ["LKP-000061", "ROOM_TYPE", "PHARMACY", "Pharmacy / Dispensary", 5, "TRUE", "Medicine dispensing counter"],

                # Room Status (rows 63:66)
                ["LKP-000062", "ROOM_STATUS", "AVAILABLE", "Available", 1, "TRUE", "Chamber vacant and ready"],
                ["LKP-000063", "ROOM_STATUS", "OCCUPIED", "Occupied", 2, "TRUE", "Doctor / patient currently inside"],
                ["LKP-000064", "ROOM_STATUS", "MAINTENANCE", "Under Maintenance", 3, "TRUE", "Cleaning or equipment repair"],
                ["LKP-000065", "ROOM_STATUS", "RESERVED", "Reserved", 4, "TRUE", "Reserved for upcoming shift"],

                # Blood Group (rows 67:75)
                ["LKP-000066", "BLOOD_GROUP", "A+", "A Positive (A+)", 1, "TRUE", "Blood group A Rh positive"],
                ["LKP-000067", "BLOOD_GROUP", "A-", "A Negative (A-)", 2, "TRUE", "Blood group A Rh negative"],
                ["LKP-000068", "BLOOD_GROUP", "B+", "B Positive (B+)", 3, "TRUE", "Blood group B Rh positive"],
                ["LKP-000069", "BLOOD_GROUP", "B-", "B Negative (B-)", 4, "TRUE", "Blood group B Rh negative"],
                ["LKP-000070", "BLOOD_GROUP", "AB+", "AB Positive (AB+)", 5, "TRUE", "Blood group AB Rh positive"],
                ["LKP-000071", "BLOOD_GROUP", "AB-", "AB Negative (AB-)", 6, "TRUE", "Blood group AB Rh negative"],
                ["LKP-000072", "BLOOD_GROUP", "O+", "O Positive (O+)", 7, "TRUE", "Blood group O Rh positive"],
                ["LKP-000073", "BLOOD_GROUP", "O-", "O Negative (O-)", 8, "TRUE", "Blood group O Rh negative"],
                ["LKP-000074", "BLOOD_GROUP", "UNKNOWN", "Unknown / Not Tested", 9, "TRUE", "Blood group not yet determined"],

                # Prescription Frequency (rows 76:80)
                ["LKP-000075", "RX_FREQUENCY", "ONCE_DAILY", "Once a Day (OD / 1-0-0)", 1, "TRUE", "Single dose per day"],
                ["LKP-000076", "RX_FREQUENCY", "TWICE_DAILY", "Twice a Day (BD / 1-0-1)", 2, "TRUE", "Morning and evening doses"],
                ["LKP-000077", "RX_FREQUENCY", "THRICE_DAILY", "Thrice a Day (TDS / 1-1-1)", 3, "TRUE", "Three doses spaced equally"],
                ["LKP-000078", "RX_FREQUENCY", "FOUR_TIMES_DAILY", "Four Times a Day (QDS / 1-1-1-1)", 4, "TRUE", "Four doses per day"],
                ["LKP-000079", "RX_FREQUENCY", "AS_NEEDED", "As Needed (SOS / PRN)", 5, "TRUE", "Take only when required for symptoms"],

                # Prescription Route (rows 81:85)
                ["LKP-000080", "RX_ROUTE", "ORAL", "Oral (By Mouth)", 1, "TRUE", "Tablets, capsules, syrups swallowed"],
                ["LKP-000081", "RX_ROUTE", "TOPICAL", "Topical (External)", 2, "TRUE", "Ointments, gels, creams applied to skin"],
                ["LKP-000082", "RX_ROUTE", "INHALATION", "Inhalation", 3, "TRUE", "Nebulizer, metered dose inhaler"],
                ["LKP-000083", "RX_ROUTE", "INJECTION", "Injection (IM/IV/SC)", 4, "TRUE", "Parenteral injectable administration"],
                ["LKP-000084", "RX_ROUTE", "DROPS", "Drops (Eye/Ear/Nasal)", 5, "TRUE", "Instilled drops into eye, ear, or nose"],

                # Follow-up Status (rows 86:89)
                ["LKP-000085", "FOLLOWUP_STATUS", "SCHEDULED", "Scheduled", 1, "TRUE", "Future review date booked"],
                ["LKP-000086", "FOLLOWUP_STATUS", "COMPLETED", "Completed", 2, "TRUE", "Patient attended follow-up consultation"],
                ["LKP-000087", "FOLLOWUP_STATUS", "CANCELLED", "Cancelled", 3, "TRUE", "Follow-up cancelled by clinician"],
                ["LKP-000088", "FOLLOWUP_STATUS", "MISSED", "Missed / Overdue", 4, "TRUE", "Due date passed without patient visit"],

                # Notification Channels (rows 90:92)
                ["LKP-000089", "NOTIFICATION_CHANNEL", "WHATSAPP", "WhatsApp Message", 1, "TRUE", "Official WhatsApp Business API"],
                ["LKP-000090", "NOTIFICATION_CHANNEL", "SMS", "SMS Text Message", 2, "TRUE", "Telecom DLT compliant SMS gateway"],
                ["LKP-000091", "NOTIFICATION_CHANNEL", "EMAIL", "Email", 3, "TRUE", "Electronic mail notification"],

                # Days of Week (rows 93:99)
                ["LKP-000092", "DAY_OF_WEEK", "MONDAY", "Monday", 1, "TRUE", "Standard weekly day"],
                ["LKP-000093", "DAY_OF_WEEK", "TUESDAY", "Tuesday", 2, "TRUE", "Standard weekly day"],
                ["LKP-000094", "DAY_OF_WEEK", "WEDNESDAY", "Wednesday", 3, "TRUE", "Standard weekly day"],
                ["LKP-000095", "DAY_OF_WEEK", "THURSDAY", "Thursday", 4, "TRUE", "Standard weekly day"],
                ["LKP-000096", "DAY_OF_WEEK", "FRIDAY", "Friday", 5, "TRUE", "Standard weekly day"],
                ["LKP-000097", "DAY_OF_WEEK", "SATURDAY", "Saturday", 6, "TRUE", "Standard weekly day"],
                ["LKP-000098", "DAY_OF_WEEK", "SUNDAY", "Sunday", 7, "TRUE", "Standard weekly day"],

                # Consent Status (rows 100:102)
                ["LKP-000099", "CONSENT_STATUS", "GRANTED", "Consent Granted", 1, "TRUE", "Explicit patient privacy consent given"],
                ["LKP-000100", "CONSENT_STATUS", "WITHDRAWN", "Consent Withdrawn", 2, "TRUE", "Patient opted out of communications"],
                ["LKP-000101", "CONSENT_STATUS", "PENDING", "Consent Pending", 3, "TRUE", "Awaiting patient authorization"],

                # Boolean (rows 103:104)
                ["LKP-000102", "BOOLEAN", "TRUE", "True / Yes", 1, "TRUE", "Boolean truth flag"],
                ["LKP-000103", "BOOLEAN", "FALSE", "False / No", 2, "TRUE", "Boolean false flag"]
            ]
        }
    ]

    # Populate Workbook
    for s_def in sheets_def:
        ws = wb.create_sheet(title=s_def["name"])
        headers = s_def["headers"]

        # 1. Header row
        ws.append(headers)
        ws.row_dimensions[1].height = 28

        for col_idx, header in enumerate(headers, start=1):
            cell = ws.cell(row=1, column=col_idx)
            cell.font = font_header
            cell.fill = fill_header
            cell.alignment = align_header
            cell.border = header_border

        # 2. Data rows
        for r_idx, row_data in enumerate(s_def["data"], start=2):
            ws.append(row_data)
            ws.row_dimensions[r_idx].height = 22
            for col_idx, val in enumerate(row_data, start=1):
                cell = ws.cell(row=r_idx, column=col_idx)
                cell.font = font_data
                cell.border = thin_border

                header_name = headers[col_idx - 1]
                if "id" in header_name or "code" in header_name or "status" in header_name or "date" in header_name or "time" in header_name:
                    cell.alignment = align_center
                elif isinstance(val, (int, float)) or "fee" in header_name or "amount" in header_name or "subtotal" in header_name or "tax" in header_name or "discount" in header_name:
                    cell.alignment = align_right
                    if isinstance(val, (int, float)) or (isinstance(val, str) and val.startswith("=")):
                        if "amount" in header_name or "fee" in header_name or "subtotal" in header_name or "discount" in header_name or "tax" in header_name or "revenue" in header_name:
                            cell.number_format = '₹#,##0.00'
                else:
                    cell.alignment = align_left

        # 3. Dynamic Column Auto-sizing
        for col in ws.columns:
            max_len = 0
            col_letter = get_column_letter(col[0].column)
            for cell in col:
                val_str = str(cell.value or '')
                if val_str.startswith('='):
                    val_str = "Formula_Calculated"
                max_len = max(max_len, len(val_str))
            ws.column_dimensions[col_letter].width = max(max_len + 4, 12)

        # 4. Freeze header row
        ws.freeze_panes = "A2"

    # Define Named Ranges for Centralized Lookups (Point to 20_LOOKUPS column C)
    lookup_ranges = {
        "LK_GENDER": "'20_LOOKUPS'!$C$2:$C$4",
        "LK_APPOINTMENT_STATUS": "'20_LOOKUPS'!$C$5:$C$10",
        "LK_APPOINTMENT_TYPE": "'20_LOOKUPS'!$C$11:$C$14",
        "LK_BOOKING_SOURCE": "'20_LOOKUPS'!$C$15:$C$18",
        "LK_QUEUE_STATUS": "'20_LOOKUPS'!$C$19:$C$24",
        "LK_QUEUE_PRIORITY": "'20_LOOKUPS'!$C$25:$C$28",
        "LK_CONSULTATION_STATUS": "'20_LOOKUPS'!$C$29:$C$32",
        "LK_PAYMENT_STATUS": "'20_LOOKUPS'!$C$33:$C$36",
        "LK_PAYMENT_METHOD": "'20_LOOKUPS'!$C$37:$C$41",
        "LK_USER_ROLE": "'20_LOOKUPS'!$C$42:$C$46",
        "LK_PATIENT_STATUS": "'20_LOOKUPS'!$C$47:$C$49",
        "LK_DOCTOR_STATUS": "'20_LOOKUPS'!$C$50:$C$52",
        "LK_SERVICE_CATEGORY": "'20_LOOKUPS'!$C$53:$C$57",
        "LK_ROOM_TYPE": "'20_LOOKUPS'!$C$58:$C$62",
        "LK_ROOM_STATUS": "'20_LOOKUPS'!$C$63:$C$66",
        "LK_BLOOD_GROUP": "'20_LOOKUPS'!$C$67:$C$75",
        "LK_RX_FREQUENCY": "'20_LOOKUPS'!$C$76:$C$80",
        "LK_RX_ROUTE": "'20_LOOKUPS'!$C$81:$C$85",
        "LK_FOLLOWUP_STATUS": "'20_LOOKUPS'!$C$86:$C$89",
        "LK_NOTIFICATION_CHANNEL": "'20_LOOKUPS'!$C$90:$C$92",
        "LK_DAYS_OF_WEEK": "'20_LOOKUPS'!$C$93:$C$99",
        "LK_CONSENT_STATUS": "'20_LOOKUPS'!$C$100:$C$102",
        "LK_BOOLEAN": "'20_LOOKUPS'!$C$103:$C$104"
    }

    for name, cell_range in lookup_ranges.items():
        defn = DefinedName(name, attr_text=cell_range)
        wb.defined_names[name] = defn

    # Helper function to add Data Validation using Named Ranges across 5,000 rows (Scalability)
    def add_named_validation(ws, col_letter, named_range, start_row=2, end_row=5000):
        dv = DataValidation(type="list", formula1=f"={named_range}", allow_blank=True)
        dv.error = f"Value not in allowed lookup list ({named_range})"
        dv.errorTitle = "Invalid Controlled Value"
        dv.prompt = f"Please select from {named_range}"
        dv.promptTitle = "Select Controlled Value"
        ws.add_data_validation(dv)
        dv.add(f"{col_letter}{start_row}:{col_letter}{end_row}")

    # Bind Data Validations to Centralized Lookups
    ws_pat = wb["05_PATIENTS"]
    add_named_validation(ws_pat, "I", "LK_GENDER")
    add_named_validation(ws_pat, "S", "LK_BLOOD_GROUP")
    add_named_validation(ws_pat, "U", "LK_PATIENT_STATUS")
    add_named_validation(ws_pat, "V", "LK_CONSENT_STATUS")

    ws_apt = wb["06_APPOINTMENTS"]
    add_named_validation(ws_apt, "H", "LK_APPOINTMENT_TYPE")
    add_named_validation(ws_apt, "I", "LK_BOOKING_SOURCE")
    add_named_validation(ws_apt, "J", "LK_APPOINTMENT_STATUS")
    add_named_validation(ws_apt, "O", "LK_BOOLEAN")

    ws_sch = wb["07_DOCTOR_SCHEDULES"]
    add_named_validation(ws_sch, "C", "LK_DAYS_OF_WEEK")
    add_named_validation(ws_sch, "K", "LK_DOCTOR_STATUS")

    ws_que = wb["08_QUEUE"]
    add_named_validation(ws_que, "K", "LK_QUEUE_STATUS")
    add_named_validation(ws_que, "L", "LK_QUEUE_PRIORITY")

    ws_con = wb["09_CONSULTATIONS"]
    add_named_validation(ws_con, "I", "LK_BOOLEAN")
    add_named_validation(ws_con, "K", "LK_CONSULTATION_STATUS")

    ws_bil = wb["10_BILLING"]
    add_named_validation(ws_bil, "L", "LK_PAYMENT_STATUS")

    ws_pay = wb["11_PAYMENTS"]
    add_named_validation(ws_pay, "F", "LK_PAYMENT_METHOD")
    add_named_validation(ws_pay, "H", "LK_PAYMENT_STATUS")

    ws_srv = wb["12_SERVICES"]
    add_named_validation(ws_srv, "D", "LK_SERVICE_CATEGORY")
    add_named_validation(ws_srv, "H", "LK_PATIENT_STATUS")

    ws_rx = wb["14_PRESCRIPTIONS"]
    add_named_validation(ws_rx, "F", "LK_RX_FREQUENCY")
    add_named_validation(ws_rx, "H", "LK_RX_ROUTE")

    ws_fol = wb["15_FOLLOW_UPS"]
    add_named_validation(ws_fol, "F", "LK_FOLLOWUP_STATUS")
    add_named_validation(ws_fol, "G", "LK_BOOLEAN")

    ws_rm = wb["16_ROOMS"]
    add_named_validation(ws_rm, "D", "LK_ROOM_TYPE")
    add_named_validation(ws_rm, "F", "LK_ROOM_STATUS")

    ws_not = wb["18_NOTIFICATIONS"]
    add_named_validation(ws_not, "G", "LK_NOTIFICATION_CHANNEL")
    add_named_validation(ws_not, "I", "LK_FOLLOWUP_STATUS")

    # Save to APNA_CLINIC_MASTER_SHEET_TEMPLATE_FINAL.xlsx
    wb.save(output_path)
    print(f"[SUCCESS] Generated Final Master Sheet: {output_path}")

if __name__ == "__main__":
    generate_final_master_sheet()
