// Apna Clinic - Centralized Official Website & SaaS Platform Configuration
// Primary source of truth: Official Website Architecture Plan
// Avoids duplicated hardcoded values across UI screens and components.

class PricingPlanFeature {
  final String title;
  final bool included;

  const PricingPlanFeature(this.title, {this.included = true});
}

class PricingPlan {
  final String id;
  final String name;
  final String targetAudience;
  final String description;
  final String priceDisplay;
  final String billingPeriod;
  final String? badge;
  final bool isPopular;
  final List<PricingPlanFeature> features;
  final String ctaLabel;
  final String ctaRoute;

  const PricingPlan({
    required this.id,
    required this.name,
    required this.targetAudience,
    required this.description,
    required this.priceDisplay,
    this.billingPeriod = '',
    this.badge,
    this.isPopular = false,
    required this.features,
    required this.ctaLabel,
    required this.ctaRoute,
  });

  String get price => priceDisplay;
  String get cta => ctaLabel;
}

class FaqItem {
  final String question;
  final String answer;
  const FaqItem(this.question, this.answer);
}

class WebsiteConfig {
  static const String productName = 'Apna Clinic';
  static const String companyName = 'SHAMIIT LLP';
  static const String productTagline =
      'Simple Clinic Management. Smarter Daily Operations.';
  static const String tagline = productTagline;
  static const String productHeadline = 'Manage Your Clinic. Simply.';
  static const String productDescription =
      'Apna Clinic helps doctors and clinics manage patients, appointments, queues, consultation billing, payments, receipts and daily operations from one simple platform.';

  static const String websiteUrl = 'https://apnaclinic.in';
  static const String defaultAppRoute = '/app';
  static const String supportEmail = 'support@apnaclinic.in';
  static const String salesEmail = 'sales@apnaclinic.in';
  static const String contactPhone = '+91 98765 43210';
  static const String companyAddress = 'SHAMIIT LLP, India';

  // Navigation Links
  static const List<Map<String, String>> navLinks = [
    {'label': 'Home', 'route': '/'},
    {'label': 'Features', 'route': '/features'},
    {'label': 'How It Works', 'route': '/how-it-works'},
    {'label': 'Pricing', 'route': '/pricing'},
    {'label': 'About', 'route': '/about'},
    {'label': 'Contact', 'route': '/contact'},
  ];

