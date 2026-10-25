import 'package:flutter/material.dart';

// Finora design tokens (2026 refresh): a deep ink, an electric blue, soft
// cool surfaces and semantic colours that keep AA contrast on white.
const finoraWhite = Color(0xFFFFFFFF);
const finoraSilver = Color(0xFFCBD5E1);
const finoraSlate = Color(0xFF94A3B8);
const finoraInk = Color(0xFF0F172A);
const finoraBlue = Color(0xFF2F6BFF);

const finoraCanvas = Color(0xFFF4F6FA);
const finoraBorder = Color(0xFFE6EAF0);
const finoraSoftBlue = Color(0xFFEBF1FF);
const finoraMutedInk = Color(0xFF5B6475);
const finoraBlueText = Color(0xFF2456E6);
const finoraGreen = Color(0xFF0B8457);
const finoraMint = Color(0xFFE8F7F0);
const finoraWarning = Color(0xFF9A5B00);
const finoraDanger = Color(0xFFD92D20);

/// Fill for inputs, chips and quiet surfaces.
const finoraFill = Color(0xFFEEF2F7);

/// Brand gradient for the main hero (net worth).
const finoraBrandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF2F6BFF), Color(0xFF5B3FE0)],
);

/// Dark gradient for secondary hero cards (summaries on detail screens).
const finoraInkGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0F172A), Color(0xFF1E2A55)],
);

/// Soft shadow used by hero cards and floating elements.
const finoraShadow = [
  BoxShadow(color: Color(0x1A2F3FBF), blurRadius: 20, offset: Offset(0, 6)),
];

const finoraRadius = 24.0;

/// Monospaced digits so amounts line up and do not jump when they change.
const finoraTabular = [FontFeature.tabularFigures()];

Color finoraAccessibleAccent(Color color) {
  if (color == finoraBlue) return finoraBlueText;
  if (color == finoraSlate || color == finoraSilver) return finoraMutedInk;
  return color;
}

ThemeData buildFinoraTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: finoraBlue,
    brightness: Brightness.light,
    surface: finoraWhite,
  ).copyWith(
    primary: finoraBlue,
    onPrimary: finoraWhite,
    primaryContainer: finoraSoftBlue,
    onPrimaryContainer: finoraBlueText,
    secondary: finoraSlate,
    onSecondary: finoraWhite,
    secondaryContainer: finoraSoftBlue,
    onSecondaryContainer: finoraInk,
    surface: finoraWhite,
    onSurface: finoraInk,
    onSurfaceVariant: finoraMutedInk,
    surfaceContainerHighest: finoraFill,
    outline: finoraSlate,
    outlineVariant: finoraBorder,
    error: finoraDanger,
  );

  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: finoraCanvas,
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        color: finoraInk,
        fontSize: 36,
        height: 1.08,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
      ),
      headlineMedium: TextStyle(
        color: finoraInk,
        fontSize: 28,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      titleLarge: TextStyle(
        color: finoraInk,
        fontSize: 21,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      bodyLarge: TextStyle(
        color: finoraMutedInk,
        fontSize: 16,
        height: 1.45,
      ),
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      color: finoraWhite,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(finoraRadius)),
        side: BorderSide(color: Color(0x0D0F172A)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: finoraBlue,
        foregroundColor: finoraWhite,
        minimumSize: const Size.fromHeight(54),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: finoraInk,
        backgroundColor: finoraWhite,
        minimumSize: const Size(64, 50),
        side: const BorderSide(color: finoraBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: finoraBlueText,
        shape: rounded,
        textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: finoraInk,
      foregroundColor: finoraWhite,
      elevation: 2,
      shape: StadiumBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: finoraFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: finoraBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: finoraDanger),
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: finoraWhite,
      selectedColor: finoraInk,
      secondaryLabelStyle: TextStyle(
        fontFamily: 'Inter',
        color: finoraWhite,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      side: BorderSide(color: finoraBorder),
      shape: StadiumBorder(),
      labelStyle: TextStyle(
        fontFamily: 'Inter',
        color: finoraInk,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      showCheckmark: false,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? finoraInk
              : finoraWhite,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? finoraWhite
              : finoraInk,
        ),
        side: const WidgetStatePropertyAll(BorderSide(color: finoraBorder)),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? finoraBlue : finoraFill,
      ),
      thumbColor: const WidgetStatePropertyAll(finoraWhite),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: finoraBlue,
      inactiveTrackColor: finoraFill,
      thumbColor: finoraBlue,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: finoraBlue,
      linearTrackColor: finoraFill,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: finoraMutedInk,
      titleTextStyle: TextStyle(
        color: finoraInk,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        fontFamily: 'Inter',
      ),
      subtitleTextStyle: TextStyle(
        color: finoraMutedInk,
        fontSize: 13,
        height: 1.35,
        fontFamily: 'Inter',
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: finoraInk,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: finoraInk,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        fontFamily: 'Inter',
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: finoraWhite,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: finoraWhite,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(finoraRadius)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: finoraInk,
      contentTextStyle: const TextStyle(
        color: finoraWhite,
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 70,
      backgroundColor: finoraWhite,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: finoraSoftBlue,
      indicatorShape: const StadiumBorder(),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? finoraBlueText
              : finoraMutedInk,
          size: 24,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          color: states.contains(WidgetState.selected)
              ? finoraInk
              : finoraMutedInk,
          fontSize: 12,
          fontFamily: 'Inter',
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        );
      }),
    ),
    dividerTheme: const DividerThemeData(color: finoraBorder, space: 1),
  );
}
