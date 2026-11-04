// Apna Clinic — Design System & Reusable UI Tokens
import 'package:flutter/material.dart';

class AppColors {
  // Brand Palette: Deep medical teal and clinical accents
  static const Color primary = Color(0xFF0F766E); // Deep Teal
  static const Color primaryLight = Color(0xFF0D9488); // Medical Teal
  static const Color primaryContainer = Color(0xFFCCFBF1); // Teal 100
  static const Color secondary = Color(0xFF0369A1); // Medical Sky Blue
  static const Color secondaryContainer = Color(0xFFE0F2FE); // Blue 100

  // Neutral Palette
  static const Color background = Color(0xFFF1F5F9); // Slate 100
  static const Color surface = Color(0xFFFFFFFF); // Pure White
  static const Color surfaceAlt = Color(0xFFF8FAFC); // Slate 50
  static const Color border = Color(0xFFE2E8F0); // Slate 200
  static const Color borderSubtle = Color(0xFFCBD5E1); // Slate 300
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400

  // Semantic Status Colors
  static const Color statusWaiting = Color(0xFFD97706); // Amber 600
  static const Color statusWaitingBg = Color(0xFFFEF3C7); // Amber 100
  static const Color statusCalled = Color(0xFF2563EB); // Blue 600
  static const Color statusCalledBg = Color(0xFFDBEAFE); // Blue 100
  static const Color statusInConsultation = Color(0xFF0D9488); // Teal 600
  static const Color statusInConsultationBg = Color(0xFFCCFBF1); // Teal 100
  static const Color statusCompleted = Color(0xFF16A34A); // Green 600
  static const Color statusCompletedBg = Color(0xFFDCFCE7); // Green 100
  static const Color statusCancelled = Color(0xFFDC2626); // Red 600
  static const Color statusCancelledBg = Color(0xFFFEE2E2); // Red 100

  // General Semantic Colors
  static const Color success = Color(0xFF16A34A);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);
  static const Color info = Color(0xFF0284C7);
}

/// Standardized Status Badge
class StatusBadge extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    this.icon,
  });

  factory StatusBadge.waiting([String label = 'Waiting']) => StatusBadge(
    label: label,
    textColor: AppColors.statusWaiting,
    backgroundColor: AppColors.statusWaitingBg,
    icon: Icons.hourglass_top,
  );

  factory StatusBadge.called([String label = 'Called']) => StatusBadge(
    label: label,
    textColor: AppColors.statusCalled,
    backgroundColor: AppColors.statusCalledBg,
    icon: Icons.campaign_outlined,
  );

  factory StatusBadge.inConsultation([String label = 'In Consultation']) =>
      StatusBadge(
        label: label,
        textColor: AppColors.statusInConsultation,
        backgroundColor: AppColors.statusInConsultationBg,
        icon: Icons.medical_services_outlined,
      );

  factory StatusBadge.completed([String label = 'Completed']) => StatusBadge(
    label: label,
    textColor: AppColors.statusCompleted,
    backgroundColor: AppColors.statusCompletedBg,
    icon: Icons.check_circle_outline,
  );

  factory StatusBadge.cancelled([String label = 'Cancelled']) => StatusBadge(
    label: label,
    textColor: AppColors.statusCancelled,
    backgroundColor: AppColors.statusCancelledBg,
    icon: Icons.cancel_outlined,
  );

  factory StatusBadge.paid([String label = 'Paid']) => StatusBadge(
    label: label,
    textColor: AppColors.statusCompleted,
    backgroundColor: AppColors.statusCompletedBg,
    icon: Icons.verified_outlined,
  );

  factory StatusBadge.pending([String label = 'Pending']) => StatusBadge(
    label: label,
    textColor: AppColors.statusWaiting,
    backgroundColor: AppColors.statusWaitingBg,
    icon: Icons.pending_outlined,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Standardized Metric KPI Card
class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final Color? iconBackgroundColor;
  final VoidCallback? onTap;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor = AppColors.primary,
    this.iconBackgroundColor,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final hasBoundedHeight = constraints.hasBoundedHeight;
            final headerRow = Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color:
                        iconBackgroundColor ??
                        iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 15, color: iconColor),
                ),
              ],
            );

            final bodyContent = [
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ];

            if (hasBoundedHeight) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  headerRow,
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: bodyContent,
                      ),
                    ),
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                headerRow,
                ...bodyContent,
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Standardized Card Shell
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final String? title;
  final Widget? trailing;
  final Color? backgroundColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.title,
    this.trailing,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null || trailing != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: LayoutBuilder(
                builder: (context, cardHeaderConstraints) {
                  if (cardHeaderConstraints.maxWidth < 420 &&
                      title != null &&
                      trailing != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        trailing!,
                      ],
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (title != null)
                        Flexible(
                          child: Text(
                            title!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      if (title != null && trailing != null)
                        const SizedBox(width: 8),
                      if (trailing != null) trailing!,
                    ],
                  );
                },
              ),
            ),
          if (title != null || trailing != null)
            const Divider(height: 1, thickness: 1, color: AppColors.border),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// Standardized Empty State Component
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(icon, size: 36, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 16),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
