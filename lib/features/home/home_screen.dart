import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../shared/widgets/app_background.dart';
import '../../core/services/firestore_service.dart';
import '../../features/app_detail/app_detail_provider.dart';
import '../../shared/models/app_model.dart';
import '../../shared/models/app_review.dart';
import '../../shared/widgets/app_card.dart';
import 'home_provider.dart';

// ウォッチリストのアプリカラー
const _kWatchColors = [
  Color(0xFFFF9500),
  Color(0xFF22C55E),
  Color(0xFF3B82F6),
  Color(0xFF8B5CF6),
  Color(0xFFF43F5E),
  Color(0xFF06B6D4),
];

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchlist = ref.watch(watchlistProvider);
    final recentAsync = ref.watch(recentlyViewedAppsProvider);

    return AppBackground(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      children: [
        // ─── KV ヘッダー ───
        _buildKV(),

        // ─── ウォッチリスト ───
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('ウォッチリスト',
                style: AppTextStyles.body
                    .copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
            const Spacer(),
            if (watchlist.isNotEmpty)
              GestureDetector(
                onTap: () => _showAddSheet(context, ref, watchlist),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('+ 追加',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.white, fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (watchlist.isEmpty)
          _WatchlistEmpty(onTap: () => _showAddSheet(context, ref, watchlist))
        else
          ...watchlist.asMap().entries.map((e) {
            final idx = e.key;
            final trackId = e.value;
            final color = _kWatchColors[idx % _kWatchColors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _WatchlistCard(
                trackId: trackId,
                color: color,
                onTap: () => context.push('/app/$trackId'),
                onRemove: () =>
                    ref.read(watchlistProvider.notifier).remove(trackId),
              ),
            );
          }),

        const SizedBox(height: 32),

        // ─── 最近閲覧 ───
        Text('最近見たアプリ',
            style: AppTextStyles.body
                .copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 12),
        recentAsync.when(
          data: (apps) => apps.isEmpty
              ? _EmptyCard(message: 'アプリ詳細を開くと履歴が表示されます')
              : Column(
                  children: apps
                      .map((app) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AppCard(
                              app: app,
                              onTap: () =>
                                  context.push('/app/${app.trackId}'),
                            ),
                          ))
                      .toList(),
                ),
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AppColors.orange),
            ),
          ),
          error: (_, __) =>
              _EmptyCard(message: 'インターネット接続を確認してください'),
        ),

        const SizedBox(height: 32),

        // ─── Explore 誘導 ───
        _ExploreCard(onTap: () => context.go('/explore')),
      ],
      ),
    );
  }

  Widget _buildKV() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 56, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // サブラベル
          Text(
            'APP DEVELOPER REVIEW',
            style: AppTextStyles.sectionLabel.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.ink30,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 10),
          // H1: テキスト左 + アイコン右
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // "みんなの"は黒、"レビュー"はグラデーション
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'みんなの\n',
                      style: AppTextStyles.screenTitle.copyWith(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                        height: 1.15,
                      ),
                    ),
                    WidgetSpan(
                      child: ShaderMask(
                        shaderCallback: (bounds) =>
                            AppColors.primaryGradient.createShader(bounds),
                        blendMode: BlendMode.srcIn,
                        child: Text(
                          'レビュー',
                          style: AppTextStyles.screenTitle.copyWith(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // アイコン画像
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Image.asset(
                  'asstes/favicon_review.png',
                  width: 120,
                  height: 120,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddSheet(
      BuildContext context, WidgetRef ref, List<String> current) {
    final service = ref.read(firestoreServiceProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddWatchSheet(
        service: service,
        alreadyAdded: current,
        onAdd: (trackId) =>
            ref.read(watchlistProvider.notifier).add(trackId),
      ),
    );
  }
}

// ─── Watchlist Card ────────────────────────────────────

class _WatchlistCard extends ConsumerWidget {
  const _WatchlistCard({
    required this.trackId,
    required this.color,
    required this.onTap,
    required this.onRemove,
  });

  final String trackId;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appAsync = ref.watch(appDetailProvider(trackId));
    final reviewsAsync =
        ref.watch(reviewsProvider(ReviewQuery(trackId: trackId)));

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            // カラーアクセントバー
            Container(
              width: 4,
              height: 80,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(18)),
              ),
            ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: appAsync.when(
                  data: (app) => app == null
                      ? Text('不明なアプリ', style: AppTextStyles.bodySubtle)
                      : _WatchlistCardContent(
                          app: app,
                          reviewsAsync: reviewsAsync,
                          color: color,
                        ),
                  loading: () => const SizedBox(
                    height: 56,
                    child: Center(
                        child: LinearProgressIndicator(
                            color: AppColors.orange,
                            backgroundColor: AppColors.orangeBg)),
                  ),
                  error: (_, __) =>
                      Text('読み込みエラー', style: AppTextStyles.bodySubtle),
                ),
              ),
            ),
            // 削除ボタン
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.close, size: 16, color: AppColors.ink30),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WatchlistCardContent extends StatelessWidget {
  const _WatchlistCardContent({
    required this.app,
    required this.reviewsAsync,
    required this.color,
  });

  final AppModel app;
  final AsyncValue<List<AppReview>> reviewsAsync;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // アプリ情報
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                app.trackName,
                style: AppTextStyles.body
                    .copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(app.developerName,
                  style:
                      AppTextStyles.caption.copyWith(color: AppColors.ink30),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              // バッジ行
              reviewsAsync.when(
                data: (reviews) => _ReviewBadges(reviews: reviews),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // 評価
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (app.averageUserRating != null) ...[
              Row(
                children: [
                  Icon(Icons.star_rounded, size: 14, color: color),
                  const SizedBox(width: 3),
                  Text(
                    app.averageUserRating!.toStringAsFixed(1),
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
              Text(
                '${_formatCount(app.userRatingCount)}件',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.ink30, fontSize: 10),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}万';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '$count';
  }
}

class _ReviewBadges extends StatelessWidget {
  const _ReviewBadges({required this.reviews});
  final List<AppReview> reviews;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final since7 = now.subtract(const Duration(days: 7));
    final recent = reviews.where((r) => r.reviewDate.isAfter(since7)).toList();
    final newCount = recent.length;
    final lowCount = recent.where((r) => r.rating <= 2).length;

    if (newCount == 0 && reviews.isNotEmpty) {
      return Text('直近7日 新着なし',
          style: AppTextStyles.caption.copyWith(color: AppColors.ink30, fontSize: 10));
    }
    if (reviews.isEmpty) {
      return Text('レビューを取得していません',
          style: AppTextStyles.caption.copyWith(color: AppColors.ink30, fontSize: 10));
    }

    return Wrap(
      spacing: 6,
      children: [
        if (newCount > 0)
          _Badge(
            label: '新着 $newCount件',
            bg: const Color(0xFFEBF5FF),
            fg: const Color(0xFF3B82F6),
          ),
        if (lowCount > 0)
          _Badge(
            label: '要確認 $lowCount件',
            bg: const Color(0xFFFFF0F0),
            fg: const Color(0xFFF43F5E),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: AppTextStyles.caption.copyWith(
              color: fg, fontWeight: FontWeight.w700, fontSize: 10)),
    );
  }
}

// ─── Watchlist Empty ───────────────────────────────────

class _WatchlistEmpty extends StatelessWidget {
  const _WatchlistEmpty({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.ink12),
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.orangeBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: AppColors.orange, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('アプリを監視する',
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('評価変動・新着レビューを一目で確認',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.ink30)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.ink30, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Add Watch Sheet ───────────────────────────────────

class _AddWatchSheet extends StatefulWidget {
  const _AddWatchSheet({
    required this.service,
    required this.alreadyAdded,
    required this.onAdd,
  });
  final FirestoreService service;
  final List<String> alreadyAdded;
  final void Function(String trackId) onAdd;

  @override
  State<_AddWatchSheet> createState() => _AddWatchSheetState();
}

class _AddWatchSheetState extends State<_AddWatchSheet> {
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
      setState(() { _results = []; _query = ''; });
      return;
    }
    setState(() { _loading = true; _query = q.trim(); });
    final results = await widget.service.searchApps(q.trim());
    if (mounted) {
      setState(() { _results = results; _loading = false; });
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Expanded(
                    child: Text('ウォッチリストに追加',
                        style: AppTextStyles.sectionHeading)),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
                          _query.isEmpty
                              ? 'アプリ名を入力してください'
                              : '検索結果がありません',
                          style: AppTextStyles.bodySubtle,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: AppColors.ink06),
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
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.orangeBg,
                                      borderRadius:
                                          BorderRadius.circular(999),
                                    ),
                                    child: Text('追加済み',
                                        style: AppTextStyles.caption.copyWith(
                                            color: AppColors.orange,
                                            fontWeight: FontWeight.w600)),
                                  )
                                : GestureDetector(
                                    onTap: () {
                                      widget.onAdd(id);
                                      Navigator.of(context).pop();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        gradient: AppColors.primaryGradient,
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

// ─── Shared Widgets ────────────────────────────────────


class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Center(
        child: Text(message, style: AppTextStyles.bodySubtle),
      ),
    );
  }
}

class _ExploreCard extends StatelessWidget {
  const _ExploreCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
                color: Color(0x5CFF9500),
                blurRadius: 22,
                offset: Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('カテゴリを探索する',
                      style: AppTextStyles.body.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('カテゴリ横断でトレンドを発見',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.white)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.white, size: 24),
          ],
        ),
      ),
    );
  }
}
