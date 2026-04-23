import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_genres.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/rewarded_ad_service.dart';
import '../../../features/explore/explore_provider.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../features/app_detail/app_detail_provider.dart';
import '../../../shared/models/app_model.dart';
import '../../../shared/models/app_review.dart';

final exploreCompareAppsProvider = StateProvider<List<String>>((ref) => []);

const _kAppColors = [
  Color(0xFFFF9500),
  Color(0xFF22C55E),
  Color(0xFF3B82F6),
  Color(0xFF8B5CF6),
];

const _kTopics = <({String label, Color color, List<String> keywords})>[
  (
    label: 'バグ・クラッシュ',
    color: Color(0xFFF43F5E),
    keywords: ['バグ', 'クラッシュ', '落ちる', '不具合', 'エラー', '壊れ', '動かな', '起動しない'],
  ),
  (
    label: 'パフォーマンス',
    color: Color(0xFFF97316),
    keywords: ['重い', '遅い', 'カクカク', '固まる', '応答しない', 'フリーズ', 'もたつく'],
  ),
  (
    label: 'UI/UX',
    color: Color(0xFFEAB308),
    keywords: ['使いにくい', 'デザイン', '操作', 'UI', '画面', 'わかりにくい', '見づらい'],
  ),
  (
    label: '機能要望',
    color: Color(0xFF3B82F6),
    keywords: ['欲しい', '追加して', '機能', 'できない', '対応して', '実装', 'できれば'],
  ),
  (
    label: '価格・課金',
    color: Color(0xFF8B5CF6),
    keywords: ['高い', '課金', '有料', '月額', '料金', '値段', '費用', '広告'],
  ),
  (
    label: 'ポジティブ',
    color: Color(0xFF22C55E),
    keywords: ['最高', '良い', 'おすすめ', '便利', 'シンプル', '使いやすい', '好き', 'サクサク', '快適'],
  ),
];

// ── Stopwords for keyword extraction ─────────────────────
const _kStopwords = {
  'です', 'ます', 'ません', 'ました', 'でし', 'ない', 'なく', 'なり', 'なっ',
  'ある', 'あり', 'いる', 'いて', 'いた', 'いい', 'する', 'して', 'でき',
  'なる', 'れる', 'られ', 'この', 'その', 'あの', 'どの', 'これ', 'それ',
  'こと', 'もの', 'ため', 'から', 'まで', 'ので', 'けど', 'でも', 'また',
  'など', 'まし', 'よう', 'ところ', 'アプリ', 'もっと', '思い', '思う',
  'てい', 'てく', 'には', 'ほし', 'だと', 'とか', 'たり', 'たら', 'たい',
  'って', 'だっ', 'した', 'とい', 'れて', '使い', '使っ', '使え',
};

// ── Helper functions ─────────────────────────────────────

double _topicPct(List<AppReview> reviews, List<String> keywords) {
  if (reviews.isEmpty) return 0;
  final count = reviews.where((r) {
    final text = '${r.title} ${r.body}';
    return keywords.any((kw) => text.contains(kw));
  }).length;
  return count / reviews.length * 100;
}

String _fmt(int n) {
  if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}万';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return n.toString();
}

String _fmtDate(DateTime dt) =>
    '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';

double _monthlyPaceNum(AppModel? app) {
  final rd = app?.releaseDate;
  final count = app?.userRatingCount ?? 0;
  if (rd == null || count == 0) return 0;
  final released = DateTime.tryParse(rd);
  if (released == null) return 0;
  final months =
      (DateTime.now().difference(released).inDays / 30).clamp(1, double.infinity);
  return count / months;
}

String _fmtPace(double pace) {
  if (pace == 0) return '—';
  if (pace >= 10000) return '${(pace / 10000).toStringAsFixed(1)}万/月';
  if (pace >= 1000) return '${(pace / 1000).toStringAsFixed(1)}k/月';
  return '${pace.round()}/月';
}

double? _recentAvgRating(List<AppReview> reviews, {int days = 30}) {
  final cutoff = DateTime.now().subtract(Duration(days: days));
  final recent = reviews.where((r) => r.reviewDate.isAfter(cutoff)).toList();
  if (recent.isEmpty) return null;
  return recent.map((r) => r.rating.toDouble()).reduce((a, b) => a + b) /
      recent.length;
}

List<String> _extractKeywords(List<AppReview> reviews,
    {bool positive = true, int top = 6}) {
  final filtered =
      reviews.where((r) => positive ? r.rating >= 4 : r.rating <= 2).toList();
  if (filtered.isEmpty) return [];

  final freq = <String, int>{};
  final splitRe =
      RegExp(r'[\s、。！？「」【】（）・\n\r,.!?()\[\]{}""' "'''" r'\-=_/\\|<>@#%^&*]');
  for (final r in filtered) {
    final words = '${r.title} ${r.body}'.split(splitRe);
    for (var w in words) {
      w = w.trim();
      if (w.length < 2 || w.length > 8) continue;
      if (_kStopwords.contains(w)) continue;
      if (RegExp(r'^[0-9a-zA-Z]+$').hasMatch(w)) continue;
      freq[w] = (freq[w] ?? 0) + 1;
    }
  }

  final sorted = freq.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(top).map((e) => e.key).toList();
}