  // Official Centralized Pricing Plans
  // Note: Pricing is driven strictly from this configuration.
  static const List<PricingPlan> pricingPlans = [
    PricingPlan(
      id: 'starter',
      name: 'Starter Practice',
      targetAudience: 'For Independent Doctors & OPD Cabins',
      description:
          'Essential patient registration, daily token generation, and cabin consultation slips for solo practitioners.',
      priceDisplay: 'Contact for Pricing',
      billingPeriod: 'per clinic / month',
      badge: 'SOLO DOCTORS',
      isPopular: false,
      features: [
        PricingPlanFeature('Fast Patient Registration & Lookup'),
        PricingPlanFeature('Doctor Workstation & Live Queue Counter'),
        PricingPlanFeature('Daily Monotonic Token Allocation'),
        PricingPlanFeature('A4 & A5 Consultation Slip Printing'),
        PricingPlanFeature('Offline-Friendly Operational Mode'),
        PricingPlanFeature('Google Drive Cloud Backup Support'),
        PricingPlanFeature('Billing & GST Receipts', included: false),
        PricingPlanFeature('Multi-Staff Role Separation', included: false),
      ],
      ctaLabel: 'Get Started Free',
      ctaRoute: '/register',
    ),
    PricingPlan(
      id: 'professional',
      name: 'Professional Clinic',
      targetAudience: 'For Small OPD Clinics & Growing Practices',
      description:
          'Full-featured clinic administration with itemized billing, cash/UPI reconciliation, and automated Google Drive synchronization.',
      priceDisplay: 'Contact for Pricing',
      billingPeriod: 'per clinic / month',
      badge: 'RECOMMENDED',
      isPopular: true,
      features: [
        PricingPlanFeature('Everything in Starter Practice'),
        PricingPlanFeature('Itemized Billing & Sequential Invoices'),
        PricingPlanFeature('Split Cash & UPI Payment Recording'),
        PricingPlanFeature('Daily Cash Reconciliation & Day-Close'),
        PricingPlanFeature('Bi-directional Google Sheets Cloud Sync'),
        PricingPlanFeature('Multi-Role Access (Reception, Doctor, Cashier)'),
        PricingPlanFeature('Daily Clinic Revenue & Visit Reports'),
        PricingPlanFeature('Priority Technical Support'),
      ],
      ctaLabel: 'Start 30-Day Evaluation',
      ctaRoute: '/register',
    ),
    PricingPlan(
      id: 'practice_group',
      name: 'Clinic Group / Multi-Doctor',
      targetAudience: 'For Polyclinics & Healthcare Centers',
      description:
          'Advanced multi-doctor scheduling, distinct specialist queues, custom branding headers, and comprehensive financial audits.',
      priceDisplay: 'Custom Plan',
      billingPeriod: 'custom deployment',
      badge: 'MULTI-DOCTOR',
      isPopular: false,
      features: [
        PricingPlanFeature('Everything in Professional Clinic'),
        PricingPlanFeature('Multi-Doctor Scheduling & Rosters'),
        PricingPlanFeature('Distinct Cabin Queues & Token Scopes'),
        PricingPlanFeature('Custom Clinic Header & Slip Design'),
        PricingPlanFeature('End-of-Day Financial Ledger Verification'),
        PricingPlanFeature('Automated Encrypted Disaster Recovery'),
        PricingPlanFeature('Dedicated Onboarding Assistance'),
      ],
      ctaLabel: 'Contact Sales',
      ctaRoute: '/contact',
    ),
  ];

  // Frequently Asked Questions
  static const List<Map<String, String>> faqs = [
    {
      'question': 'What is Apna Clinic?',
      'answer':
          'Apna Clinic is a simple, modern clinic management application developed by SHAMIIT LLP. It is designed specifically for outpatient (OPD) doctors and clinics to manage patient registration, queue tokens, appointments, consultation billing, and daily cash reconciliation without heavyweight hospital ERP complexity.',
    },
    {
      'question': 'Who can use Apna Clinic?',
      'answer':
          'It is built for individual doctors, general physicians, pediatricians, dentists, specialist OPD clinics, and small multi-doctor polyclinics seeking fast, dependable day-to-day administration.',
    },
    {
      'question': 'Where is my clinic data stored?',
      'answer':
          'Your operational records (patients, visits, invoices, and summaries) are stored on your local workstation and synchronized to your own private Google Drive and Google Sheets. SHAMIIT does not hold your patients\' medical data on its servers.',
    },
    {
      'question': 'Why does Apna Clinic connect to Google Drive?',
      'answer':
          'By connecting your Google Drive, you retain complete ownership of your clinic records in familiar, accessible Google Sheets and encrypted backup files. There is zero vendor lock-in.',
    },
    {
      'question': 'Can I use Apna Clinic if internet connectivity is unstable?',
      'answer':
          'Yes. Apna Clinic is built with an offline-first transactional engine. Patient registration, token calling, and billing work continuously even when disconnected. Changes are stored in a local Sync Outbox and automatically sync to your Google Drive when connectivity is restored.',
    },
    {
      'question': 'Is Apna Clinic a hospital ERP?',
      'answer':
          'No. Apna Clinic is specifically tailored for outpatient clinics and doctor practices. It intentionally avoids unnecessary hospital bed management, complex ward hierarchies, and pharmacy warehousing to keep your daily clinic operations fast and effortless.',
    },
    {
      'question': 'Can I print consultation slips and billing receipts?',
      'answer':
          'Yes. Apna Clinic supports vector PDF printing for both A4 and A5 formats with your clinic branding, doctor registration details, patient demographics, and token numbers.',
    },
    {
      'question': 'How do I create an account and get started?',
      'answer':
          'Click "Create Account" on this website, sign in with your Google account or email, connect your clinic\'s Google Drive, configure your primary doctor and consultation fee, and you are ready to manage your clinic in minutes.',
    },
    {
      'question': 'Can multiple staff members use different roles?',
      'answer':
          'Yes. Apna Clinic supports role-based access for Clinic Owners, Receptionists, Doctors, and Accountants with appropriate clinical privacy isolation.',
    },
  ];

