import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/models/app_review.dart';
import '../app_detail_provider.dart';

class ReviewsTab extends ConsumerStatefulWidget {
  const ReviewsTab({super.key, required this.trackId});
  final String trackId;

  @override
  ConsumerState<ReviewsTab> createState() => _ReviewsTabState();
}

class _ReviewsTabState extends ConsumerState<ReviewsTab> {
  final _controller = TextEditingController();
  String _search = '';
  String _filter = 'all'; // all / positive / negative

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<AppReview> _applyFilters(List<AppReview> all) {
    return all.where((r) {
      if (_filter == 'positive' && r.rating < 4) return false;
      if (_filter == 'negative' && r.rating > 2) return false;
      if (_search.isNotEmpty &&
          !r.title.contains(_search) &&
          !r.body.contains(_search)) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final results =
        ref.watch(reviewsProvider(ReviewQuery(trackId: widget.trackId)));
    final fetchState = ref.watch(fetchReviewsProvider);

    return Column(
      children: [
        // 取得中バナー
        if (fetchState.isLoading)
          Container(
            width: double.infinity,
            color: AppColors.orangeBg,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.orange),
                ),
                const SizedBox(width: 8),
                Text('App Store からレビューを取得中...',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.orange)),
              ],
            ),
          ),

        // Search + Filter bar
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
          child: Column(
            children: [
              // Search bar
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: AppColors.ink30, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onChanged: (v) => setState(() => _search = v),
                        style: AppTextStyles.body.copyWith(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'キーワードで検索...',
                          hintStyle: AppTextStyles.body
                              .copyWith(fontSize: 13, color: AppColors.ink30),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (_search.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _controller.clear();
                          setState(() => _search = '');
                        },
                        child: const Icon(Icons.close,
                            color: AppColors.ink30, size: 16),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Filter chips
              Row(
                children: [
                  _FilterChip(
                    label: 'すべて',
                    active: _filter == 'all',
                    onTap: () => setState(() => _filter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: '高評価',
                    active: _filter == 'positive',
                    onTap: () => setState(() => _filter = 'positive'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: '低評価',
                    active: _filter == 'negative',
                    onTap: () => setState(() => _filter = 'negative'),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Review list
        Expanded(
          child: results.when(
            data: (all) {
              final reviews = _applyFilters(all);
              if (reviews.isEmpty) {
                return Center(
                  child: Text(
                    all.isEmpty ? 'まだレビューがありません' : '該当するレビューがありません',
                    style: AppTextStyles.bodySubtle,
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                itemCount: reviews.length,
                itemBuilder: (context, i) => _ReviewCard(review: reviews[i]),
              );
            },
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.orange)),
            error: (_, __) => Center(
                child: Text('エラーが発生しました', style: AppTextStyles.bodySubtle)),
          ),
        ),
      ],
    );
  }
}

// ─── Filter Chip ───────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          gradient: active ? AppColors.primaryGradient : null,
          color: active ? null : AppColors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: AppColors.orange.withValues(alpha: 0.36),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ]
              : [
                  const BoxShadow(
                      color: Color(0x0D16121D),
                      blurRadius: 6,
                      offset: Offset(0, 2))
                ],
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: active ? AppColors.white : AppColors.ink55,
          ),
        ),
      ),
    );
  }
}

// ─── Review Card ───────────────────────────────────────

class _ReviewCard extends StatefulWidget {
  const _ReviewCard({required this.review});
  final AppReview review;

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool _expanded = false;

  String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return '今日';
    if (diff.inDays == 1) return '1日前';
    if (diff.inDays < 7) return '${diff.inDays}日前';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}週間前';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}ヶ月前';
    return '${(diff.inDays / 365).floor()}年前';
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0D16121D),
                  blurRadius: 18,
                  offset: Offset(0, 4))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Row(
                    children: List.generate(5, (i) => Icon(
                      i < review.rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 13,
                      color: AppColors.orange,
                    )),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      review.title,
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _relativeDate(review.reviewDate),
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.ink30),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              AnimatedCrossFade(
                firstChild: Text(
                  review.body,
                  style: AppTextStyles.bodySubtle,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                secondChild: Text(
                  review.body,
                  style: AppTextStyles.bodySubtle,
                ),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    review.authorName,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.ink30),
                  ),
                  if (review.body.length > 80)
                    Text(
                      _expanded ? '閉じる' : '続きを読む',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.orange,
                          fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
