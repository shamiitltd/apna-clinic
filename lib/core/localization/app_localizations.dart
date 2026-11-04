import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en', ''),
    Locale('hi', ''),
  ];

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'Apna Clinic',
      'nav_dashboard': 'Dashboard',
      'nav_appointments': 'Appointments',
      'nav_patients': 'Patients',
      'nav_queue': 'Queue',
      'nav_doctor': 'Doctor Desk',
      'nav_billing': 'Billing',
      'nav_reports': 'Reports',
      'nav_settings': 'Settings',
      'btn_new_patient': 'New Patient',
      'btn_new_visit': 'New Visit',
      'btn_new_appointment': 'New Appointment',
      'btn_print_slip': 'Print Slip',
      'btn_collect_payment': 'Collect Payment',
      'btn_save': 'Save',
      'btn_cancel': 'Cancel',
      'label_token': 'Token',
      'label_doctor': 'Doctor',
      'label_patient': 'Patient',
      'label_reason_for_visit': 'Patient-reported reason for visit',
      'label_fee': 'Consultation Fee',
      'status_scheduled': 'Scheduled',
      'status_waiting': 'Waiting',
      'status_called': 'Called',
      'status_in_consultation': 'In Consultation',
      'status_completed': 'Completed',
      'status_cancelled': 'Cancelled',
      'status_no_show': 'No Show',
      'status_online': 'Online',
      'status_offline': 'Offline Mode',
      'status_syncing': 'Syncing...',
      'doctor_notes': "Doctor's Notes",
      'medicines_prescription': 'Medicines / Prescription',
      'advice_followup': 'Advice / Follow-up',
      'signature': 'Signature',
    },
    'hi': {
      'app_title': 'अपना क्लिनिक',
      'nav_dashboard': 'डैशबोर्ड',
      'nav_appointments': 'अपॉइंटमेंट',
      'nav_patients': 'मरीज़',
      'nav_queue': 'कतार',
      'nav_doctor': 'डॉक्टर डेस्क',
      'nav_billing': 'बिलिंग',
      'nav_reports': 'रिपोर्ट',
      'nav_settings': 'सेटिंग्स',
      'btn_new_patient': 'नया मरीज़',
      'btn_new_visit': 'नयी विज़िट',
      'btn_new_appointment': 'नया अपॉइंटमेंट',
      'btn_print_slip': 'पर्ची प्रिंट करें',
      'btn_collect_payment': 'शुल्क प्राप्त करें',
      'btn_save': 'सुरक्षित करें',
      'btn_cancel': 'रद्द करें',
      'label_token': 'टोकन',
      'label_doctor': 'डॉक्टर',
      'label_patient': 'मरीज़',
      'label_reason_for_visit': 'मरीज़ द्वारा बताया गया कारण',
      'label_fee': 'परामर्श शुल्क',
      'status_waiting': 'प्रतीक्षारत',
      'status_called': 'बुलाया गया',
      'status_in_consultation': 'परामर्श जारी',
      'status_completed': 'संपन्न',
      'status_cancelled': 'रद्द',
      'status_no_show': 'अनुपस्थित',
      'status_online': 'ऑनलाइन',
      'status_offline': 'ऑफ़लाइन मोड',
      'status_syncing': 'सिंक हो रहा है...',
      'doctor_notes': 'डॉक्टर के नोट्स',
      'medicines_prescription': 'दवाएं / पर्चा',
      'advice_followup': 'सलाह / पुनः परामर्श',
      'signature': 'हस्ताक्षर',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'hi'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
