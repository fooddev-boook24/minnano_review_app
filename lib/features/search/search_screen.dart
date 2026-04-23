import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_genres.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/analytics_service.dart';
import '../../features/explore/explore_provider.dart';
import '../../shared/models/app_model.dart';
import 'search_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(searchPageProvider.notifier).loadMore();
    }
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(searchQueryProvider.notifier).state = query.trim();
    });
  }

  void _onSubmit(String query) {
    _debounce?.cancel();
    final q = query.trim();
    if (q.isEmpty) return;
    ref.read(searchQueryProvider.notifier).state = q;
    ref.read(analyticsServiceProvider).logSearchExecuted(q);
  }

  @override
  Widget build(BuildContext context) {
    final pageAsync = ref.watch(searchPageProvider);
    final query = ref.watch(searchQueryProvider);
    final selectedCategory = ref.watch(searchCategoryProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Column(
      children: [
        // ヘッダー
        Container(
          color: AppColors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                child: Text('検索', style: AppTextStyles.screenTitle),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                child: _SearchBar(
                  controller: _controller,
                  onChanged: _onChanged,
                  onSubmit: _onSubmit,
                  onClear: () {
                    _debounce?.cancel();
                    _controller.clear();
                    ref.read(searchQueryProvider.notifier).state = '';
                  },
                ),
              ),
              // カテゴリフィルタチップ
              categoriesAsync.maybeWhen(
                data: (categories) => categories.isEmpty
                    ? const SizedBox.shrink()
                    : _CategoryChips(
                        categories: categories,
                        selected: selectedCategory,
                        onSelect: (cat) {
                          ref.read(searchCategoryProvider.notifier).state =
                              cat == selectedCategory ? null : cat;
                        },
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: AppColors.ink06),
            ],
          ),
        ),

        // ボディ
        Expanded(
          child: pageAsync.when(
            data: (state) {
              final apps = state.apps;

              if (query.isEmpty && selectedCategory == null && apps.isEmpty) {
                return const _EmptyPrompt();
              }

              if (apps.isEmpty && query.isNotEmpty) {
                return _NoResults(query: query);
              }

              // Section header label
              String? sectionLabel;
              if (query.isEmpty && selectedCategory == null) {
                sectionLabel = '注目のアプリ';
              } else if (query.isEmpty && selectedCategory != null) {
                sectionLabel = genreJa(selectedCategory);
              }

              return ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(24),
                itemCount: apps.length + (state.isLoadingMore ? 1 : 0) +
                    (sectionLabel != null ? 1 : 0),
                separatorBuilder: (_, i) {
                  if (sectionLabel != null && i == 0) {
                    return const SizedBox.shrink();
                  }
                  return const SizedBox(height: 12);
                },
                itemBuilder: (context, i) {
                  // Section heading
                  if (sectionLabel != null && i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(sectionLabel,
                          style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                    );
                  }

                  final appIdx =
                      sectionLabel != null ? i - 1 : i;

                  // Loading indicator at bottom
                  if (appIdx >= apps.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.orange),
                        ),
                      ),
                    );
                  }

                  return _SearchAppCard(
                    app: apps[appIdx],
                    onTap: () =>
                        context.push('/app/${apps[appIdx].trackId}'),
                  );
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.orange),
            ),
            error: (e, _) => Center(
              child: Text('エラーが発生しました', style: AppTextStyles.bodySubtle),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Category chips ───────────────────────────────────

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<String> categories;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = categories[i];
          final active = selected == cat;
          return GestureDetector(
            onTap: () => onSelect(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active ? AppColors.orange : AppColors.bg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                genreJa(cat),
                style: AppTextStyles.caption.copyWith(
                  color: active ? AppColors.white : AppColors.ink55,
                  fontWeight:
                      active ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Search bar ───────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onSubmit,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmit,
      textInputAction: TextInputAction.search,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        hintText: 'アプリ名・開発者名で検索',
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.ink30),
        filled: true,
        fillColor: AppColors.bg,
        prefixIcon:
            const Icon(Icons.search, color: AppColors.ink30, size: 20),
        suffixIcon: IconButton(
          icon: const Icon(Icons.close, color: AppColors.ink30, size: 18),
          onPressed: onClear,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
        ),
      ),
    );
  }
}

