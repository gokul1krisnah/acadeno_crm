import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

/// External push & in-app notification banner matching Figma node 1824:1634
/// ("Article - Item 2: Reminder").
///
/// Features:
/// - Rounded dark glassmorphic capsule with 36px border radius
/// - 0.9 opacity white border and dual diffuse elevation shadows
/// - 52x52 circular peach/orange radial gradient badge with bell icon
/// - Plus Jakarta Sans Bold 16.5px title (#FDFDFD) and Medium 10px body (white)
/// - Responsive sizing suitable for mobile screens with interactive tap & dismiss
class AcadenoExternalNotificationBanner extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const AcadenoExternalNotificationBanner({
    super.key,
    required this.title,
    required this.body,
    this.onTap,
    this.onDismiss,
  });

  /// Displays the Figma notification banner using [ScaffoldMessengerState.showSnackBar].
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? show({
    required BuildContext context,
    required String title,
    required String body,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 5),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return null;
    messenger.hideCurrentSnackBar();
    return messenger.showSnackBar(
      SnackBar(
        content: AcadenoExternalNotificationBanner(
          title: title,
          body: body,
          onTap: onTap,
          onDismiss: () => messenger.hideCurrentSnackBar(),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        duration: duration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 390,
          minWidth: 280,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(36),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF000000),
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2E8C95A5),
                        blurRadius: 28,
                        offset: Offset(0, 14),
                        spreadRadius: -4,
                      ),
                      BoxShadow(
                        color: Color(0x148C95A5),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Circular Badge (52x52, border #EA580C, radial gradient, bell asset)
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFEA580C),
                            width: 1,
                          ),
                          gradient: const RadialGradient(
                            center: Alignment(0, -0.2),
                            radius: 0.9,
                            colors: [
                              Colors.white,
                              Color(0xFFFFEEDD),
                              Color(0xFFFEDFC4),
                            ],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1AF97316),
                              blurRadius: 3,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Image.asset(
                          'assets/images/notification_bell_badge.png',
                          width: 30,
                          height: 30,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.notifications_active_rounded,
                            size: 26,
                            color: Color(0xFFEA580C),
                          ),
                        ),
                      ),
                      const Gap(14),
                      // Text Content (Title & Body)
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFFDFDFD),
                                letterSpacing: -0.4125,
                                height: 20.63 / 16.5,
                              ),
                            ),
                            if (body.isNotEmpty) ...[
                              const Gap(3),
                              Text(
                                body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                  height: 15 / 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (onDismiss != null) ...[
                        const Gap(8),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white70,
                            size: 18,
                          ),
                          onPressed: onDismiss,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
