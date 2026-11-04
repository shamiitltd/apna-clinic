import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_clinic/main.dart';
import 'package:apna_clinic/core/constants/app_constants.dart';
import 'package:apna_clinic/core/routing/app_router.dart';
import 'package:apna_clinic/application/auth/app_access_notifier.dart';
import 'package:apna_clinic/presentation/dashboard/dashboard_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    isClinicConfiguredOverride = () => true;
    appAccessStatusOverride = AppAccessStatus.ready;
  });

  tearDown(() {
    isClinicConfiguredOverride = null;
    appAccessStatusOverride = null;
  });

  testWidgets('ApnaClinicApp boots and renders topbar title', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const ProviderScope(child: ApnaClinicApp()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Initial landing at / renders official website
    expect(find.text(AppConstants.appName), findsWidgets);

    // Navigating to /dashboard with AppAccessStatus.ready renders clinical dashboard
    appRouter.go('/dashboard');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(DashboardScreen), findsOneWidget);
  });
}
