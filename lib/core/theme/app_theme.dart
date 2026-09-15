import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const emerald = Color(0xFF087F5B);
  static const purple = Color(0xFF7950F2);
  static const amber = Color(0xFFF59F00);
  static const softRed = Color(0xFFE8590C);
  static const incomeBlue = Color(0xFF1971C2);

  static ThemeData light() => _theme(
    ColorScheme.fromSeed(
      seedColor: emerald,
      brightness: Brightness.light,
      surface: const Color(0xFFF8FAF9),
    ),
  );

  static ThemeData dark() => _theme(
    ColorScheme.fromSeed(
      seedColor: emerald,
      brightness: Brightness.dark,
      surface: const Color(0xFF101714),
    ),
  );

  static ThemeData _theme(ColorScheme colors) => ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: colors.surface,
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceContainerHighest.withValues(alpha: .45),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w600, color: colors.onSurface),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
  );
}
