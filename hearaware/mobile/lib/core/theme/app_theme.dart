import 'package:flutter/material.dart';

/// High-contrast dark theme. Meaning is never carried by colour alone:
/// every state also has an icon and a text label.
class AppColors {
  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF15151A);
  static const surfaceHi = Color(0xFF23232B);
  static const accent = Color(0xFFFFD60A);
  static const onAccent = Color(0xFF000000);
  static const danger = Color(0xFFFF453A);
  static const ok = Color(0xFF32D74B);
  static const text = Color(0xFFFFFFFF);
  static const textDim = Color(0xFFC7C7CC);
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: AppColors.onAccent,
    surface: AppColors.surface,
    error: AppColors.danger,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.text),
      headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.text),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text),
      bodyLarge: TextStyle(fontSize: 18, color: AppColors.text),
      bodyMedium: TextStyle(fontSize: 16, color: AppColors.textDim),
    ),
    appBarTheme: const AppBarTheme(backgroundColor: AppColors.bg, foregroundColor: AppColors.text),
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}
