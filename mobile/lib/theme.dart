import 'package:flutter/material.dart';

class JuneColors {
  static const inkNavy = Color(0xFF10182B);
  static const sage = Color(0xFF3B6D5E);
  static const amber = Color(0xFFBA7517);
  static const paper = Color(0xFFFBF8F2);
  static const neutralMuted = Color(0xFF6B6760);
  static const hairline = Color(0xFFE7E1D5);
}

ThemeData juneTheme() {
  const seedScheme = ColorScheme(
    brightness: Brightness.light,
    primary: JuneColors.inkNavy,
    onPrimary: JuneColors.paper,
    secondary: JuneColors.sage,
    onSecondary: JuneColors.paper,
    tertiary: JuneColors.amber,
    onTertiary: JuneColors.paper,
    error: JuneColors.amber,
    onError: JuneColors.paper,
    surface: JuneColors.paper,
    onSurface: JuneColors.inkNavy,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: seedScheme,
    scaffoldBackgroundColor: JuneColors.paper,
    fontFamily: 'Inter',
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: JuneColors.paper,
      foregroundColor: JuneColors.inkNavy,
      elevation: 0,
      centerTitle: false,
    ),
    textTheme: base.textTheme.copyWith(
      // Serif display face for headline / "standing" moments.
      displayLarge: const TextStyle(
        fontFamily: 'Lora',
        fontSize: 36,
        fontWeight: FontWeight.w500,
        color: JuneColors.inkNavy,
        height: 1.15,
      ),
      headlineMedium: const TextStyle(
        fontFamily: 'Lora',
        fontSize: 24,
        fontWeight: FontWeight.w500,
        color: JuneColors.inkNavy,
        height: 1.25,
      ),
      bodyLarge: const TextStyle(
        fontSize: 16,
        color: JuneColors.inkNavy,
        height: 1.4,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        color: JuneColors.neutralMuted,
        height: 1.4,
      ),
      labelLarge: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: JuneColors.inkNavy,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: JuneColors.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: JuneColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: JuneColors.inkNavy, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: JuneColors.inkNavy,
        foregroundColor: JuneColors.paper,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

Color severityColor(String severity) {
  switch (severity) {
    case 'ok':
      return JuneColors.sage;
    case 'attention':
      return JuneColors.amber;
    case 'info':
    default:
      return JuneColors.neutralMuted;
  }
}
