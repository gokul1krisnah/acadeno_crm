import 'package:flutter/material.dart';

/// Optional watermark wrapper.
///
/// Disabled by default so no background text (`<Staff Name> · ID:<ID>`) is
/// rendered on Home, Lead Details, or Dashboard screens.
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
  Widget build(BuildContext context) => child;
}
