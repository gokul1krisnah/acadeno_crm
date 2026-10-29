import 'package:flutter/material.dart';

extension SafePaddingExtension on BuildContext {
  double get safeBottom => MediaQuery.paddingOf(this).bottom + 100;

  double get safeBottomStrict => MediaQuery.paddingOf(this).bottom;

  double get safeTopStrict => MediaQuery.paddingOf(this).top;

  double get devicePadding =>
      (MediaQuery.sizeOf(this).width * 0.05).clamp(16, 24);

  TextTheme get textTheme => Theme.of(this).textTheme;

  double get deviceHeight => MediaQuery.sizeOf(this).height;
  double get deviceWidth => MediaQuery.sizeOf(this).width;
  double get bottomInset => MediaQuery.viewInsetsOf(this).bottom;

  EdgeInsets get deviceSafePadding => MediaQuery.paddingOf(this);
  EdgeInsets get deviceInset => MediaQuery.viewInsetsOf(this);

  double dynamicHeight(double heightRatio) => deviceHeight * heightRatio;
  double dynamicWidth(double widthRatio) => deviceWidth * widthRatio;
}
