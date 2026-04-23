import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_genres.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/analytics_service.dart';
import '../../features/home/home_provider.dart';
import 'app_detail_provider.dart';
import 'tabs/ai_analysis_tab.dart';
import 'tabs/analysis_tab.dart';
import 'tabs/compare_tab.dart';
import 'tabs/reviews_tab.dart';

class AppDetailScreen extends ConsumerStatefulWidget {
  const AppDetailScreen({super.key, required this.trackId});
  final String trackId;

  @override
  ConsumerState<AppDetailScreen> createState() => _AppDetailScreenState();
}

class _AppDetailScreenState extends ConsumerState<AppDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = ['レビュー', '解析', '比較', 'AI分析'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);

    // 画面表示時にレビュー取得 & Analytics
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logAppViewed(widget.trackId);
      ref.read(recentlyViewedProvider.notifier).add(widget.trackId);
      // 取得完了後に reviewsProvider を自動 invalidate して画面を更新
      ref.read(fetchReviewsProvider.notifier).fetch(widget.trackId);
    });
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    ref
        .read(analyticsServiceProvider)
        .logTabChanged(widget.trackId, _tabs[_tabController.index]);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appAsync = ref.watch(appDetailProvider(widget.trackId));

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.ink),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share, size: 20, color: AppColors.ink),
            tooltip: 'シェアカードを作る',
            onPressed: () =>
                context.push('/app/${widget.trackId}/share'),
          ),
        ],
      ),
      body: appAsync.when(
        data: (app) => Column(
          children: [
            // 固定ヘッダー
            Container(
              color: AppColors.white,
              child: Column(
                children: [
                  _AppHeader(
                    artworkUrl: app?.artworkUrl100,
                    trackName: app?.trackName ?? '',
                    developerName: app?.developerName ?? '',
                    rating: app?.averageUserRating,
                    ratingCount: app?.userRatingCount ?? 0,
                    genre: genreJa(app?.primaryGenreName ?? ''),
                  ),
                  TabBar(
                    controller: _tabController,
                    tabs: _tabs.map((t) => Tab(text: t)).toList(),
                    labelStyle:
                        AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                    unselectedLabelStyle: AppTextStyles.bodySubtle,
                    labelColor: AppColors.orange,
                    unselectedLabelColor: AppColors.ink55,
                    indicatorColor: AppColors.orange,
                    indicatorWeight: 2,
                    dividerColor: AppColors.ink06,
                  ),
                ],
              ),
            ),
            // タブコンテンツ
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  ReviewsTab(trackId: widget.trackId),
                  AnalysisTab(trackId: widget.trackId),
                  CompareTab(trackId: widget.trackId),
                  AiAnalysisTab(trackId: widget.trackId),
                ],
              ),
            ),
          ],
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.orange),
        ),
        error: (e, _) => Center(
          child: Text('エラーが発生しました', style: AppTextStyles.bodySubtle),
        ),
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader({
    this.artworkUrl,
    required this.trackName,
    required this.developerName,
    this.rating,
    required this.ratingCount,
    required this.genre,
  });

  final String? artworkUrl;
  final String trackName;
  final String developerName;
  final double? rating;
  final int ratingCount;
  final String genre;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // アイコン
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: artworkUrl != null
                ? (kIsWeb
                    ? Image.network(
                        artworkUrl!,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 72,
                          height: 72,
                          color: AppColors.orangeBg,
                          child: const Icon(Icons.apps,
                              color: AppColors.orange, size: 36),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: artworkUrl!,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 72,
                          height: 72,
                          color: AppColors.orangeBg,
                          child: const Icon(Icons.apps,
                              color: AppColors.orange, size: 36),
                        ),
                      ))
                : Container(
                    width: 72,
                    height: 72,
                    color: AppColors.orangeBg,
                    child: const Icon(Icons.apps,
                        color: AppColors.orange, size: 36),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  trackName,
                  style: AppTextStyles.sectionHeading,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(developerName, style: AppTextStyles.bodySubtle),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (rating != null) ...[
                      const Icon(Icons.star_rounded,
                          size: 14, color: AppColors.orange),
                      const SizedBox(width: 3),
                      Text(
                        rating!.toStringAsFixed(1),
                        style: AppTextStyles.caption
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '($ratingCount件)',
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.orangeBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        genre,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.orange),
                      ),
                    ),
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
