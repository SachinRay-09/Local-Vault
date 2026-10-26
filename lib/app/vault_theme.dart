import 'package:flutter/material.dart';

/// Builds the app [ThemeData] from a [ColorScheme]. Used for both the light
/// and dark themes; only the [scheme] brightness differs.
ThemeData buildVaultTheme(ColorScheme scheme) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardTheme(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: scheme.surfaceContainerHigh,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      actionTextColor: scheme.inversePrimary,
    ),
    progressIndicatorTheme:
        ProgressIndicatorThemeData(color: scheme.primary),
    dividerColor: scheme.outlineVariant,
  );
}

/// Converts a persisted theme-mode string into a [ThemeMode].
/// Any unrecognized value falls back to [ThemeMode.system].
ThemeMode parseThemeMode(String raw) {
  switch (raw) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}
