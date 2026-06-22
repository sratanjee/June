import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class JuneColors {
  static const inkNavy = Color(0xFF10182B);
  static const inkNavySoft = Color(0xFF2A3247);
  static const sage = Color(0xFF3B6D5E);
  static const sageSurface = Color(0xFFE3ECE7);
  static const amber = Color(0xFFBA7517);
  static const amberSurface = Color(0xFFF6E8D3);
  static const paper = Color(0xFFFBF8F2);
  static const paperShade = Color(0xFFF3EFE5);
  static const neutralMuted = Color(0xFF6B6760);
  static const hairline = Color(0xFFE7E1D5);
  static const card = Color(0xFFFFFFFF);
}

ThemeData juneTheme() {
  final scheme = ColorScheme(
    brightness: Brightness.light,
    primary: JuneColors.inkNavy,
    onPrimary: JuneColors.paper,
    primaryContainer: JuneColors.paperShade,
    onPrimaryContainer: JuneColors.inkNavy,
    secondary: JuneColors.sage,
    onSecondary: JuneColors.paper,
    secondaryContainer: JuneColors.sageSurface,
    onSecondaryContainer: JuneColors.sage,
    tertiary: JuneColors.amber,
    onTertiary: JuneColors.paper,
    tertiaryContainer: JuneColors.amberSurface,
    onTertiaryContainer: JuneColors.amber,
    error: JuneColors.amber,
    onError: JuneColors.paper,
    surface: JuneColors.paper,
    onSurface: JuneColors.inkNavy,
    surfaceContainerLowest: JuneColors.paper,
    surfaceContainerLow: JuneColors.paper,
    surfaceContainer: JuneColors.paperShade,
    surfaceContainerHigh: JuneColors.card,
    surfaceContainerHighest: JuneColors.card,
    outline: JuneColors.hairline,
    outlineVariant: JuneColors.hairline,
  );

  final lora = GoogleFonts.loraTextTheme();
  final inter = GoogleFonts.interTextTheme();

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: JuneColors.paper,
    splashFactory: InkSparkle.splashFactory,

    appBarTheme: AppBarTheme(
      backgroundColor: JuneColors.paper,
      foregroundColor: JuneColors.inkNavy,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      titleTextStyle: GoogleFonts.lora(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: JuneColors.inkNavy,
        letterSpacing: -0.4,
      ),
    ),

    textTheme: TextTheme(
      // Hero serif display moments — refined down for editorial calm.
      displayLarge: lora.displayLarge?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w500,
        color: JuneColors.inkNavy,
        height: 1.2,
        letterSpacing: -0.6,
      ),
      displayMedium: lora.displayMedium?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: JuneColors.inkNavy,
        height: 1.3,
        letterSpacing: -0.4,
      ),
      headlineMedium: lora.headlineMedium?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: JuneColors.inkNavy,
        height: 1.25,
        letterSpacing: -0.2,
      ),
      bodyLarge: inter.bodyLarge?.copyWith(
        fontSize: 15,
        color: JuneColors.inkNavy,
        height: 1.45,
      ),
      bodyMedium: inter.bodyMedium?.copyWith(
        fontSize: 13,
        color: JuneColors.neutralMuted,
        height: 1.45,
      ),
      labelLarge: inter.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: JuneColors.inkNavy,
        letterSpacing: 0,
      ),
      labelMedium: inter.labelMedium?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: JuneColors.neutralMuted,
        letterSpacing: 1.0,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: JuneColors.card,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: JuneColors.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: JuneColors.hairline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: JuneColors.inkNavy, width: 1.5),
      ),
      labelStyle: GoogleFonts.inter(
        color: JuneColors.neutralMuted,
        fontSize: 13,
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: JuneColors.inkNavy,
        foregroundColor: JuneColors.paper,
        disabledBackgroundColor: JuneColors.paperShade,
        disabledForegroundColor: JuneColors.neutralMuted,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: JuneColors.inkNavy,
        foregroundColor: JuneColors.paper,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    cardTheme: CardThemeData(
      color: JuneColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: JuneColors.hairline),
      ),
      margin: EdgeInsets.zero,
    ),

    dividerTheme: const DividerThemeData(
      color: JuneColors.hairline,
      thickness: 1,
      space: 0,
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: JuneColors.paper,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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

Color severitySurface(String severity) {
  switch (severity) {
    case 'ok':
      return JuneColors.sageSurface;
    case 'attention':
      return JuneColors.amberSurface;
    case 'info':
    default:
      return JuneColors.paperShade;
  }
}
