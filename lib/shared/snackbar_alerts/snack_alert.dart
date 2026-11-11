import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class SnackBarAlert {
  static const Color _errorRed = Color(0xFFDC2626);

  /// Compact, slightly-rounded floating snackbar:
  /// - Success (`isWarning: false`): Primary brand color (`#443BCD`) with a tick mark (`✓`).
  /// - Error / Failed (`isWarning: true`): Red (`#DC2626`) with an X mark (`✕`).
  static void showToast({
    required BuildContext context,
    required String message,
    VoidCallback? onTap,
    String? actionText,
    bool isTop = false,
    bool isWarning = false,
    Color? color,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();

    final backgroundColor =
        color ?? (isWarning ? _errorRed : AppColors.primary);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth > 480;

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        elevation: 3,
        width: isWide ? 360 : null,
        margin: isWide
            ? null
            : const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        duration: const Duration(milliseconds: 2400),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(7),
              ),
              alignment: Alignment.center,
              child: Icon(
                isWarning ? Icons.close_rounded : Icons.check_rounded,
                size: 15,
                color: AppColors.white,
              ),
            ),
            const Gap(10),
            Expanded(
              child: Text(
                message,
                style: AppTypography.body(
                  size: 13,
                  weight: FontWeight.w600,
                  color: AppColors.white,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
        action: actionText != null
            ? SnackBarAction(
                label: actionText,
                textColor: AppColors.white,
                onPressed: () {
                  if (onTap != null) onTap();
                },
              )
            : null,
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    showToast(
      context: context,
      message: message,
      isWarning: false,
      color: AppColors.primary,
    );
  }

  static void showError(BuildContext context, String message) {
    showToast(
      context: context,
      message: message,
      isWarning: true,
      color: _errorRed,
    );
  }
}
