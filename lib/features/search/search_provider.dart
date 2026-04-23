import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/firestore_service.dart';
import '../../shared/models/app_model.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');
final searchCategoryProvider = StateProvider<String?>((ref) => null);

// ─── Paginated search state ───────────────────────────

class SearchPageState {
  const SearchPageState({
    this.apps = const [],
    this.cursor,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  final List<AppModel> apps;
  final DocumentSnapshot? cursor;
  final bool hasMore;
  final bool isLoadingMore;

  SearchPageState copyWith({
    List<AppModel>? apps,
    DocumentSnapshot? cursor,
    bool? hasMore,
    bool? isLoadingMore,
    bool clearCursor = false,
  }) {
    return SearchPageState(
      apps: apps ?? this.apps,
      cursor: clearCursor ? null : cursor ?? this.cursor,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class SearchNotifier extends AutoDisposeAsyncNotifier<SearchPageState> {
  static const _pageSize = 20;

  @override
  Future<SearchPageState> build() async {
    final query = ref.watch(searchQueryProvider);
    final category = ref.watch(searchCategoryProvider);
    return _fetchFirst(query, category);
  }

  Future<SearchPageState> _fetchFirst(String query, String? category) async {
    final service = ref.read(firestoreServiceProvider);

    if (query.trim().isEmpty && category == null) {
      // Top apps view
      final result = await service.getTopAppsPaged(limit: _pageSize);
      return SearchPageState(
        apps: result.apps,
        cursor: result.cursor,
        hasMore: result.apps.length >= _pageSize,
      );
    }

    if (query.trim().isEmpty && category != null) {
      // Category filter only
      final result = await service.getAppsByCategoryPaged(category,
          limit: _pageSize);
      return SearchPageState(
        apps: result.apps,
        cursor: result.cursor,
        hasMore: result.apps.length >= _pageSize,
      );
    }

    // Text search (not paginated — merges two queries)
    final results = await service.searchApps(query.trim());
    final filtered = category != null
        ? results.where((a) => a.primaryGenreName == category).toList()
        : results;
    return SearchPageState(apps: filtered, hasMore: false);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    final query = ref.read(searchQueryProvider);
    final category = ref.read(searchCategoryProvider);
    if (query.trim().isNotEmpty) return; // text search: no pagination

    state = AsyncData(current.copyWith(isLoadingMore: true));

    final service = ref.read(firestoreServiceProvider);
    try {
      if (category != null) {
        final result = await service.getAppsByCategoryPaged(category,
            limit: _pageSize, startAfter: current.cursor);
        state = AsyncData(current.copyWith(
          apps: [...current.apps, ...result.apps],
          cursor: result.cursor,
          hasMore: result.apps.length >= _pageSize,
          isLoadingMore: false,
        ));
      } else {
        final result = await service.getTopAppsPaged(
            limit: _pageSize, startAfter: current.cursor);
        state = AsyncData(current.copyWith(
          apps: [...current.apps, ...result.apps],
          cursor: result.cursor,
          hasMore: result.apps.length >= _pageSize,
          isLoadingMore: false,
        ));
      }
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }
}

final searchPageProvider =
    AutoDisposeAsyncNotifierProvider<SearchNotifier, SearchPageState>(
        SearchNotifier.new);

// Keep legacy providers for backward compatibility (used in other screens)
final topAppsProvider = FutureProvider<List<AppModel>>((ref) async {
  return ref.read(firestoreServiceProvider).getTopApps(limit: 20);
});

final searchResultsProvider = FutureProvider<List<AppModel>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final category = ref.watch(searchCategoryProvider);

  if (query.trim().isEmpty) {
    if (category != null) {
      return ref
          .read(firestoreServiceProvider)
          .getAppsByCategory(category, limit: 20);
    }
    return [];
  }

  final service = ref.read(firestoreServiceProvider);
  final results = await service.searchApps(query.trim());
  if (category != null) {
    return results.where((a) => a.primaryGenreName == category).toList();
  }
  return results;
});
