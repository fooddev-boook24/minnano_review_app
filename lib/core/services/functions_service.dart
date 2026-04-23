import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final functionsServiceProvider = Provider((ref) => FunctionsService());

class FunctionsService {
  final _functions = FirebaseFunctions.instanceFor(region: 'asia-northeast1');

  /// iTunes RSS からレビューを取得して Firestore に保存
  Future<void> fetchAppReviews(int trackId) async {
    final callable = _functions.httpsCallable('fetchAppReviews');
    await callable.call({'trackId': trackId});
  }

  /// AI によるレビューサマリーを生成（Pro 限定）
  /// 24時間以内に生成済みの場合は FirebaseFunctionsException (already-exists) を返す
  Future<void> generateReviewSummary(int trackId) async {
    final callable = _functions.httpsCallable('generateReviewSummary');
    await callable.call({'trackId': trackId});
  }

  /// OGP シェアカード画像を生成して Storage URL を返す
  Future<String> generateShareOgp({
    required int trackId,
    required String template,
    required String message,
    required String deviceId,
  }) async {
    final callable = _functions.httpsCallable('generateShareOgp');
    final result = await callable.call({
      'trackId': trackId,
      'template': template,
      'message': message,
      'deviceId': deviceId,
    });
    return result.data['url'] as String;
  }
}
