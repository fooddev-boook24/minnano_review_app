import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_genres.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/rewarded_ad_service.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import '../../../shared/models/app_model.dart';
import '../../../shared/models/app_review.dart';
import '../app_detail_provider.dart';

/// 比較対象に追加されたアプリ一覧（trackId のリスト）
final compareAppsProvider = StateProvider<List<String>>((ref) => []);

class CompareTab extends ConsumerWidget {
  const CompareTab({super.key, required this.trackId});
  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compareApps = ref.watch(compareAppsProvider);
    final slotUnlocked = ref.watch(compareSlotUnlockedProvider);
    const maxApps = 4;
    const freeLimit = 2;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('競合と比較', style: AppTextStyles.sectionHeading),
        const SizedBox(height: 4),
        Text('最大4アプリと指標を並列比較できます', style: AppTextStyles.bodySubtle),
        const SizedBox(height: 20),
        ...compareApps.map((id) => _CompareAppCard(
              trackId: id,
              onRemove: () {
                final list = [...ref.read(compareAppsProvider)];
                list.remove(id);
                ref.read(compareAppsProvider.notifier).state = list;
              },
              onTap: () => context.push('/app/$id'),
            )),
        if (compareApps.length < freeLimit)
          _AddAppButton(onTap: () => _showAppSearch(context, ref, compareApps))
        else if (compareApps.length < maxApps)
          slotUnlocked
              ? _AddAppButton(onTap: () => _showAppSearch(context, ref, compareApps))
              : _AdUnlockBanner(
                  onTap: () => _unlockWithAd(context, ref),
                ),
        if (compareApps.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('比較結果', style: AppTextStyles.sectionHeading),
          const SizedBox(height: 12),
          _ComparisonView(baseTrackId: trackId, compareIds: compareApps),
        ],
      ],
    );
  }

  Future<void> _unlockWithAd(BuildContext context, WidgetRef ref) async {
    final rewarded = await ref.read(rewardedAdServiceProvider).show();
    if (rewarded) {
      ref.read(compareSlotUnlockedProvider.notifier).state = true;
    } else if (context.mounted) {
      showAppSnackBar(context, '広告の視聴が完了しませんでした');
    }
  }

  void _showAppSearch(
      BuildContext context, WidgetRef ref, List<String> current) {
    final service = ref.read(firestoreServiceProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AppSearchSheet(
        service: service,
        alreadyAdded: [trackId, ...current],
        onAdd: (id) {
          final list = [...ref.read(compareAppsProvider), id];
          ref.read(compareAppsProvider.notifier).state = list;
        },
      ),
    );
  }
}

// ─── Compare App Card ──────────────────────────────────

class _CompareAppCard extends ConsumerWidget {
  const _CompareAppCard(
      {required this.trackId, required this.onRemove, required this.onTap});
  final String trackId;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appAsync = ref.watch(appDetailProvider(trackId));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0D16121D), blurRadius: 18, offset: Offset(0, 4)),
          ],
        ),
        child: appAsync.when(
          data: (app) => app == null
              ? Text('アプリが見つかりません', style: AppTextStyles.bodySubtle)
              : Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(app.trackName, style: AppTextStyles.cardDeveloper),
                        Text(app.developerName, style: AppTextStyles.caption),
                        if (app.averageUserRating != null) ...[
                          const SizedBox(height: 2),
                          Row(children: [
                            const Icon(Icons.star_rounded,
                                size: 13, color: AppColors.orange),
                            const SizedBox(width: 2),
                            Text(app.averageUserRating!.toStringAsFixed(1),
                                style: AppTextStyles.caption),
                          ]),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: AppColors.ink30, size: 18),
                    onPressed: onRemove,
                  ),
                ]),
          loading: () => const SizedBox(
              height: 40,
              child:
                  Center(child: CircularProgressIndicator(color: AppColors.orange))),
          error: (_, __) =>
              Text('読み込みエラー', style: AppTextStyles.bodySubtle),
        ),
      ),
    );
  }
}

// ─── Add Button ────────────────────────────────────────

class _AddAppButton extends StatelessWidget {
  const _AddAppButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.ink12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: AppColors.orange, size: 20),
            const SizedBox(width: 8),
            Text('比較するアプリを追加',
                style: AppTextStyles.body.copyWith(color: AppColors.orange)),
          ],
        ),
      ),
    );
  }
}

// ─── Ad Unlock Banner ──────────────────────────────────

