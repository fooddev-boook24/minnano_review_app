import 'package:cloud_firestore/cloud_firestore.dart';

/// appReviews/{trackId}/items/{reviewId}
class AppReview {
  const AppReview({
    required this.reviewId,
    required this.trackId,
    required this.rating,
    required this.title,
    required this.body,
    required this.authorName,
    required this.country,
    this.version,
    required this.reviewDate,
    required this.fetchedAt,
  });

  final String reviewId;
  final int trackId;
  final int rating;
  final String title;
  final String body;
  final String authorName;
  final String country;
  final String? version;
  final DateTime reviewDate;
  final DateTime fetchedAt;

  factory AppReview.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppReview(
      reviewId: data['reviewId'] as String? ?? doc.id,
      trackId: (data['trackId'] as num).toInt(),
      rating: (data['rating'] as num).toInt(),
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      country: data['country'] as String? ?? 'jp',
      version: data['version'] as String?,
      reviewDate: (data['reviewDate'] as Timestamp).toDate(),
      fetchedAt: (data['fetchedAt'] as Timestamp).toDate(),
    );
  }
}
