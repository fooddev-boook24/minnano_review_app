import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/firestore_service.dart';
import '../../shared/models/app_model.dart';

// ─── Watchlist ─────────────────────────────────────────

class WatchlistNotifier extends StateNotifier<List<String>> {
  WatchlistNotifier() : super([]) {
    _load();
  }

  static const _key = 'watchlist_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_key) ?? [];
  }

  Future<void> add(String trackId) async {
    if (state.contains(trackId)) return;
    state = [...state, trackId];
    await _save();
  }

  Future<void> remove(String trackId) async {
    state = state.where((id) => id != trackId).toList();
    await _save();
  }

  bool contains(String trackId) => state.contains(trackId);

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, state);
  }
}

final watchlistProvider =
    StateNotifierProvider<WatchlistNotifier, List<String>>(
  (ref) => WatchlistNotifier(),
);

// ─── Recently Viewed ───────────────────────────────────

class RecentlyViewedNotifier extends StateNotifier<List<String>> {
  RecentlyViewedNotifier() : super([]) {
    _load();
  }

  static const _key = 'recently_viewed_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_key) ?? [];
  }

  Future<void> add(String trackId) async {
    final list = state.toList();
    list.remove(trackId);
    list.insert(0, trackId);
    state = list.take(10).toList();
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, state);
  }
}

final recentlyViewedProvider =
    StateNotifierProvider<RecentlyViewedNotifier, List<String>>(
  (ref) => RecentlyViewedNotifier(),
);

final recentlyViewedAppsProvider =
    FutureProvider<List<AppModel>>((ref) async {
  final ids = ref.watch(recentlyViewedProvider);
  if (ids.isEmpty) return [];
  final service = ref.read(firestoreServiceProvider);
  final results = await Future.wait(
    ids.map((id) => service.getAppByTrackId(int.parse(id))),
  );
  return results.whereType<AppModel>().toList();
});