typedef _VersionStat = ({String version, double avgRating, int count});

List<_VersionStat> _getVersionRatings(List<AppReview> reviews) {
  final map = <String, List<int>>{};
  for (final r in reviews) {
    final v = (r.version?.isNotEmpty == true) ? r.version! : '不明';
    (map[v] ??= []).add(r.rating);
  }
  final result = map.entries
      .map<_VersionStat>((e) => (
            version: e.key,
            avgRating:
                e.value.fold<int>(0, (a, b) => a + b) / e.value.length,
            count: e.value.length,
          ))
      .toList();
  result.sort((a, b) {
    if (a.version == '不明') return 1;
    if (b.version == '不明') return -1;
    return b.count.compareTo(a.count);
  });
  return result.take(5).toList();
}

// ─── Main tab ──────────────────────────────────────────

class ExploreCompareTab extends ConsumerWidget {
  const ExploreCompareTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compareApps = ref.watch(exploreCompareAppsProvider);
    final slotUnlocked = ref.watch(compareSlotUnlockedProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      children: [
        _AppSelectorSection(
          compareApps: compareApps,
          slotUnlocked: slotUnlocked,
          onAdd: (id) {
            final list = [...ref.read(exploreCompareAppsProvider)];
            if (!list.contains(id)) list.add(id);
            ref.read(exploreCompareAppsProvider.notifier).state = list;
          },
          onRemove: (id) {
            final list = [...ref.read(exploreCompareAppsProvider)]..remove(id);
            ref.read(exploreCompareAppsProvider.notifier).state = list;
          },
          onAutoSelect: (ids) =>
              ref.read(exploreCompareAppsProvider.notifier).state = ids,
          onUnlockTap: () => _unlockAd(context, ref),
          onAppTap: (id) => context.push('/app/$id'),
        ),
        if (compareApps.length < 2) ...[
          const SizedBox(height: 48),
          const _EmptyState(),
        ] else ...[
          const SizedBox(height: 24),
          _CompareBody(compareApps: compareApps),
        ],
      ],
    );
  }

  Future<void> _unlockAd(BuildContext context, WidgetRef ref) async {
    final ok = await ref.read(rewardedAdServiceProvider).show();
    if (ok) {
      ref.read(compareSlotUnlockedProvider.notifier).state = true;
    } else if (context.mounted) {
      showAppSnackBar(context, '広告を最後まで視聴すると追加スロットが解放されます');
    }
  }
}

// ─── App selector ──────────────────────────────────────

class _AppSelectorSection extends ConsumerStatefulWidget {
  const _AppSelectorSection({
    required this.compareApps,
    required this.slotUnlocked,
    required this.onAdd,
    required this.onRemove,
    required this.onAutoSelect,
    required this.onUnlockTap,
    required this.onAppTap,
  });

  final List<String> compareApps;
  final bool slotUnlocked;
  final void Function(String) onAdd;
  final void Function(String) onRemove;
  final void Function(List<String>) onAutoSelect;
  final VoidCallback onUnlockTap;
  final void Function(String) onAppTap;

  @override
  ConsumerState<_AppSelectorSection> createState() =>
      _AppSelectorSectionState();
}

class _AppSelectorSectionState extends ConsumerState<_AppSelectorSection> {
  bool _autoLoading = false;

  Future<void> _showCategoryPicker() async {
    final cats = ref.read(categoriesProvider).valueOrNull ?? [];
    if (cats.isEmpty) {
      showAppSnackBar(context, 'カテゴリを読み込み中です...');
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CategorySheet(categories: cats),
    );
    if (selected == null || !mounted) return;

    setState(() => _autoLoading = true);
    try {
      final apps = await ref
          .read(firestoreServiceProvider)
          .getAppsByCategory(selected, limit: 4);
      if (apps.isEmpty) {
        if (mounted) showAppSnackBar(context, '該当カテゴリのアプリが見つかりませんでした');
        return;
      }
      widget.onAutoSelect(apps.map((a) => a.trackId.toString()).toList());
    } finally {
      if (mounted) setState(() => _autoLoading = false);
    }
  }

