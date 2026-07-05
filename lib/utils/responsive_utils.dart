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
  static double getFontSize(BuildContext context, double baseSize) {
    final screenSize = getScreenSize(context);
    switch (screenSize) {
      case ScreenSize.small:
        return baseSize * 0.85;
      case ScreenSize.medium:
        return baseSize * 0.92;
      case ScreenSize.large:
        return baseSize;
      case ScreenSize.xlarge:
        return baseSize * 1.1;
    }
  }

  /// Get relative padding based on screen size
  static double getPadding(BuildContext context, double basePadding) {
    final screenSize = getScreenSize(context);
    switch (screenSize) {
      case ScreenSize.small:
        return basePadding * 0.6;
      case ScreenSize.medium:
        return basePadding * 0.8;
      case ScreenSize.large:
        return basePadding;
      case ScreenSize.xlarge:
        return basePadding * 1.2;
    }
  }

  /// Get icon size based on screen size
  static double getIconSize(BuildContext context, double baseIconSize) {
    final screenSize = getScreenSize(context);
    switch (screenSize) {
      case ScreenSize.small:
        return baseIconSize * 0.75;
      case ScreenSize.medium:
        return baseIconSize * 0.85;
      case ScreenSize.large:
        return baseIconSize;
      case ScreenSize.xlarge:
        return baseIconSize * 1.15;
    }
  }

  /// Get button height based on screen size
  static double getButtonHeight(BuildContext context, double baseHeight) {
    final screenSize = getScreenSize(context);
    switch (screenSize) {
      case ScreenSize.small:
        return baseHeight * 0.8;
      case ScreenSize.medium:
        return baseHeight * 0.9;
      case ScreenSize.large:
        return baseHeight;
      case ScreenSize.xlarge:
        return baseHeight * 1.1;
    }
  }

  /// Check if device is a round watch
  static bool isRoundWatch(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    // If horizontal padding is significantly different from vertical,
    // it's likely a round watch
    return (padding.left - padding.right).abs() < 10;
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