class _EmptyPrompt extends StatelessWidget {
  const _EmptyPrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.orangeBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search, size: 30, color: AppColors.orange),
          ),
          const SizedBox(height: 14),
          Text('アプリ名や開発者名を入力',
              style:
                  AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('してください', style: AppTextStyles.bodySubtle),
        ],
      ),
    );
  }
}

// ─── Search app card ──────────────────────────────────

class _SearchAppCard extends StatelessWidget {
  const _SearchAppCard({required this.app, required this.onTap});

  final AppModel app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rating = app.averageUserRating;
    final ratingCount = app.userRatingCount;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D16121D),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon + name + developer
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _AppIcon(url: app.artworkUrl100, size: 64),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.trackName,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          app.developerName,
                          style: AppTextStyles.bodySubtle.copyWith(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: AppColors.ink30),
                ],
              ),

              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.ink06),
              const SizedBox(height: 14),

              // Review stats row
              Row(
                children: [
                  // Average rating
                  Expanded(
                    child: _StatCell(
                      label: '平均評価',
                      value: rating != null ? rating.toStringAsFixed(1) : '—',
                      sub: rating != null
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(5, (i) {
                                final filled = i < rating.floor();
                                final half = !filled && (rating - i) >= 0.5;
                                return Icon(
                                  filled
                                      ? Icons.star
                                      : half
                                          ? Icons.star_half
                                          : Icons.star_border,
                                  size: 11,
                                  color: AppColors.orange,
                                );
                              }),
                            )
                          : null,
                      valueColor: rating != null ? AppColors.orange : AppColors.ink30,
                    ),
                  ),
                  _StatDivider(),
                  // Review count
                  Expanded(
                    child: _StatCell(
                      label: 'レビュー数',
                      value: ratingCount > 0 ? _formatCount(ratingCount) : '—',
                      valueColor: AppColors.ink,
                    ),
                  ),
                  _StatDivider(),
                  // Monthly review velocity
                  Expanded(
                    child: _StatCell(
                      label: '月間獲得ペース',
                      value: _monthlyPace(),
                      valueColor: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}万';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  /// リリースからの月数でレビュー総数を割った月間獲得ペース推定
  String _monthlyPace() {
    final rd = app.releaseDate;
    final count = app.userRatingCount;
    if (rd == null || count == 0) return '—';
    final released = DateTime.tryParse(rd);
    if (released == null) return '—';
    final months =
        (DateTime.now().difference(released).inDays / 30).clamp(1, double.infinity);
    final pace = count / months;
    if (pace >= 10000) return '${(pace / 10000).toStringAsFixed(1)}万/月';
    if (pace >= 1000) return '${(pace / 1000).toStringAsFixed(1)}k/月';
    return '${pace.round()}/月';
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    this.sub,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Widget? sub;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: AppTextStyles.caption.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 3),
        if (sub != null) ...[sub!, const SizedBox(height: 2)],
        Text(
          label,
          style: AppTextStyles.bodySubtle.copyWith(fontSize: 10),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: AppColors.ink06,
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.url, this.size = 56});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: url != null && url!.isNotEmpty
          ? (kIsWeb
              ? Image.network(url!,
                  width: size, height: size, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder(size))
              : CachedNetworkImage(
                  imageUrl: url!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _placeholder(size),
                ))
          : _placeholder(size),
    );
  }

  Widget _placeholder(double size) => Container(
        width: size,
        height: size,
        color: AppColors.bg,
        child: Icon(Icons.apps, size: size * 0.4, color: AppColors.ink30),
      );
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.ink06,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off,
                size: 30, color: AppColors.ink30),
          ),
          const SizedBox(height: 14),
          Text(
            query.isEmpty
                ? 'アプリが見つかりませんでした'
                : '「$query」の検索結果がありません',
            style: AppTextStyles.bodySubtle,
          ),
        ],
      ),
    );
  }
}