  void _showAppSearch() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AppSearchSheet(
        service: ref.read(firestoreServiceProvider),
        alreadyAdded: widget.compareApps,
        onAdd: widget.onAdd,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxSlots = widget.slotUnlocked ? 4 : 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) {
            final color = _kAppColors[i % _kAppColors.length];
            if (i < widget.compareApps.length) {
              return Expanded(
                child: _SlotFilled(
                  trackId: widget.compareApps[i],
                  color: color,
                  onRemove: () => widget.onRemove(widget.compareApps[i]),
                  onTap: () => widget.onAppTap(widget.compareApps[i]),
                ),
              );
            }
            if (i >= maxSlots) {
              return Expanded(child: _SlotLocked(onTap: widget.onUnlockTap));
            }
            return Expanded(child: _SlotEmpty(onTap: _showAppSearch));
          }),
        ),
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onTap: _autoLoading ? null : _showCategoryPicker,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _autoLoading
                      ? AppColors.ink12
                      : AppColors.orange.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_autoLoading)
                    const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.orange),
                    )
                  else
                    const Icon(Icons.auto_awesome,
                        size: 13, color: AppColors.orange),
                  const SizedBox(width: 6),
                  Text(
                    _autoLoading ? '選定中...' : 'カテゴリから競合を自動選定',
                    style: AppTextStyles.caption.copyWith(
                      color:
                          _autoLoading ? AppColors.ink30 : AppColors.orange,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Slots ─────────────────────────────────────────────

class _SlotFilled extends ConsumerWidget {
  const _SlotFilled({
    required this.trackId,
    required this.color,
    required this.onRemove,
    required this.onTap,
  });

  final String trackId;
  final Color color;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appDetailProvider(trackId)).valueOrNull;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
              child: Column(
                children: [
                  _AppIcon(url: app?.artworkUrl100, size: 40, color: color),
                  const SizedBox(height: 5),
                  Text(
                    app?.trackName ?? '...',
                    style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Positioned(
              top: -5,
              right: -5,
              child: GestureDetector(
                onTap: onRemove,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                      color: AppColors.ink55, shape: BoxShape.circle),
                  child: const Icon(Icons.close,
                      size: 11, color: AppColors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotEmpty extends StatelessWidget {
  const _SlotEmpty({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        height: 96,
        decoration: BoxDecoration(
          color: AppColors.orangeBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.orange.withValues(alpha: 0.35), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                  color: AppColors.orange, shape: BoxShape.circle),
              child: const Icon(Icons.add_rounded,
                  size: 18, color: AppColors.white),
            ),
            const SizedBox(height: 5),
            Text(
              '追加',
              style: AppTextStyles.caption.copyWith(
                  color: AppColors.orange,
                  fontWeight: FontWeight.w700,
                  fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotLocked extends StatelessWidget {
  const _SlotLocked({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        height: 96,
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.ink12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded,
                size: 20, color: AppColors.ink30),
            const SizedBox(height: 4),
            Text('広告で解放',
                style: AppTextStyles.caption
                    .copyWith(fontSize: 10, color: AppColors.ink30)),
          ],
        ),
      ),
    );
  }
}

// ─── Empty state ───────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
                color: AppColors.orangeBg, shape: BoxShape.circle),
            child: const Icon(Icons.compare_arrows_rounded,
                size: 30, color: AppColors.orange),
          ),
          const SizedBox(height: 16),
          Text('アプリを2つ以上追加して',
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('比較を開始してください', style: AppTextStyles.bodySubtle),
        ],
      ),
    );
  }
}

// ─── Compare body ──────────────────────────────────────

class _CompareBody extends ConsumerWidget {
  const _CompareBody({required this.compareApps});
  final List<String> compareApps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appAsyncs =
        compareApps.map((id) => ref.watch(appDetailProvider(id))).toList();
    final reviewAsyncs = compareApps
        .map((id) => ref.watch(reviewsProvider(ReviewQuery(trackId: id))))
        .toList();

    if (appAsyncs.any((a) => a.isLoading) ||
        reviewAsyncs.any((r) => r.isLoading)) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child:
            Center(child: CircularProgressIndicator(color: AppColors.orange)),
      );
    }

    final apps = appAsyncs.map((a) => a.valueOrNull).toList();
    final reviewLists =
        reviewAsyncs.map((r) => r.valueOrNull ?? <AppReview>[]).toList();
    final colors = List.generate(
        compareApps.length, (i) => _kAppColors[i % _kAppColors.length]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('評価サマリー'),
        const SizedBox(height: 8),
        _SummaryCard(apps: apps, colors: colors),
        const SizedBox(height: 24),
        const _SectionLabel('モメンタム'),
        const SizedBox(height: 8),
        _MomentumCard(apps: apps, reviewLists: reviewLists, colors: colors),
        const SizedBox(height: 24),
        const _SectionLabel('指標比較'),
        const SizedBox(height: 8),
        _MetricsCard(apps: apps, reviewLists: reviewLists, colors: colors),
        const SizedBox(height: 24),
        const _SectionLabel('評価分布'),
        const SizedBox(height: 8),
        _StarDistCard(reviewLists: reviewLists, colors: colors),
        const SizedBox(height: 24),
        const _SectionLabel('バージョン別評価'),
        const SizedBox(height: 8),
        _VersionRatingsCard(apps: apps, reviewLists: reviewLists, colors: colors),
        const SizedBox(height: 24),
        const _SectionLabel('トピック対比'),
        const SizedBox(height: 8),
        _TopicCard(apps: apps, reviewLists: reviewLists, colors: colors),
        const SizedBox(height: 24),
        const _SectionLabel('頻出キーワード'),
        const SizedBox(height: 8),
        _KeywordsCard(apps: apps, reviewLists: reviewLists, colors: colors),
        const SizedBox(height: 24),
        const _SectionLabel('最新レビュー'),
        const SizedBox(height: 8),
        _LatestReviewsCard(
            apps: apps, reviewLists: reviewLists, colors: colors),
      ],
    );
  }
}

