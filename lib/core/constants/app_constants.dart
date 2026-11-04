class AppConstants {
  // Brand & Identifiers
  static const String appName = 'Apna Clinic';
  static const String appTagline =
      'Simplicity, Offline Resilience, Privacy-First Clinic Administration';
  static const String defaultTimezone = 'Asia/Kolkata';
  static const String currencySymbol = '₹';
  static const String currencyCode = 'INR';

  // Indian Date Format
  static const String dateFormat = 'dd/MM/yyyy';
  static const String dateTimeFormat = 'dd/MM/yyyy hh:mm a';

  // Paper Sizes
  static const String paperSizeA5 = 'A5';
  static const String paperSizeA4 = 'A4';

  // Mandatory Clinical Boundary Label
  static const String reasonForVisitLabel = 'Patient-reported reason for visit';
  static const String clinicalDisclaimer =
      'Administrative system only. Clinical notes and prescriptions are handwritten by the doctor on the physical slip. No treatment advice or prescriptions are digitally generated.';

  // Google Drive & Sheets Architecture
  static const String driveRootFolder = 'Apna Clinic';
  static const String masterWorkbookPrefix = 'ApnaClinic_Master_v1';
  static const String backupManifestFilename = 'backup_manifest.json';

  // Canonical Google Sheets Tab Names
  static const String tabClinicConfig = 'Clinic_Config';
  static const String tabDoctors = 'Doctors';
  static const String tabStaff = 'Staff';
  static const String tabPatients = 'Patients';
  static const String tabAppointments = 'Appointments';
  static const String tabVisits = 'Visits';
  static const String tabTokenCounters = 'Token_Counters';
  static const String tabQueueEvents = 'Queue_Events';
  static const String tabFeeCatalog = 'Fee_Catalog';
  static const String tabInvoices = 'Invoices';
  static const String tabInvoiceItems = 'Invoice_Items';
  static const String tabPayments = 'Payments';
  static const String tabRefunds = 'Refunds';
  static const String tabExpenses = 'Expenses';
  static const String tabFollowups = 'Followups';
  static const String tabConsentLog = 'Consent_Log';
  static const String tabAuditEvents = 'Audit_Events';
  static const String tabSyncManifest = 'Sync_Manifest';
  static const String tabDailySummary = 'Daily_Summary';
  static const String tabLookupConfig = 'Lookup_Config';

  // Performance Limits & Benchmarks
  static const int maxBatchSyncEvents = 100;
  static const int targetSearchLatencyMs = 300;
  static const int targetSaveLatencyMs = 500;
  static const int targetPdfGenLatencyMs = 3000;
}
