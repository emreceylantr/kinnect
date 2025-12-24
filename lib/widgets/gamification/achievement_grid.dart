import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/achievement.dart';

/// Grid view displaying achievements with locked/unlocked states
class AchievementGrid extends StatelessWidget {
  final List<Achievement> allAchievements;
  final Set<String> unlockedIds;

  const AchievementGrid({
    super.key,
    required this.allAchievements,
    required this.unlockedIds,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: allAchievements.length,
      itemBuilder: (context, index) {
        final achievement = allAchievements[index];
        final isUnlocked = unlockedIds.contains(achievement.id);

        return _AchievementBadge(
          achievement: achievement,
          isUnlocked: isUnlocked,
        );
      },
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  final Achievement achievement;
  final bool isUnlocked;

  const _AchievementBadge({
    required this.achievement,
    required this.isUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAchievementDetail(context),
      child: Column(
        children: [
          // Rozet ikonu
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isUnlocked
                  ? LinearGradient(
                      colors: [
                        achievement.rarityColor,
                        achievement.rarityColor.withOpacity(0.6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isUnlocked ? null : Colors.grey.shade800,
              boxShadow: isUnlocked
                  ? [
                      BoxShadow(
                        color: achievement.rarityColor.withOpacity(0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            child: Center(
              child: isUnlocked
                  ? ClipOval(
                      child: Image.asset(
                        achievement.imagePath,
                        width: 46,
                        height: 46,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(
                      Icons.lock,
                      color: Colors.grey,
                      size: 20,
                    ),
            ),
          ),
          const SizedBox(height: 4),

          // İsim
          Text(
            achievement.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: isUnlocked ? Colors.white : Colors.grey,
              fontWeight: isUnlocked ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _showAchievementDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16161F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Rozet büyük ikon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isUnlocked
                    ? LinearGradient(
                        colors: [
                          achievement.rarityColor,
                          achievement.rarityColor.withOpacity(0.6),
                        ],
                      )
                    : null,
                color: isUnlocked ? null : Colors.grey.shade800,
                boxShadow: isUnlocked
                    ? [
                        BoxShadow(
                          color: achievement.rarityColor.withOpacity(0.5),
                          blurRadius: 20,
                        )
                      ]
                    : null,
              ),
              child: Center(
                child: isUnlocked
                    ? ClipOval(
                        child: Image.asset(
                          achievement.imagePath,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Text('🔒', style: TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 16),

            // Rozet adı
            Text(
              achievement.name,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isUnlocked ? achievement.rarityColor : Colors.grey,
              ),
            ),
            const SizedBox(height: 4),

            // Nadir seviyesi
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  achievement.rarityName,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: achievement.rarityColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Açıklama
            Text(
              achievement.description,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),

            // Durum ve XP
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? Colors.green.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isUnlocked ? Icons.check_circle : Icons.lock,
                        size: 16,
                        color: isUnlocked ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isUnlocked ? 'Kazanıldı' : 'Kilitli',
                        style: GoogleFonts.poppins(
                          color: isUnlocked ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text(
                        '+${achievement.xpReward} XP',
                        style: GoogleFonts.poppins(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _getRarityText(AchievementRarity rarity) {
    switch (rarity) {
      case AchievementRarity.common:
        return 'Yaygın';
      case AchievementRarity.rare:
        return 'Nadir';
      case AchievementRarity.epic:
        return 'Destansı';
      case AchievementRarity.legendary:
        return 'Efsanevi';
    }
  }
}
