import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.darkSurface,
        error: AppColors.error,
        onPrimary: AppColors.white,
        onSecondary: AppColors.darkBackground,
        onSurface: AppColors.darkTextPrimary,
        onError: AppColors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: AppTypography.h1(color: AppColors.darkTextPrimary),
        headlineMedium: AppTypography.h2(color: AppColors.darkTextPrimary),
        headlineSmall: AppTypography.h3(color: AppColors.darkTextPrimary),
        bodyLarge: AppTypography.body(color: AppColors.darkTextPrimary),
        bodyMedium: AppTypography.body(color: AppColors.darkTextSecondary),
        labelLarge: AppTypography.button(color: AppColors.white),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.lightSurface,
        error: AppColors.error,
        onPrimary: AppColors.white,
        onSecondary: AppColors.white,
        onSurface: AppColors.lightTextPrimary,
        onError: AppColors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      textTheme: TextTheme(
        headlineLarge: AppTypography.h1(color: AppColors.lightTextPrimary),
        headlineMedium: AppTypography.h2(color: AppColors.lightTextPrimary),
        headlineSmall: AppTypography.h3(color: AppColors.lightTextPrimary),
        bodyLarge: AppTypography.body(color: AppColors.lightTextPrimary),
        bodyMedium: AppTypography.body(color: AppColors.lightTextSecondary),
        labelLarge: AppTypography.button(color: AppColors.white),
      ),
    );
  }
}
