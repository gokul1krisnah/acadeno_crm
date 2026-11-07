import 'package:flutter/material.dart';

import 'fluid_config.dart';

/// A [SizedBox] that uses the fluid scaling utility to create a responsive container.
///
/// The `FluidBox` smoothly scales its `height` and `width` between minimum and
/// maximum values based on the screen width.
class FluidBox extends StatelessWidget {
  /// The maximum height the box can have.
  final double maxHeight;

  /// The minimum height the box can have.
  final double minHeight;

  /// The maximum width the box can have.
  final double maxWidth;

  /// The minimum width the box can have.
  final double minWidth;

  /// The widget to display inside the box.
  final Widget? child;

  /// Creates a responsive box with separate height and width constraints.
  const FluidBox({
    required this.maxHeight,
    required this.minHeight,
    required this.maxWidth,
    required this.minWidth,
    this.child,
    super.key,
  });

  /// A convenience constructor for creating a square-shaped responsive box.
  const FluidBox.square({
    required double maxSize,
    required double minSize,
    super.key,
    this.child,
  }) : maxHeight = maxSize,
       maxWidth = maxSize,
       minHeight = minSize,
       minWidth = minSize;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: Fluid.fluid(minHeight, maxHeight),
    width: Fluid.fluid(minWidth, maxWidth),
    child: child,
  );
}
