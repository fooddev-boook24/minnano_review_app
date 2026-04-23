import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/models/app_review.dart';
import '../app_detail_provider.dart';

class AnalysisTab extends ConsumerWidget {
  const AnalysisTab({super.key, required this.trackId});
  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync =
        ref.watch(reviewsProvider(ReviewQuery(trackId: trackId)));

    return reviewsAsync.when(
      data: (reviews) {
        if (reviews.isEmpty) {
          return Center(
            child: Text('レビューデータがありません', style: AppTextStyles.bodySubtle),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            _SectionLabel('評価分布'),
            const SizedBox(height: 8),
            _RatingDistributionCard(reviews: reviews),
            const SizedBox(height: 20),
            _SectionLabel('評価推移'),
            const SizedBox(height: 8),
            _VersionTrendCard(reviews: reviews),
            const SizedBox(height: 20),
            _SectionLabel('月別レビュー件数'),
            const SizedBox(height: 8),
            _MonthlyVolumeCard(reviews: reviews),
            const SizedBox(height: 20),
            _SectionLabel('市場シグナル'),
            const SizedBox(height: 8),
            _MarketSignalsCard(reviews: reviews),
            const SizedBox(height: 20),
            _SectionLabel('トピック分類'),
            const SizedBox(height: 8),
            _TopicCard(reviews: reviews),
            const SizedBox(height: 20),
            _SectionLabel('低評価が語ること'),
            const SizedBox(height: 8),
            _LowRatingBreakdownCard(reviews: reviews),
            const SizedBox(height: 20),
            _SectionLabel('代表レビュー'),
            const SizedBox(height: 8),
            _HighlightReviewsCard(reviews: reviews),
            const SizedBox(height: 20),
            _SectionLabel('キーワード（星評価別）'),
            const SizedBox(height: 8),
            _WordCloudCard(reviews: reviews),
          ],
        );
      },
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.orange)),
      error: (_, __) => Center(
          child: Text('エラーが発生しました', style: AppTextStyles.bodySubtle)),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTextStyles.sectionLabel);
  }
}

// ─── Rating Distribution ────────────────────────────────

class _RatingDistributionCard extends StatelessWidget {
  const _RatingDistributionCard({required this.reviews});
  final List<AppReview> reviews;

  // 直近90日 vs 前90日の評価トレンド
  ({double delta, String label, Color color})? _computeTrend() {
    final now = DateTime.now();
    final d90 = now.subtract(const Duration(days: 90));
    final d180 = now.subtract(const Duration(days: 180));
    final recent = reviews.where((r) => r.reviewDate.isAfter(d90)).toList();
    final prior = reviews
        .where((r) => r.reviewDate.isAfter(d180) && !r.reviewDate.isAfter(d90))
        .toList();
    if (recent.isEmpty || prior.isEmpty) return null;
    final recentAvg =
        recent.map((r) => r.rating).reduce((a, b) => a + b) / recent.length;
    final priorAvg =
        prior.map((r) => r.rating).reduce((a, b) => a + b) / prior.length;
    final delta = recentAvg - priorAvg;
    if (delta >= 0.15) {
      return (delta: delta, label: '↑ 上昇中', color: const Color(0xFF22C55E));
    } else if (delta <= -0.15) {
      return (delta: delta, label: '↓ 下降中', color: const Color(0xFFF43F5E));
    } else {
      return (delta: delta, label: '→ 横ばい', color: AppColors.ink30);
    }
  }

