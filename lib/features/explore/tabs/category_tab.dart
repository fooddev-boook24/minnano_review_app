import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_genres.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/analytics_service.dart';
import '../../../shared/models/app_model.dart';
import '../../../shared/models/category_insight.dart';
import '../explore_provider.dart';

class CategoryTab extends ConsumerWidget {
  const CategoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    ref.listen(categoriesProvider, (_, next) {
      next.whenData((cats) {
        if (cats.isNotEmpty && ref.read(selectedCategoryProvider) == null) {
          ref.read(selectedCategoryProvider.notifier).state = cats.first;
        }
      });
    });

    return Column(
      children: [
        // ─── カテゴリ選択バー ───
        categoriesAsync.when(
          data: (categories) => categories.isEmpty
              ? const SizedBox.shrink()
              : _CategoryBar(
                  categories: categories,
                  selected: selectedCategory,
                  onSelect: (cat) {
                    ref.read(selectedCategoryProvider.notifier).state = cat;
                    ref.read(analyticsServiceProvider).logCategorySelected(cat);
                  },
                ),
          loading: () => const SizedBox(
            height: 48,
            child: Center(
                child: CircularProgressIndicator(color: AppColors.orange)),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const Divider(height: 1, color: AppColors.ink06),

        // ─── コンテンツ ───
        Expanded(
          child: categoriesAsync.when(
            data: (cats) => cats.isEmpty
                ? const _NoDataPrompt()
                : selectedCategory == null
                    ? const _NoDataPrompt()
                    : _InsightView(category: selectedCategory),
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.orange)),
            error: (_, __) => const _NoDataPrompt(),
          ),
        ),
      ],
    );
  }
}

// ─── Category Bar（TabBar風）────────────────────────────

class _CategoryBar extends StatefulWidget {
  const _CategoryBar({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<String> categories;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  State<_CategoryBar> createState() => _CategoryBarState();
}

class _CategoryBarState extends State<_CategoryBar> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0.0, 0.04, 0.85, 1.0],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: ListView.separated(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: widget.categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 24),
          itemBuilder: (context, i) {
            final cat = widget.categories[i];
            final active = widget.selected == cat;

            return GestureDetector(
              onTap: () => widget.onSelect(cat),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      genreJa(cat),
                      style: AppTextStyles.body.copyWith(
                        fontSize: 13,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w400,
                        color: active ? AppColors.ink : AppColors.ink55,
                      ),
                    ),
                    if (active)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── No Data ─────────────────────────────────────────────

class _NoDataPrompt extends StatelessWidget {
  const _NoDataPrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('データを集計中です', style: AppTextStyles.bodySubtle),
          const SizedBox(height: 4),
          Text('しばらくお待ちください', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

// ─── Insight View ────────────────────────────────────────

class _InsightView extends ConsumerWidget {
  const _InsightView({required this.category});
  final String category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightAsync = ref.watch(categoryInsightProvider(category));
    final topAppsAsync = ref.watch(categoryTopAppsProvider(category));

    return insightAsync.when(
      data: (insight) {
        if (insight == null) {
          return Center(
              child: Text('まだデータがありません',
                  style: AppTextStyles.bodySubtle));
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(0, 24, 0, 40),
          children: [
            // Stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _StatsRow(
                  avgRating: insight.avgRating,
                  reviewCount: insight.reviewCount),
            ),
            const SizedBox(height: 28),

            // Entry Score
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _Section(
                title: '参入機会スコア',
                child: _EntryScoreRow(insight: insight),
              ),
            ),
            const SizedBox(height: 28),

            // Top Apps horizontal scroll
            _Section(
              title: 'カテゴリ上位アプリ',
              titlePadding: const EdgeInsets.symmetric(horizontal: 24),
              child: topAppsAsync.when(
                data: (apps) => apps.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text('データがありません',
                            style: AppTextStyles.bodySubtle),
                      )
                    : _TopAppsScroll(apps: apps),
                loading: () => const SizedBox(
                  height: 120,
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.orange, strokeWidth: 2)),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 28),

            // Complaints bar chart
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _Section(
                title: 'よくある不満',
                child: _HorizontalBarChart(
                  items: insight.topComplaints,
                  barColor: const Color(0xFFF43F5E),
                  deltaPositiveIsBad: true,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Praise bar chart
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _Section(
                title: '評価されていること',
                child: _HorizontalBarChart(
                  items: insight.topPraise,
                  barColor: const Color(0xFF22C55E),
                  deltaPositiveIsBad: false,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Rising keywords
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _Section(
                title: '急上昇キーワード',
                child: _KeywordRow(keywords: insight.risingKeywords),
              ),
            ),
            const SizedBox(height: 28),

            // Whitespace
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _WhitespaceSection(hint: insight.whitespaceHint),
            ),
          ],
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppColors.orange)),
      error: (_, __) =>
          Center(child: Text('エラーが発生しました', style: AppTextStyles.bodySubtle)),
    );
  }
}

// ─── Top Apps Horizontal Scroll ──────────────────────────

class _TopAppsScroll extends StatelessWidget {
  const _TopAppsScroll({required this.apps});
  final List<AppModel> apps;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: apps.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _TopAppCard(app: apps[i]),
      ),
    );
  }
}

