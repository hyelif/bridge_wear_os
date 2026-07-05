import 'package:flutter/material.dart';

class ResponsiveTheme {
  static const double _fontSmall = 11.0;
  static const double _fontMedium = 13.0;
  static const double _fontLarge = 15.0;
  static const double _fontXlarge = 17.0;

  static ThemeData getTheme(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final _SizeTier tier = _sizeTier(screenWidth);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1565C0),
        brightness: Brightness.dark,
        surface: const Color(0xFF000000),
        onSurface: const Color(0xFFE0E0E0),
        primary: const Color(0xFF64B5F6),
        onPrimary: const Color(0xFF000000),
        secondary: const Color(0xFF4DD0E1),
        onSecondary: const Color(0xFF000000),
        error: const Color(0xFFEF5350),
        outline: const Color(0xFF424242),
      ),
      scaffoldBackgroundColor: const Color(0xFF000000),
      textTheme: TextTheme(
        displayLarge: TextStyle(fontSize: _fontXlarge * 1.8, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(fontSize: _fontXlarge * 1.4, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(fontSize: _fontLarge * 1.3, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(fontSize: _fontLarge * 1.1, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontSize: _fontLarge, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: _fontMedium, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(fontSize: _fontMedium),
        bodyMedium: TextStyle(fontSize: _fontSmall),
        bodySmall: TextStyle(fontSize: _fontSmall * 0.85),
        labelLarge: TextStyle(fontSize: _fontSmall, fontWeight: FontWeight.w500),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xF01E1E1E),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.all(tier.spacing * 0.5),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(fontSize: _fontMedium, fontWeight: FontWeight.bold),
        iconTheme: IconThemeData(size: tier.iconSize),
      ),
      iconTheme: IconThemeData(size: tier.iconSize),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.all(tier.spacing),
        hintStyle: TextStyle(fontSize: _fontSmall, color: Colors.white38),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF64B5F6),
          foregroundColor: Colors.black,
          padding: EdgeInsets.symmetric(horizontal: tier.spacing * 2, vertical: tier.spacing),
          minimumSize: Size(double.infinity, tier.iconSize * 2),
          textStyle: TextStyle(fontSize: _fontSmall, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: tier.spacing, vertical: tier.spacing * 0.5),
          minimumSize: Size(tier.iconSize * 4, tier.iconSize * 1.5),
          textStyle: TextStyle(fontSize: _fontSmall * 0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.1),
        labelStyle: TextStyle(fontSize: _fontSmall, color: Colors.white),
        padding: EdgeInsets.symmetric(horizontal: tier.spacing, vertical: tier.spacing * 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xF01E1E1E),
        contentTextStyle: TextStyle(fontSize: _fontSmall),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.1),
        thickness: 0.5,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: const Color(0xFF64B5F6),
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static _SizeTier _sizeTier(double width) {
    if (width < 200) return _SizeTier.small;
    if (width < 280) return _SizeTier.medium;
    if (width < 360) return _SizeTier.large;
    return _SizeTier.xlarge;
  }
}

class _SizeTier {
  final double fontSize;
  final double spacing;
  final double iconSize;
  final double borderRadius;

  const _SizeTier._({
    required this.fontSize,
    required this.spacing,
    required this.iconSize,
    required this.borderRadius,
  });

  static const small = _SizeTier._(fontSize: 10, spacing: 4, iconSize: 16, borderRadius: 6);
  static const medium = _SizeTier._(fontSize: 12, spacing: 6, iconSize: 20, borderRadius: 8);
  static const large = _SizeTier._(fontSize: 14, spacing: 8, iconSize: 24, borderRadius: 10);
  static const xlarge = _SizeTier._(fontSize: 16, spacing: 10, iconSize: 28, borderRadius: 12);
}
