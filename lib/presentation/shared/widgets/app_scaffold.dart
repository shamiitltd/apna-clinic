import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/demo/demo_data_seeder.dart';
import '../../../application/providers.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/permissions/roles.dart';
import '../../../domain/entities/doctor.dart';
import '../../../domain/entities/subscription.dart';
import '../theme/app_theme.dart';

class AppScaffold extends ConsumerWidget {
  final Widget body;
  final String currentRoute;
  final Widget? floatingActionButton;
  final String? title;
  final List<Widget>? actions;

  const AppScaffold({
    super.key,
    required this.body,
    this.currentRoute = '/',
    this.floatingActionButton,
    this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    final session = ref.watch(sessionProvider);
    final subscription = ref.watch(subscriptionProvider).valueOrNull;
    final userRole = session.role;
    final isGoogleAuthed = session.isGoogleAuthenticated;

    // Filter available navigation items based on active role
    final navItems = _getNavItemsForRole(userRole);
    final currentNavIndex = _getNavIndexForRoute(navItems, currentRoute);

    // Auto-start controlled periodic sync (every 2 minutes) in background only when Google-authenticated
    if (isGoogleAuthed) {
      final scheduler = ref.read(masterSheetSyncSchedulerProvider);
      if (!scheduler.isScheduled) {
        scheduler.startPeriodicSync(
          clinicId: session.clinicId,
          interval: const Duration(minutes: 2),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: screenWidth < 600 ? 0 : 16,
        title: screenWidth < 600
            ? (title != null
                ? Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  )
                : const Text(
                    AppConstants.appName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ))
            : LayoutBuilder(
                builder: (context, titleConstraints) {
                  final maxW = titleConstraints.maxWidth;
                  final isCompactBrand = maxW < 360;
                  final showTitle = maxW >= 550 && title != null;
                  final showBadge = maxW >= 1200 && screenWidth >= 1600;

                  return ClipRect(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Clinic Brand & Identity
                        Flexible(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isCompactBrand ? 6 : 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.local_hospital,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                if (!isCompactBrand) ...[
                                  const SizedBox(width: 6),
                                  const Flexible(
                                    child: Text(
                                      AppConstants.appName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Colors.white,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (showTitle) ...[
                          const SizedBox(width: 8),
                          const Text(
                            '/',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              title!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                        if (showBadge) ...[
                          const SizedBox(width: 10),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                border: Border.all(color: Colors.green.shade600),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 7,
                                    color: Colors.green.shade700,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      'ONLINE • LOCAL STORE READY',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade900,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
        actions: [
          if (actions != null) ...actions!,

          // Cloud Sync Action (Manual Trigger & Real-time Indicator)
          _CloudSyncButton(clinicId: session.clinicId),

          // Google Authentication Action (Sign In button or Authenticated Account Chip)
          if (screenWidth >= 600) ...[
            if (session.isGoogleAuthenticated)
              PopupMenuButton<String>(
                tooltip:
                    'Google Account: ${session.googleUserEmail ?? "Connected"}',
                constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
                onSelected: (val) async {
                  if (val == 'signout') {
                    final authService = ref.read(authServiceProvider);
                    await authService.signOut();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Signed out of Google account.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } else if (val == 'switch') {
                    final authService = ref.read(authServiceProvider);
                    await authService.signIn();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          session.googleUserDisplayName ?? 'Google User',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        if (session.googleUserEmail != null)
                          Text(
                            session.googleUserEmail!,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'switch',
                    child: Row(
                      children: [
                        Icon(Icons.switch_account, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Switch Google Account',
                            style: TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'signout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sign Out',
                            style: TextStyle(fontSize: 13, color: Colors.red),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_done,
                        size: 15,
                        color: Colors.teal,
                      ),
                      if (screenWidth >= 1600) ...[
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: Text(
                            session.googleUserDisplayName ??
                                session.googleUserEmail ??
                                'Google Synced',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.teal.shade900,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_drop_down,
                        size: 16,
                        color: Colors.teal,
                      ),
                    ],
                  ),
                ),
              )
            else if (screenWidth >= 1600)
              FilledButton.icon(
                onPressed: () async {
                  final authService = ref.read(authServiceProvider);
                  final result = await authService.signIn();
                  if (context.mounted) {
                    if (result.isSuccess) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.green,
                          content: Text('Google Sign-In successful.'),
                        ),
                      );
                    } else if (result.isCancelled) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Google Sign-In was cancelled.'),
                        ),
                      );
                    } else if (!result.isRedirecting) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.red.shade800,
                          content: Text(
                            result.errorMessage ?? 'Authentication failed.',
                          ),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.account_circle, size: 15),
                label: const Text('Sign in with Google'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Tooltip(
                message: 'Sign in with Google',
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    final authService = ref.read(authServiceProvider);
                    final result = await authService.signIn();
                    if (context.mounted &&
                        !result.isSuccess &&
                        !result.isCancelled &&
                        !result.isRedirecting) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.red.shade800,
                          content: Text(
                            result.errorMessage ?? 'Authentication failed.',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.account_circle,
                    size: 20,
                    color: Color(0xFF0F766E),
                  ),
                ),
              ),
            const SizedBox(width: 4),
          ],

          // Responsive Workstation Lock & Security Switcher
          if (userRole == UserRole.owner && !session.isWorkstationLocked) ...[
            if (isDesktop)
              PopupMenuButton<dynamic>(
                tooltip: 'Lock Workstation to Staff Role',
                constraints: const BoxConstraints(minWidth: 280, maxWidth: 360),
                onSelected: (target) {
                  if (target is UserRole && target != UserRole.owner) {
                    _showLockConfirmationDialog(context, ref, target);
                  } else if (target == 'lock_screen') {
                    ref
                        .read(sessionProvider.notifier)
                        .autoLockWorkstation(ref.read(localDatabaseProvider));
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    enabled: false,
                    child: Text(
                      'WORKSTATION ACCESS CONTROL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'lock_screen',
                    child: Row(
                      children: [
                        Icon(Icons.lock_clock, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lock Workstation Now (PIN to Resume)',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: UserRole.owner,
                    enabled: false,
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: Colors.amber),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Owner / Admin (Unlocked)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: UserRole.receptionist,
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline, size: 16, color: Colors.teal),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lock to Receptionist Desk',
                            style: TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: UserRole.doctor,
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline, size: 16, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lock to Doctor Desk',
                            style: TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: UserRole.accountant,
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: Colors.purple,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lock to Accountant Desk',
                            style: TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        size: 16,
                        color: Colors.amber.shade800,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Owner Mode',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_drop_down,
                        size: 18,
                        color: Colors.amber.shade800,
                      ),
                    ],
                  ),
                ),
              )
            else
              PopupMenuButton<dynamic>(
                tooltip: 'Lock Workstation to Staff Role',
                constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
                onSelected: (target) {
                  if (target is UserRole && target != UserRole.owner) {
                    _showLockConfirmationDialog(context, ref, target);
                  } else if (target == 'lock_screen') {
                    ref
                        .read(sessionProvider.notifier)
                        .autoLockWorkstation(ref.read(localDatabaseProvider));
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'lock_screen',
                    child: Row(
                      children: [
                        Icon(Icons.lock_clock, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lock Workstation Now',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: UserRole.receptionist,
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline, size: 16, color: Colors.teal),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lock to Receptionist',
                            style: TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: UserRole.doctor,
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline, size: 16, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lock to Doctor',
                            style: TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: UserRole.accountant,
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: Colors.purple,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lock to Accountant',
                            style: TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Icon(
                    Icons.admin_panel_settings,
                    size: 16,
                    color: Colors.amber.shade800,
                  ),
                ),
              ),
          ] else ...[
            // Staff lockdown view (Non-owner role locked, cannot switch without PIN)
            if (isDesktop) ...[
              Tooltip(
                message:
                    'Workstation locked to ${userRole.name.toUpperCase()} mode. Click to Unlock.',
                child: InkWell(
                  onTap: () => _showUnlockWorkstationDialog(context, ref),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock,
                          size: 14,
                          color: Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${userRole.name.toUpperCase()} (LOCKED)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF991B1B),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_open,
                                size: 11,
                                color: Colors.white,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'UNLOCK',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: 'Lock Screen Now (Inactivity / Break)',
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.lock_clock,
                    size: 18,
                    color: Color(0xFFDC2626),
                  ),
                  onPressed: () {
                    ref
                        .read(sessionProvider.notifier)
                        .autoLockWorkstation(ref.read(localDatabaseProvider));
                  },
                ),
              ),
            ] else ...[
              Tooltip(
                message:
                    'Locked: ${userRole.name.toUpperCase()}. Click to Unlock.',
                child: InkWell(
                  onTap: () => _showUnlockWorkstationDialog(context, ref),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth < 400 ? 6 : 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock, size: 14, color: Color(0xFFDC2626)),
                        if (screenWidth >= 400) ...[
                          const SizedBox(width: 4),
                          const Text(
                            'UNLOCK',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (screenWidth >= 600) ...[
                const SizedBox(width: 2),
                Tooltip(
                  message: 'Lock Screen Now',
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.lock_clock,
                      size: 16,
                      color: Color(0xFFDC2626),
                    ),
                    onPressed: () {
                      ref
                          .read(sessionProvider.notifier)
                          .autoLockWorkstation(ref.read(localDatabaseProvider));
                    },
                  ),
                ),
              ],
            ],
          ],
          const SizedBox(width: 6),

          // Instant Seed Demo Data Action (Displayed when enableSyntheticDemoData is true OR when database is empty)
          if ((AppConfig.current.enableSyntheticDemoData ||
                  ref.watch(localDatabaseProvider).query('Patients').isEmpty) &&
              screenWidth >= 600) ...[
            if (screenWidth >= 1200)
              Tooltip(
                message: 'Populate 8 Patients, 5 Live Queue Tokens, Appointments, and Invoices',
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await DemoDataSeeder.seed(ref);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.green,
                          content: Text(
                            'Demo clinic data seeded! (8 Patients, 5 Visits, Queue & Invoices ready)',
                          ),
                        ),
                      );
                      context.go(currentRoute);
                    }
                  },
                  icon: const Icon(Icons.auto_fix_high, size: 15),
                  label: const Text('Seed Demo Data'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primaryLight),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                ),
              )
            else
              Tooltip(
                message: 'Seed Demo Clinic Data (8 Patients, 5 Visits, Queue & Invoices)',
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    await DemoDataSeeder.seed(ref);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.green,
                          content: Text('Demo clinic data seeded!'),
                        ),
                      );
                      context.go(currentRoute);
                    }
                  },
                  icon: const Icon(
                    Icons.auto_fix_high,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      drawer: !isDesktop
          ? Drawer(
              child: SafeArea(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: AppColors.primary,
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.local_hospital,
                                color: Colors.white,
                                size: 22,
                              ),
                              SizedBox(width: 8),
                              Text(
                                AppConstants.appName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Active Workspace: ${userRole.name.toUpperCase()}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: navItems.map((item) {
                          final isSelected =
                              currentRoute == item.route ||
                              (item.route != '/' &&
                                  currentRoute.startsWith(item.route));
                          return ListTile(
                            leading: Icon(
                              isSelected ? item.selectedIcon : item.icon,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            title: Text(
                              item.label,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                            ),
                            selected: isSelected,
                            selectedTileColor: AppColors.primaryContainer
                                .withValues(alpha: 0.5),
                            onTap: () {
                              Navigator.pop(context);
                              context.go(item.route);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const Divider(height: 1),
                    if (isGoogleAuthed)
                      ListTile(
                        leading: const Icon(
                          Icons.cloud_done,
                          color: Colors.teal,
                        ),
                        title: Text(
                          session.googleUserDisplayName ??
                              session.googleUserEmail ??
                              'Google Account',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          session.googleUserEmail ??
                              'Cloud Backup & Sheets Synced',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.logout,
                            size: 18,
                            color: Colors.red,
                          ),
                          tooltip: 'Sign Out',
                          onPressed: () async {
                            Navigator.pop(context);
                            final authService = ref.read(authServiceProvider);
                            await authService.signOut();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Signed out of Google account.',
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                      )
                    else
                      ListTile(
                        leading: const Icon(
                          Icons.account_circle,
                          color: Color(0xFF0F766E),
                        ),
                        title: const Text(
                          'Sign in with Google',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: const Text(
                          'Connect Google Sheets & Drive',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () async {
                          Navigator.pop(context);
                          final authService = ref.read(authServiceProvider);
                          final result = await authService.signIn();
                          if (context.mounted) {
                            if (result.isSuccess) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Colors.green,
                                  content: Text('Google Sign-In successful.'),
                                ),
                              );
                            } else if (result.isCancelled) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Google Sign-In was cancelled.',
                                  ),
                                ),
                              );
                            } else if (!result.isRedirecting) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.red.shade800,
                                  content: Text(
                                    result.errorMessage ??
                                        'Authentication failed.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    if (AppConfig.current.enableSyntheticDemoData ||
                        ref
                            .watch(localDatabaseProvider)
                            .query('Patients')
                            .isEmpty) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            await DemoDataSeeder.seed(ref);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Colors.green,
                                  content: Text('Demo clinic data seeded!'),
                                ),
                              );
                              context.go(currentRoute);
                            }
                          },
                          icon: const Icon(Icons.auto_fix_high, size: 16),
                          label: const Text('Seed Demo Data'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(40),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : null,
      body: InactivityDetector(
        onInactivityTimeout: () {
          ref
              .read(sessionProvider.notifier)
              .autoLockWorkstation(ref.read(localDatabaseProvider));
        },
        child: Stack(
          children: [
            Row(
              children: [
                if (isDesktop && navItems.length >= 2)
                  NavigationRail(
                    selectedIndex:
                        (currentNavIndex >= 0 && currentNavIndex < navItems.length)
                        ? currentNavIndex
                        : 0,
                    onDestinationSelected: (index) {
                      final dest = navItems[index];
                      context.go(dest.route);
                    },
                    labelType: NavigationRailLabelType.all,
                    backgroundColor: AppColors.surface,
                    indicatorColor: AppColors.primaryContainer,
                    destinations: navItems.map((item) {
                      return NavigationRailDestination(
                        icon: Icon(item.icon, size: 20),
                        selectedIcon: Icon(
                          item.selectedIcon,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        label: Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: currentRoute == item.route
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                if (isDesktop && navItems.length >= 2)
                  const VerticalDivider(
                    thickness: 1,
                    width: 1,
                    color: AppColors.border,
                  ),
                Expanded(
                  child: Column(
                    children: [
                      if (subscription != null &&
                          subscription.status == SubscriptionStatus.gracePeriod)
                        _buildGracePeriodBanner(context, subscription),
                      if (subscription != null &&
                          subscription.status == SubscriptionStatus.expired)
                        _buildExpiredBanner(context, subscription),
                      Expanded(child: body),
                    ],
                  ),
                ),
              ],
            ),
            if (session.isAutoLocked)
              const Positioned.fill(
                child: _WorkstationLockOverlay(),
              ),
          ],
        ),
      ),
      bottomNavigationBar: null,
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _buildGracePeriodBanner(BuildContext context, ClinicSubscription sub) {
    final now = DateTime.now().toUtc();
    final daysLeft = sub.graceDaysRemaining(now);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFFFFBEB),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFD97706)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Subscription Offline Grace Mode: $daysLeft days remaining. Operating on cached offline license.',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: const Color(0xFFB45309),
            ),
            onPressed: () => context.go('/settings'),
            child: const Text('Renew (₹3,999/yr)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredBanner(BuildContext context, ClinicSubscription sub) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFFEF2F2),
      child: Row(
        children: [
          const Icon(Icons.lock_clock, size: 18, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Subscription Expired — Safe Read-Only Mode. Patient data export and reports remain available, but new visits and registrations are paused.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF991B1B)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => context.go('/settings'),
            child: const Text('Renew License', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  static Future<void> _showLockConfirmationDialog(
    BuildContext context,
    WidgetRef ref,
    UserRole targetRole,
  ) async {
    final session = ref.read(sessionProvider);
    final roleName = targetRole == UserRole.receptionist
        ? 'Receptionist'
        : (targetRole == UserRole.doctor ? 'Doctor' : 'Accountant');

    List<Doctor> doctors = [];
    Doctor? selectedDoctor;
    if (targetRole == UserRole.doctor) {
      try {
        final clinicRepo = ref.read(clinicRepositoryProvider);
        doctors = await clinicRepo.getDoctors(session.clinicId);
        if (doctors.isNotEmpty) {
          selectedDoctor = doctors.firstWhere(
            (d) => d.doctorId == session.assignedDoctorId,
            orElse: () => doctors.first,
          );
        }
      } catch (_) {}
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.lock_outline, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Lock to $roleName Mode?'),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This computer will be locked into the $roleName workspace:',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '• Staff will only have access to $roleName permissions.\n'
                  '• Restricted areas (like Owner Settings and ${targetRole == UserRole.receptionist ? "Doctor Desk" : "Clinic Administration"}) are blocked.\n'
                  '• Switching back to Owner / Admin mode will require entering your 4-digit Owner Security PIN (Default: 1234).',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (targetRole == UserRole.doctor && doctors.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Select Active Doctor for this Workstation:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<Doctor>(
                    value: selectedDoctor,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.medical_services_outlined, size: 18),
                    ),
                    items: doctors.map((d) {
                      final specialtyText = d.specialtyLabel.isNotEmpty ? ' (${d.specialtyLabel})' : '';
                      return DropdownMenuItem<Doctor>(
                        value: d,
                        child: Text(
                          '${d.displayName}$specialtyText',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (d) {
                      setDialogState(() {
                        selectedDoctor = d;
                      });
                    },
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'PRD Isolation: Only patients assigned to this doctor will appear on the Doctor Desk live queue.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF0F766E),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.lock, size: 16),
              label: Text('Lock as $roleName'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(sessionProvider.notifier).lockWorkstationToRole(
            targetRole,
            doctorId: targetRole == UserRole.doctor ? selectedDoctor?.doctorId : null,
            doctorName: targetRole == UserRole.doctor ? selectedDoctor?.displayName : null,
          );
      if (context.mounted) {
        final feedbackMsg = targetRole == UserRole.doctor && selectedDoctor != null
            ? 'Workstation locked to Doctor Mode for ${selectedDoctor!.displayName}.'
            : 'Workstation locked to $roleName Mode.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F766E),
            content: Text(feedbackMsg),
          ),
        );
        context.go(targetRole == UserRole.doctor ? '/doctor' : '/dashboard');
      }
    }
  }

  static Future<void> _showUnlockWorkstationDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final pinController = TextEditingController();
    String? errorMessage;
    bool obscurePin = true;

    Future<void> submitPin(StateSetter setState, BuildContext dialogCtx) async {
      final session = ref.read(sessionProvider);
      if (session.isLockedOut) {
        setState(() {
          errorMessage =
              'Workstation is locked. Please wait ${session.lockoutSecondsRemaining}s before retrying.';
        });
        return;
      }

      final pin = pinController.text.trim();
      if (pin.isEmpty) {
        setState(() => errorMessage = 'Enter your PIN');
        return;
      }

      final success = await ref.read(sessionProvider.notifier).unlockWorkstation(
            pin,
            clinicRepo: ref.read(clinicRepositoryProvider),
            db: ref.read(localDatabaseProvider),
          );

      if (success) {
        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
        if (context.mounted) {
          final updated = ref.read(sessionProvider);
          final title = updated.role == UserRole.owner
              ? 'Owner access restored.'
              : 'Logged in as ${updated.staffName} (${updated.role.wireValue.toUpperCase()}).';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green,
              content: Text('Workstation unlocked. $title'),
            ),
          );
        }
      } else {
        final current = ref.read(sessionProvider);
        setState(() {
          if (current.isLockedOut) {
            errorMessage =
                'Too many failed attempts. Workstation locked for 30 seconds.';
          } else {
            final remaining = 5 - current.failedPinAttempts;
            errorMessage =
                'Incorrect PIN. $remaining attempts remaining before lockout.';
          }
        });
      }
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Text(
                'Unlock Workstation',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter Staff PIN or Owner Security PIN to unlock workstation and switch active workspace.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pinController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  obscureText: obscurePin,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'PIN (Owner or Staff)',
                    hintText: 'Default Owner PIN: 1234',
                    prefixIcon: const Icon(Icons.key, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePin ? Icons.visibility_off : Icons.visibility,
                        size: 18,
                      ),
                      onPressed: () => setState(() => obscurePin = !obscurePin),
                    ),
                    errorText: errorMessage,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    counterText: '',
                  ),
                  onSubmitted: (_) => submitPin(setState, dialogCtx),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
              ),
              icon: const Icon(Icons.lock_open, size: 16),
              label: const Text('Unlock Workstation'),
              onPressed: () => submitPin(setState, dialogCtx),
            ),
          ],
        ),
      ),
    );
  }

  static List<_NavDestinationItem> _getNavItemsForRole(UserRole role) {
    switch (role) {
      case UserRole.doctor:
        return const [
          _NavDestinationItem(
            route: '/doctor',
            label: 'Doctor Desk',
            icon: Icons.medical_services_outlined,
            selectedIcon: Icons.medical_services,
          ),
          _NavDestinationItem(
            route: '/queue',
            label: 'Live Queue',
            icon: Icons.format_list_numbered,
            selectedIcon: Icons.format_list_numbered_rtl,
          ),
          _NavDestinationItem(
            route: '/appointments',
            label: 'Appointments',
            icon: Icons.calendar_month_outlined,
            selectedIcon: Icons.calendar_month,
          ),
          _NavDestinationItem(
            route: '/patients',
            label: 'Patients',
            icon: Icons.people_outline,
            selectedIcon: Icons.people,
          ),
        ];

      case UserRole.accountant:
        return const [
          _NavDestinationItem(
            route: '/dashboard',
            label: 'Dashboard',
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
          ),
          _NavDestinationItem(
            route: '/billing',
            label: 'Billing & Ledger',
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long,
          ),
          _NavDestinationItem(
            route: '/reports',
            label: 'Reports',
            icon: Icons.bar_chart_outlined,
            selectedIcon: Icons.bar_chart,
          ),
        ];

      case UserRole.receptionist:
        return const [
          _NavDestinationItem(
            route: '/dashboard',
            label: 'Dashboard',
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
          ),
          _NavDestinationItem(
            route: '/appointments',
            label: 'Appointments',
            icon: Icons.calendar_month_outlined,
            selectedIcon: Icons.calendar_month,
          ),
          _NavDestinationItem(
            route: '/patients',
            label: 'Patients',
            icon: Icons.people_outline,
            selectedIcon: Icons.people,
          ),
          _NavDestinationItem(
            route: '/queue',
            label: 'Live Queue',
            icon: Icons.format_list_numbered,
            selectedIcon: Icons.format_list_numbered_rtl,
          ),
          _NavDestinationItem(
            route: '/billing',
            label: 'Billing',
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long,
          ),
          _NavDestinationItem(
            route: '/reports',
            label: 'Reports',
            icon: Icons.bar_chart_outlined,
            selectedIcon: Icons.bar_chart,
          ),
        ];

      case UserRole.owner:
        return const [
          _NavDestinationItem(
            route: '/dashboard',
            label: 'Dashboard',
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
          ),
          _NavDestinationItem(
            route: '/appointments',
            label: 'Appointments',
            icon: Icons.calendar_month_outlined,
            selectedIcon: Icons.calendar_month,
          ),
          _NavDestinationItem(
            route: '/patients',
            label: 'Patients',
            icon: Icons.people_outline,
            selectedIcon: Icons.people,
          ),
          _NavDestinationItem(
            route: '/queue',
            label: 'Live Queue',
            icon: Icons.format_list_numbered,
            selectedIcon: Icons.format_list_numbered_rtl,
          ),
          _NavDestinationItem(
            route: '/doctor',
            label: 'Doctor Desk',
            icon: Icons.medical_services_outlined,
            selectedIcon: Icons.medical_services,
          ),
          _NavDestinationItem(
            route: '/billing',
            label: 'Billing',
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long,
          ),
          _NavDestinationItem(
            route: '/reports',
            label: 'Reports',
            icon: Icons.bar_chart_outlined,
            selectedIcon: Icons.bar_chart,
          ),
          _NavDestinationItem(
            route: '/settings',
            label: 'Settings',
            icon: Icons.tune_outlined,
            selectedIcon: Icons.tune,
          ),
        ];
    }
  }

  static int _getNavIndexForRoute(
    List<_NavDestinationItem> items,
    String route,
  ) {
    for (int i = 0; i < items.length; i++) {
      if (route == items[i].route ||
          (items[i].route != '/' && route.startsWith(items[i].route))) {
        return i;
      }
    }
    return 0;
  }
}

class _NavDestinationItem {
  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _NavDestinationItem({
    required this.route,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

class _CloudSyncButton extends ConsumerStatefulWidget {
  final String clinicId;
  const _CloudSyncButton({required this.clinicId});

  @override
  ConsumerState<_CloudSyncButton> createState() => _CloudSyncButtonState();
}

class _CloudSyncButtonState extends ConsumerState<_CloudSyncButton> {
  bool _isManualSyncing = false;

  @override
  Widget build(BuildContext context) {
    final scheduler = ref.watch(masterSheetSyncSchedulerProvider);
    final isSyncing = scheduler.isSyncActive || _isManualSyncing;

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: IconButton(
        tooltip: isSyncing
            ? 'Syncing with Google Sheets...'
            : 'Sync with Google Sheets Now',
        icon: isSyncing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : const Icon(Icons.cloud_sync, size: 22, color: AppColors.primary),
        onPressed: isSyncing
            ? null
            : () async {
                setState(() => _isManualSyncing = true);
                try {
                  final authService = ref.read(authServiceProvider);
                  String? token = await authService.getValidAccessToken(
                    clinicId: widget.clinicId,
                  );

                  // If no active Google token in memory/vault, prompt Sign-In popup immediately
                  if (token == null || token.isEmpty) {
                    final authResult = await authService.signIn();
                    if (authResult.isSuccess && authResult.tokens != null) {
                      token = authResult.tokens!.accessToken;
                    } else if (authResult.isCancelled) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Google Sign-In cancelled.'),
                          ),
                        );
                      }
                      return;
                    }
                  }

                  // 1. Bi-directional ingestion: pull existing rows from Google Sheet into local database
                  int importedCount = 0;
                  try {
                    final initService = ref.read(
                      masterSheetInitializationServiceProvider,
                    );
                    final initResult = await initService
                        .initializeFromMasterSheet(
                          clinicId: widget.clinicId,
                          explicitAccessToken: token,
                          createIfMissing: true,
                        );
                    if (initResult.isSuccess) {
                      importedCount = initResult.totalRecordsImported;
                    }
                  } catch (_) {}

                  // 2. Outbox synchronization: push local events to Google Sheets
                  final telemetry = await scheduler.triggerManualSync(
                    clinicId: widget.clinicId,
                    explicitAccessToken: token,
                  );

                  if (context.mounted) {
                    if (telemetry.isSuccess || importedCount > 0) {
                      final count = telemetry.recordsSucceeded;
                      final msg = importedCount > 0
                          ? '✓ Synced with Google Sheets! (Imported $importedCount record(s) from sheet)'
                          : (count > 0
                                ? '✓ Synced $count record(s) to Google Sheets!'
                                : '✓ Google Sheet is already up to date!');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(msg),
                          backgroundColor: const Color(0xFF0F766E),
                          duration: const Duration(seconds: 4),
                        ),
                      );
                      // Trigger page refresh if on patients or other screens
                      context.go(GoRouterState.of(context).uri.toString());
                    } else {
                      final isAuthError =
                          telemetry.lastErrorCode == 'AUTH_REQUIRED' ||
                          (telemetry.lastErrorMessage?.contains('OAuth') ??
                              false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isAuthError
                                ? 'Google Drive authentication required to sync. Please connect your account.'
                                : 'Sync Notice: ${telemetry.lastErrorMessage ?? "Sync encountered an issue. Will retry automatically."}',
                          ),
                          backgroundColor: Colors.orange.shade800,
                          duration: const Duration(seconds: 5),
                          action: isAuthError
                              ? SnackBarAction(
                                  label: 'Connect',
                                  textColor: Colors.white,
                                  onPressed: () => context.go('/drive-setup'),
                                )
                              : null,
                        ),
                      );
                    }
                  }
                } finally {
                  if (mounted) {
                    setState(() => _isManualSyncing = false);
                  }
                }
              },
      ),
    );
  }
}

/// Inactivity detection wrapper for single shared workstation (PRD Section 5 M08).
/// Detects idle state and auto-locks workstation after 5 minutes of inactivity.
class InactivityDetector extends ConsumerStatefulWidget {
  final Widget child;
  final VoidCallback onInactivityTimeout;
  final Duration timeout;

  const InactivityDetector({
    super.key,
    required this.child,
    required this.onInactivityTimeout,
    this.timeout = const Duration(minutes: 5),
  });

  @override
  ConsumerState<InactivityDetector> createState() => _InactivityDetectorState();
}

class _InactivityDetectorState extends ConsumerState<InactivityDetector> {
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _resetTimer() {
    _inactivityTimer?.cancel();
    final isLocked = ref.read(sessionProvider).isAutoLocked;
    if (isLocked) return;

    _inactivityTimer = Timer(widget.timeout, () {
      if (mounted) {
        widget.onInactivityTimeout();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      onPointerHover: (_) => _resetTimer(),
      child: widget.child,
    );
  }
}

/// Workstation lock barrier displayed on inactivity timeout or manual lock (PRD Section 5 M08).
/// Enforces PIN verification, prevents unauthorized patient record viewing,
/// and applies temporary lockout after consecutive failed attempts.
class _WorkstationLockOverlay extends ConsumerStatefulWidget {
  const _WorkstationLockOverlay();

  @override
  ConsumerState<_WorkstationLockOverlay> createState() =>
      _WorkstationLockOverlayState();
}

class _WorkstationLockOverlayState
    extends ConsumerState<_WorkstationLockOverlay> {
  final _pinController = TextEditingController();
  bool _obscurePin = true;
  String? _errorMessage;
  bool _isUnlocking = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _attemptUnlock() async {
    final session = ref.read(sessionProvider);
    if (session.isLockedOut) {
      setState(() {
        _errorMessage =
            'Workstation locked due to multiple incorrect attempts. Please wait ${session.lockoutSecondsRemaining}s.';
      });
      return;
    }

    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      setState(() => _errorMessage = 'Enter your PIN to resume');
      return;
    }

    setState(() => _isUnlocking = true);
    final success = await ref.read(sessionProvider.notifier).unlockWorkstation(
          pin,
          clinicRepo: ref.read(clinicRepositoryProvider),
          db: ref.read(localDatabaseProvider),
        );
    if (mounted) {
      setState(() => _isUnlocking = false);
    }

    if (success) {
      if (mounted) {
        final current = ref.read(sessionProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              'Session resumed as ${current.role == UserRole.owner ? "Owner (Admin)" : current.staffName}.',
            ),
          ),
        );
      }
    } else {
      final current = ref.read(sessionProvider);
      setState(() {
        if (current.isLockedOut) {
          _errorMessage =
              'Too many failed attempts. Workstation locked for 30 seconds.';
        } else {
          final remaining = 5 - current.failedPinAttempts;
          _errorMessage = 'Incorrect PIN. $remaining attempts remaining.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final isLockedOut = session.isLockedOut;

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      alignment: Alignment.center,
      child: Card(
        elevation: 16,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_clock_outlined,
                  size: 48,
                  color: Color(0xFF0F766E),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Workstation Locked',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Workstation auto-locked to protect patient confidentiality. Enter Staff PIN or Owner Security PIN to resume.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              if (isLockedOut)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer, size: 18, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Brute-force lockout active. Wait ${session.lockoutSecondsRemaining}s before retrying.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              TextField(
                controller: _pinController,
                autofocus: true,
                enabled: !isLockedOut,
                obscureText: _obscurePin,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Staff / Owner Security PIN',
                  hintText: 'Enter 4-6 digit PIN',
                  prefixIcon: const Icon(Icons.key, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePin ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePin = !_obscurePin),
                  ),
                  errorText: _errorMessage,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  counterText: '',
                ),
                onSubmitted: (_) => _attemptUnlock(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed:
                      isLockedOut || _isUnlocking ? null : _attemptUnlock,
                  icon: _isUnlocking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.lock_open, size: 18),
                  label: Text(_isUnlocking ? 'Verifying...' : 'Resume Session'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
