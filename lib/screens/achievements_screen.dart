import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/achievement.dart';

/// Full screen showing all achievements with locked/unlocked states
class AchievementsScreen extends StatefulWidget {
  final String userId;
  final Set<String> unlockedIds;
  final List<String> featuredBadgeIds;
  final bool isOwnProfile;

  const AchievementsScreen({
    super.key,
    required this.userId,
    required this.unlockedIds,
    required this.featuredBadgeIds,
    this.isOwnProfile = false,
  });

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late List<String> _selectedBadges;

  @override
  void initState() {
    super.initState();
    _selectedBadges = List.from(widget.featuredBadgeIds);
  }

  @override
  Widget build(BuildContext context) {
    // Grup rozetleri kategoriye göre
    final categories = <String, List<Achievement>>{};
    for (final a in kinnectAchievements) {
      categories.putIfAbsent(a.category, () => []).add(a);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF06060F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Rozetler',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context, _selectedBadges),
        ),
        actions: [
          if (widget.isOwnProfile)
            TextButton(
              onPressed: _saveFeaturedBadges,
              child: Text(
                'Kaydet',
                style: GoogleFonts.poppins(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Seçili rozetler
            if (widget.isOwnProfile) ...[
              Text(
                'Profilinde Göster (3 adet seç)',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              _buildFeaturedSection(),
              const SizedBox(height: 24),
              const Divider(color: Colors.white12),
              const SizedBox(height: 16),
            ],

            // Tüm rozetler kategorilere göre
            ...categories.entries.map((entry) => _buildCategorySection(
                  _getCategoryTitle(entry.key),
                  entry.value,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final badgeId = i < _selectedBadges.length ? _selectedBadges[i] : null;
        final achievement = badgeId != null
            ? kinnectAchievements.firstWhere((a) => a.id == badgeId,
                orElse: () => kinnectAchievements.first)
            : null;
        final isUnlocked =
            badgeId != null && widget.unlockedIds.contains(badgeId);

        return GestureDetector(
          onTap: badgeId != null ? () => _removeFeatured(badgeId) : null,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: badgeId != null && isUnlocked
                  ? achievement!.rarityColor.withOpacity(0.2)
                  : Colors.white.withOpacity(0.05),
              border: Border.all(
                color: badgeId != null && isUnlocked
                    ? achievement!.rarityColor
                    : Colors.white24,
                width: 2,
              ),
            ),
            child: Center(
              child: badgeId != null && isUnlocked
                  ? ClipOval(
                      child: Image.asset(
                        achievement!.imagePath,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Icon(
                      Icons.add,
                      color: Colors.white24,
                      size: 24,
                    ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCategorySection(String title, List<Achievement> achievements) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: achievements.length,
          itemBuilder: (context, index) {
            final achievement = achievements[index];
            final isUnlocked = widget.unlockedIds.contains(achievement.id);
            final isSelected = _selectedBadges.contains(achievement.id);

            return _AchievementTile(
              achievement: achievement,
              isUnlocked: isUnlocked,
              isSelected: isSelected,
              canSelect: widget.isOwnProfile &&
                  isUnlocked &&
                  _selectedBadges.length < 3,
              onTap: () => _showAchievementDetail(achievement, isUnlocked),
              onSelect: widget.isOwnProfile && isUnlocked
                  ? () => _toggleFeatured(achievement.id)
                  : null,
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  String _getCategoryTitle(String category) {
    switch (category) {
      case 'social':
        return '👥 Sosyal';
      case 'content':
        return '🔥 İçerik';
      case 'engagement':
        return '⚡ Etkileşim';
      case 'streak':
        return '🏆 Seri';
      default:
        return '⭐ Diğer';
    }
  }

  void _toggleFeatured(String badgeId) {
    setState(() {
      if (_selectedBadges.contains(badgeId)) {
        _selectedBadges.remove(badgeId);
      } else if (_selectedBadges.length < 3) {
        _selectedBadges.add(badgeId);
      }
    });
  }

  void _removeFeatured(String badgeId) {
    setState(() {
      _selectedBadges.remove(badgeId);
    });
  }

  Future<void> _saveFeaturedBadges() async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'featured_badges': _selectedBadges}).eq('id', widget.userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rozetler kaydedildi!')),
        );
        Navigator.pop(context, _selectedBadges);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  void _showAchievementDetail(Achievement achievement, bool isUnlocked) {
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
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Büyük rozet
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

            Text(
              achievement.name,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isUnlocked ? achievement.rarityColor : Colors.grey,
              ),
            ),
            const SizedBox(height: 8),

            // Nasıl kazanılır
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                achievement.description,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // XP ve durum
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _infoChip(
                  isUnlocked ? '✅ Kazanıldı' : '🔒 Kilitli',
                  isUnlocked ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 12),
                _infoChip(
                  '+${achievement.xpReward} XP',
                  Colors.orange,
                ),
              ],
            ),

            // Profilde göster butonu
            if (widget.isOwnProfile && isUnlocked) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  _toggleFeatured(achievement.id);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedBadges.contains(achievement.id)
                      ? Colors.red.withOpacity(0.2)
                      : Colors.orange.withOpacity(0.2),
                  foregroundColor: _selectedBadges.contains(achievement.id)
                      ? Colors.red
                      : Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  _selectedBadges.contains(achievement.id)
                      ? 'Profilden Kaldır'
                      : 'Profilde Göster',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final Achievement achievement;
  final bool isUnlocked;
  final bool isSelected;
  final bool canSelect;
  final VoidCallback onTap;
  final VoidCallback? onSelect;

  const _AchievementTile({
    required this.achievement,
    required this.isUnlocked,
    required this.isSelected,
    required this.canSelect,
    required this.onTap,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onSelect,
      child: Column(
        children: [
          Stack(
            children: [
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
                        )
                      : null,
                  color: isUnlocked ? null : Colors.grey.shade800,
                  boxShadow: isUnlocked
                      ? [
                          BoxShadow(
                            color: achievement.rarityColor.withOpacity(0.4),
                            blurRadius: 12,
                          )
                        ]
                      : null,
                  border: isSelected
                      ? Border.all(color: Colors.orange, width: 3)
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
                      : const Icon(Icons.lock, color: Colors.grey, size: 20),
                ),
              ),
              if (isSelected)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.orange,
                    ),
                    child:
                        const Icon(Icons.check, size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
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
}
