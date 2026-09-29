import 'package:flutter/material.dart';

// Core palette supplied for the Finora visual refresh.
const finoraWhite = Color(0xFFFFFFFF);
const finoraSilver = Color(0xFFC2CACC);
const finoraSlate = Color(0xFF7C8182);
const finoraInk = Color(0xFF272829);
const finoraBlue = Color(0xFF3C94FF);

// Derived surfaces and semantic colours keep the five-colour palette usable
// across states without relying on colour alone.
const finoraCanvas = Color(0xFFF4F6F7);
const finoraBorder = Color(0xFFDDE2E3);
const finoraSoftBlue = Color(0xFFEAF3FF);
const finoraMutedInk = Color(0xFF5F6364);
const finoraBlueText = Color(0xFF006EDC);
const finoraGreen = Color(0xFF18875D);
const finoraMint = Color(0xFFEAF6F1);
const finoraWarning = Color(0xFF8A5A00);
const finoraDanger = Color(0xFFB3261E);

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
    onPrimary: finoraInk,
    secondary: finoraSlate,
    onSecondary: finoraInk,
    surface: finoraWhite,
    onSurface: finoraInk,
    outline: finoraSlate,
    outlineVariant: finoraSilver,
    error: finoraDanger,
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
        color: finoraMutedInk,
        fontSize: 16,
        height: 1.45,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: finoraWhite,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shadowColor: Color(0x1A272829),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        side: BorderSide(color: finoraBorder),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: finoraBlue,
        foregroundColor: finoraInk,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: finoraWhite,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: finoraSilver),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: finoraSilver),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: finoraBlue, width: 2),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: finoraInk,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: finoraBlueText),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: finoraBlueText,
        side: const BorderSide(color: finoraSilver),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: finoraWhite,
      elevation: 8,
      shadowColor: const Color(0x1A272829),
      indicatorColor: Colors.transparent,
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
              ? finoraBlueText
              : finoraMutedInk,
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
        );
      }),
    ),
    dividerTheme: const DividerThemeData(color: finoraBorder),
  );
}
