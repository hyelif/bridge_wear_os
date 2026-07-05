import 'package:flutter/material.dart';

/// Responsive theme for Wear OS app
/// Adapts colors, typography, and spacing to different watch sizes

class ResponsiveTheme {
  /// Get theme data based on screen size
  static ThemeData getTheme(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Determine base sizes based on screen width
    double baseFontSize;
    double baseSpacing;
    double baseIconSize;
    double borderRadius;

    if (screenWidth < 200) {
      // Small watches
      baseFontSize = 10.0;
      baseSpacing = 4.0;
      baseIconSize = 16.0;
      borderRadius = 6.0;
    } else if (screenWidth < 280) {
      // Medium watches
      baseFontSize = 12.0;
      baseSpacing = 6.0;
      baseIconSize = 20.0;
      borderRadius = 8.0;
    } else if (screenWidth < 360) {
      // Large watches (most common)
      baseFontSize = 14.0;
      baseSpacing = 8.0;
      baseIconSize = 24.0;
      borderRadius = 10.0;
    } else {
      // Extra large watches
      baseFontSize = 16.0;
      baseSpacing = 10.0;
      baseIconSize = 28.0;
      borderRadius = 12.0;
    }

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      // Typography
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: baseFontSize * 2.0,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          fontSize: baseFontSize * 1.5,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: TextStyle(
          fontSize: baseFontSize * 1.25,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          fontSize: baseFontSize * 1.15,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          fontSize: baseFontSize,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          fontSize: baseFontSize * 0.9,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          fontSize: baseFontSize,
        ),
        bodyMedium: TextStyle(
          fontSize: baseFontSize * 0.85,
        ),
        bodySmall: TextStyle(
          fontSize: baseFontSize * 0.75,
        ),
        labelLarge: TextStyle(
          fontSize: baseFontSize * 0.85,
          fontWeight: FontWeight.w500,
        ),
      ),
      // Card theme
      cardTheme: CardThemeData(
        margin: EdgeInsets.all(baseSpacing * 0.5),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      // AppBar
      appBarTheme: AppBarTheme(
        titleTextStyle: TextStyle(
          fontSize: baseFontSize,
          fontWeight: FontWeight.bold,
        ),
        toolbarHeight: baseIconSize * 2,
        iconTheme: IconThemeData(
          size: baseIconSize,
        ),
      ),
      // Icons
      iconTheme: IconThemeData(
        size: baseIconSize,
      ),
      // Input
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        contentPadding: EdgeInsets.all(baseSpacing),
      ),
      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: baseSpacing * 2,
            vertical: baseSpacing,
          ),
          minimumSize: Size(double.infinity, baseIconSize * 2),
          textStyle: TextStyle(
            fontSize: baseFontSize,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: baseSpacing * 1.5,
            vertical: baseSpacing * 0.5,
          ),
          minimumSize: Size(baseIconSize * 4, baseIconSize * 1.5),
          textStyle: TextStyle(fontSize: baseFontSize * 0.85),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
      // List tiles
      listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(
          horizontal: baseSpacing,
          vertical: baseSpacing * 0.5,
        ),
        minVerticalPadding: baseSpacing * 0.5,
        iconColor: Colors.white70,
        textColor: Colors.white,
      ),
      // Snackbar
      snackBarTheme: SnackBarThemeData(
        contentTextStyle: TextStyle(fontSize: baseFontSize * 0.85),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Extension to easily access theme in widgets
extension ThemeExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  IconThemeData get iconTheme => Theme.of(this).iconTheme;
}