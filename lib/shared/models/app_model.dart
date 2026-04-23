import 'package:cloud_firestore/cloud_firestore.dart';

/// timelines/{artistId}/apps/{trackId} のモデル（読み取り専用）
class AppModel {
  const AppModel({
    required this.trackId,
    required this.trackName,
    required this.developerName,
    required this.developerId,
    this.artworkUrl100,
    this.averageUserRating,
    required this.userRatingCount,
    required this.primaryGenreName,
    required this.trackViewUrl,
    this.formattedPrice,
    this.version,
    this.description,
    this.releaseDate,
  });

  final int trackId;
  final String trackName;
  final String developerName;
  final String developerId;
  final String? artworkUrl100;
  final double? averageUserRating;
  final int userRatingCount;
  final String primaryGenreName;
  final String trackViewUrl;
  final String? formattedPrice;
  final String? version;
  final String? description;
  final String? releaseDate;

  factory AppModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppModel(
      trackId: (data['trackId'] as num).toInt(),
      trackName: data['trackName'] as String? ?? '',
      developerName: data['developerName'] as String? ?? '',
      developerId: data['developerId'] as String? ?? '',
      artworkUrl100: data['artworkUrl100'] as String?,
      averageUserRating: (data['averageUserRating'] as num?)?.toDouble(),
      userRatingCount: (data['userRatingCount'] as num?)?.toInt() ?? 0,
      primaryGenreName: data['primaryGenreName'] as String? ?? '',
      trackViewUrl: data['trackViewUrl'] as String? ?? '',
      formattedPrice: data['formattedPrice'] as String?,
      version: data['version'] as String?,
      description: data['description'] as String?,
      releaseDate: data['releaseDate'] as String?,
    );
  }
}
