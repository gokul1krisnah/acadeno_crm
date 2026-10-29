import 'package:flutter/widgets.dart';

/// A configuration class for the fluid scaling system.
///
/// This singleton class is responsible for holding the screen context and calculating
/// values that scale proportionally between a minimum and maximum screen width.
/// It mimics the behavior of the CSS `clamp()` function to create fluid typography,
/// spacing, and layouts.
class FluidConfig {
  static final FluidConfig _instance = FluidConfig._internal();
  factory FluidConfig() => _instance;
  FluidConfig._internal();

  /// The minimum screen width at which scaling starts. Below this width, values will be clamped to their minimum.
  static const double minWidth = 320;

  /// The maximum screen width at which scaling stops. Above this width, values will be clamped to their maximum.
  static const double maxWidth = 1440;

  BuildContext? _context;

  /// Initializes the [FluidConfig] with the root [BuildContext].
  void init(BuildContext context) {
    _context = context;
  }

  /// The current width of the screen.
  double get screenWidth {
    final ctx = _context;
    if (ctx != null && ctx.mounted) {
      return MediaQuery.sizeOf(ctx).width;
    }
    return minWidth;
  }

  /// Calculates a fluid value that scales linearly between a `min` and `max` value
  /// based on the current screen width, constrained by [minWidth] and [maxWidth].
  double fluid(double min, double max) {
    final width = screenWidth;

    // Clamp to the minimum value if the screen is too narrow.
    if (width <= minWidth) return min;
    // Clamp to the maximum value if the screen is too wide.
    if (width >= maxWidth) return max;

    // Perform linear interpolation for screen widths between the min and max thresholds.
    return min + (max - min) * ((width - minWidth) / (maxWidth - minWidth));
  }
}

/// A static facade for easy access to the fluid scaling utility.
abstract class Fluid {
  /// Initializes the fluid scaling system with a [BuildContext].
  static void init(BuildContext context) => FluidConfig().init(context);

  /// Calculates a fluid value that scales between `min` and `max`.
  static double fluid(double min, double max) => FluidConfig().fluid(min, max);
}
