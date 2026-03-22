import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/language/app_l10n.dart';
import '../../profile/screens/profile_screen.dart';
import '../../../data/models/photo_emoji.dart';

class ReactionsSheet extends StatelessWidget {
  final List<Map<String, dynamic>> emojiReactions;
  final String myId;
  final Function(Map<String, dynamic> reaction) onDeleteReaction;

  const ReactionsSheet({
    super.key,
    required this.emojiReactions,
    required this.myId,
    required this.onDeleteReaction,
  });

  static void show(
    BuildContext context, {
    required List<Map<String, dynamic>> emojiReactions,
    required String myId,
    required Function(Map<String, dynamic> reaction) onDeleteReaction,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ReactionsSheet(
        emojiReactions: emojiReactions,
        myId: myId,
        onDeleteReaction: onDeleteReaction,
      ),
    );
  }

  String _getEmojiIcon(String? emojiType) {
    if (emojiType == null) return '📸';

    try {
      final type = PhotoEmojiType.values.firstWhere(
        (e) => e.name == emojiType,
        orElse: () => PhotoEmojiType.smile,
      );
      return type.defaultEmoji;
    } catch (_) {
      return '📸';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '📸 Tepkiler (${emojiReactions.length})',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 24,
                childAspectRatio: 0.75,
              ),
              itemCount: emojiReactions.length,
              itemBuilder: (context, index) {
                final reaction = emojiReactions[index];
                final profile = reaction['profiles'] ?? {};
                final isMyReaction = reaction['user_id'] == myId;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ProfileScreen(userId: reaction['user_id']),
                      ),
                    );
                  },
                  onLongPress: isMyReaction
                      ? () {
                          Navigator.pop(context);
                          onDeleteReaction(reaction);
                        }
                      : null,
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary,
                                width: 2,
                              ),
                              image: DecorationImage(
                                image:
                                    NetworkImage(reaction['emoji_url'] ?? ''),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            right: -8,
                            bottom: -8,
                            child: Text(
                              _getEmojiIcon(reaction['emoji_type']),
                              style: const TextStyle(fontSize: 30),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile['username'] ?? AppL10n.user,
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
