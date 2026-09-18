import 'package:flutter/material.dart';

const finoraInk = Color(0xFF17366B);
const finoraBlue = Color(0xFF2477FF);
const finoraPink = Color(0xFFFF4F8F);
const finoraAqua = Color(0xFF2AC7C4);
const finoraYellow = Color(0xFFFFB83E);
const finoraGreen = Color(0xFF16B979);
const finoraMint = Color(0xFFE6F8F4);
const finoraSoftBlue = Color(0xFFEAF2FF);
const finoraCanvas = Color(0xFFF3F6FA);

ThemeData buildFinoraTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: finoraBlue,
    brightness: Brightness.light,
    surface: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: finoraCanvas,
    fontFamily: 'SF Pro Display',
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        color: finoraInk,
        fontSize: 38,
        height: 1.08,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.4,
      ),
      headlineMedium: TextStyle(
        color: finoraInk,
        fontSize: 28,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.7,
      ),
      titleLarge: TextStyle(
        color: finoraInk,
        fontSize: 21,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
      bodyLarge: TextStyle(
        color: Color(0xFF63718A),
        fontSize: 16,
        height: 1.45,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shadowColor: Color(0x1A17366B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        side: BorderSide(color: Color(0xFFE5EBF3)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFDDE5F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFDDE5F0)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: Colors.white,
      elevation: 8,
      shadowColor: const Color(0x1A17366B),
      indicatorColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? finoraPink
              : const Color(0xFF9AA8BC),
          size: 24,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          color: states.contains(WidgetState.selected)
              ? finoraPink
              : const Color(0xFF8997AA),
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
        );
      }),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFE8EDF4)),
  );
}
