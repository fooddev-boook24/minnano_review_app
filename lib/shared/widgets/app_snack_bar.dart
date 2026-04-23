import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

const double _kBottomNavHeight = 75;

/// モバイルでは BottomNav の上に表示、Web では通常位置に表示する SnackBar
void showAppSnackBar(BuildContext context, String message) {
  final width = MediaQuery.sizeOf(context).width;
  final isMobile = width < 600;
  final bottomPadding = MediaQuery.paddingOf(context).bottom;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: AppTextStyles.body.copyWith(color: AppColors.white)),
      backgroundColor: AppColors.ink,
      behavior: SnackBarBehavior.floating,
      margin: isMobile
          ? EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: _kBottomNavHeight + bottomPadding,
            )
          : const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
