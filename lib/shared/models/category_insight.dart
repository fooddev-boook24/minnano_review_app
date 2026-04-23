import 'package:cloud_firestore/cloud_firestore.dart';

/// categoryInsights/{categoryName}
class CategoryInsight {
  const CategoryInsight({
    required this.categoryName,
    required this.avgRating,
    required this.reviewCount,
    required this.topComplaints,
    required this.topPraise,
    required this.risingKeywords,
    required this.whitespaceHint,
    required this.aggregatedAt,
  });

  final String categoryName;
  final double avgRating;
  final int reviewCount;
  final List<InsightItem> topComplaints;
  final List<InsightItem> topPraise;
  final List<String> risingKeywords;
  final String whitespaceHint;
  final DateTime aggregatedAt;

  factory CategoryInsight.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CategoryInsight(
      categoryName: data['categoryName'] as String? ?? doc.id,
      avgRating: (data['avgRating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (data['reviewCount'] as num?)?.toInt() ?? 0,
      topComplaints: _parseItems(data['topComplaints']),
      topPraise: _parseItems(data['topPraise']),
      risingKeywords: List<String>.from(data['risingKeywords'] ?? []),
      whitespaceHint: data['whitespaceHint'] as String? ?? '',
      aggregatedAt: (data['aggregatedAt'] as Timestamp).toDate(),
    );
  }

  static List<InsightItem> _parseItems(dynamic raw) {
    if (raw == null) return [];
    return (raw as List).map((e) => InsightItem.fromMap(e as Map<String, dynamic>)).toList();
  }
}

class InsightItem {
  const InsightItem({
    required this.label,
    required this.count,
    required this.pct,
    this.delta,
  });

  final String label;
  final int count;
  final double pct;
  final double? delta;

  factory InsightItem.fromMap(Map<String, dynamic> map) {
    return InsightItem(
      label: map['label'] as String? ?? '',
      count: (map['count'] as num?)?.toInt() ?? 0,
      pct: (map['pct'] as num?)?.toDouble() ?? 0.0,
      delta: (map['delta'] as num?)?.toDouble(),
    );
  }
}
