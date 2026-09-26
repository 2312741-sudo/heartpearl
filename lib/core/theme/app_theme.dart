import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

class AppTheme {
  static ThemeData get darkTheme {
    final baseTextTheme = ThemeData(brightness: Brightness.dark).textTheme;
    final interTextTheme = GoogleFonts.interTextTheme(baseTextTheme);

    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: GoogleFonts.inter().fontFamily,
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
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.h3(color: AppColors.darkTextPrimary),
        iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      textTheme: interTextTheme.copyWith(
        headlineLarge: AppTypography.h1(color: AppColors.darkTextPrimary),
        headlineMedium: AppTypography.h2(color: AppColors.darkTextPrimary),
        headlineSmall: AppTypography.h3(color: AppColors.darkTextPrimary),
        titleLarge: AppTypography.h3(color: AppColors.darkTextPrimary),
        titleMedium: AppTypography.bodyBold(color: AppColors.darkTextPrimary),
        titleSmall: AppTypography.captionBold(color: AppColors.darkTextPrimary),
        bodyLarge: AppTypography.body(color: AppColors.darkTextPrimary),
        bodyMedium: AppTypography.body(color: AppColors.darkTextSecondary),
        bodySmall: AppTypography.caption(color: AppColors.darkTextMuted),
        labelLarge: AppTypography.button(color: AppColors.white),
        labelMedium: AppTypography.captionBold(color: AppColors.darkTextPrimary),
        labelSmall: AppTypography.micro(color: AppColors.darkTextMuted),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkSurfaceLight,
        contentTextStyle: AppTypography.body(color: AppColors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dialogTheme: DialogThemeData(
        titleTextStyle: AppTypography.h3(color: AppColors.darkTextPrimary),
        contentTextStyle: AppTypography.body(color: AppColors.darkTextSecondary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkSurface,
        modalBackgroundColor: AppColors.darkSurface,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    final baseTextTheme = ThemeData(brightness: Brightness.light).textTheme;
    final interTextTheme = GoogleFonts.interTextTheme(baseTextTheme);

    return ThemeData(
      brightness: Brightness.light,
      fontFamily: GoogleFonts.inter().fontFamily,
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
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.h3(color: AppColors.lightTextPrimary),
        iconTheme: const IconThemeData(color: AppColors.lightTextPrimary),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      textTheme: interTextTheme.copyWith(
        headlineLarge: AppTypography.h1(color: AppColors.lightTextPrimary),
        headlineMedium: AppTypography.h2(color: AppColors.lightTextPrimary),
        headlineSmall: AppTypography.h3(color: AppColors.lightTextPrimary),
        titleLarge: AppTypography.h3(color: AppColors.lightTextPrimary),
        titleMedium: AppTypography.bodyBold(color: AppColors.lightTextPrimary),
        titleSmall: AppTypography.captionBold(color: AppColors.lightTextPrimary),
        bodyLarge: AppTypography.body(color: AppColors.lightTextPrimary),
        bodyMedium: AppTypography.body(color: AppColors.lightTextSecondary),
        bodySmall: AppTypography.caption(color: AppColors.lightTextMuted),
        labelLarge: AppTypography.button(color: AppColors.white),
        labelMedium: AppTypography.captionBold(color: AppColors.lightTextPrimary),
        labelSmall: AppTypography.micro(color: AppColors.lightTextMuted),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.lightTextPrimary,
        contentTextStyle: AppTypography.body(color: AppColors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dialogTheme: DialogThemeData(
        titleTextStyle: AppTypography.h3(color: AppColors.lightTextPrimary),
        contentTextStyle: AppTypography.body(color: AppColors.lightTextSecondary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightSurface,
        modalBackgroundColor: AppColors.lightSurface,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}
