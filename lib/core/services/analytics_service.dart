import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final analyticsServiceProvider = Provider((ref) => AnalyticsService());

class AnalyticsService {
  final _analytics = FirebaseAnalytics.instance;

  Future<void> logAppViewed(String trackId) async {
    await _analytics.logEvent(
      name: 'review_app_viewed',
      parameters: {'track_id': trackId},
    );
  }

  Future<void> logTabChanged(String trackId, String tabName) async {
    await _analytics.logEvent(
      name: 'review_tab_changed',
      parameters: {'track_id': trackId, 'tab_name': tabName},
    );
  }

  Future<void> logSearchExecuted(String query) async {
    await _analytics.logEvent(
      name: 'review_search_executed',
      parameters: {'query': query},
    );
  }

  Future<void> logCategorySelected(String categoryName) async {
    await _analytics.logEvent(
      name: 'review_category_selected',
      parameters: {'category_name': categoryName},
    );
  }

  Future<void> logCompareAppAdded(String trackId) async {
    await _analytics.logEvent(
      name: 'review_compare_app_added',
      parameters: {'track_id': trackId},
    );
  }

  Future<void> logSummaryRequested(String trackId) async {
    await _analytics.logEvent(
      name: 'review_summary_requested',
      parameters: {'track_id': trackId},
    );
  }

  Future<void> logSummaryCompleted(String trackId) async {
    await _analytics.logEvent(
      name: 'review_summary_completed',
      parameters: {'track_id': trackId},
    );
  }

  Future<void> logProPaywallShown() async {
    await _analytics.logEvent(name: 'review_pro_paywall_shown');
  }

  Future<void> logProPurchaseStarted() async {
    await _analytics.logEvent(name: 'review_pro_purchase_started');
  }

  Future<void> logProPurchaseCompleted() async {
    await _analytics.logEvent(name: 'review_pro_purchase_completed');
  }

  Future<void> logShareCardOpened(String trackId) async {
    await _analytics.logEvent(
        name: 'review_share_card_opened',
        parameters: {'track_id': trackId});
  }

  Future<void> logShareCardAdStarted(String trackId) async {
    await _analytics.logEvent(
        name: 'review_share_card_ad_started',
        parameters: {'track_id': trackId});
  }

  Future<void> logShareCardAdCompleted(String trackId) async {
    await _analytics.logEvent(
        name: 'review_share_card_ad_completed',
        parameters: {'track_id': trackId});
  }

  Future<void> logShareCardAdFailed(String trackId) async {
    await _analytics.logEvent(
        name: 'review_share_card_ad_failed',
        parameters: {'track_id': trackId});
  }

  Future<void> logShareCardShared(
      String trackId, String template, bool isUnlocked) async {
    await _analytics.logEvent(
      name: 'review_share_card_shared',
      parameters: {
        'track_id': trackId,
        'template': template,
        'is_unlocked': isUnlocked ? 1 : 0,
      },
    );
  }

  Future<void> logShareCardDefaultShared(String trackId) async {
    await _analytics.logEvent(
        name: 'review_share_card_default_shared',
        parameters: {'track_id': trackId});
  }
}
