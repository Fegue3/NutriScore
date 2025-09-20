// lib/core/theme.dart
import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const freshGreen = Color(0xFF4CAF6D);
  static const warmTangerine = Color(0xFFFF8A4C);
  static const leafyGreen = Color(0xFF66BB6A);
  static const goldenAmber = Color(0xFFFFC107);
  static const ripeRed = Color(0xFFE53935);

  // Neutrals
  static const charcoal = Color(0xFF333333);
  static const coolGray = Color(0xFF666666);
  static const softOffWhite = Color(0xFFFAFAF7);
  static const lightSage = Color(0xFFE8F5E9);
}

class AppText {
  static const String headingsFamily = 'Nunito Sans';
  static const String bodyFamily = 'Inter';
  static const String numericFamily = 'Roboto Mono';

  static TextTheme textTheme = TextTheme(
    // H1 – 32 / bold / 120%
    displaySmall: const TextStyle(
      fontFamily: headingsFamily,
      fontSize: 32,
      height: 1.2,
      fontWeight: FontWeight.w700,
      color: AppColors.charcoal,
    ),
    // H2 – 24 / semibold / 130%
    headlineMedium: const TextStyle(
      fontFamily: headingsFamily,
      fontSize: 24,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: AppColors.charcoal,
    ),
    // H3 – 20 / medium / 130%
    titleLarge: const TextStyle(
      fontFamily: headingsFamily,
      fontSize: 20,
      height: 1.3,
      fontWeight: FontWeight.w500,
      color: AppColors.charcoal,
    ),
    // Body – 16 / regular / 150%
    bodyLarge: const TextStyle(
      fontFamily: bodyFamily,
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: AppColors.charcoal,
    ),
    // Small – 14 / regular / 150%
    bodyMedium: const TextStyle(
      fontFamily: bodyFamily,
      fontSize: 14,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: AppColors.coolGray,
    ),
    // Caption/Label – 12 / medium / 140%
    labelSmall: const TextStyle(
      fontFamily: bodyFamily,
      fontSize: 12,
      height: 1.4,
      fontWeight: FontWeight.w500,
      color: AppColors.coolGray,
    ),
  ).apply(
    fontFamily: bodyFamily,
    bodyColor: AppColors.charcoal,
    displayColor: AppColors.charcoal,
  );

  static const TextStyle numeric = TextStyle(
    fontFamily: numericFamily,
    fontSize: 18,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: AppColors.charcoal,
  );
}

class AppShapes {
  static const radius16 = 16.0;
  static const pill24 = 24.0;

  static final cardShape =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius16));
  static final pillShape =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(pill24));
}

// Helper para estados (WidgetState/WidgetStateProperty)
T _resolve<T>(Set<WidgetState> states, T normal, T pressed) {
  if (states.contains(WidgetState.pressed) || states.contains(WidgetState.focused)) {
    return pressed;
  }
  return normal;
}

class NutriTheme {
  // usa final para evitar aviso do linter
  static final ColorScheme _scheme = const ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.freshGreen,
    onPrimary: Colors.white,
    secondary: AppColors.warmTangerine,
    onSecondary: Colors.white,
    tertiary: AppColors.leafyGreen,
    onTertiary: Colors.white,
    error: AppColors.ripeRed,
    onError: Colors.white,

    // Em vez de background/onBackground (deprecated),
    // usa surface/onSurface como superfícies padrão claras.
    surface: AppColors.softOffWhite,
    onSurface: AppColors.charcoal,

    // Estes campos continuam válidos
    outline: AppColors.coolGray,
    shadow: Colors.black,
    surfaceTint: AppColors.freshGreen,

    // Campos opcionais modernos (mantidos coerentes)
    surfaceContainerHighest: Colors.white,
    surfaceContainerHigh: Colors.white,
    surfaceContainer: AppColors.softOffWhite,
    surfaceContainerLow: AppColors.softOffWhite,
    surfaceContainerLowest: AppColors.softOffWhite,
  );

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _scheme,
      scaffoldBackgroundColor: AppColors.softOffWhite,
      visualDensity: VisualDensity.standard,

      // Tipografia
      textTheme: AppText.textTheme,

      // AppBar claro, alinhado às guidelines
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.softOffWhite,
        foregroundColor: AppColors.charcoal,
        elevation: 0,
        centerTitle: false,
      ),

      // Cards → agora CardThemeData (não CardTheme)
      cardTheme: CardThemeData(
        color: AppColors.lightSage,
        elevation: 4,
        shadowColor: Colors.black54.withAlpha(13), // ~0.05 alpha
        shape: AppShapes.cardShape,
        margin: EdgeInsets.zero,
      ),

      // Primary Button (CTA) — Fresh Green, Nunito 16 Bold, Pill 24
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => _resolve(s, AppColors.freshGreen, const Color(0xFF388E3C)),
          ),
          foregroundColor: const WidgetStatePropertyAll<Color>(Colors.white),
          textStyle: const WidgetStatePropertyAll<TextStyle>(
            TextStyle(
              fontFamily: AppText.headingsFamily,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(AppShapes.pillShape),
          padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          // evita .withOpacity() deprecado — usa alpha direto
          overlayColor: WidgetStatePropertyAll<Color>(Colors.white70.withAlpha(15)),
        ),
      ),

      // Secondary Button — Warm Tangerine, Nunito 16 SemiBold, Pill 24
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: const WidgetStatePropertyAll<Color>(AppColors.warmTangerine),
          foregroundColor: const WidgetStatePropertyAll<Color>(Colors.white),
          textStyle: const WidgetStatePropertyAll<TextStyle>(
            TextStyle(
              fontFamily: AppText.headingsFamily,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(AppShapes.pillShape),
          padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),

      // Ghost Button — borda 2px Fresh Green, Inter 16
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          side: const WidgetStatePropertyAll<BorderSide>(
            BorderSide(color: AppColors.freshGreen, width: 2),
          ),
          foregroundColor: const WidgetStatePropertyAll<Color>(AppColors.freshGreen),
          textStyle: const WidgetStatePropertyAll<TextStyle>(
            TextStyle(
              fontFamily: AppText.bodyFamily,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(AppShapes.pillShape),
          padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),

      // FAB — círculo 56, ícone branco
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.freshGreen,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
        elevation: 6,
      ),

      // Bottom Navigation — fundo semitransparente, ativo verde, inativo cinza
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xEEFFFFFF),
        indicatorColor: AppColors.freshGreen.withAlpha(31), // ~0.12
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.freshGreen : AppColors.coolGray,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: AppText.bodyFamily,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? AppColors.freshGreen : AppColors.coolGray,
          );
        }),
        elevation: 0,
        height: 64,
      ),

      // Inputs
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: TextStyle(fontFamily: AppText.bodyFamily, color: AppColors.coolGray),
        labelStyle: TextStyle(fontFamily: AppText.bodyFamily, color: AppColors.coolGray),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.coolGray, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.freshGreen, width: 2),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.leafyGreen,
      ),

      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.ripeRed,
        contentTextStyle: TextStyle(fontFamily: AppText.bodyFamily, color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
