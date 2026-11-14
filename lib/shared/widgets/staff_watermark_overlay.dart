import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/router/app_router.dart';

/// Faint, non-interactive tiled diagonal watermark overlay (PR-1.3, PR-1.4).
///
/// Displays Staff Name, Staff ID, and current Date over lead screens to deter
/// unauthorized external camera photography.
class StaffWatermarkOverlay extends StatelessWidget {
  final Widget child;
  final String? staffNameOverride;
  final String? staffIdOverride;

  const StaffWatermarkOverlay({
    super.key,
    required this.child,
    this.staffNameOverride,
    this.staffIdOverride,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final rawName =
        staffNameOverride ??
        user?.displayName?.trim() ??
        (user?.email != null ? user!.email!.split('@').first : null) ??
        (isAdminSession ? 'Super Admin' : 'Staff');
    final rawUid = staffIdOverride ?? user?.uid ?? 'ACADENO';
    final shortId = rawUid.length > 6
        ? rawUid.substring(0, 6).toUpperCase()
        : rawUid.toUpperCase();
    final dateStr = DateFormat('dd MMM yyyy').format(DateTime.now());
    final watermarkText = '$rawName · ID:$shortId · $dateStr';

    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _TiledWatermarkPainter(text: watermarkText),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TiledWatermarkPainter extends CustomPainter {
  final String text;

  const _TiledWatermarkPainter({required this.text});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || text.isEmpty) return;

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0x090F172A), // ~3.5% opacity — faint & non-intrusive
          letterSpacing: 0.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const double stepX = 260;
    const double stepY = 150;
    const double angle = -math.pi / 7; // ~-25 degrees

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    for (double y = -40; y < size.height + stepY; y += stepY) {
      final rowShift = ((y ~/ stepY).isOdd) ? (stepX / 2) : 0.0;
      for (double x = -80 + rowShift; x < size.width + stepX; x += stepX) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(angle);
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TiledWatermarkPainter oldDelegate) {
    return oldDelegate.text != text;
  }
}