class _AdUnlockBanner extends StatelessWidget {
  const _AdUnlockBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
                color: Color(0x5CFF9500), blurRadius: 22, offset: Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.play_circle_outline, color: AppColors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('広告を見て3・4枠目を解放',
                      style: AppTextStyles.body.copyWith(
                          color: AppColors.white, fontWeight: FontWeight.w700)),
                  Text('今のセッション中は広告なしで追加できます',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.white.withValues(alpha: 0.8))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Comparison View ───────────────────────────────────

class _ComparisonView extends ConsumerWidget {
  const _ComparisonView(
      {required this.baseTrackId, required this.compareIds});
  final String baseTrackId;
  final List<String> compareIds;

  static const _topics = [
    (label: 'バグ・クラッシュ', color: Color(0xFFF43F5E), keywords: ['バグ', 'クラッシュ', '落ちる', '不具合', 'エラー', '壊れ']),
    (label: 'UI / UX',        color: Color(0xFFFF9500), keywords: ['使いにくい', 'デザイン', '操作', 'UI', '画面']),
    (label: '機能要望',        color: Color(0xFF3B82F6), keywords: ['欲しい', '追加して', '機能', 'できない', '対応して']),
    (label: 'ポジティブ',      color: Color(0xFF22C55E), keywords: ['最高', '良い', 'おすすめ', '便利', 'シンプル', '使いやすい']),
  ];

