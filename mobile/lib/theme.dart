import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------- PALETTE SWITCH ----------
// Flip this single line to A/B/C between the visual options.
//
// JunePalette.calm  — Option 1: editorial calm (warm paper, deep ink navy,
//                     muted sage / burnt amber). Personality-spec-native.
// JunePalette.bold  — Option 2: bold fintech (pure white, pure black,
//                     Cash App / Robinhood electric green, iOS orange).
// JunePalette.warm  — Option 3: warm coral (cream paper, warm charcoal,
//                     Airbnb coral attention, muted teal ok).
//
const JunePalette _palette = JunePalette.warm;

enum JunePalette { calm, bold, warm }

class _CalmPalette {
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

class _BoldPalette {
  static const inkNavy = Color(0xFF0A0A0A);       // true near-black
  static const inkNavySoft = Color(0xFF1C1C1E);   // iOS dark surface
  static const sage = Color(0xFF00C853);          // electric green
  static const sageSurface = Color(0xFFE0FCE6);
  static const amber = Color(0xFFFF9500);         // iOS orange
  static const amberSurface = Color(0xFFFFF1DC);
  static const paper = Color(0xFFFFFFFF);
  static const paperShade = Color(0xFFF5F5F7);    // Apple silver
  static const neutralMuted = Color(0xFF6E6E73);  // iOS neutral
  static const hairline = Color(0xFFE5E5E7);
  static const card = Color(0xFFFFFFFF);
}

class _WarmPalette {
  static const inkNavy = Color(0xFF1F1816);       // warm charcoal (not navy, not black)
  static const inkNavySoft = Color(0xFF3A2F2C);   // softer warm dark
  static const sage = Color(0xFF4E9A8C);          // muted warm teal (savings, ok)
  static const sageSurface = Color(0xFFDCEDE9);
  static const amber = Color(0xFFE45D52);         // coral red — friendly attention
  static const amberSurface = Color(0xFFFCE3DF);
  static const paper = Color(0xFFFAF5EE);         // warm cream
  static const paperShade = Color(0xFFF0E8DA);    // soft dust
  static const neutralMuted = Color(0xFF7A6E66);  // warm gray
  static const hairline = Color(0xFFE7DDCB);
  static const card = Color(0xFFFFFCF6);          // cream white
}

class JuneColors {
  static const inkNavy = _palette == JunePalette.bold
      ? _BoldPalette.inkNavy
      : (_palette == JunePalette.warm
          ? _WarmPalette.inkNavy
          : _CalmPalette.inkNavy);
  static const inkNavySoft = _palette == JunePalette.bold
      ? _BoldPalette.inkNavySoft
      : (_palette == JunePalette.warm
          ? _WarmPalette.inkNavySoft
          : _CalmPalette.inkNavySoft);
  static const sage = _palette == JunePalette.bold
      ? _BoldPalette.sage
      : (_palette == JunePalette.warm
          ? _WarmPalette.sage
          : _CalmPalette.sage);
  static const sageSurface = _palette == JunePalette.bold
      ? _BoldPalette.sageSurface
      : (_palette == JunePalette.warm
          ? _WarmPalette.sageSurface
          : _CalmPalette.sageSurface);
  static const amber = _palette == JunePalette.bold
      ? _BoldPalette.amber
      : (_palette == JunePalette.warm
          ? _WarmPalette.amber
          : _CalmPalette.amber);
  static const amberSurface = _palette == JunePalette.bold
      ? _BoldPalette.amberSurface
      : (_palette == JunePalette.warm
          ? _WarmPalette.amberSurface
          : _CalmPalette.amberSurface);
  static const paper = _palette == JunePalette.bold
      ? _BoldPalette.paper
      : (_palette == JunePalette.warm
          ? _WarmPalette.paper
          : _CalmPalette.paper);
  static const paperShade = _palette == JunePalette.bold
      ? _BoldPalette.paperShade
      : (_palette == JunePalette.warm
          ? _WarmPalette.paperShade
          : _CalmPalette.paperShade);
  static const neutralMuted = _palette == JunePalette.bold
      ? _BoldPalette.neutralMuted
      : (_palette == JunePalette.warm
          ? _WarmPalette.neutralMuted
          : _CalmPalette.neutralMuted);
  static const hairline = _palette == JunePalette.bold
      ? _BoldPalette.hairline
      : (_palette == JunePalette.warm
          ? _WarmPalette.hairline
          : _CalmPalette.hairline);
  static const card = _palette == JunePalette.bold
      ? _BoldPalette.card
      : (_palette == JunePalette.warm
          ? _WarmPalette.card
          : _CalmPalette.card);
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
