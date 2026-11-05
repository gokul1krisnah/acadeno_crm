import 'package:flutter/material.dart';

abstract class AppColors {
  // ---------------------------------------------------------------------------
  // Acadeno CRM Brand Colors
  // ---------------------------------------------------------------------------
  static const Color primary = Color(0xFFEF8144); // Primary Vibrant Orange
  static const Color indigo = Color(0xFF443BCD); // Primary
  static const Color blue = Color(0xFF3380D9); // Info, charts
  static const Color orange = Color(0xFFEF8144); // Attention / Primary
  static const Color amber = Color(0xFFF9B23E); // Highlight
  static const Color coral = Color(0xFFDF5464); // Brand accent / Error

  // Neutral / Layout tokens
  static const Color text = Color(0xFF1B1D2E); // Dark text
  static const Color secondary = Color(0xFF5A5F73); // Muted text / icons
  static const Color border = Color(0xFFE4E6EF); // Dividers & borders
  static const Color ground = Color(0xFFF6F7FB); // Surface / card background
  static const Color tonal = Color(0xFFECEBFA); // Tinted indigo background

  // ---------------------------------------------------------------------------
  // Standard UI Colors
  // ---------------------------------------------------------------------------
  static const Color white = Color(0xFFFFFFFF);
  static const Color solidWhite = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Colors.transparent;
  static const Color fullyTransparent = Color(0x00FFFFFF);
  static const Color semiTransparent = Color(0xCCFFFFFF);
  static const Color lighterFade = Color(0x66FFFFFF);
  static const Color white0 = Color.fromARGB(0, 255, 253, 253);

  static const Color errorRed = Color(0xFFDF5464);
  static const Color green = Color(0xFF22C55E);
  static const Color green2 = Color(0xFF81C974);
  static const Color green3 = Color(0xFF6DCDA0);
  static const Color green4 = Color(0xFF6DCDA0);

  // Greys & Borders
  static const Color grey = Color(0xFFA1A0A0);
  static const Color grey5 = Color(0xFFA7A7A7);
  static const Color greyText = Color(0xFF5A5F73);
  static const Color lightGrey = Color(0x4DBDBFC0);
  static const Color lightGrey2 = Color(0xFF484848);
  static const Color hintText = Color(0xFFA7A7A7);
  static const Color primaryBorder = Color(0xFFE4E6EF);
  static const Color borderColor = Color(0xFFE4E6EF);
  static const Color border2 = Color(0xFF7D7D7D);
  static const Color borderF0 = Color(0xFFF0F0F0);
  static const Color editBorderColor = Color(0xFFE9EBED);
  static const Color editLabelColor = Color(0xFF8E8E8E);

  // Black variants
  static const Color textBlack = Color(0xFF1B1D2E);
  static const Color textBlack2 = Color(0xFF121111);
  static const Color textBlack3 = Color(0xFF0C0C0C);
  static const Color textBlack4 = Color(0xFF171717);
  static const Color textBlack5 = Color(0X1A292D32);
  static const Color textBlack6 = Color(0xFF777777);
  static const Color textBlack7 = Color(0xFF2C2C2C);
  static const Color textBlack8 = Color(0xFF484848);
  static const Color black3 = Color.fromARGB(30, 0, 0, 0);
  static const Color black5 = Color(0xFF484848);
  static const Color black6 = Color(0xFF292D32);
  static const Color black7 = Color(0xFF1D1D1D);
  static const Color black8 = Color(0xFF222B45);
  static const Color black9 = Color(0xFF171717);
  static const Color black10 = Color(0xFF2C2C2C);

  // Text colors
  static const Color textColor3 = Color(0xFF292D32);
  static const Color textColor4 = Color(0xFF6B779A);
  static const Color textColor5 = Color(0xFF222B45);
  static const Color kTextGrey = Color(0xFF5A5F73);
  static const Color kTextGrey2 = Color(0xFF484848);
  static const Color kTextGrey3 = Color(0xFF777777);
  static const Color kTextGrey4 = Color(0xFF7D7D7D);
  static const Color textGrey4 = Color(0xFF484848);
  static const Color tabText = Color(0xFF78828A);

  // Component colors
  static const Color textFieldWhite = Color(0xFFFFFFFF);
  static const Color iconBlue = Color(0xFF3380D9);
  static const Color buttonPrimary = primary;
  static const Color buttonText = Color(0xFFFFFFFF);
  static const Color buttonHover = Color(0xFFECEBFA);
  static const Color navBgUnselected = Color(0x0A777777);
  static const Color navBgSelected = Color(0xFFECEBFA);
  static const Color navBarShadow = Color(0x0A400A76);
  static const Color notificationDivider = Color(0xFFECEDF2);
  static const Color locationAppBarGrey = Color(0xFF595D62);
  static const Color switchGrey2 = Color(0xFFE9EAEB);

  // Shimmer & Shadows
  static const Color shimmerBase = Color(0xFFE0E0E0);
  static const Color progressBg = Color(0xFF6C6C6C);
  static const Color shadow2 = Color(0x4DBDBFC0);
  static const Color shadow3 = Color(0xFFE0E0E0);
  static const Color shadow4 = Color(0X1A443BCD);
  static const Color boxShadow = Color(0x0D0F0F0F);
  static const Color linearGradient = Color.fromARGB(0, 255, 255, 255);
}