  double _topicPct(List<AppReview> reviews, List<String> keywords) {
    if (reviews.isEmpty) return 0;
    final count = reviews.where((r) {
      final text = '${r.title} ${r.body}';
      return keywords.any((kw) => text.contains(kw));
    }).length;
    return count / reviews.length * 100;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allIds = [baseTrackId, ...compareIds];
    final appAsyncs = allIds.map((id) => ref.watch(appDetailProvider(id))).toList();
    final reviewAsyncs = allIds
        .map((id) => ref.watch(reviewsProvider(ReviewQuery(trackId: id))))
        .toList();

    final isLoading = appAsyncs.any((a) => a.isLoading) ||
        reviewAsyncs.any((r) => r.isLoading);
    if (isLoading) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(color: AppColors.orange),
      ));
    }

    final apps = appAsyncs.map((a) => a.valueOrNull).toList();
    final reviewLists =
        reviewAsyncs.map((r) => r.valueOrNull ?? <AppReview>[]).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x0D16121D), blurRadius: 18, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: app names
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: AppColors.ink06, width: 1)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 88),
                ...apps.asMap().entries.map((e) {
                  final app = e.value;
                  final isBase = e.key == 0;
                  return Expanded(
                    child: Column(
                      children: [
                        Text(
                          app?.trackName ?? '—',
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isBase ? AppColors.orange : AppColors.ink,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isBase) ...[
                          const SizedBox(height: 2),
                          Text('（このアプリ）',
                              style: AppTextStyles.caption.copyWith(
                                  fontSize: 9, color: AppColors.orange)),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          // Rating row
          _MetricRow(
            label: '★ 評価',
            values: apps.map((app) {
              final r = app?.averageUserRating;
              return r != null ? r.toStringAsFixed(1) : '—';
            }).toList(),
            higherIsBetter: true,
            rawValues: apps
                .map((app) => app?.averageUserRating ?? 0.0)
                .toList(),
          ),
          // Review count row
          _MetricRow(
            label: 'レビュー数',
            values: apps.map((app) {
              final c = app?.userRatingCount ?? 0;
              return c >= 1000 ? '${(c / 1000).toStringAsFixed(1)}K' : '$c';
            }).toList(),
            higherIsBetter: true,
            rawValues: apps
                .map((app) => (app?.userRatingCount ?? 0).toDouble())
                .toList(),
          ),
          // Topic rows
          ..._topics.map((t) => _MetricRow(
                label: t.label,
                color: t.color,
                values: reviewLists.map((reviews) {
                  final pct = _topicPct(reviews, t.keywords);
                  return '${pct.round()}%';
                }).toList(),
                higherIsBetter: t.label == 'ポジティブ',
                rawValues: reviewLists
                    .map((r) => _topicPct(r, t.keywords))
                    .toList(),
              )),
          // High/low rating rates
          _MetricRow(
            label: '高評価率',
            color: const Color(0xFF22C55E),
            values: reviewLists.map((reviews) {
              if (reviews.isEmpty) return '—';
              final pct = reviews.where((r) => r.rating >= 4).length /
                  reviews.length *
                  100;
              return '${pct.round()}%';
            }).toList(),
            higherIsBetter: true,
            rawValues: reviewLists.map((reviews) {
              if (reviews.isEmpty) return 0.0;
              return reviews.where((r) => r.rating >= 4).length /
                  reviews.length *
                  100;
            }).toList(),
          ),
          _MetricRow(
            label: '低評価率',
            color: const Color(0xFFF43F5E),
            values: reviewLists.map((reviews) {
              if (reviews.isEmpty) return '—';
              final pct = reviews.where((r) => r.rating <= 2).length /
                  reviews.length *
                  100;
              return '${pct.round()}%';
            }).toList(),
            higherIsBetter: false,
            rawValues: reviewLists.map((reviews) {
              if (reviews.isEmpty) return 0.0;
              return reviews.where((r) => r.rating <= 2).length /
                  reviews.length *
                  100;
            }).toList(),
          ),
          // Price row
          _StringMetricRow(
            label: '価格',
            values: apps
                .map((app) => app?.formattedPrice ?? '—')
                .toList(),
          ),
          // Category row
          _StringMetricRow(
            label: 'カテゴリ',
            values: apps
                .map((app) => genreJa(app?.primaryGenreName ?? '—'))
                .toList(),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.values,
    required this.higherIsBetter,
    required this.rawValues,
    this.color,
  });
  final String label;
  final List<String> values;
  final bool higherIsBetter;
  final List<double> rawValues;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final best = higherIsBetter
        ? rawValues.reduce((a, b) => a > b ? a : b)
        : rawValues.reduce((a, b) => a < b ? a : b);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.ink06, width: 1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Row(
              children: [
                if (color != null) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.ink55, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          ...values.asMap().entries.map((e) {
            final isBest = rawValues[e.key] == best && best > 0;
            return Expanded(
              child: Text(
                e.value,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: isBest ? FontWeight.w700 : FontWeight.w500,
                  color: isBest
                      ? (color ?? AppColors.orange)
                      : AppColors.ink55,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StringMetricRow extends StatelessWidget {
  const _StringMetricRow({required this.label, required this.values});
  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border:
            Border(bottom: BorderSide(color: AppColors.ink06, width: 1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.ink55, fontSize: 11),
            ),
          ),
          ...values.map((v) => Expanded(
                child: Text(
                  v,
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.ink55, fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )),
        ],
      ),
    );
  }
}

// ─── App Search Bottom Sheet ───────────────────────────

class _AppSearchSheet extends StatefulWidget {
  const _AppSearchSheet(
      {required this.service, required this.alreadyAdded, required this.onAdd});
  final FirestoreService service;
  final List<String> alreadyAdded;
  final void Function(String trackId) onAdd;

  @override
  State<_AppSearchSheet> createState() => _AppSearchSheetState();
}

class _AppSearchSheetState extends State<_AppSearchSheet> {
  final _controller = TextEditingController();
  List<AppModel> _results = [];
  bool _loading = false;
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() {
        _results = [];
        _query = '';
      });
      return;
    }
    setState(() {
      _loading = true;
      _query = q.trim();
    });
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
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      margin: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text('アプリを追加', style: AppTextStyles.sectionHeading),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppColors.ink30, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      onChanged: _search,
                      style: AppTextStyles.body,
                      decoration: InputDecoration(
                        hintText: 'アプリ名・開発者名で検索',
                        hintStyle: AppTextStyles.body
                            .copyWith(color: AppColors.ink30),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
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
                          _query.isEmpty ? 'アプリ名を入力してください' : '検索結果がありません',
                          style: AppTextStyles.bodySubtle,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(
                            height: 1, color: AppColors.ink06),
                        itemBuilder: (context, i) {
                          final app = _results[i];
                          final id = app.trackId.toString();
                          final added = widget.alreadyAdded.contains(id);
                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 8),
                            title: Text(app.trackName,
                                style: AppTextStyles.cardDeveloper),
                            subtitle: Text(app.developerName,
                                style: AppTextStyles.caption),
                            trailing: added
                                ? const Icon(Icons.check,
                                    color: AppColors.orange, size: 20)
                                : GestureDetector(
                                    onTap: () {
                                      widget.onAdd(id);
                                      Navigator.of(context).pop();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.orange,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text('追加',
                                          style: AppTextStyles.caption.copyWith(
                                              color: AppColors.white,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
