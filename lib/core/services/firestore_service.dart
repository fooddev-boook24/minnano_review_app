import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/app_model.dart';
import '../../shared/models/app_review.dart';
import '../../shared/models/app_review_summary.dart';
import '../../shared/models/category_insight.dart';

final firestoreServiceProvider = Provider((ref) => FirestoreService());

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // 全アプリキャッシュ（セッション内で再利用）
  List<AppModel>? _allAppsCache;

  // ── timelines（読み取り専用） ──────────────────────────────────

  /// 開発者名・アプリ名で検索（timelines コレクション）
  Future<List<Map<String, dynamic>>> searchDevelopers(String query) async {
    final lower = query.toLowerCase();
    final snap = await _db
        .collection('timelines')
        .where('developerNameLower', isGreaterThanOrEqualTo: lower)
        .where('developerNameLower', isLessThan: '${lower}z')
        .limit(20)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  /// アプリ名で部分一致検索
  Future<List<AppModel>> searchApps(String query) async {
    final lower = query.toLowerCase();
    try {
      final all = await _fetchAllApps();
      final results = all
          .where((a) => a.trackName.toLowerCase().contains(lower))
          .toList()
        ..sort((a, b) =>
            (b.averageUserRating ?? 0).compareTo(a.averageUserRating ?? 0));
      return results;
    } on FirebaseException catch (_) {
      return [];
    }
  }

  /// 開発者のアプリ一覧を取得
  Future<List<AppModel>> getAppsByDeveloper(String artistId) async {
    final snap = await _db
        .collection('timelines')
        .doc(artistId)
        .collection('apps')
        .get();
    return snap.docs.map(AppModel.fromFirestore).toList();
  }

  /// trackId でアプリ1件を取得
  Future<AppModel?> getAppByTrackId(int trackId) async {
    final snap = await _db
        .collectionGroup('apps')
        .where('trackId', isEqualTo: trackId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return AppModel.fromFirestore(snap.docs.first);
  }

  /// カテゴリ別の上位アプリ一覧
  /// primaryGenreName は apps サブコレクションのフィールドなので
  /// 全 timelines → 全 apps 取得 → Dart でフィルタ
  Future<List<AppModel>> getAppsByCategory(String category,
      {int limit = 10}) async {
    try {
      final all = await _fetchAllApps();
      final filtered = all
          .where((a) => a.primaryGenreName == category && a.userRatingCount >= 10)
          .toList()
        ..sort((a, b) =>
            (b.averageUserRating ?? 0).compareTo(a.averageUserRating ?? 0));
      return filtered.take(limit).toList();
    } on FirebaseException catch (_) {
      return [];
    }
  }

  /// カテゴリ別（ページング版）
  Future<({List<AppModel> apps, DocumentSnapshot? cursor})>
      getAppsByCategoryPaged(String category,
          {int limit = 20, DocumentSnapshot? startAfter}) async {
    try {
      final all = await _fetchAllApps();
      final filtered = all
          .where((a) => a.primaryGenreName == category)
          .toList()
        ..sort((a, b) =>
            (b.averageUserRating ?? 0).compareTo(a.averageUserRating ?? 0));
      // Dart 側でページング（cursor は使わず offset で代替）
      return (apps: filtered.take(limit).toList(), cursor: null);
    } on FirebaseException catch (_) {
      return (apps: <AppModel>[], cursor: null);
    }
  }

  /// 全 timelines → 全 apps を一括取得（セッション内キャッシュあり）
  Future<List<AppModel>> _fetchAllApps() async {
    if (_allAppsCache != null) return _allAppsCache!;
    final timelinesSnap =
        await _db.collection('timelines').limit(300).get();
    debugPrint('[FirestoreService] timelines count: ${timelinesSnap.docs.length}');
    if (timelinesSnap.docs.isEmpty) return [];
    final appSnaps = await Future.wait(timelinesSnap.docs.map((doc) => _db
        .collection('timelines')
        .doc(doc.id)
        .collection('apps')
        .get()));
    final seen = <int>{};
    final results = <AppModel>[];
    for (final snap in appSnaps) {
      for (final doc in snap.docs) {
        final app = AppModel.fromFirestore(doc);
        if (seen.add(app.trackId)) results.add(app);
      }
    }
    debugPrint('[FirestoreService] total apps: ${results.length}');
    debugPrint('[FirestoreService] categories: ${results.map((a) => a.primaryGenreName).toSet().toList()..sort()}');
    _allAppsCache = results;
    return results;
  }

  /// 初期表示用：timelines から開発者を取得し各アプリを返す
  /// （collectionGroup + orderBy はインデックス不要の方法に変更）
  Future<List<AppModel>> getTopApps({int limit = 20}) async {
    try {
      final timelinesSnap = await _db
          .collection('timelines')
          .limit(limit)
          .get();
      if (timelinesSnap.docs.isEmpty) return [];
      final futures = timelinesSnap.docs.map((doc) => _db
          .collection('timelines')
          .doc(doc.id)
          .collection('apps')
          .orderBy('averageUserRating', descending: true)
          .limit(1)
          .get());
      final appSnaps = await Future.wait(futures);
      return appSnaps
          .expand((snap) => snap.docs.map(AppModel.fromFirestore))
          .toList();
    } on FirebaseException catch (_) {
      return [];
    }
  }

  /// 初期表示用（カーソル付き）
  Future<({List<AppModel> apps, DocumentSnapshot? cursor})> getTopAppsPaged(
      {int limit = 20, DocumentSnapshot? startAfter}) async {
    try {
      Query query = _db.collection('timelines').limit(limit);
      if (startAfter != null) query = query.startAfterDocument(startAfter);
      final timelinesSnap = await query.get();
      if (timelinesSnap.docs.isEmpty) {
        return (apps: <AppModel>[], cursor: null);
      }
      final futures = timelinesSnap.docs.map((doc) => _db
          .collection('timelines')
          .doc(doc.id)
          .collection('apps')
          .orderBy('averageUserRating', descending: true)
          .limit(1)
          .get());
      final appSnaps = await Future.wait(futures);
      final apps = appSnaps
          .expand((snap) => snap.docs.map(AppModel.fromFirestore))
          .toList();
      final cursor =
          timelinesSnap.docs.isNotEmpty ? timelinesSnap.docs.last : null;
      return (apps: apps, cursor: cursor);
    } on FirebaseException catch (_) {
      return (apps: <AppModel>[], cursor: null);
    }
  }

  // ── appReviews ─────────────────────────────────────────────────

  /// レビュー一覧を取得
  Future<List<AppReview>> getReviews({
    required String trackId,
    int? ratingFilter,
    int limit = 200,
    DocumentSnapshot? startAfter,
  }) async {
    Query query = _db
        .collection('appReviews')
        .doc(trackId)
        .collection('items')
        .orderBy('reviewDate', descending: true);

    if (ratingFilter != null) {
      query = query.where('rating', isEqualTo: ratingFilter);
    }
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    query = query.limit(limit);

    try {
      final snap = await query.get();
      return snap.docs.map(AppReview.fromFirestore).toList();
    } on FirebaseException catch (_) {
      return [];
    }
  }

  /// appReviews のメタ情報（lastFetchedAt, totalCount）
  Future<Map<String, dynamic>?> getReviewMeta(String trackId) async {
    try {
      final doc = await _db.collection('appReviews').doc(trackId).get();
      return doc.data();
    } on FirebaseException catch (_) {
      return null;
    }
  }

  // ── appReviewSummaries ─────────────────────────────────────────

  Future<AppReviewSummary?> getReviewSummary(String trackId) async {
    try {
      final doc = await _db.collection('appReviewSummaries').doc(trackId).get();
      if (!doc.exists) return null;
      return AppReviewSummary.fromFirestore(doc);
    } on FirebaseException catch (_) {
      return null;
    }
  }

  // ── categoryInsights ──────────────────────────────────────────

  Future<CategoryInsight?> getCategoryInsight(String categoryName) async {
    try {
      final doc = await _db.collection('categoryInsights').doc(categoryName).get();
      if (!doc.exists) return null;
      return CategoryInsight.fromFirestore(doc);
    } on FirebaseException catch (_) {
      return null;
    }
  }

  Future<List<CategoryInsight>> getAllCategoryInsights() async {
    try {
      final snap = await _db.collection('categoryInsights').get();
      return snap.docs.map(CategoryInsight.fromFirestore).toList();
    } on FirebaseException catch (_) {
      return [];
    }
  }

  Future<List<String>> getCategories() async {
    try {
      // 実際の apps データから primaryGenreName を抽出（確実に一致する）
      final all = await _fetchAllApps();
      final genres = all
          .map((a) => a.primaryGenreName)
          .where((g) => g.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      return genres;
    } on FirebaseException catch (_) {
      return [];
    }
  }
}
