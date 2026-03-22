// Kinnect - Tekil Yorum Widget'ı
// post_detail_screen.dart'tan refactor edildi

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme/app_colors.dart';
import '../../../core/language/app_l10n.dart';
import '../../../shared/widgets/kinnect_image.dart';

/// Tek bir yorumu gösteren widget
/// Hem metin hem de sesli yorumları destekler
class CommentItem extends StatelessWidget {
  final Map<String, dynamic> comment;
  final bool isMyComment;
  final bool isPostOwner;
  final bool isPlaying;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onReply;
  final VoidCallback? onPlayPause;
  final VoidCallback? onAvatarTap;

  const CommentItem({
    super.key,
    required this.comment,
    required this.isMyComment,
    required this.isPostOwner,
    this.isPlaying = false,
    this.onEdit,
    this.onDelete,
    this.onReply,
    this.onPlayPause,
    this.onAvatarTap,
  });

  bool get canDelete => isMyComment || isPostOwner;
  bool get isAudio => comment['audio_url'] != null;
  bool get isReply => (comment['content']?.toString() ?? '').startsWith('@');

  @override
  Widget build(BuildContext context) {
    final profile = comment['profiles'] ?? {};
    final content = comment['content']?.toString() ?? '';
    final createdAt = DateTime.tryParse(comment['created_at'] ?? '');

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isReply ? 40 : 16,
        isReply ? 4 : 10,
        16,
        isReply ? 4 : 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Yanıt oku
          if (isReply)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 6),
              child: Icon(Icons.subdirectory_arrow_right,
                  color: Colors.white24, size: 16),
            ),

          // Avatar
          GestureDetector(
            onTap: onAvatarTap,
            child: CircleAvatar(
              radius: isReply ? 12 : 16,
              backgroundColor: AppColors.bgCardDark,
              child: profile['avatar_url'] != null
                  ? KinnectImage(
                      imageUrl: profile['avatar_url'],
                      isCircle: true,
                      fit: BoxFit.cover,
                    )
                  : const Icon(Icons.person, color: Colors.white38, size: 14),
            ),
          ),
          const SizedBox(width: 10),

          // İçerik
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Text(
                      profile['username'] ?? AppL10n.anonymous,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: isReply ? 12 : 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (createdAt != null)
                      Text(
                        timeago.format(createdAt, locale: 'tr'),
                        style: GoogleFonts.poppins(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    const Spacer(),

                    // Düzenle butonu
                    if (isMyComment && onEdit != null)
                      GestureDetector(
                        onTap: onEdit,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Icon(Icons.edit_outlined,
                              color: Colors.white30, size: 16),
                        ),
                      ),

                    // Sil butonu
                    if (canDelete && onDelete != null)
                      GestureDetector(
                        onTap: onDelete,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Icon(Icons.delete_outline,
                              color: AppColors.accentRedAccent.withOpacity(0.5),
                              size: 16),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),

                // İçerik: Ses veya Metin
                if (isAudio)
                  _buildAudioPlayer()
                else
                  Text(
                    content,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),

                // Yanıtla butonu
                if (onReply != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onReply,
                    child: Text(
                      AppL10n.replyLabel,
                      style: GoogleFonts.poppins(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPlayer() {
    return GestureDetector(
      onTap: onPlayPause,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isPlaying ? AppColors.primary : const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              isPlaying ? AppL10n.playing : AppL10n.voiceComment,
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
