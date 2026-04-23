import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary accent
  static const Color orange = Color(0xFFFF9500);
  static const Color orangeLight = Color(0xFFFFAC33);
  static const Color orangeDark = Color(0xFFFF7A00);
  static const Color orangeBg = Color(0x1AFF9500); // 10%
  static const Color orangeBg2 = Color(0x0FFF9500); // 6%

  // Neutral
  static const Color white = Color(0xFFFFFFFF);
  static const Color bg = Color(0xFFF6F6F9);
  static const Color ink = Color(0xFF16121D);
  static const Color ink55 = Color(0x8C16121D); // 55%
  static const Color ink30 = Color(0x4D16121D); // 30%
  static const Color ink12 = Color(0x1F16121D); // 12%
  static const Color ink06 = Color(0x0F16121D); // 6%

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [orangeLight, orangeDark],
  );

  // Timeline accent colors (loop)
  static const List<Color> accentColors = [orange, orangeDark, orangeLight];
  static const List<Color> accentBgColors = [
    Color(0x1FFF9500),
    Color(0x1FFF7A00),
    Color(0x1FFFAC33),
  ];
}
