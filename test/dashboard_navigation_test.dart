import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_clinic/main.dart';
import 'package:apna_clinic/core/routing/app_router.dart';
import 'package:apna_clinic/application/providers.dart';
import 'package:apna_clinic/infrastructure/database/local_database.dart';
import 'package:apna_clinic/infrastructure/database/storage_adapter.dart';
import 'package:apna_clinic/presentation/dashboard/dashboard_screen.dart';
import 'package:apna_clinic/application/auth/app_access_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    isClinicConfiguredOverride = () => true;
    appAccessStatusOverride = AppAccessStatus.ready;
  });

  tearDown(() {
    isClinicConfiguredOverride = null;
    appAccessStatusOverride = null;
  });

  group('APNA CLINIC — DASHBOARD NAVIGATION & LIFECYCLE TESTS', () {
    testWidgets(
      'Dashboard loads initially and reloads without infinite spinner after navigation across all routes',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final memoryDb = LocalDatabase(MemoryStorageAdapter());
        await memoryDb.initialize();

        final container = ProviderContainer(
          overrides: [
            localDatabaseProvider.overrideWithValue(memoryDb),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const ApnaClinicApp(),
          ),
        );

        // 1. Initial Dashboard load
        appRouter.go('/dashboard');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.byType(DashboardScreen), findsOneWidget);
        expect(find.text("Today's Patient Queue Overview"), findsOneWidget);
        expect(find.text('TOTAL VISITS'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Sign in with Google'), findsOneWidget);

        Future<void> navigateAndVerify(String route) async {
          // Navigate to destination route
          appRouter.go(route);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // Navigate back to Dashboard
          appRouter.go('/dashboard');
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));

          // Verify Dashboard is displayed and NOT stuck on loading spinner
          expect(
            find.byType(DashboardScreen),
            findsOneWidget,
            reason: 'Dashboard should be displayed after returning from $route',
          );
          expect(
            find.byType(CircularProgressIndicator),
            findsNothing,
            reason: 'Loading spinner must not be stuck after returning from $route',
          );
          expect(
            find.text("Today's Patient Queue Overview"),
            findsOneWidget,
            reason: 'Queue overview must be visible after returning from $route',
          );
          expect(
            find.text('TOTAL VISITS'),
            findsOneWidget,
            reason: 'Total visits card must be visible after returning from $route',
          );
        }

        // 2. Dashboard -> Patients -> Dashboard
        await navigateAndVerify('/patients');

        // 3. Dashboard -> Appointments -> Dashboard
        await navigateAndVerify('/appointments');

        // 4. Dashboard -> Live Queue -> Dashboard
        await navigateAndVerify('/queue');

        // 5. Dashboard -> Billing -> Dashboard
        await navigateAndVerify('/billing');

        // 6. Dashboard -> Doctor Desk -> Dashboard
        await navigateAndVerify('/doctor');

        // 7. Dashboard -> Reports -> Dashboard
        await navigateAndVerify('/reports');

        // 8. Dashboard -> Settings -> Dashboard
        await navigateAndVerify('/settings');

        // 9. Repeat multiple rapid round trips
        for (int i = 0; i < 3; i++) {
          await navigateAndVerify('/patients');
          await navigateAndVerify('/queue');
          await navigateAndVerify('/billing');
          await navigateAndVerify('/appointments');
        }

        // Final verification that Dashboard is fully loaded and functional
        expect(find.byType(DashboardScreen), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text("Today's Patient Queue Overview"), findsOneWidget);
        expect(find.text('TOTAL VISITS'), findsOneWidget);
      },
    );
  });
}
