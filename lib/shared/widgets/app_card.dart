import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_genres.dart';
import '../../core/constants/app_shadows.dart';
import '../../core/constants/app_text_styles.dart';
import '../../shared/models/app_model.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.app,
    required this.onTap,
  });

  final AppModel app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppShadows.card,
        ),
        child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _AppIcon(url: app.artworkUrl100),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.trackName,
                          style: AppTextStyles.cardDeveloper,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          app.developerName,
                          style: AppTextStyles.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (app.averageUserRating != null) ...[
                              const Icon(Icons.star_rounded,
                                  size: 13, color: AppColors.orange),
                              const SizedBox(width: 2),
                              Text(
                                app.averageUserRating!.toStringAsFixed(1),
                                style: AppTextStyles.caption,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              genreJa(app.primaryGenreName),
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.ink30,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.orangeBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.apps, color: AppColors.orange, size: 28),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: kIsWeb
          ? Image.network(
              url!,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 52,
                height: 52,
                color: AppColors.orangeBg,
                child: const Icon(Icons.apps, color: AppColors.orange, size: 28),
              ),
            )
          : CachedNetworkImage(
              imageUrl: url!,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 52,
                height: 52,
                color: AppColors.orangeBg,
              ),
              errorWidget: (_, __, ___) => Container(
                width: 52,
                height: 52,
                color: AppColors.orangeBg,
                child: const Icon(Icons.apps, color: AppColors.orange, size: 28),
              ),
            ),
    );
  }
}
