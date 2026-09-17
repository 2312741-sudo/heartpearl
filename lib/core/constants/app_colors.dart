import 'package:flutter/material.dart';

/// HeartPearl Design System - Color Palette
class AppColors {
  // Brand Colors
  static const Color primary = Color(0xFFC42E5C); // Rose brand
  static const Color primaryLight = Color(0xFFE55080); // Rose light / highlight
  static const Color primaryDark = Color(0xFF9C2549); // Pressed state
  static const Color secondary = Color(0xFFFF80A0); // Blush accent
  static const Color soft = Color(0xFFFFD0DD); // Soft pink
  static const Color pearl = Color(0xFFFFFFFF); // Pearl white
  static const Color pearlTint = Color(0xFFF6EEFF); // Pearl lavender

  // Dark Theme Palette
  static const Color darkBackground = Color(0xFF120716); // Deep berry dark
  static const Color darkSurface = Color(0xFF1E0D26); // Card/Surface
  static const Color darkSurfaceLight = Color(0xFF281335); // Elevated
  static const Color darkBorder = Color(0xFF3A1535); // Subtle border
  static const Color darkBorderLight = Color(0xFF4F1E48);

  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFF6EEFF);
  static const Color darkTextMuted = Color(0xFF8E5478);

  // Light Theme Palette
  static const Color lightBackground = Color(0xFFFFF5F8); // Gentle rose mist
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceLight = Color(0xFFFCE4EC);
  static const Color lightBorder = Color(0xFFF8BBD0);
  static const Color lightBorderLight = Color(0xFFF48FB1);

  static const Color lightTextPrimary = Color(0xFF1E071F);
  static const Color lightTextSecondary = Color(0xFF4A2338);
  static const Color lightTextMuted = Color(0xFF9E657F);

  // Status & UI
  static const Color success = Color(0xFF2ECC71);
  static const Color error = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF39C12);
  static const Color info = Color(0xFF3498DB);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Colors.transparent;

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF2A1035), Color(0xFF1A0B22)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient pearlGlowGradient = LinearGradient(
    colors: [Color(0xFFFF80A0), Color(0xFFC42E5C), Color(0xFF6B1D37)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
