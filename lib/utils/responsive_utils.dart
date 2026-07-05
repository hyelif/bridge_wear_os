import 'package:flutter/material.dart';

/// Responsive utilities for Wear OS devices
/// Adapts UI to different screen sizes and pixel densities
class ResponsiveUtils {
  /// Get screen size category
  static ScreenSize getScreenSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 200) return ScreenSize.small;
    if (width < 280) return ScreenSize.medium;
    if (width < 360) return ScreenSize.large;
    return ScreenSize.xlarge;
  }

  /// Get relative font size based on screen size
  /// Updated multipliers for better readability on all screen sizes
  static double getFontSize(BuildContext context, double baseSize) {
    final screenSize = getScreenSize(context);
    switch (screenSize) {
      case ScreenSize.small:
        return baseSize * 0.90;
      case ScreenSize.medium:
        return baseSize * 0.95;
      case ScreenSize.large:
        return baseSize;
      case ScreenSize.xlarge:
        return baseSize * 1.15;
    }
  }

  /// Get relative padding based on screen size
  /// Updated multipliers for more comfortable touch targets
  static double getPadding(BuildContext context, double basePadding) {
    final screenSize = getScreenSize(context);
    switch (screenSize) {
      case ScreenSize.small:
        return basePadding * 0.7;
      case ScreenSize.medium:
        return basePadding * 0.85;
      case ScreenSize.large:
        return basePadding;
      case ScreenSize.xlarge:
        return basePadding * 1.25;
    }
  }

  /// Get icon size based on screen size
  static double getIconSize(BuildContext context, double baseIconSize) {
    final screenSize = getScreenSize(context);
    switch (screenSize) {
      case ScreenSize.small:
        return baseIconSize * 0.80;
      case ScreenSize.medium:
        return baseIconSize * 0.90;
      case ScreenSize.large:
        return baseIconSize;
      case ScreenSize.xlarge:
        return baseIconSize * 1.20;
    }
  }

  /// Get button height based on screen size
  static double getButtonHeight(BuildContext context, double baseHeight) {
    final screenSize = getScreenSize(context);
    switch (screenSize) {
      case ScreenSize.small:
        return baseHeight * 0.85;
      case ScreenSize.medium:
        return baseHeight * 0.95;
      case ScreenSize.large:
        return baseHeight;
      case ScreenSize.xlarge:
        return baseHeight * 1.15;
    }
  }

  /// Detect round screens by checking if left/right safe area padding differs.
  /// Round watches typically report asymmetric horizontal safe area insets
  /// due to the curved display edges, while square/rectangular screens
  /// report symmetric (or zero) horizontal padding.
  static bool isRoundWatch(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    // If left and right padding differ by more than 1 pixel, it's a round screen
    return (padding.left - padding.right).abs() > 1.0;
  }

  /// Internal ambient mode state.
  /// Set via [setAmbientMode] from a widget that observes ambient changes
  /// (e.g., using the `wear` package's [AmbientMode] widget or a platform
  /// channel listener).
  static bool _ambientMode = false;

  /// Update the ambient mode state.
  /// Call this from a [StatefulWidget] that listens to ambient mode changes.
  static void setAmbientMode(bool value) {
    _ambientMode = value;
  }

  /// Return true if the device is in ambient / always-on display mode.
  /// The caller must have previously set the state via [setAmbientMode].
  static bool ambientMode() {
    return _ambientMode;
  }

  /// Convert Bluetooth RSSI value (dBm) to a signal strength of 1-5 bars.
  ///
  /// RSSI range: -30 (strongest) to -100 (weakest).
  ///   >= -50  -> 5 bars (excellent)
  ///   >= -60  -> 4 bars (good)
  ///   >= -70  -> 3 bars (fair)
  ///   >= -85  -> 2 bars (weak)
  ///   <  -85  -> 1 bar  (very weak)
  static int getSignalBars(int rssi) {
    if (rssi >= -50) return 5;
    if (rssi >= -60) return 4;
    if (rssi >= -70) return 3;
    if (rssi >= -85) return 2;
    return 1;
  }

  /// Get safe area padding for round watches
  static EdgeInsets getSafePadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }

  /// Get screen width
  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Get screen height
  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }
}

enum ScreenSize {
  small,    // < 200px (older watches)
  medium,   // 200-279px
  large,    // 280-359px (most common)
  xlarge,   // 360px+ (larger watches)
}

/// Extension on BuildContext for easy access to responsive utilities
extension ResponsiveExtension on BuildContext {
  ScreenSize get screenSize => ResponsiveUtils.getScreenSize(this);
  double fontSize(double base) => ResponsiveUtils.getFontSize(this, base);
  double padding(double base) => ResponsiveUtils.getPadding(this, base);
  double iconSize(double base) => ResponsiveUtils.getIconSize(this, base);
  double buttonHeight(double base) => ResponsiveUtils.getButtonHeight(this, base);
  bool get isRound => ResponsiveUtils.isRoundWatch(this);
  EdgeInsets get safePadding => ResponsiveUtils.getSafePadding(this);
  double get screenWidth => ResponsiveUtils.getScreenWidth(this);
  double get screenHeight => ResponsiveUtils.getScreenHeight(this);
}
