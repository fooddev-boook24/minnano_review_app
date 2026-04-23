import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

final rewardedAdServiceProvider = Provider((ref) => RewardedAdService());

/// セッション中の比較スロット解放フラグ（3〜4枠目）
final compareSlotUnlockedProvider = StateProvider<bool>((ref) => false);

class RewardedAdService {
  // TODO: 本番リリース前に実際の AdUnit ID に差し替え
  static const _androidAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
  static const _iosAdUnitId = 'ca-app-pub-3940256099942544/1712485313';

  RewardedAd? _ad;

  String get _adUnitId => defaultTargetPlatform == TargetPlatform.iOS
      ? _iosAdUnitId
      : _androidAdUnitId;

  Future<void> load() async {
    if (kIsWeb) return;
    await RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _ad = ad,
        onAdFailedToLoad: (_) => _ad = null,
      ),
    );
  }

  /// 広告を表示し、リワードを受け取ったら true を返す。
  /// Web・広告ロード失敗時は true を返してフォールバック。
  Future<bool> show() async {
    if (kIsWeb) return true;
    if (_ad == null) await load();
    final ad = _ad;
    if (ad == null) return true;

    final completer = Completer<bool>();
    bool rewarded = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _ad = null;
        if (!completer.isCompleted) completer.complete(rewarded);
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _ad = null;
        if (!completer.isCompleted) completer.complete(true);
      },
    );
    ad.show(onUserEarnedReward: (_, __) => rewarded = true);
    return completer.future;
  }
}