class _TopAppCard extends StatelessWidget {
  const _TopAppCard({required this.app});
  final AppModel app;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/app/${app.trackId}'),
      child: Container(
        width: 76,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: app.artworkUrl100 != null
                  ? CachedNetworkImage(
                      imageUrl: app.artworkUrl100!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _AppIconPlaceholder(),
                    )
                  : _AppIconPlaceholder(),
            ),
            const SizedBox(height: 6),
            Text(
              app.trackName,
              style: AppTextStyles.caption.copyWith(
                  fontSize: 10, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            if (app.averageUserRating != null) ...[
              const SizedBox(height: 4),
              Text(
                '★ ${app.averageUserRating!.toStringAsFixed(1)}',
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.orange,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppIconPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.apps, size: 24, color: AppColors.ink30),
    );
  }
}

// ─── Horizontal Bar Chart ─────────────────────────────────

class _HorizontalBarChart extends StatelessWidget {
  const _HorizontalBarChart({
    required this.items,
    required this.barColor,
    required this.deltaPositiveIsBad,
  });

  final List<InsightItem> items;
  final Color barColor;
  final bool deltaPositiveIsBad;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text('データがありません', style: AppTextStyles.bodySubtle);
    }
    final maxPct = items.map((e) => e.pct).reduce((a, b) => a > b ? a : b);

    return Column(
      children: items.asMap().entries.map((entry) {
        final i = entry.key;
        final item = entry.value;
        final isLast = i == items.length - 1;
        final barRatio = maxPct > 0 ? (item.pct / maxPct).clamp(0.0, 1.0) : 0.0;

        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.label,
                      style: AppTextStyles.body.copyWith(
                          fontSize: 12, color: AppColors.ink55),
                    ),
                  ),
                  if (item.delta != null) ...[
                    const SizedBox(width: 6),
                    _DeltaBadge(
                        delta: item.delta!,
                        positiveIsBad: deltaPositiveIsBad),
                    const SizedBox(width: 6),
                  ] else
                    const SizedBox(width: 6),
                  Text(
                    '${item.pct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: barColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Container(
                        height: 6,
                        width: constraints.maxWidth,
                        decoration: BoxDecoration(
                          color: barColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      Container(
                        height: 6,
                        width: constraints.maxWidth * barRatio,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({required this.delta, required this.positiveIsBad});
  final double delta;
  final bool positiveIsBad;

  @override
  Widget build(BuildContext context) {
    final isUp = delta > 0;
    final isBad = positiveIsBad ? isUp : !isUp;
    final color = isBad ? const Color(0xFFF43F5E) : const Color(0xFF22C55E);
    final sign = isUp ? '↑' : '↓';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$sign${delta.abs().round()}%',
        style: AppTextStyles.caption.copyWith(
            fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

// ─── Stats ───────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.avgRating, required this.reviewCount});
  final double avgRating;
  final int reviewCount;

  String _fmt(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}万';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Stat(
          label: '平均評価',
          value: avgRating.toStringAsFixed(1),
          suffix: '/ 5',
          color: AppColors.orange,
        ),
        Container(
          width: 1,
          height: 36,
          color: AppColors.ink06,
          margin: const EdgeInsets.symmetric(horizontal: 24),
        ),
        _Stat(
          label: 'レビュー総数',
          value: _fmt(reviewCount),
          suffix: '件',
          color: AppColors.ink,
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.suffix,
    required this.color,
  });
  final String label;
  final String value;
  final String suffix;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.caption
                .copyWith(color: AppColors.ink30, fontSize: 11)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value,
                style: TextStyle(
                  fontFamily: 'DM Sans',
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: color,
                )),
            const SizedBox(width: 4),
            Text(suffix,
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.ink30)),
          ],
        ),
      ],
    );
  }
}

// ─── Section ─────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.titlePadding,
  });
  final String title;
  final Widget child;
  final EdgeInsets? titlePadding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: titlePadding ?? EdgeInsets.zero,
          child: Text(title,
              style: AppTextStyles.body
                  .copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

// ─── Keyword Row ─────────────────────────────────────────

class _KeywordRow extends StatelessWidget {
  const _KeywordRow({required this.keywords});
  final List<String> keywords;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: keywords.map((kw) {
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(kw,
              style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink55)),
        );
      }).toList(),
    );
  }
}

