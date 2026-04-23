import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  // Zen Maru Gothic — 日本語見出し・ブランド文言
  static TextStyle screenTitle = GoogleFonts.zenMaruGothic(
    fontSize: 22,
    fontWeight: FontWeight.w900,
    color: AppColors.ink,
  );

  static TextStyle sectionHeading = GoogleFonts.zenMaruGothic(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  static TextStyle cardDeveloper = GoogleFonts.zenMaruGothic(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  // DM Sans — 数値・英語・UIラベル全般
  static TextStyle ctaButton = GoogleFonts.dmSans(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.white,
  );

  static TextStyle body = GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.ink,
  );

  static TextStyle bodySubtle = GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.ink55,
  );

  static TextStyle caption = GoogleFonts.dmSans(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.ink55,
  );

  static TextStyle sectionLabel = GoogleFonts.dmSans(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: AppColors.ink30,
    letterSpacing: 1.8,
  );

  static TextStyle numericLarge = GoogleFonts.dmSans(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  static TextStyle numericMedium = GoogleFonts.dmSans(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );
}
