import 'package:flutter/material.dart';

// Finora design tokens, built on the brand palette
//   #014164 navy · #027DB9 blue · #EFEDEC warm grey · #8899A2 slate · #FFFFFF
// in a light, fresh direction: warm off-white canvas, white cards, navy
// text and one bright blue accent. Derived shades keep AA contrast.
const finoraWhite = Color(0xFFFFFFFF);
const finoraNavy = Color(0xFF014164);
const finoraWarmGrey = Color(0xFFEFEDEC);

/// Light text on blue and navy surfaces.
const finoraSilver = Color(0xFFCFE3EE);

/// Brand slate, for icons, dividers and decoration (not for small text).
const finoraSlate = Color(0xFF8899A2);

/// Main text colour: the brand navy.
const finoraInk = finoraNavy;

/// Accent: the brand blue (4.6:1 on white).
const finoraBlue = Color(0xFF027DB9);

const finoraCanvas = Color(0xFFF7F6F5);
const finoraBorder = Color(0xFFE4E1DF);
const finoraSoftBlue = Color(0xFFE6F2F8);

/// Secondary text: a darker slate that stays readable on white.
const finoraMutedInk = Color(0xFF55666F);
const finoraBlueText = Color(0xFF026A9E);
const finoraGreen = Color(0xFF12805C);
const finoraMint = Color(0xFFE7F5EF);
const finoraWarning = Color(0xFFA15C07);
const finoraDanger = Color(0xFFC0392B);

/// Fill for inputs, chips and quiet surfaces: the brand warm grey.
const finoraFill = finoraWarmGrey;

/// Bright blue for the main hero (net worth).
const finoraBrandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF027DB9), Color(0xFF1597D3)],
);

/// Navy to blue for summary cards on detail screens.
const finoraInkGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF014164), Color(0xFF02608F)],
);

/// Subtle neutral shadow for raised elements.
const finoraShadow = [
  BoxShadow(color: Color(0x1A014164), blurRadius: 16, offset: Offset(0, 6)),
];

/// Corner radii: cards and sheets, controls, and small tags.
const finoraRadius = 12.0;
const finoraRadiusControl = 10.0;
const finoraRadiusSmall = 6.0;

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
    borderRadius: BorderRadius.circular(finoraRadiusControl),
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
        side: BorderSide(color: finoraBorder),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: finoraBlue,
        foregroundColor: finoraWhite,
        minimumSize: const Size.fromHeight(54),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(finoraRadiusControl),
        ),
        textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: finoraInk,
        backgroundColor: finoraWhite,
        minimumSize: const Size(64, 50),
        side: const BorderSide(color: finoraBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(finoraRadiusControl),
        ),
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
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(finoraRadius)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: finoraFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(finoraRadiusControl),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(finoraRadiusControl),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(finoraRadiusControl),
        borderSide: const BorderSide(color: finoraBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(finoraRadiusControl),
        borderSide: const BorderSide(color: finoraDanger),
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: finoraWhite,
      selectedColor: finoraBlue,
      secondaryLabelStyle: TextStyle(
        fontFamily: 'Inter',
        color: finoraWhite,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      side: BorderSide(color: finoraBorder),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(finoraRadiusSmall + 2)),
      ),
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
              ? finoraBlue
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(finoraRadiusControl),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 70,
      backgroundColor: finoraWhite,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: finoraSoftBlue,
      indicatorShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(finoraRadiusControl)),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? finoraBlue
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
