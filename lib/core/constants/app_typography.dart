import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static TextStyle get regular => GoogleFonts.inter(
        fontWeight: FontWeight.w400,
      );

  static TextStyle get medium => GoogleFonts.inter(
        fontWeight: FontWeight.w500,
      );

  static TextStyle get semiBold => GoogleFonts.inter(
        fontWeight: FontWeight.w600,
      );

  static TextStyle get bold => GoogleFonts.inter(
        fontWeight: FontWeight.w700,
      );

  static TextStyle get extraBold => GoogleFonts.inter(
        fontWeight: FontWeight.w800,
      );

  // Pre-configured headline styles
  static TextStyle h1({Color? color}) => extraBold.copyWith(
        fontSize: 32,
        letterSpacing: -1.0,
        color: color,
      );

  static TextStyle h2({Color? color}) => bold.copyWith(
        fontSize: 24,
        letterSpacing: -0.5,
        color: color,
      );

  static TextStyle h3({Color? color}) => semiBold.copyWith(
        fontSize: 20,
        letterSpacing: -0.3,
        color: color,
      );

  static TextStyle body({Color? color}) => regular.copyWith(
        fontSize: 15,
        height: 1.4,
        color: color,
      );

  static TextStyle bodyBold({Color? color}) => semiBold.copyWith(
        fontSize: 15,
        height: 1.4,
        color: color,
      );

  static TextStyle caption({Color? color}) => regular.copyWith(
        fontSize: 13,
        color: color,
      );

  static TextStyle button({Color? color}) => bold.copyWith(
        fontSize: 16,
        letterSpacing: 0.3,
        color: color,
      );
}
