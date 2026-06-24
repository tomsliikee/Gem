import 'package:flutter/material.dart';

class GlassmorphicTheme {
  // HSL-based dark mode tokens
  static const double primaryH = 244.0;
  static const double primaryS = 1.0;
  static const double primaryL = 0.69;

  static const double secondaryH = 186.0;
  static const double secondaryS = 1.0;
  static const double secondaryL = 0.50;

  static const double surfaceH = 240.0;
  static const double surfaceS = 0.26;
  static const double surfaceL = 0.16;

  static Color get primaryColor => HSLColor.fromAHSL(1.0, primaryH, primaryS, primaryL).toColor();
  static Color get secondaryColor => HSLColor.fromAHSL(1.0, secondaryH, secondaryS, secondaryL).toColor();
  static Color get surfaceColor => HSLColor.fromAHSL(0.1, surfaceH, surfaceS, surfaceL).toColor();

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF0F0F1A),
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
      ),
    );
  }

  // Design constants for glassmorphism panels
  static const double blurSigmaX = 15.0;
  static const double blurSigmaY = 15.0;
  static const Color panelBorderColor = Color(0x33FFFFFF);
  static const Color panelBgColor = Color(0x1AFFFFFF);
  static const BorderRadius panelBorderRadius = BorderRadius.all(Radius.circular(16.0));
  
  static BoxDecoration get glassDecoration {
    return BoxDecoration(
      color: panelBgColor,
      borderRadius: panelBorderRadius,
      border: const Border.fromBorderSide(
        BorderSide(color: panelBorderColor, width: 1.0),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 16.0,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}
