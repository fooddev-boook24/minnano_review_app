import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text('設定', style: AppTextStyles.screenTitle),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.ink06),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // アプリ情報
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x0D16121D),
                    blurRadius: 18,
                    offset: Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.rate_review_outlined,
                      color: AppColors.white, size: 26),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('みんなのレビュー',
                        style: AppTextStyles.body
                            .copyWith(fontWeight: FontWeight.w700)),
                    Text('App Storeレビュー横断解析',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.ink30)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