  @override
  Widget build(BuildContext context) {
    final counts = List.filled(6, 0);
    for (final r in reviews) {
      if (r.rating >= 1 && r.rating <= 5) counts[r.rating]++;
    }
    final total = reviews.length;
    final maxCount = counts.reduce((a, b) => a > b ? a : b);

    final avg = total > 0
        ? reviews.map((r) => r.rating).reduce((a, b) => a + b) / total
        : 0.0;

    final trend = _computeTrend();

    return _card(
      child: Column(
        children: [
          Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  avg.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: AppColors.orange,
                    fontFamily: 'DM Sans',
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < avg.round()
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 10,
                      color: AppColors.orange,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text('$total件',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.ink30, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: List.generate(5, (i) {
                final star = 5 - i;
                final count = counts[star];
                final ratio = maxCount > 0 ? count / maxCount : 0.0;
                final pct = total > 0 ? (count / total * 100).round() : 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Text(
                        '★$star',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 10,
                          color: AppColors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: ratio,
                            backgroundColor: AppColors.ink06,
                            valueColor: const AlwaysStoppedAnimation(
                                AppColors.orange),
                            minHeight: 7,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 26,
                        child: Text(
                          '$pct%',
                          style: AppTextStyles.caption.copyWith(
                              fontSize: 10, color: AppColors.ink30),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
          // ── トレンドフッター ──
          if (trend != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.ink06),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('直近90日のトレンド',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.ink30, fontSize: 11)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: trend.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${trend.label}  (${trend.delta >= 0 ? "+" : ""}${trend.delta.toStringAsFixed(2)})',
                    style: AppTextStyles.caption.copyWith(
                        color: trend.color, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Version Trend (fixed Y-axis + scrollable) ──────────

class _VersionTrendCard extends StatelessWidget {
  const _VersionTrendCard({required this.reviews});
  final List<AppReview> reviews;

  static const double _chartH = 160;
  static const double _bottomRes = 28;
  static const double _plotH = _chartH - _bottomRes;
  static const double _minY = 1;
  static const double _maxY = 5.3;

  List<({String version, double avgRating, int count})> _buildTrend() {
    final groups = <String, List<int>>{};
    for (final r in reviews) {
      if (r.version == null || r.version!.isEmpty) continue;
      groups.putIfAbsent(r.version!, () => []).add(r.rating);
    }
    return groups.entries.map((e) {
      final avg = e.value.reduce((a, b) => a + b) / e.value.length;
      return (version: e.key, avgRating: avg, count: e.value.length);
    }).toList()
      ..sort((a, b) => _compareVersion(a.version, b.version));
  }

  int _compareVersion(String a, String b) {
    final pa = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final pb = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    for (int i = 0; i < max(pa.length, pb.length); i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }

  // Y pixel position from top of the chart widget
  double _yPixel(double value) =>
      (_maxY - value) / (_maxY - _minY) * _plotH;

  @override
  Widget build(BuildContext context) {
    final trend = _buildTrend();

    if (trend.isEmpty) {
      return _card(
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('バージョン情報がありません'),
          ),
        ),
      );
    }

    final lastIsLow = trend.length >= 2 &&
        trend.last.avgRating < trend[trend.length - 2].avgRating;
    final spots = trend
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.avgRating))
        .toList();

    final chartWidth = max(trend.length * 64.0, 260.0);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _chartH,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Fixed Y-axis ──
                SizedBox(
                  width: 24,
                  height: _chartH,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [5, 4, 3, 2, 1].map((v) {
                      final top = _yPixel(v.toDouble()) - 6;
                      return Positioned(
                        top: top,
                        right: 2,
                        child: Text(
                          '$v',
                          style: AppTextStyles.caption
                              .copyWith(fontSize: 9, color: AppColors.ink30),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // ── Scrollable chart ──
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: chartWidth,
                      height: _chartH,
                      child: LineChart(
                        LineChartData(
                          minY: _minY,
                          maxY: _maxY,
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 1,
                            getDrawingHorizontalLine: (_) => const FlLine(
                                color: AppColors.ink06, strokeWidth: 1),
                          ),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: _bottomRes,
                                getTitlesWidget: (v, _) {
                                  final i = v.toInt();
                                  if (i < 0 || i >= trend.length) {
                                    return const SizedBox();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      trend[i].version,
                                      style: AppTextStyles.caption.copyWith(
                                          fontSize: 8, color: AppColors.ink30),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              curveSmoothness: 0.25,
                              color: AppColors.orange,
                              barWidth: 2.5,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, pct, bar, idx) {
                                  final isLast = idx == trend.length - 1;
                                  final isAlert = isLast && lastIsLow;
                                  return FlDotCirclePainter(
                                    radius: 4.5,
                                    color: isAlert
                                        ? const Color(0xFFF43F5E)
                                        : AppColors.orange,
                                    strokeWidth: 2,
                                    strokeColor: AppColors.white,
                                  );
                                },
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppColors.orange.withValues(alpha: 0.18),
                                    AppColors.orange.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (_) => AppColors.ink,
                              getTooltipItems: (spots) => spots.map((s) {
                                final i = s.x.toInt();
                                if (i < 0 || i >= trend.length) return null;
                                return LineTooltipItem(
                                  '★ ${trend[i].avgRating.toStringAsFixed(1)}\nv${trend[i].version}  ${trend[i].count}件',
                                  AppTextStyles.caption.copyWith(
                                      color: AppColors.white, fontSize: 11),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        duration: const Duration(milliseconds: 300),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (lastIsLow) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x10F43F5E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '最新バージョン v${trend.last.version} で評価が低下しています',
                style: AppTextStyles.caption
                    .copyWith(color: const Color(0xFFF43F5E)),
              ),
            ),
          ],
          // ── 評価の安定性 ──
          if (trend.length >= 3) ...[
            const SizedBox(height: 10),
            Builder(builder: (context) {
              final ratings = trend.map((t) => t.avgRating).toList();
              final avg = ratings.reduce((a, b) => a + b) / ratings.length;
              final variance = ratings
                      .map((v) => (v - avg) * (v - avg))
                      .reduce((a, b) => a + b) /
                  ratings.length;
              final stdev = sqrt(variance);
              final String stability;
              final Color stColor;
              if (stdev < 0.3) {
                stability = '安定';
                stColor = const Color(0xFF22C55E);
              } else if (stdev < 0.6) {
                stability = '普通';
                stColor = AppColors.orange;
              } else {
                stability = '不安定';
                stColor = const Color(0xFFF43F5E);
              }
              return Row(
                children: [
                  Text('開発品質の安定性',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.ink30, fontSize: 11)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: stColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$stability  (σ=${stdev.toStringAsFixed(2)})',
                      style: AppTextStyles.caption.copyWith(
                          color: stColor, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ─── Monthly Volume ──────────────────────────────────────

class _MonthlyVolumeCard extends StatelessWidget {
  const _MonthlyVolumeCard({required this.reviews});
  final List<AppReview> reviews;

  List<({String label, int count})> _buildMonthly() {
    final now = DateTime.now();
    final months = <String, int>{};
    for (int i = 5; i >= 0; i--) {
      int y = now.year;
      int m = now.month - i;
      while (m <= 0) {
        m += 12;
        y--;
      }
      final key = '$y-${m.toString().padLeft(2, '0')}';
      months[key] = 0;
    }
    for (final r in reviews) {
      final key =
          '${r.reviewDate.year}-${r.reviewDate.month.toString().padLeft(2, '0')}';
      if (months.containsKey(key)) {
        months[key] = months[key]! + 1;
      }
    }
    return months.entries.map((e) {
      final m = int.parse(e.key.split('-')[1]);
      return (label: '$m月', count: e.value);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final data = _buildMonthly();
    final maxCount = data.map((e) => e.count).reduce((a, b) => a > b ? a : b);

    return _card(
      child: SizedBox(
        height: 120,
        child: BarChart(
          BarChartData(
            maxY: (maxCount + 1).toDouble(),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxCount > 0 ? (maxCount / 3).ceilToDouble() : 1,
              getDrawingHorizontalLine: (_) =>
                  const FlLine(color: AppColors.ink06, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= data.length) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        data[i].label,
                        style: AppTextStyles.caption
                            .copyWith(fontSize: 9, color: AppColors.ink30),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: data.asMap().entries.map((e) {
              final isLatest = e.key == data.length - 1;
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value.count.toDouble(),
                    width: 22,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(5)),
                    gradient: isLatest
                        ? AppColors.primaryGradient
                        : LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.orange.withValues(alpha: 0.35),
                              AppColors.orange.withValues(alpha: 0.2),
                            ],
                          ),
                  ),
                ],
              );
            }).toList(),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.ink,
                getTooltipItem: (group, gI, rod, rI) => BarTooltipItem(
                  '${data[group.x].label}  ${rod.toY.toInt()}件',
                  AppTextStyles.caption
                      .copyWith(color: AppColors.white, fontSize: 11),
                ),
              ),
            ),
          ),
          duration: const Duration(milliseconds: 300),
        ),
      ),
    );
  }
}

// ─── Topic Classification ────────────────────────────────

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.reviews});
  final List<AppReview> reviews;

  static const _topics = [
    (
      label: 'バグ・クラッシュ',
      color: Color(0xFFF43F5E),
      keywords: ['バグ', 'クラッシュ', '落ちる', '固まる', 'エラー', '不具合', '壊れ']
    ),
    (
      label: 'UI / UX',
      color: Color(0xFFFF9500),
      keywords: ['使いにくい', 'デザイン', '操作', 'UI', '画面', 'レイアウト', '見づらい']
    ),
    (
      label: '機能要望',
      color: Color(0xFF3B82F6),
      keywords: ['欲しい', '追加して', '機能', 'できない', 'できれば', 'あったら', '対応して']
    ),
    (
      label: '価格・課金',
      color: Color(0xFF8B5CF6),
      keywords: ['高い', '値段', '課金', '料金', '無料', '有料', '広告']
    ),
    (
      label: 'ポジティブ',
      color: Color(0xFF22C55E),
      keywords: ['最高', '良い', 'おすすめ', '便利', 'ありがとう', '好き', 'シンプル', '使いやすい']
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final total = reviews.length;
    final data = _topics.map((t) {
      final count = reviews.where((r) {
        final text = '${r.title} ${r.body}';
        return t.keywords.any((kw) => text.contains(kw));
      }).length;
      final pct = total > 0 ? (count / total * 100).round() : 0;
      return (topic: t, count: count, pct: pct);
    }).toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    final maxCount = data.isEmpty
        ? 1
        : data.map((e) => e.count).reduce((a, b) => a > b ? a : b);

    return _card(
      child: Column(
        children: data.asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final e = entry.value;
          final isLast = entry.key == data.length - 1;
          return GestureDetector(
            onTap: () => _showTopicReviews(
              context,
              label: e.topic.label,
              color: e.topic.color,
              keywords: e.topic.keywords,
              reviews: reviews,
            ),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Rank badge
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: e.topic.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Center(
                          child: Text(
                            '$rank',
                            style: TextStyle(
                              color: e.topic.color,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              fontFamily: 'DM Sans',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.topic.label,
                          style: AppTextStyles.body.copyWith(fontSize: 13),
                        ),
                      ),
                      Text(
                        '${e.count}件',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.ink55, fontSize: 11),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: e.topic.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${e.pct}%',
                          style: AppTextStyles.caption.copyWith(
                            color: e.topic.color,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right,
                          size: 16, color: AppColors.ink30),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maxCount > 0 ? e.count / maxCount : 0,
                      backgroundColor: AppColors.ink06,
                      valueColor: AlwaysStoppedAnimation(
                          e.topic.color.withValues(alpha: 0.75)),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  static void _showTopicReviews(
    BuildContext context, {
    required String label,
    required Color color,
    required List<String> keywords,
    required List<AppReview> reviews,
  }) {
    final filtered = reviews.where((r) {
      final text = '${r.title} ${r.body}';
      return keywords.any((kw) => text.contains(kw));
    }).toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TopicReviewsSheet(
          label: label, color: color, reviews: filtered),
    );
  }
}

// ─── Highlight Reviews ───────────────────────────────────

class _HighlightReviewsCard extends StatelessWidget {
  const _HighlightReviewsCard({required this.reviews});
  final List<AppReview> reviews;

  @override
  Widget build(BuildContext context) {
    // 本文が長い（情報量が多い）レビューを代表として選ぶ
    final best = (reviews.where((r) => r.rating >= 4).toList()
          ..sort((a, b) => b.body.length.compareTo(a.body.length)))
        .firstOrNull;
    final worst = (reviews.where((r) => r.rating <= 2).toList()
          ..sort((a, b) => b.body.length.compareTo(a.body.length)))
        .firstOrNull;

    if (best == null && worst == null) {
      return _card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text('代表レビューがありません', style: AppTextStyles.bodySubtle),
          ),
        ),
      );
    }

    return Column(
      children: [
        if (best != null) _HighlightTile(review: best, isPositive: true),
        if (best != null && worst != null) const SizedBox(height: 10),
        if (worst != null) _HighlightTile(review: worst, isPositive: false),
      ],
    );
  }
}

class _HighlightTile extends StatelessWidget {
  const _HighlightTile({required this.review, required this.isPositive});
  final AppReview review;
  final bool isPositive;

  String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return '今日';
    if (diff.inDays < 7) return '${diff.inDays}日前';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}週間前';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}ヶ月前';
    return '${(diff.inDays / 365).floor()}年前';
  }

  @override
  Widget build(BuildContext context) {
    final color =
        isPositive ? const Color(0xFF22C55E) : const Color(0xFFF43F5E);
    final label = isPositive ? '高評価レビュー' : '低評価レビュー';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 10),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 11,
                    color: AppColors.orange,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _relativeDate(review.reviewDate),
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.ink30, fontSize: 10),
              ),
            ],
          ),
          if (review.title.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.title,
              style: AppTextStyles.body
                  .copyWith(fontWeight: FontWeight.w600, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            review.body,
            style: AppTextStyles.bodySubtle.copyWith(fontSize: 12),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Word Cloud ──────────────────────────────────────────

class _WordCloudCard extends StatelessWidget {
  const _WordCloudCard({required this.reviews});
  final List<AppReview> reviews;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _WordCloudPanel(reviews: reviews, positive: true)),
        const SizedBox(width: 10),
        Expanded(child: _WordCloudPanel(reviews: reviews, positive: false)),
      ],
    );
  }
}

class _WordCloudPanel extends StatelessWidget {
  const _WordCloudPanel({required this.reviews, required this.positive});
  final List<AppReview> reviews;
  final bool positive;

  static const _posKeywords = [
    'シンプル', '集中', '使いやすい', 'デザイン', '通知', '軽い',
    '直感的', 'おすすめ', '便利', '最高', '良い', '好き', '快適', '丁寧',
  ];
  static const _negKeywords = [
    'クラッシュ', '課金', 'バグ', '重い', '広告', '遅い',
    '使えない', '最悪', '不具合', '消えた', '落ちる', '高い', '対応して', '固まる',
  ];

  List<({String word, int count})> _extract() {
    final keywords = positive ? _posKeywords : _negKeywords;
    final filtered = positive
        ? reviews.where((r) => r.rating >= 4).toList()
        : reviews.where((r) => r.rating <= 2).toList();
    final counts = <String, int>{};
    for (final kw in keywords) {
      for (final r in filtered) {
        if (r.title.contains(kw) || r.body.contains(kw)) {
          counts[kw] = (counts[kw] ?? 0) + 1;
        }
      }
    }
    return (counts.entries
            .where((e) => e.value > 0)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(10)
        .map((e) => (word: e.key, count: e.value))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final words = _extract();
    final color =
        positive ? const Color(0xFF22C55E) : const Color(0xFFF43F5E);
    final label = positive ? '★4-5 が語る強み' : '★1-2 が語る弱点';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D16121D), blurRadius: 18, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700, color: AppColors.ink55),
              ),
            ],
          ),
          const SizedBox(height: 12),
          words.isEmpty
              ? Text('データなし', style: AppTextStyles.caption)
              : Wrap(
                  spacing: 6,
                  runSpacing: 8,
                  children: words.asMap().entries.map((entry) {
                    final i = entry.key;
                    final w = entry.value;
                    final ratio = words.first.count > 0
                        ? w.count / words.first.count
                        : 0.0;
                    final fontSize = (11 + ratio * 9).clamp(11.0, 20.0);
                    final alpha = (0.4 + ratio * 0.6).clamp(0.4, 1.0);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(
                            alpha: (0.06 + ratio * 0.08).clamp(0.06, 0.14)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        w.word,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: i < 3
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: color.withValues(alpha: alpha),
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }
}

// ─── Market Signals ──────────────────────────────────────

class _MarketSignalsCard extends StatelessWidget {
  const _MarketSignalsCard({required this.reviews});
  final List<AppReview> reviews;

  @override
  Widget build(BuildContext context) {
    final total = reviews.length;
    if (total == 0) return const SizedBox.shrink();

    final now = DateTime.now();

    // 満足度: ★4-5の割合
    final satisfiedCount = reviews.where((r) => r.rating >= 4).length;
    final satisfactionPct = (satisfiedCount / total * 100).round();

    // 不満率: ★1-2の割合
    final dissatisfiedCount = reviews.where((r) => r.rating <= 2).length;
    final dissatisfactionPct = (dissatisfiedCount / total * 100).round();

    // ユーザー熱量: 本文100文字以上のレビューの割合
    final engagedCount = reviews.where((r) => r.body.length >= 100).length;
    final engagementPct = (engagedCount / total * 100).round();

    // レビュー増減: 直近60日 vs 前60日
    final d60 = now.subtract(const Duration(days: 60));
    final d120 = now.subtract(const Duration(days: 120));
    final recent60 = reviews.where((r) => r.reviewDate.isAfter(d60)).length;
    final prior60 = reviews
        .where((r) =>
            r.reviewDate.isAfter(d120) && !r.reviewDate.isAfter(d60))
        .length;
    final int? trendPct = prior60 > 0
        ? ((recent60 - prior60) / prior60 * 100).round()
        : null;

    return _card(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MarketMetric(
                  label: '満足度',
                  sublabel: '★4-5のレビュー割合',
                  value: '$satisfactionPct%',
                  interpretation: satisfactionPct >= 70
                      ? '競合への支持は厚い'
                      : satisfactionPct >= 50
                          ? '一定の満足層あり'
                          : 'ユーザー満足度が低い',
                  color: satisfactionPct >= 70
                      ? const Color(0xFF22C55E)
                      : satisfactionPct >= 50
                          ? AppColors.orange
                          : const Color(0xFFF43F5E),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MarketMetric(
                  label: '不満率',
                  sublabel: '★1-2のレビュー割合',
                  value: '$dissatisfactionPct%',
                  interpretation: dissatisfactionPct >= 20
                      ? '乗り換え需要あり'
                      : dissatisfactionPct >= 10
                          ? '不満は一定数存在'
                          : '概ね支持されている',
                  color: dissatisfactionPct >= 20
                      ? const Color(0xFFF43F5E)
                      : dissatisfactionPct >= 10
                          ? AppColors.orange
                          : const Color(0xFF22C55E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MarketMetric(
                  label: 'ユーザー熱量',
                  sublabel: '長文レビューの割合',
                  value: '$engagementPct%',
                  interpretation: engagementPct >= 50
                      ? '熱心なユーザーが多い'
                      : engagementPct >= 30
                          ? '一定の関与度あり'
                          : 'ライトユーザーが多め',
                  color: engagementPct >= 50
                      ? const Color(0xFF22C55E)
                      : engagementPct >= 30
                          ? AppColors.orange
                          : AppColors.ink55,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MarketMetric(
                  label: 'レビュー増減',
                  sublabel: '直近60日 vs 前60日',
                  value: trendPct == null
                      ? '-'
                      : '${trendPct > 0 ? '+' : ''}$trendPct%',
                  interpretation: trendPct == null
                      ? 'データ不足'
                      : trendPct >= 20
                          ? '競合が急成長中'
                          : trendPct <= -20
                              ? '利用者が減少中'
                              : '安定した市場規模',
                  color: trendPct == null
                      ? AppColors.ink30
                      : trendPct >= 20
                          ? const Color(0xFFF43F5E)
                          : trendPct <= -20
                              ? const Color(0xFF22C55E)
                              : AppColors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MarketMetric extends StatelessWidget {
  const _MarketMetric({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.interpretation,
    required this.color,
  });
  final String label;
  final String sublabel;
  final String value;
  final String interpretation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink55,
                  fontSize: 11)),
          const SizedBox(height: 1),
          Text(sublabel,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.ink30, fontSize: 9)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'DM Sans',
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(interpretation,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.ink55, fontSize: 10, height: 1.4)),
        ],
      ),
    );
  }
}

// ─── Low Rating Breakdown ────────────────────────────────

class _LowRatingBreakdownCard extends StatelessWidget {
  const _LowRatingBreakdownCard({required this.reviews});
  final List<AppReview> reviews;

  static const _topics = [
    (
      label: 'バグ・クラッシュ',
      color: Color(0xFFF43F5E),
      keywords: [
        'バグ', 'クラッシュ', '落ちる', '固まる', 'エラー', '不具合', '壊れ', '動かない', '止まる'
      ]
    ),
    (
      label: 'UI / UX',
      color: Color(0xFFFF9500),
      keywords: [
        '使いにくい', 'デザイン', '操作', 'UI', '画面', 'レイアウト', '見づらい', 'わかりにくい'
      ]
    ),
    (
      label: '機能不足',
      color: Color(0xFF3B82F6),
      keywords: [
        '欲しい', '追加して', '機能', 'できない', 'できれば', 'あったら', '対応して', '未実装'
      ]
    ),
    (
      label: '価格・課金',
      color: Color(0xFF8B5CF6),
      keywords: [
        '高い', '値段', '課金', '料金', '有料', '広告', '課金しないと', '値上げ'
      ]
    ),
    (
      label: 'サポート対応',
      color: Color(0xFF06B6D4),
      keywords: [
        '返信', 'サポート', '問い合わせ', '対応', '無視', '放置', '改善されない', '直らない'
      ]
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final lowReviews = reviews.where((r) => r.rating <= 2).toList();
    final total = lowReviews.length;

    if (total == 0) {
      return _card(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('低評価レビューがありません', style: AppTextStyles.bodySubtle),
          ),
        ),
      );
    }

    final data = _topics.map((t) {
      final count = lowReviews.where((r) {
        final text = '${r.title} ${r.body}';
        return t.keywords.any((kw) => text.contains(kw));
      }).length;
      final pct = (count / total * 100).round();
      return (topic: t, count: count, pct: pct);
    }).toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    final visible = data.where((e) => e.count > 0).toList();
    final maxCount = visible.isEmpty
        ? 1
        : visible.map((e) => e.count).reduce((a, b) => a > b ? a : b);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '★1-2 のレビュー $total件 が語る不満の内訳',
            style: AppTextStyles.caption
                .copyWith(color: AppColors.ink55, fontSize: 11),
          ),
          const SizedBox(height: 14),
          if (visible.isEmpty)
            Text('該当なし', style: AppTextStyles.bodySubtle)
          else
            ...visible.map((e) => GestureDetector(
                  onTap: () => _TopicCard._showTopicReviews(
                    context,
                    label: e.topic.label,
                    color: e.topic.color,
                    keywords: e.topic.keywords,
                    reviews: reviews.where((r) => r.rating <= 2).toList(),
                  ),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: e.topic.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.topic.label,
                              style: AppTextStyles.body.copyWith(fontSize: 13),
                            ),
                          ),
                          Text('${e.count}件',
                              style: AppTextStyles.caption.copyWith(
                                  color: AppColors.ink55, fontSize: 11)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: e.topic.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${e.pct}%',
                              style: AppTextStyles.caption.copyWith(
                                color: e.topic.color,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right,
                              size: 16, color: AppColors.ink30),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: e.count / maxCount,
                          backgroundColor: AppColors.ink06,
                          valueColor: AlwaysStoppedAnimation(
                              e.topic.color.withValues(alpha: 0.75)),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                  ))),
        ],
      ),
    );
  }
}

// ─── Topic Reviews Sheet ─────────────────────────────────

class _TopicReviewsSheet extends StatelessWidget {
  const _TopicReviewsSheet({
    required this.label,
    required this.color,
    required this.reviews,
  });

  final String label;
  final Color color;
  final List<AppReview> reviews;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.ink12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$label のレビュー',
                    style: AppTextStyles.sectionHeading,
                  ),
                ),
                Text(
                  '${reviews.length}件',
                  style: AppTextStyles.caption.copyWith(color: AppColors.ink30),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.ink06),
          Expanded(
            child: reviews.isEmpty
                ? Center(
                    child: Text('該当するレビューがありません',
                        style: AppTextStyles.bodySubtle))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: reviews.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.ink06),
                    itemBuilder: (context, i) =>
                        _SheetReviewItem(review: reviews[i], accentColor: color),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SheetReviewItem extends StatelessWidget {
  const _SheetReviewItem({required this.review, required this.accentColor});
  final AppReview review;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Stars
              ...List.generate(5, (i) => Icon(
                    i < review.rating ? Icons.star : Icons.star_border,
                    size: 12,
                    color: AppColors.orange,
                  )),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  review.title,
                  style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (review.body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              review.body,
              style: AppTextStyles.body.copyWith(
                  color: AppColors.ink55, fontSize: 13, height: 1.5),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '${review.authorName} • ${review.reviewDate.year}/${review.reviewDate.month.toString().padLeft(2, '0')}/${review.reviewDate.day.toString().padLeft(2, '0')}',
            style: AppTextStyles.caption.copyWith(
                color: AppColors.ink30, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Card Shell ───────────────────────────────────

Widget _card({required Widget child}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(
            color: Color(0x0D16121D), blurRadius: 18, offset: Offset(0, 4))
      ],
    ),
    child: child,
  );
}
