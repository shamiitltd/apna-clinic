// Apna Clinic - Website & Account System Automated Tests
// Verifies marketing landing page, public routes, authentication flows, Firestore persistence, and account guards.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:apna_clinic/main.dart';
import 'package:apna_clinic/core/routing/app_router.dart';
import 'package:apna_clinic/core/config/website_config.dart';
import 'package:apna_clinic/application/providers.dart';
import 'package:apna_clinic/infrastructure/auth/mock_auth_repository.dart';
import 'package:apna_clinic/infrastructure/database/local_database.dart';
import 'package:apna_clinic/infrastructure/database/storage_adapter.dart';
import 'package:apna_clinic/presentation/website/home/website_home_screen.dart';
import 'package:apna_clinic/presentation/website/pages/features_page.dart';
import 'package:apna_clinic/presentation/website/pages/pricing_page.dart';
import 'package:apna_clinic/presentation/website/pages/contact_page.dart';
import 'package:apna_clinic/presentation/website/account/register_screen.dart';
import 'package:apna_clinic/presentation/auth/login_screen.dart';
import 'package:apna_clinic/presentation/website/account/account_dashboard_screen.dart';
import 'package:apna_clinic/presentation/dashboard/dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthRepository mockAuth;
  late LocalDatabase memoryDb;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    isClinicConfiguredOverride = () => true;
    appAccessStatusOverride = null;

    mockAuth = MockAuthRepository();
    memoryDb = LocalDatabase(MemoryStorageAdapter());
    await memoryDb.initialize();
  });

  tearDown(() {
    isClinicConfiguredOverride = null;
    appAccessStatusOverride = null;
  });

  Widget createTestWidget({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuth),
        localDatabaseProvider.overrideWithValue(memoryDb),
        ...overrides,
      ],
      child: const ApnaClinicApp(),
    );
  }

  group('APNA CLINIC — WEBSITE & LANDING PAGE TESTS', () {
    testWidgets('1. Official Homepage loads with 19 required sections, headline, and CTAs', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      appRouter.go('/');
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify Homepage and Navbar
      expect(find.byType(WebsiteHomeScreen), findsOneWidget);
      expect(find.text(WebsiteConfig.productName), findsWidgets);
      expect(find.text('Manage Your Clinic. Simply.'), findsOneWidget);
      expect(find.text('Start with Apna Clinic'), findsOneWidget);
      expect(find.text('Explore Features'), findsOneWidget);

      // Verify Value Strip
      expect(find.text('Fast Patient Registration'), findsWidgets);
      expect(find.text('Smart Queue Management'), findsWidgets);
      expect(find.text('Google Drive Data Ownership'), findsWidgets);

      // Verify Problem Section
      expect(
        find.text('Running a Clinic Shouldn\'t Mean Managing Paperwork All Day'),
        findsOneWidget,
      );

      // Verify Pricing Section headline
      expect(find.text('Simple Pricing for Every Clinic'), findsOneWidget);

      // Verify FAQ headline
      expect(find.text('Got Questions? We Have Answers.'), findsOneWidget);
    });

    testWidgets('2. Public routes navigate and display without auth barriers', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Navigate to /features
      appRouter.go('/features');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(FeaturesPage), findsOneWidget);
      expect(find.text('Comprehensive Clinic Features'), findsOneWidget);

      // Navigate to /pricing
      appRouter.go('/pricing');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PricingPage), findsOneWidget);
      expect(find.text('Simple, Fair & Predictable Plans'), findsOneWidget);

      // Navigate to /contact
      appRouter.go('/contact');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ContactPage), findsOneWidget);
      expect(find.text('Get in Touch with Our Team'), findsOneWidget);
    });

    testWidgets('3. Contact Form validates inputs and persists inquiry to backend', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      appRouter.go('/contact');
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ContactPage), findsOneWidget);

      // Enter valid contact details
      final nameFinder = find.widgetWithText(TextFormField, 'Full Name *');
      final emailFinder = find.widgetWithText(TextFormField, 'Email Address *');
      final msgFinder = find.widgetWithText(TextFormField, 'Message / Details *');

      await tester.enterText(nameFinder, 'Dr. Rajesh Verma');
      await tester.enterText(emailFinder, 'dr.verma@cityclinic.in');
      await tester.enterText(msgFinder, 'Interested in polyclinic license for 4 doctors.');
      await tester.pump();

      // Submit form
      final submitFinder = find.widgetWithText(ElevatedButton, 'Send Inquiry');
      await tester.tap(submitFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify success UI
      expect(find.text('Thank You! Message Received'), findsOneWidget);
      expect(mockAuth.submittedInquiries.length, 1);
      expect(mockAuth.submittedInquiries.first['name'], 'Dr. Rajesh Verma');
      expect(mockAuth.submittedInquiries.first['email'], 'dr.verma@cityclinic.in');
    });

    testWidgets('4. Registration portal renders Google & Email signup options', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      appRouter.go('/register');
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.text('Create Your Apna Clinic Account'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Register with Email & Password'), findsOneWidget);
    });

    testWidgets('5. Unauthenticated user accessing /account is guarded and redirected to /login', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      mockAuth.clearMockUser();

      appRouter.go('/account');
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Must be redirected to LoginScreen
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('6. Authenticated user can access /account and click "Open Apna Clinic" to launch dashboard', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Seed authenticated platform user with connected Drive & configured clinic
      await mockAuth.registerWithGoogle(
        organizationName: 'City Care Clinic',
        phone: '+91 9876543210',
      );
      await mockAuth.updateDriveConnectionMetadata(
        uid: mockAuth.currentUid!,
        driveEmail: 'doctor@gmail.com',
        driveFolderId: 'mock_folder_123',
        spreadsheetId: 'mock_sheet_123',
      );
      await mockAuth.updateClinicSetupStatus(
        uid: mockAuth.currentUid!,
        completed: true,
      );

      appRouter.go('/account');
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AccountDashboardScreen), findsOneWidget);
      expect(find.text('Open Apna Clinic'), findsWidgets);
      expect(find.text('Product Access & Subscription'), findsOneWidget);

      // Tap "Open Apna Clinic"
      final openBtn = find.widgetWithText(ElevatedButton, 'Open Apna Clinic');
      await tester.tap(openBtn.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Should land on clinical DashboardScreen
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.text("Today's Patient Queue Overview"), findsOneWidget);
    });

    testWidgets('7. Login screen automatically redirects to /dashboard upon successful sign-in', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      mockAuth.clearMockUser();

      appRouter.go('/login');
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Initially on LoginScreen
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);

      // Tap "Continue with Google" to log in
      final googleBtn = find.widgetWithText(OutlinedButton, 'Continue with Google');
      await tester.tap(googleBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Must be redirected directly to DashboardScreen
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.text("Today's Patient Queue Overview"), findsOneWidget);
    });

    testWidgets('8. Authenticated user visiting /login is redirected directly to /dashboard', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Pre-authenticate mock user
      await mockAuth.signInWithGoogle();

      appRouter.go('/login');
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Must be redirected directly to DashboardScreen
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.text("Today's Patient Queue Overview"), findsOneWidget);
    });
  });
}
