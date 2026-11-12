import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract class AppTypography {
  /// Font family name registered in pubspec.yaml
  static const String fontFamily = 'Poppins';

  // ---------------------------------------------------------------------------
  // Font Weights
  // ---------------------------------------------------------------------------
  static const FontWeight wExtraLight = FontWeight.w200;
  static const FontWeight wLight = FontWeight.w300;
  static const FontWeight wRegular = FontWeight.w400;
  static const FontWeight wMedium = FontWeight.w500;
  static const FontWeight wSemiBold = FontWeight.w600;
  static const FontWeight wBold = FontWeight.w700;
  static const FontWeight wExtraBold = FontWeight.w800;

  // ---------------------------------------------------------------------------
  // Dynamic Headings & Body Generators
  // ---------------------------------------------------------------------------

  /// Headings (Poppins 600 by default)
  static TextStyle heading(
    double size, {
    Color color = AppColors.text,
    FontWeight weight = wSemiBold,
    double? height,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  /// Body, labels, meta, captions (Poppins 400/500/600)
  static TextStyle body({
    double size = 15,
    FontWeight weight = wRegular,
    Color color = AppColors.text,
    double? height,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  // ---------------------------------------------------------------------------
  // Pre-configured Styles (From Design Specification)
  // ---------------------------------------------------------------------------

  /// Section title: Poppins 600, 19px
  static TextStyle get sectionTitle => heading(19);

  /// Card title: Poppins 600, 16px
  static TextStyle get cardTitle => heading(16);

  /// Body large: Poppins 400, 16px
  static TextStyle get bodyLarge => body(size: 16);

  /// Body regular: Poppins 400, 15px
  static TextStyle get bodyMedium => body(size: 15);

  /// Form labels: Poppins 500, 14px
  static TextStyle get label => body(size: 14, weight: wMedium);

  /// Meta text: Poppins 400, 13px
  static TextStyle get meta => body(size: 13, color: AppColors.secondary);

  /// Captions: Poppins 400, 12px
  static TextStyle get caption => body(size: 12, color: AppColors.secondary);

  /// Primary button text: Poppins 600, 16px, White
  static TextStyle get buttonSemiBold => TextStyle(
    fontFamily: fontFamily,
    color: AppColors.white,
    fontSize: 16,
    fontWeight: wSemiBold,
    height: 1.57,
  );

  /// Figma Dashboard Button Specification:
  /// font-family: Inter;
  /// font-weight: 600 (Semi Bold);
  /// font-size: 14px;
  /// line-height: 20px;
  /// letter-spacing: 1.17% (14 * 0.0117);
  /// text-align: center;
  /// vertical-align: middle;
  static TextStyle figmaButton({Color? color}) => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 14 * 0.0117,
    color: color,
  );
}
