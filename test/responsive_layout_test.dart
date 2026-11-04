import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:apna_clinic/presentation/dashboard/dashboard_screen.dart';
import 'package:apna_clinic/presentation/doctor/doctor_queue_screen.dart';
import 'package:apna_clinic/presentation/appointments/appointments_screen.dart';
import 'package:apna_clinic/presentation/patients/patients_screen.dart';
import 'package:apna_clinic/presentation/queue/queue_screen.dart';
import 'package:apna_clinic/presentation/billing/billing_screen.dart';
import 'package:apna_clinic/presentation/reports/reports_screen.dart';
import 'package:apna_clinic/presentation/settings/settings_screen.dart';

Widget wrapWithApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: child,
    ),
  );
}

void main() {
  const viewports = <String, Size>{
    'Large Desktop 1920x1080': Size(1920, 1080),
    'Large Desktop 1440x900': Size(1440, 900),
    'Standard Desktop 1366x768': Size(1366, 768),
    'Standard Desktop 1200x800': Size(1200, 800),
    'Laptop Short 1024x600': Size(1024, 600),
    'Tablet Portrait 768x1024': Size(768, 1024),
    'Tablet Narrow 600x800': Size(600, 800),
    'Phone 390x844': Size(390, 844),
    'Phone 360x640': Size(360, 640),
    'Small Phone 320x568': Size(320, 568),
    'Short Small Phone 320x480': Size(320, 480),
  };

  group('Responsive Layout Matrix — Zero Flutter Overflow', () {
    for (final entry in viewports.entries) {
      final name = entry.key;
      final size = entry.value;

      testWidgets('Doctor Desk renders with zero overflow on $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(wrapWithApp(const DoctorQueueScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull, reason: 'Doctor Desk overflowed on $name');
      });

      testWidgets('Appointments renders with zero overflow on $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(wrapWithApp(const AppointmentsScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull, reason: 'Appointments overflowed on $name');
      });

      testWidgets('Dashboard renders with zero overflow on $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(wrapWithApp(const DashboardScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull, reason: 'Dashboard overflowed on $name');
      });

      testWidgets('Queue renders with zero overflow on $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(wrapWithApp(const QueueScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull, reason: 'Queue overflowed on $name');
      });

      testWidgets('Billing renders with zero overflow on $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(wrapWithApp(const BillingScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull, reason: 'Billing overflowed on $name');
      });

      testWidgets('Patients renders with zero overflow on $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(wrapWithApp(const PatientsScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull, reason: 'Patients overflowed on $name');
      });

      testWidgets('Reports renders with zero overflow on $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(wrapWithApp(const ReportsScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull, reason: 'Reports overflowed on $name');
      });

      testWidgets('Settings renders with zero overflow on $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(wrapWithApp(const SettingsScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull, reason: 'Settings overflowed on $name');
      });
    }
  });

  group('Responsive Navigation Architecture Verification', () {
    for (final entry in viewports.entries) {
      final name = entry.key;
      final size = entry.value;
      final isDesktop = size.width >= 1024;

      testWidgets('Navigation structure on $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(wrapWithApp(const DashboardScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // CRITICAL: Bottom navigation bar must NEVER be rendered on any phone or tablet
        expect(find.byType(NavigationBar), findsNothing,
            reason: 'NavigationBar found on $name, but bottom nav must never appear');

        if (isDesktop) {
          // Desktop / Laptop: Sidebar NavigationRail visible, Hamburger menu NOT in AppBar
          expect(find.byType(NavigationRail), findsOneWidget,
              reason: 'NavigationRail should be visible on desktop $name');
          expect(find.byTooltip('Open navigation menu'), findsNothing,
              reason: 'Hamburger drawer button should not be shown on desktop $name');
        } else {
          // Tablet / Phone: Sidebar NavigationRail hidden, Hamburger menu visible in AppBar
          expect(find.byType(NavigationRail), findsNothing,
              reason: 'NavigationRail should NOT be visible on tablet/phone $name');
          expect(find.byTooltip('Open navigation menu'), findsOneWidget,
              reason: 'Hamburger drawer button must be visible on tablet/phone $name');

          // Tapping hamburger menu opens Drawer with destinations
          await tester.tap(find.byTooltip('Open navigation menu'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.byType(Drawer), findsOneWidget,
              reason: 'Drawer must open when hamburger menu is tapped on $name');
          expect(find.text('Active Workspace: RECEPTIONIST'), findsOneWidget);
        }
      });
    }
  });
}