// ─── Whitespace ──────────────────────────────────────────

class _WhitespaceSection extends StatelessWidget {
  const _WhitespaceSection({required this.hint});
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 3,
          height: 16,
          margin: const EdgeInsets.only(top: 3),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ホワイトスペース',
                  style: AppTextStyles.body
                      .copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              Text(hint,
                  style: AppTextStyles.body.copyWith(
                      color: AppColors.ink55,
                      height: 1.7,
                      fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Entry Score ──────────────────────────────────────────

class _EntryScoreRow extends StatelessWidget {
  const _EntryScoreRow({required this.insight});
  final CategoryInsight insight;

  /// スコア計算（0〜100）
  /// - 低評価ほど参入チャンス大（0〜40pt）
  /// - 不満の強さが高いほど参入チャンス大（0〜40pt）
  /// - 市場規模が大きいほど参入機会が多い（0〜20pt）
  int _score() {
    // 評価の低さ: avgRating が低いほど高得点
    final ratingScore =
        ((4.5 - insight.avgRating) / 3.5 * 40).clamp(0.0, 40.0);

    // 最大不満率: topComplaints[0].pct（最大50%=40pt）
    final topComplaintPct =
        insight.topComplaints.isNotEmpty ? insight.topComplaints[0].pct : 0.0;
    final complaintScore = (topComplaintPct / 50.0 * 40).clamp(0.0, 40.0);

    // 市場規模
    final marketScore = insight.reviewCount > 100000
        ? 20.0
        : insight.reviewCount > 30000
            ? 15.0
            : insight.reviewCount > 5000
                ? 10.0
                : insight.reviewCount > 500
                    ? 5.0
                    : 2.0;

    return (ratingScore + complaintScore + marketScore).round().clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final score = _score();
    final Color color;
    final String label;
    final String hint;
    if (score >= 65) {
      color = const Color(0xFFF43F5E);
      label = '参入チャンス大';
      hint = '競合の評価が低く不満が高まっている。解決されていない課題を先に取り込める。';
    } else if (score >= 40) {
      color = AppColors.orange;
      label = '参入余地あり';
      hint = '一部のニーズが未充足。差別化できれば勝機がある。';
    } else {
      color = const Color(0xFF22C55E);
      label = '競争が激しい';
      hint = '既存アプリが高評価で定着済み。明確な差別化なしには参入困難。';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$score',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text('/ 100',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.ink30, fontSize: 10)),
              ],
            ),
            const SizedBox(width: 16),
            Container(width: 1, height: 52, color: AppColors.ink06),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(label,
                        style: AppTextStyles.caption.copyWith(
                            color: color, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 6),
                  Text(hint,
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.ink55, height: 1.5, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _ScoreBreakdown(insight: insight, score: score, color: color),
      ],
    );
  }
}

/// スコアの内訳を3本のミニバーで可視化
class _ScoreBreakdown extends StatelessWidget {
  const _ScoreBreakdown({
    required this.insight,
    required this.score,
    required this.color,
  });
  final CategoryInsight insight;
  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratingRatio =
        ((4.5 - insight.avgRating) / 3.5).clamp(0.0, 1.0);
    final topComplaintPct =
        insight.topComplaints.isNotEmpty ? insight.topComplaints[0].pct : 0.0;
    final complaintRatio = (topComplaintPct / 50.0).clamp(0.0, 1.0);
    final marketRatio = insight.reviewCount > 100000
        ? 1.0
        : insight.reviewCount > 30000
            ? 0.75
            : insight.reviewCount > 5000
                ? 0.5
                : insight.reviewCount > 500
                    ? 0.25
                    : 0.1;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _MiniBar(label: '評価の低さ', ratio: ratingRatio, color: color),
          const SizedBox(height: 8),
          _MiniBar(label: '不満の強さ', ratio: complaintRatio, color: color),
          const SizedBox(height: 8),
          _MiniBar(label: '市場規模', ratio: marketRatio, color: color),
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({
    required this.label,
    required this.ratio,
    required this.color,
  });
  final String label;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label,
              style: AppTextStyles.caption
                  .copyWith(fontSize: 10, color: AppColors.ink55)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            return Stack(
              children: [
                Container(
                  height: 5,
                  width: constraints.maxWidth,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Container(
                  height: 5,
                  width: constraints.maxWidth * ratio,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            );
          }),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text(
            '${(ratio * 100).round()}%',
            style: TextStyle(
              fontFamily: 'DM Sans',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
