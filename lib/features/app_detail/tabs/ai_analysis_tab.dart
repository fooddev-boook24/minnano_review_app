import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/rewarded_ad_service.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../core/services/functions_service.dart';
import '../../../shared/models/app_review_summary.dart';
import '../app_detail_provider.dart';

class AiAnalysisTab extends ConsumerWidget {
  const AiAnalysisTab({super.key, required this.trackId});
  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _AiAnalysisContent(trackId: trackId);
  }
}

class _AiAnalysisContent extends ConsumerWidget {
  const _AiAnalysisContent({required this.trackId});
  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(reviewSummaryProvider(trackId));
    final isGenerating = ref.watch(summaryGeneratingProvider(trackId));

    return summaryAsync.when(
      data: (summary) => summary == null
          ? _GeneratePrompt(trackId: trackId, isGenerating: isGenerating)
          : _SummaryView(trackId: trackId, summary: summary, isGenerating: isGenerating),
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppColors.orange)),
      error: (_, __) =>
          Center(child: Text('エラーが発生しました', style: AppTextStyles.bodySubtle)),
    );
  }
}

class _GeneratePrompt extends ConsumerWidget {
  const _GeneratePrompt({required this.trackId, required this.isGenerating});
  final String trackId;
  final bool isGenerating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, size: 48, color: AppColors.orange),
            const SizedBox(height: 16),
            Text('競合分析を生成', style: AppTextStyles.sectionHeading),
            const SizedBox(height: 8),
            Text(
              'ユーザーレビューをAIが解析し、\nこのアプリの弱点・未解決ニーズ・あなたの参入機会を抽出します。',
              style: AppTextStyles.bodySubtle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '広告を1本視聴して生成できます',
              style: AppTextStyles.caption.copyWith(color: AppColors.ink30),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _GenerateButton(trackId: trackId, isGenerating: isGenerating),
          ],
        ),
      ),
    );
  }
}

class _SummaryView extends ConsumerWidget {
  const _SummaryView({
    required this.trackId,
    required this.summary,
    required this.isGenerating,
  });
  final String trackId;
  final AppReviewSummary summary;
  final bool isGenerating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // ヘッダー
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('競合分析レポート', style: AppTextStyles.sectionHeading),
                  const SizedBox(height: 2),
                  Text('${summary.reviewCount}件のレビューを分析',
                      style: AppTextStyles.caption),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.orangeBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome,
                      size: 12, color: AppColors.orange),
                  const SizedBox(width: 4),
                  Text('AI',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.orange,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SummaryCard(
          icon: Icons.shield_outlined,
          color: AppColors.orange,
          title: 'ユーザーが評価していること（競合の強み）',
          items: summary.positivePoints,
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          icon: Icons.report_problem_outlined,
          color: const Color(0xFFF43F5E),
          title: 'ユーザーの不満・弱点（あなたが勝てるポイント）',
          items: summary.negativePoints,
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          icon: Icons.rocket_launch_outlined,
          color: const Color(0xFF3B82F6),
          title: '未解決ニーズ（あなたの参入機会）',
          items: summary.featureRequests.take(4).toList(),
        ),
        const SizedBox(height: 12),
        _DiffHintCard(hint: summary.asoHint),
        const SizedBox(height: 20),
        _GenerateButton(trackId: trackId, isGenerating: isGenerating),
        const SizedBox(height: 4),
        Text(
          '※ 再生成は24時間インターバル・広告視聴が必要です',
          style: AppTextStyles.caption.copyWith(color: AppColors.ink30),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.items,
  });
  final IconData icon;
  final Color color;
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x0D16121D), blurRadius: 18, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(title,
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item, style: AppTextStyles.body)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _DiffHintCard extends StatelessWidget {
  const _DiffHintCard({required this.hint});
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x3DFF9500), blurRadius: 20, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0x33FFFFFF), width: 1)),
            ),
            child: Row(children: [
              const Icon(Icons.emoji_objects_outlined,
                  color: AppColors.white, size: 18),
              const SizedBox(width: 8),
              Text('差別化・参入戦略',
                  style: AppTextStyles.body.copyWith(
                      color: AppColors.white, fontWeight: FontWeight.w700)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Text(hint,
                style: AppTextStyles.body.copyWith(
                    color: AppColors.white, height: 1.7)),
          ),
        ],
      ),
    );
  }
}

class _GenerateButton extends ConsumerWidget {
  const _GenerateButton({required this.trackId, required this.isGenerating});
  final String trackId;
  final bool isGenerating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: isGenerating ? null : () => _generate(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: isGenerating ? null : AppColors.primaryGradient,
          color: isGenerating ? AppColors.ink12 : null,
          borderRadius: BorderRadius.circular(999),
          boxShadow: isGenerating
              ? null
              : const [
                  BoxShadow(
                      color: Color(0x5CFF9500), blurRadius: 22, offset: Offset(0, 6)),
                ],
        ),
        alignment: Alignment.center,
        child: isGenerating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.orange),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_circle_outline,
                      color: AppColors.white, size: 18),
                  const SizedBox(width: 6),
                  Text('広告を見て競合分析を生成', style: AppTextStyles.ctaButton),
                ],
              ),
      ),
    );
  }

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    ref.read(summaryGeneratingProvider(trackId).notifier).state = true;
    ref.read(analyticsServiceProvider).logSummaryRequested(trackId);
    try {
      // 広告視聴
      final rewarded = await ref.read(rewardedAdServiceProvider).show();
      if (!rewarded) {
        if (context.mounted) showAppSnackBar(context, '広告の視聴が完了しませんでした');
        return;
      }

      await ref.read(fetchReviewsProvider.notifier).fetch(trackId);
      await ref
          .read(functionsServiceProvider)
          .generateReviewSummary(int.parse(trackId));
      ref.invalidate(reviewSummaryProvider(trackId));
      ref.read(analyticsServiceProvider).logSummaryCompleted(trackId);
    } on FirebaseFunctionsException catch (e) {
      if (context.mounted) {
        showAppSnackBar(
          context,
          e.code == 'already-exists' ? '24時間以内に生成済みです' : 'エラーが発生しました',
        );
      }
    } finally {
      ref.read(summaryGeneratingProvider(trackId).notifier).state = false;
    }
  }
}
