// Apna Clinic - Google Drive Setup Screen (Layer 3)
// Primary source of truth: New Login, Account & Google Drive Data Architecture Plan
// Solicits explicit user authorization to connect their Google Drive for clinic-owned cloud data.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/auth/app_access_notifier.dart';
import '../../application/providers.dart';

class DriveSetupScreen extends ConsumerStatefulWidget {
  const DriveSetupScreen({super.key});

  @override
  ConsumerState<DriveSetupScreen> createState() => _DriveSetupScreenState();
}

class _DriveSetupScreenState extends ConsumerState<DriveSetupScreen> {
  @override
  Widget build(BuildContext context) {
    final accessState = ref.watch(appAccessProvider);
    final notifier = ref.read(appAccessProvider.notifier);

    final isConnected = accessState.driveConnected &&
        accessState.driveFolderId != null &&
        !accessState.driveFolderId!.startsWith('local_folder_');
    final driveEmail = accessState.driveEmail ?? '';
    final clinicId = accessState.firebaseUid != null
        ? 'clinic_${accessState.firebaseUid}'
        : 'primary_clinic';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cloud / Drive Icon
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isConnected ? Colors.teal.shade50 : const Color(0xFFE0F2FE),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isConnected ? Icons.cloud_done_rounded : Icons.cloud_upload_outlined,
                    size: 44,
                    color: isConnected ? const Color(0xFF0F766E) : const Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  isConnected ? 'Google Drive Connected' : 'Connect Your Google Drive',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  isConnected
                      ? 'Your clinic workspace has been verified. All operational data (patients, appointments, invoices) is securely linked to your Google Drive.'
                      : 'Your clinic data remains strictly under your control. Connect Google Drive to initialize Apna Clinic.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),

                // Data Sovereignty Note
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shield_outlined, size: 20, color: Color(0xFF0F766E)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Data Ownership Guarantee: SHAMIIT never holds your patients\' health records on its servers. Operational data is stored only on your workstation and your private Google Drive/Sheets.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade800, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Error Banner
                if (accessState.errorMessage != null && !isConnected) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline, size: 20, color: Colors.red.shade700),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            accessState.errorMessage!,
                            style: TextStyle(fontSize: 13, color: Colors.red.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Connected State Display
                if (isConnected) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Color(0xFF0F766E), size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '✓ Google Drive Connected',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F766E),
                                  fontSize: 14,
                                ),
                              ),
                              if (driveEmail.isNotEmpty)
                                Text(
                                  driveEmail,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.teal.shade900,
                                  )                                 ),
                              if (accessState.driveFolderId != null &&
                                  !accessState.driveFolderId!.startsWith('local_folder_'))
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Drive Folder: Apna Clinic (${accessState.driveFolderId})',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      color: Colors.teal.shade800,
                                    ),
                                  ),
                                ),
                              if (accessState.driveSpreadsheetId != null &&
                                  !accessState.driveSpreadsheetId!.startsWith('local_sheet_'))
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Master Sheet: ApnaClinic_MasterData (${accessState.driveSpreadsheetId})',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      color: Colors.teal.shade800,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Open Folder in Google Drive Button
                  if (accessState.driveFolderId != null &&
                      !accessState.driveFolderId!.startsWith('local_folder_')) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed: () => launchUrl(
                          Uri.parse('https://drive.google.com/drive/folders/${accessState.driveFolderId}'),
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.folder_open_rounded, size: 16, color: Color(0xFF0F766E)),
                        label: const Text(
                          'Open "Apna Clinic" Folder in Google Drive',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF0F766E)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Open Master Sheet in Google Sheets Button
                  if (accessState.driveSpreadsheetId != null &&
                      !accessState.driveSpreadsheetId!.startsWith('local_sheet_')) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed: () => launchUrl(
                          Uri.parse('https://docs.google.com/spreadsheets/d/${accessState.driveSpreadsheetId}'),
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.table_chart_outlined, size: 16, color: Color(0xFF0F766E)),
                        label: const Text(
                          'Open Master Sheet in Google Sheets',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF0F766E)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Continue Setup Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () {
                        if (accessState.status == AppAccessStatus.clinicSetupRequired) {
                          context.go('/onboarding');
                        } else {
                          context.go('/');
                        }
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text(
                        'Continue Setup',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Reconnect / Re-authorize Drive Button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: accessState.isLoading
                          ? null
                          : () => notifier.connectGoogleDrive(clinicId: clinicId),
                      icon: accessState.isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync, size: 18),
                      label: Text(
                        accessState.isLoading
                            ? 'Connecting...'
                            : 'Re-authorize & Create Drive Workspace',
                        style: const TextStyle(fontSize: 14),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Connect Drive Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: accessState.isLoading
                          ? null
                          : () => notifier.connectGoogleDrive(clinicId: clinicId),
                      icon: accessState.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add_to_drive, size: 22),
                      label: Text(
                        accessState.isLoading ? 'Connecting Drive...' : 'Connect Google Drive',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Sign Out Action
                TextButton(
                  onPressed: () => notifier.signOut(),
                  child: const Text('Sign out of Apna Clinic'),
                ),

                const SizedBox(height: 12),

                Text(
                  'Powered by SHAMIIT LLP',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
