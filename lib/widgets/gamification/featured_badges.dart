import 'package:flutter/material.dart';
import '../../models/achievement.dart';
import 'profile_badge_display.dart';

/// 3 featured badges displayed on profile under bio
class FeaturedBadges extends StatelessWidget {
  final List<String> badgeIds;
  final Set<String> unlockedIds;
  final VoidCallback? onTap;
  final Function(Achievement)? onBadgeTap;
  final bool showEmptySlots;

  const FeaturedBadges({
    super.key,
    required this.badgeIds,
    required this.unlockedIds,
    this.onTap,
    this.onBadgeTap,
    this.showEmptySlots = true,
  });

  @override
  Widget build(BuildContext context) {
    // Eğer boş slotları göstermiyorsak ve rozet yoksa hiçbir şey gösterme
    if (!showEmptySlots && badgeIds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(showEmptySlots ? 3 : badgeIds.length, (i) {
        final badgeId = i < badgeIds.length ? badgeIds[i] : null;
        final achievement = badgeId != null
            ? kinnectAchievements.cast<Achievement?>().firstWhere(
                  (a) => a?.id == badgeId,
                  orElse: () => null,
                )
            : null;
        final isUnlocked = badgeId != null && unlockedIds.contains(badgeId);

        // Boş slotları göstermiyorsak ve bu slot boşsa atla
        if (!showEmptySlots && (achievement == null || !isUnlocked)) {
          return const SizedBox.shrink();
        }

        // Rozet var ve açık ise - ProfileBadgeDisplay kullan
        if (achievement != null && isUnlocked) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ProfileBadgeDisplay(
              imagePath: achievement.imagePath,
              size: 42,
              onTap: () {
                if (onBadgeTap != null) {
                  onBadgeTap!(achievement);
                } else if (onTap != null) {
                  onTap!();
                }
              },
            ),
          );
        } else {
          // Boş slot
          return GestureDetector(
            onTap: onTap,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.3),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.add_rounded,
                  color: Colors.white30,
                  size: 18,
                ),
              ),
            ),
          );
        }
      }),
    );
  }
}
