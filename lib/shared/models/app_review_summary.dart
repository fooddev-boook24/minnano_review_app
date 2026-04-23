import 'package:cloud_firestore/cloud_firestore.dart';

/// appReviewSummaries/{trackId}
class AppReviewSummary {
  const AppReviewSummary({
    required this.positivePoints,
    required this.negativePoints,
    required this.featureRequests,
    required this.asoHint,
    required this.keywordsPositive,
    required this.keywordsNegative,
    required this.topicCounts,
    required this.generatedAt,
    required this.reviewCount,
  });

  final List<String> positivePoints;
  final List<String> negativePoints;
  final List<String> featureRequests;
  final String asoHint;
  final List<String> keywordsPositive;
  final List<String> keywordsNegative;
  final TopicCounts topicCounts;
  final DateTime generatedAt;
  final int reviewCount;

  factory AppReviewSummary.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final keywords = data['keywords'] as Map<String, dynamic>? ?? {};
    return AppReviewSummary(
      positivePoints: List<String>.from(data['positivePoints'] ?? []),
      negativePoints: List<String>.from(data['negativePoints'] ?? []),
      featureRequests: List<String>.from(data['featureRequests'] ?? []),
      asoHint: data['asoHint'] as String? ?? '',
      keywordsPositive: List<String>.from(keywords['positive'] ?? []),
      keywordsNegative: List<String>.from(keywords['negative'] ?? []),
      topicCounts: TopicCounts.fromMap(data['topicCounts'] as Map<String, dynamic>? ?? {}),
      generatedAt: (data['generatedAt'] as Timestamp).toDate(),
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class TopicCounts {
  const TopicCounts({
    required this.bug,
    required this.ux,
    required this.feature,
    required this.price,
    required this.positive,
  });

  final int bug;
  final int ux;
  final int feature;
  final int price;
  final int positive;

  factory TopicCounts.fromMap(Map<String, dynamic> map) {
    return TopicCounts(
      bug: (map['bug'] as num?)?.toInt() ?? 0,
      ux: (map['ux'] as num?)?.toInt() ?? 0,
      feature: (map['feature'] as num?)?.toInt() ?? 0,
      price: (map['price'] as num?)?.toInt() ?? 0,
      positive: (map['positive'] as num?)?.toInt() ?? 0,
    );
  }
}