  static const List<FaqItem> faqList = [
    FaqItem(
      'What is Apna Clinic?',
      'Apna Clinic is a simple, modern clinic management application developed by SHAMIIT LLP. It is designed specifically for outpatient (OPD) doctors and clinics to manage patient registration, queue tokens, appointments, consultation billing, and daily cash reconciliation without heavyweight hospital ERP complexity.',
    ),
    FaqItem(
      'Who can use Apna Clinic?',
      'It is built for individual doctors, general physicians, pediatricians, dentists, specialist OPD clinics, and small multi-doctor polyclinics seeking fast, dependable day-to-day administration.',
    ),
    FaqItem(
      'Can I manage patients?',
      'Yes. Apna Clinic supports fast 30-second patient registration, phone-based lookup, duplicate detection, and returning patient visit history.',
    ),
    FaqItem(
      'Can I manage appointments?',
      'Yes. Interactive calendar scheduling with doctor selection, time-slot management, double-booking prevention, and instant check-in converting to queue tokens.',
    ),
    FaqItem(
      'Does Apna Clinic support billing?',
      'Yes. Itemized consultation and procedure billing, sequential invoice numbers, and multi-mode split payments (Cash, UPI, Card).',
    ),
    FaqItem(
      'Can I print consultation slips?',
      'Yes. Clean A4 and A5 printable slips featuring your clinic branding, doctor registration details, and patient token numbers.',
    ),
    FaqItem(
      'Can I print receipts?',
      'Yes. Itemized receipts suitable for thermal POS receipt printers (58mm/80mm) as well as standard desktop printers.',
    ),
    FaqItem(
      'Where is my clinic data stored?',
      'Your operational records (patients, visits, invoices, and summaries) are stored on your local workstation and synchronized directly to your own private Google Drive and Google Sheets.',
    ),
    FaqItem(
      'Why does Apna Clinic connect to Google Drive?',
      'By connecting your Google Drive, you retain complete ownership of your clinic records in familiar, accessible Google Sheets with zero vendor lock-in.',
    ),
    FaqItem(
      'Can I use Apna Clinic if internet connectivity is unstable?',
      'Yes. Apna Clinic is built with an offline-first transactional engine. Registration, queue progression, and billing work continuously even when disconnected, syncing when connection restores.',
    ),
    FaqItem(
      'Is Apna Clinic a hospital ERP?',
      'No. Apna Clinic is specifically tailored for outpatient clinics and doctor practices. It intentionally avoids unnecessary hospital bed management and complex ward hierarchies to keep operations fast and effortless.',
    ),
    FaqItem(
      'How do I create an account?',
      'Click "Create Account" on this website, sign in with your Google account or email, connect your clinic\'s Google Drive, configure your primary doctor and consultation fee, and you are ready to manage your clinic in minutes.',
    ),
    FaqItem(
      'How do I connect Google Drive?',
      'From the setup screen or account portal, authorize your clinic\'s Google account using standard OAuth. The application initializes your dedicated folder and structured sheets automatically.',
    ),
    FaqItem(
      'Can multiple staff roles use the system?',
      'Yes. Apna Clinic supports role-based access for Clinic Owners, Receptionists, Doctors, and Accountants with appropriate clinical privacy isolation.',
    ),
    FaqItem(
      'How can I contact support?',
      'Our support team is available via our official contact form, support center, or by emailing support@apnaclinic.in with 24-48 business hour response times.',
    ),
  ];
}
