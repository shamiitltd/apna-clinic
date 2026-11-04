import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter/services.dart' show rootBundle;

import 'application/auth/app_access_notifier.dart';
import 'application/providers.dart';
import 'core/config/app_config.dart';
import 'core/constants/app_constants.dart';
import 'core/localization/app_localizations.dart';
import 'core/routing/app_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/logging/app_logger.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env configuration at runtime if available
  try {
    String? envContent;
    try {
      envContent = await rootBundle.loadString('.env');
    } catch (_) {
      try {
        envContent = await rootBundle.loadString('assets/.env');
      } catch (_) {}
    }
    if (envContent != null && envContent.isNotEmpty) {
      final parsed = AppConfig.parseEnv(envContent);
      AppConfig.initializeFromEnv(parsed);
    }
  } catch (_) {
    // Falls back to compile-time String.fromEnvironment configuration
  }

  // Initialize Firebase using production DefaultFirebaseOptions
  if (AppConfig.current.hasFirebaseConfig) {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (e) {
      AppLogger.warning('Firebase initialization note: $e');
    }
  }

  // Pre-initialize Riverpod container, local database, and auth session before runApp
  // This eliminates any race condition between OAuth redirect parsing, GoRouter, and UI rendering.
  final container = ProviderContainer();
  appProviderContainer = container;

  try {
    final db = container.read(localDatabaseProvider);
    await db.initialize();

    // Restore configured clinic from Clinic_Config into active session
    final clinicRecords = db.query('Clinic_Config');
    if (clinicRecords.isNotEmpty) {
      final configured = clinicRecords.first;
      final configuredClinicId = configured['clinic_id'] as String?;
      final configuredOwner = configured['owner_name'] as String? ?? 'Admin';
      if (configuredClinicId != null && configuredClinicId.isNotEmpty) {
        container.read(sessionProvider.notifier).setClinic(
          configuredClinicId,
          'staff_admin',
          configuredOwner,
        );
      }
    }
  } catch (_) {}

  // Wire clinic configuration checker for startup routing
  isClinicConfiguredOverride = () {
    final db = container.read(localDatabaseProvider);
    return db.query('Clinic_Config').isNotEmpty;
  };

  // Restore saved workstation role across reloads
  try {
    final sessionNotifier = container.read(sessionProvider.notifier);
    await sessionNotifier.restoreSavedRole();
  } catch (_) {}

  // Process Google OAuth redirect callback (if app opened from Google OAuth redirect)
  try {
    final currentClinicId = container.read(sessionProvider).clinicId;
    final authService = container.read(authServiceProvider);
    final callbackResult = await authService.handleRedirectCallback(clinicId: currentClinicId);
    if (callbackResult != null && callbackResult.isSuccess && callbackResult.tokens != null) {
      AppLogger.info('OAuth callback succeeded. Initializing Drive workspace with returned tokens...');
      final driveService = container.read(driveConnectionServiceProvider);
      await driveService.initializeWorkspaceWithToken(
        accessToken: callbackResult.tokens!.accessToken,
        clinicId: currentClinicId,
        driveEmail: callbackResult.user?.email,
      );
    } else if (callbackResult == null || !callbackResult.isSuccess) {
      await authService.restoreSession(clinicId: currentClinicId);
    }
  } catch (e) {
    AppLogger.error('OAuth redirect processing error: $e');
  }

  // Initialize AppAccess state machine after OAuth tokens and Drive workspace are configured
  try {
    final accessNotifier = container.read(appAccessProvider.notifier);
    await accessNotifier.initialize();
  } catch (_) {}

  // Wire router refresh notifier to re-evaluate routes automatically when access or session changes
  container.listen<AppAccessState>(appAccessProvider, (_, state) {
    if (state.driveConnected) {
      container.read(sessionProvider.notifier).setGoogleAuthSuccess(
        email: state.driveEmail ?? state.firebaseEmail ?? '',
        displayName: state.account?.fullName ?? 'Clinic Admin',
      );
    }
    appRouterRefreshNotifier.refresh();
  });
  container.listen<SessionState>(sessionProvider, (_, __) {
    appRouterRefreshNotifier.refresh();
  });

  runApp(UncontrolledProviderScope(
    container: container,
    child: const ApnaClinicApp(),
  ));
}

class ApnaClinicApp extends ConsumerStatefulWidget {
  const ApnaClinicApp({super.key});

  @override
  ConsumerState<ApnaClinicApp> createState() => _ApnaClinicAppState();
}

class _ApnaClinicAppState extends ConsumerState<ApnaClinicApp> {
  @override
  Widget build(BuildContext context) {
    // Primary clinical brand palette: Clean medical teal/cyan with slate neutrals
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0D9488), // Deep medical teal
      brightness: Brightness.light,
      primary: const Color(0xFF0F766E),
      secondary: const Color(0xFF0369A1),
      surface: const Color(0xFFF8FAFC),
    );

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        fontFamily: GoogleFonts.inter().fontFamily,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 1,
          titleTextStyle: GoogleFonts.inter(
            color: const Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          showCloseIcon: true,
          elevation: 6,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
