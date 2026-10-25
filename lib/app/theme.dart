import 'package:flutter/material.dart';

// Finora design tokens: neutral greys (zinc), one calm accent blue and
// semantic colours with AA contrast on white. Kept deliberately sober so the
// same tokens work in other contexts (web, documents, partner screens).
const finoraWhite = Color(0xFFFFFFFF);
const finoraSilver = Color(0xFFD4D4D8);
const finoraSlate = Color(0xFFA1A1AA);
const finoraInk = Color(0xFF18181B);
const finoraBlue = Color(0xFF2B59C3);

const finoraCanvas = Color(0xFFF7F7F8);
const finoraBorder = Color(0xFFE4E4E7);
const finoraSoftBlue = Color(0xFFEEF2FA);
const finoraMutedInk = Color(0xFF52525B);
const finoraBlueText = Color(0xFF2450B5);
const finoraGreen = Color(0xFF15803D);
const finoraMint = Color(0xFFF0F7F2);
const finoraWarning = Color(0xFFA16207);
const finoraDanger = Color(0xFFB91C1C);

/// Fill for inputs, chips and quiet surfaces.
const finoraFill = Color(0xFFF1F1F3);

/// Graphite for the main hero (net worth): a barely visible gradient.
const finoraBrandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF18181B), Color(0xFF2E2E33)],
);

/// Same graphite for summary cards on detail screens.
const finoraInkGradient = finoraBrandGradient;

/// Subtle neutral shadow for raised elements.
const finoraShadow = [
  BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
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
      selectedColor: finoraInk,
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
      indicatorColor: finoraFill,
      indicatorShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(finoraRadiusControl)),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? finoraInk
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
