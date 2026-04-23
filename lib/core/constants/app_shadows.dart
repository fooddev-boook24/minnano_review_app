import 'package:flutter/material.dart';

class AppShadows {
  AppShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0D16121D), // 5%
      blurRadius: 18,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x0D16121D), // 5%
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> cardRaised = [
    BoxShadow(
      color: Color(0x1C16121D), // 11%
      blurRadius: 36,
      offset: Offset(0, 12),
    ),
    BoxShadow(
      color: Color(0x0F16121D), // 6%
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> btn = [
    BoxShadow(
      color: Color(0x5CFF9500), // 36%
      blurRadius: 22,
      offset: Offset(0, 6),
    ),
    BoxShadow(
      color: Color(0x2EFF9500), // 18%
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];
}