// ─── Summary card ──────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.apps, required this.colors});
  final List<AppModel?> apps;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    int bestIdx = -1;
    double bestRating = -1;
    for (int i = 0; i < apps.length; i++) {
      final r = apps[i]?.averageUserRating ?? 0;
      if (r > bestRating) {
        bestRating = r;
        bestIdx = i;
      }
    }

    return _Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: apps.asMap().entries.map((e) {
            final i = e.key;
            final app = e.value;
            final color = colors[i];
            final isBest = i == bestIdx && app?.averageUserRating != null;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    _AppIcon(url: app?.artworkUrl100, size: 48, color: color),
                    const SizedBox(height: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      app?.trackName ?? '...',
                      style: AppTextStyles.caption.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink),
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      app?.averageUserRating?.toStringAsFixed(1) ?? '—',
                      style: AppTextStyles.numericLarge.copyWith(
                          color: isBest ? color : AppColors.ink),
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      height: 18,
                      child: isBest
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Best',
                                style: AppTextStyles.caption.copyWith(
                                    color: color,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 2),
                    if (app?.averageUserRating != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (s) {
                          final rating = app!.averageUserRating!;
                          final filled = s < rating.floor();
                          final half = !filled && (rating - s) >= 0.5;
                          return Icon(
                            filled
                                ? Icons.star_rounded
                                : half
                                    ? Icons.star_half_rounded
                                    : Icons.star_outline_rounded,
                            size: 12,
                            color: color,
                          );
                        }),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '${_fmt(app?.userRatingCount ?? 0)}件',
                      style: AppTextStyles.caption
                          .copyWith(fontSize: 10, color: AppColors.ink55),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Momentum card ─────────────────────────────────────

class _MomentumCard extends StatelessWidget {
  const _MomentumCard({
    required this.apps,
    required this.reviewLists,
    required this.colors,
  });
  final List<AppModel?> apps;
  final List<List<AppReview>> reviewLists;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final paces = apps.map(_monthlyPaceNum).toList();
    final recentAvgs =
        reviewLists.map((r) => _recentAvgRating(r, days: 30)).toList();
    final overallAvgs =
        apps.map((a) => a?.averageUserRating ?? 0.0).toList();

    return _Card(
      child: Column(
        children: [
          _AppIconHeader(apps: apps, colors: colors),
          const Divider(height: 1, color: AppColors.ink06),
          _MRow(
            label: '月間ペース',
            values: paces.map(_fmtPace).toList(),
            nums: paces,
            colors: colors,
            higher: true,
          ),
          _MRow(
            label: '直近30日\n平均評価',
            values: recentAvgs
                .map((v) => v != null ? v.toStringAsFixed(1) : '—')
                .toList(),
            nums: recentAvgs.map((v) => v ?? 0.0).toList(),
            colors: colors,
            higher: true,
          ),
          _MRowTrend(
            label: 'トレンド\n(直近vs全体)',
            recentAvgs: recentAvgs,
            overallAvgs: overallAvgs,
            colors: colors,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _MRowTrend extends StatelessWidget {
  const _MRowTrend({
    required this.label,
    required this.recentAvgs,
    required this.overallAvgs,
    required this.colors,
    this.isLast = false,
  });
  final String label;
  final List<double?> recentAvgs;
  final List<double> overallAvgs;
  final List<Color> colors;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              SizedBox(
                width: 96,
                child: Text(label,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.ink55, fontSize: 11),
                    maxLines: 2),
              ),
              ...recentAvgs.asMap().entries.map((e) {
                final recent = e.value;
                final overall = overallAvgs[e.key];
                final color = colors[e.key];
                if (recent == null || overall == 0) {
                  return const Expanded(
                    child: Center(
                      child: Text('—',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.ink30)),
                    ),
                  );
                }
                final diff = recent - overall;
                final isUp = diff > 0.05;
                final isDown = diff < -0.05;
                final trendColor = isUp
                    ? const Color(0xFF22C55E)
                    : isDown
                        ? const Color(0xFFF43F5E)
                        : AppColors.ink30;
                final icon = isUp
                    ? Icons.trending_up_rounded
                    : isDown
                        ? Icons.trending_down_rounded
                        : Icons.trending_flat_rounded;
                final diffStr =
                    '${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(1)}';
                return Expanded(
                  child: Column(
                    children: [
                      Icon(icon, size: 18, color: trendColor),
                      Text(
                        diffStr,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isUp
                              ? color
                              : isDown
                                  ? const Color(0xFFF43F5E)
                                  : AppColors.ink30,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, color: AppColors.ink06),
      ],
    );
  }
}

// ─── Metrics card ──────────────────────────────────────

class _MetricsCard extends StatelessWidget {
  const _MetricsCard({
    required this.apps,
    required this.reviewLists,
    required this.colors,
  });
  final List<AppModel?> apps;
  final List<List<AppReview>> reviewLists;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final ratings = apps.map((a) => a?.averageUserRating ?? 0.0).toList();
    final counts = apps.map((a) => (a?.userRatingCount ?? 0).toDouble()).toList();
    final bugPcts =
        reviewLists.map((r) => _topicPct(r, _kTopics[0].keywords)).toList();
    final perfPcts =
        reviewLists.map((r) => _topicPct(r, _kTopics[1].keywords)).toList();
    final posPcts =
        reviewLists.map((r) => _topicPct(r, _kTopics[5].keywords)).toList();
    final pricePcts =
        reviewLists.map((r) => _topicPct(r, _kTopics[4].keywords)).toList();
    final highPcts = reviewLists
        .map((r) => r.isEmpty
            ? 0.0
            : r.where((rv) => rv.rating >= 4).length / r.length * 100)
        .toList();
    final lowPcts = reviewLists
        .map((r) => r.isEmpty
            ? 0.0
            : r.where((rv) => rv.rating <= 2).length / r.length * 100)
        .toList();
    // Avg review length (engagement)
    final avgLens = reviewLists
        .map((r) => r.isEmpty
            ? 0.0
            : r.map((rv) => rv.body.length.toDouble()).reduce((a, b) => a + b) /
                r.length)
        .toList();

    return _Card(
      child: Column(
        children: [
          _AppIconHeader(apps: apps, colors: colors),
          const Divider(height: 1, color: AppColors.ink06),
          _MRow(
              label: '★ 評価',
              values: ratings
                  .map((r) => r > 0 ? r.toStringAsFixed(1) : '—')
                  .toList(),
              nums: ratings,
              colors: colors,
              higher: true),
          _MRow(
              label: 'レビュー数',
              values: counts.map((c) => _fmt(c.toInt())).toList(),
              nums: counts,
              colors: colors,
              higher: true),
          _MRow(
              label: '高評価率\n(4-5★)',
              values:
                  highPcts.map((p) => '${p.toStringAsFixed(1)}%').toList(),
              nums: highPcts,
              colors: colors,
              higher: true),
          _MRow(
              label: '低評価率\n(1-2★)',
              values: lowPcts.map((p) => '${p.toStringAsFixed(1)}%').toList(),
              nums: lowPcts,
              colors: colors,
              higher: false),
          _MRow(
              label: 'バグ言及率',
              values:
                  bugPcts.map((p) => '${p.toStringAsFixed(1)}%').toList(),
              nums: bugPcts,
              colors: colors,
              higher: false),
          _MRow(
              label: 'パフォーマンス\n不満率',
              values:
                  perfPcts.map((p) => '${p.toStringAsFixed(1)}%').toList(),
              nums: perfPcts,
              colors: colors,
              higher: false),
          _MRow(
              label: '価格・課金\n不満率',
              values:
                  pricePcts.map((p) => '${p.toStringAsFixed(1)}%').toList(),
              nums: pricePcts,
              colors: colors,
              higher: false),
          _MRow(
              label: 'ポジティブ率',
              values:
                  posPcts.map((p) => '${p.toStringAsFixed(1)}%').toList(),
              nums: posPcts,
              colors: colors,
              higher: true),
          _MRow(
              label: '平均レビュー\n文字数',
              values: avgLens
                  .map((l) => l > 0 ? '${l.round()}文字' : '—')
                  .toList(),
              nums: avgLens,
              colors: colors,
              higher: true,
              isLast: true),
        ],
      ),
    );
  }
}

class _AppIconHeader extends StatelessWidget {
  const _AppIconHeader({required this.apps, required this.colors});
  final List<AppModel?> apps;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Row(
        children: [
          const SizedBox(width: 96),
          ...apps.asMap().entries.map((e) => Expanded(
                child: Column(
                  children: [
                    _AppIcon(
                        url: e.value?.artworkUrl100,
                        size: 28,
                        color: colors[e.key]),
                    const SizedBox(height: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: colors[e.key], shape: BoxShape.circle),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _MRow extends StatelessWidget {
  const _MRow({
    required this.label,
    required this.values,
    required this.nums,
    required this.colors,
    required this.higher,
    this.isLast = false,
  });

  final String label;
  final List<String> values;
  final List<double> nums;
  final List<Color> colors;
  final bool higher;
  final bool isLast;

  int get _best {
    if (nums.isEmpty) return -1;
    double b = nums[0];
    int idx = 0;
    for (int i = 1; i < nums.length; i++) {
      if (higher ? nums[i] > b : nums[i] < b) {
        b = nums[i];
        idx = i;
      }
    }
    return idx;
  }

  @override
  Widget build(BuildContext context) {
    final best = _best;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              SizedBox(
                width: 96,
                child: Text(label,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.ink55, fontSize: 11),
                    maxLines: 2),
              ),
              ...values.asMap().entries.map((e) {
                final isBest = e.key == best;
                return Expanded(
                  child: Text(
                    e.value,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 13,
                      fontWeight:
                          isBest ? FontWeight.w700 : FontWeight.w400,
                      color: isBest ? colors[e.key] : AppColors.ink,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, color: AppColors.ink06),
      ],
    );
  }
}

// ─── Star distribution card ────────────────────────────

class _StarDistCard extends StatelessWidget {
  const _StarDistCard({required this.reviewLists, required this.colors});
  final List<List<AppReview>> reviewLists;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          children: List.generate(5, (s) {
            final star = 5 - s;
            final pcts = reviewLists.map((reviews) {
              if (reviews.isEmpty) return 0.0;
              return reviews.where((r) => r.rating == star).length /
                  reviews.length;
            }).toList();
            final maxPct =
                pcts.reduce((a, b) => a > b ? a : b).clamp(0.001, 1.0);

            return Padding(
              padding: EdgeInsets.only(bottom: s < 4 ? 12 : 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text('$star★',
                        style: AppTextStyles.caption.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink55)),
                  ),
                  Expanded(
                    child: Column(
                      children: pcts.asMap().entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(children: [
                            Expanded(
                              child: LayoutBuilder(
                                  builder: (context, constraints) {
                                return Stack(children: [
                                  Container(
                                      height: 8,
                                      decoration: BoxDecoration(
                                          color: AppColors.ink06,
                                          borderRadius:
                                              BorderRadius.circular(4))),
                                  Container(
                                    height: 8,
                                    width: constraints.maxWidth *
                                        (e.value / maxPct),
                                    decoration: BoxDecoration(
                                        color: colors[e.key],
                                        borderRadius:
                                            BorderRadius.circular(4)),
                                  ),
                                ]);
                              }),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 32,
                              child: Text(
                                  '${(e.value * 100).toStringAsFixed(0)}%',
                                  style: AppTextStyles.caption.copyWith(
                                      fontSize: 10,
                                      color: AppColors.ink55)),
                            ),
                          ]),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─── Version ratings card ──────────────────────────────

class _VersionRatingsCard extends StatelessWidget {
  const _VersionRatingsCard({
    required this.apps,
    required this.reviewLists,
    required this.colors,
  });
  final List<AppModel?> apps;
  final List<List<AppReview>> reviewLists;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          children: apps.asMap().entries.map((e) {
            final app = e.value;
            final color = colors[e.key];
            final stats = _getVersionRatings(reviewLists[e.key]);
            final isLast = e.key == apps.length - 1;

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        app?.trackName ?? '...',
                        style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppColors.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  if (stats.isEmpty)
                    Text('バージョンデータなし',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.ink30, fontSize: 10))
                  else
                    ...stats.map((s) {
                      final barWidth = (s.avgRating / 5.0).clamp(0.0, 1.0);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          SizedBox(
                            width: 72,
                            child: Text(
                              's v${s.version}',
                              style: AppTextStyles.caption.copyWith(
                                  fontSize: 10, color: AppColors.ink55),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            child: LayoutBuilder(
                                builder: (context, constraints) {
                              return Stack(children: [
                                Container(
                                    height: 8,
                                    decoration: BoxDecoration(
                                        color: AppColors.ink06,
                                        borderRadius:
                                            BorderRadius.circular(4))),
                                Container(
                                  height: 8,
                                  width: constraints.maxWidth * barWidth,
                                  decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.8),
                                      borderRadius:
                                          BorderRadius.circular(4)),
                                ),
                              ]);
                            }),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 52,
                            child: Text(
                              '${s.avgRating.toStringAsFixed(1)}★ (${s.count}件)',
                              style: AppTextStyles.caption.copyWith(
                                  fontSize: 9, color: AppColors.ink55),
                            ),
                          ),
                        ]),
                      );
                    }),
                  if (!isLast) ...[
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: AppColors.ink06),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Topic card ────────────────────────────────────────

class _TopicCard extends StatelessWidget {
  const _TopicCard({
    required this.apps,
    required this.reviewLists,
    required this.colors,
  });
  final List<AppModel?> apps;
  final List<List<AppReview>> reviewLists;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          children: _kTopics.asMap().entries.map((entry) {
            final topic = entry.value;
            final isLast = entry.key == _kTopics.length - 1;
            final pcts = reviewLists
                .map((r) => _topicPct(r, topic.keywords))
                .toList();
            final maxPct = pcts.isEmpty
                ? 1.0
                : pcts
                    .reduce((a, b) => a > b ? a : b)
                    .clamp(1.0, double.infinity);

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: topic.color, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(topic.label,
                        style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppColors.ink)),
                  ]),
                  const SizedBox(height: 7),
                  ...pcts.asMap().entries.map((e) {
                    final pct = e.value;
                    final color = colors[e.key];
                    final app = apps[e.key];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        SizedBox(
                          width: 64,
                          child: Text(
                            app?.trackName ?? '',
                            style: AppTextStyles.caption.copyWith(
                                fontSize: 10, color: AppColors.ink55),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          child: LayoutBuilder(
                              builder: (context, constraints) {
                            return Stack(children: [
                              Container(
                                  height: 10,
                                  decoration: BoxDecoration(
                                      color: AppColors.ink06,
                                      borderRadius:
                                          BorderRadius.circular(5))),
                              Container(
                                height: 10,
                                width:
                                    constraints.maxWidth * (pct / maxPct),
                                decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.85),
                                    borderRadius:
                                        BorderRadius.circular(5)),
                              ),
                            ]);
                          }),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 38,
                          child: Text('${pct.toStringAsFixed(1)}%',
                              style: AppTextStyles.caption.copyWith(
                                  fontSize: 10, color: AppColors.ink55)),
                        ),
                      ]),
                    );
                  }),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Keywords card ─────────────────────────────────────

class _KeywordsCard extends StatelessWidget {
  const _KeywordsCard({
    required this.apps,
    required this.reviewLists,
    required this.colors,
  });
  final List<AppModel?> apps;
  final List<List<AppReview>> reviewLists;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          children: apps.asMap().entries.map((e) {
            final app = e.value;
            final color = colors[e.key];
            final reviews = reviewLists[e.key];
            final posKw = _extractKeywords(reviews, positive: true, top: 5);
            final negKw = _extractKeywords(reviews, positive: false, top: 5);
            final isLast = e.key == apps.length - 1;

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        app?.trackName ?? '...',
                        style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppColors.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  // Positive keywords
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.thumb_up_rounded,
                          size: 12, color: Color(0xFF22C55E)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: posKw.isEmpty
                            ? Text('データなし',
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.ink30, fontSize: 10))
                            : Wrap(
                                spacing: 5,
                                runSpacing: 4,
                                children: posKw
                                    .map((w) => _Chip(
                                        label: w,
                                        bg: const Color(0xFF22C55E)
                                            .withValues(alpha: 0.1),
                                        textColor:
                                            const Color(0xFF16A34A)))
                                    .toList(),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Negative keywords
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.thumb_down_rounded,
                          size: 12, color: Color(0xFFF43F5E)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: negKw.isEmpty
                            ? Text('データなし',
                                style: AppTextStyles.caption.copyWith(
                                    color: AppColors.ink30, fontSize: 10))
                            : Wrap(
                                spacing: 5,
                                runSpacing: 4,
                                children: negKw
                                    .map((w) => _Chip(
                                        label: w,
                                        bg: const Color(0xFFF43F5E)
                                            .withValues(alpha: 0.1),
                                        textColor:
                                            const Color(0xFFDC2626)))
                                    .toList(),
                              ),
                      ),
                    ],
                  ),
                  if (!isLast) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppColors.ink06),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label, required this.bg, required this.textColor});
  final String label;
  final Color bg;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: AppTextStyles.caption
              .copyWith(fontSize: 10, color: textColor, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Latest reviews card ───────────────────────────────

class _LatestReviewsCard extends StatelessWidget {
  const _LatestReviewsCard({
    required this.apps,
    required this.reviewLists,
    required this.colors,
  });
  final List<AppModel?> apps;
  final List<List<AppReview>> reviewLists;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final all = <({AppReview review, int appIdx})>[];
    for (int i = 0; i < reviewLists.length; i++) {
      for (final r in reviewLists[i].take(5)) {
        all.add((review: r, appIdx: i));
      }
    }
    all.sort((a, b) => b.review.reviewDate.compareTo(a.review.reviewDate));
    final shown = all.take(10).toList();

    if (shown.isEmpty) {
      return _Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
              child: Text('レビューデータがありません',
                  style: AppTextStyles.bodySubtle)),
        ),
      );
    }

    return _Card(
      child: Column(
        children: shown.asMap().entries.map((e) {
          final item = e.value;
          final review = item.review;
          final appIdx = item.appIdx;
          final color = colors[appIdx];
          final app = apps[appIdx];
          final isLast = e.key == shown.length - 1;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          app?.trackName ?? '',
                          style: AppTextStyles.caption.copyWith(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ...List.generate(
                          5,
                          (s) => Icon(
                                s < review.rating
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 11,
                                color: AppColors.orange,
                              )),
                      const Spacer(),
                      Text(
                        _fmtDate(review.reviewDate),
                        style: AppTextStyles.caption
                            .copyWith(fontSize: 10, color: AppColors.ink30),
                      ),
                    ]),
                    if (review.title.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(review.title,
                          style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: AppColors.ink)),
                    ],
                    const SizedBox(height: 3),
                    Text(
                      review.body,
                      style: AppTextStyles.bodySubtle
                          .copyWith(fontSize: 12, height: 1.5),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!isLast) const Divider(height: 1, color: AppColors.ink06),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─── Shared widgets ────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.all(Radius.circular(18)),
        boxShadow: [
          BoxShadow(
              color: Color(0x0D16121D),
              blurRadius: 16,
              offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: AppTextStyles.sectionLabel);
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.url, this.size = 48, required this.color});
  final String? url;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: url != null && url!.isNotEmpty
          ? (kIsWeb
              ? Image.network(url!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder())
              : CachedNetworkImage(
                  imageUrl: url!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _placeholder(),
                ))
          : _placeholder(),
    );
  }

  Widget _placeholder() => Container(
        width: size,
        height: size,
        color: color.withValues(alpha: 0.1),
        child: Icon(Icons.apps,
            size: size * 0.4, color: color.withValues(alpha: 0.5)),
      );
}

// ─── Category sheet ────────────────────────────────────

class _CategorySheet extends StatelessWidget {
  const _CategorySheet({required this.categories});
  final List<String> categories;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.ink12,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text('カテゴリを選択', style: AppTextStyles.sectionHeading),
          ),
          const Divider(height: 1, color: AppColors.ink06),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: categories.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.ink06),
              itemBuilder: (context, i) => ListTile(
                title: Text(genreJa(categories[i]),
                    style: AppTextStyles.body),
                onTap: () => Navigator.of(context).pop(categories[i]),
              ),
            ),
          ),
          SizedBox(
              height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

// ─── App search sheet ──────────────────────────────────

class _AppSearchSheet extends StatefulWidget {
  const _AppSearchSheet({
    required this.service,
    required this.alreadyAdded,
    required this.onAdd,
  });
  final FirestoreService service;
  final List<String> alreadyAdded;
  final void Function(String) onAdd;

  @override
  State<_AppSearchSheet> createState() => _AppSearchSheetState();
}

class _AppSearchSheetState extends State<_AppSearchSheet> {
  final _ctrl = TextEditingController();
  List<AppModel> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    final results = await widget.service.searchApps(q.trim());
    if (mounted) {
      setState(() {
        _results = results;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.ink12,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text('アプリを追加', style: AppTextStyles.sectionHeading),
          ),
          const Divider(height: 1, color: AppColors.ink06),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: _search,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                hintText: 'アプリ名で検索',
                hintStyle:
                    AppTextStyles.body.copyWith(color: AppColors.ink30),
                filled: true,
                fillColor: AppColors.bg,
                prefixIcon: const Icon(Icons.search,
                    size: 18, color: AppColors.ink30),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide:
                        const BorderSide(color: AppColors.orange, width: 1.5)),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.orange))
                : _results.isEmpty
                    ? Center(
                        child: Text(
                          _ctrl.text.isEmpty
                              ? 'アプリ名を入力してください'
                              : '該当するアプリが見つかりません',
                          style: AppTextStyles.bodySubtle,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: AppColors.ink06),
                        itemBuilder: (context, i) {
                          final app = _results[i];
                          final id = app.trackId.toString();
                          final added = widget.alreadyAdded.contains(id);
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 4),
                            leading: _AppIcon(
                                url: app.artworkUrl100,
                                size: 40,
                                color: AppColors.orange),
                            title: Text(app.trackName,
                                style: AppTextStyles.body.copyWith(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(app.developerName,
                                style: AppTextStyles.caption),
                            trailing: added
                                ? const Icon(Icons.check_circle_rounded,
                                    color: AppColors.orange, size: 20)
                                : Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      gradient: AppColors.primaryGradient,
                                      borderRadius:
                                          BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '追加',
                                      style: AppTextStyles.ctaButton
                                          .copyWith(fontSize: 12),
                                    ),
                                  ),
                            onTap: added
                                ? null
                                : () {
                                    widget.onAdd(id);
                                    Navigator.of(context).pop();
                                  },
                          );
                        },
                      ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}
