import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/firestore_service.dart';
import '../../core/services/functions_service.dart';
import '../../shared/models/app_model.dart';
import '../../shared/models/app_review.dart';
import '../../shared/models/app_review_summary.dart';

// trackId（String）を引数として渡す family provider
final appDetailProvider =
    FutureProvider.family<AppModel?, String>((ref, trackId) async {
  final service = ref.read(firestoreServiceProvider);
  return service.getAppByTrackId(int.parse(trackId));
});

final reviewsProvider =
    FutureProvider.family<List<AppReview>, _ReviewQuery>((ref, query) async {
  final service = ref.read(firestoreServiceProvider);
  return service.getReviews(
    trackId: query.trackId,
    ratingFilter: query.ratingFilter,
  );
});

final reviewSummaryProvider =
    FutureProvider.family<AppReviewSummary?, String>((ref, trackId) async {
  final service = ref.read(firestoreServiceProvider);
  return service.getReviewSummary(trackId);
});

// レビューフィルター状態（null = 全件）
final reviewRatingFilterProvider =
    StateProvider.family<int?, String>((ref, trackId) => null);

// AI分析生成中フラグ
final summaryGeneratingProvider =
    StateProvider.family<bool, String>((ref, trackId) => false);

class _ReviewQuery {
  const _ReviewQuery({required this.trackId, this.ratingFilter});
  final String trackId;
  final int? ratingFilter;

  @override
  bool operator ==(Object other) =>
      other is _ReviewQuery &&
      other.trackId == trackId &&
      other.ratingFilter == ratingFilter;

  @override
  int get hashCode => Object.hash(trackId, ratingFilter);
}

// レビュー取得を簡単に呼び出す用
ReviewQuery reviewQuery(String trackId, int? ratingFilter) =>
    ReviewQuery(trackId: trackId, ratingFilter: ratingFilter);

class ReviewQuery extends _ReviewQuery {
  ReviewQuery({required super.trackId, super.ratingFilter});
}

// fetchAppReviews を叩く非同期 Notifier
class FetchReviewsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> fetch(String trackId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(functionsServiceProvider)
          .fetchAppReviews(int.parse(trackId));
    });
    // 成功・スキップ問わず再描画（エラー時はスキップ）
    if (!state.hasError) {
      ref.invalidate(reviewsProvider);
    }
  }
}

final fetchReviewsProvider =
    AsyncNotifierProvider<FetchReviewsNotifier, void>(FetchReviewsNotifier.new);
