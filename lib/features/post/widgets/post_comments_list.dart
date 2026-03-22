import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme/app_colors.dart';
import '../../../core/language/app_l10n.dart';
import '../../../shared/widgets/shimmer/comment_shimmer.dart';
import '../../profile/screens/profile_screen.dart';

// Callback typedefs
typedef OnEditComment = void Function(Map<String, dynamic> comment);
typedef OnDeleteComment = void Function(String commentId);
typedef OnPlayPauseAudio = void Function(String url, String id);
typedef OnReplyTocomment = void Function(Map<String, dynamic> comment);

class PostCommentsList extends StatelessWidget {
  final bool loadingComments;
  final List<Map<String, dynamic>> comments;
  final String myId;
  final String postOwnerId;
  final bool isExploreMode;
  final String? playingCommentId;

  // Callbacks
  final OnEditComment onEditComment;
  final OnDeleteComment onDeleteComment;
  final OnPlayPauseAudio onPlayPauseAudio;
  final OnReplyTocomment onReplyToComment;

  const PostCommentsList({
    super.key,
    required this.loadingComments,
    required this.comments,
    required this.myId,
    required this.postOwnerId,
    required this.isExploreMode,
    this.playingCommentId,
    required this.onEditComment,
    required this.onDeleteComment,
    required this.onPlayPauseAudio,
    required this.onReplyToComment,
  });

  @override
  Widget build(BuildContext context) {
    if (loadingComments) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        itemBuilder: (context, index) => const CommentShimmer(),
      );
    }

    if (comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Text(
            isExploreMode ? AppL10n.firstFuel : AppL10n.firstComment,
            style: GoogleFonts.poppins(color: Colors.white54),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: comments.length,
      itemBuilder: (_, i) {
        final c = comments[i];
        final p = c["profiles"] ?? {};
        final id = c["id"].toString();
        final isAudio = c["audio_url"] != null;
        final isMine = c["user_id"] == myId;
        final isPostOwner = postOwnerId == myId;
        final canDelete = isMine || isPostOwner;
        final isPlaying = playingCommentId == id;

        // 🆕 Yanıt mı kontrol et (@ile başlıyorsa)
        final content = c["content"]?.toString() ?? "";
        final isReply = content.startsWith("@");

        return Padding(
          padding: EdgeInsets.fromLTRB(
            isReply ? 40 : 16, // 🆕 Yanıtlar girintili
            isReply ? 4 : 10,
            16,
            isReply ? 4 : 10,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🆕 Yanıtlar için küçük ok işareti
              if (isReply)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 6),
                  child: Icon(
                    Icons.subdirectory_arrow_right,
                    color: Colors.white24,
                    size: 14,
                  ),
                ),
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ProfileScreen(userId: c['user_id']))),
                child: CircleAvatar(
                  radius: isReply ? 14 : 18, // 🆕 Yanıtlar küçük avatar
                  backgroundImage: p["avatar_url"] != null
                      ? NetworkImage(p["avatar_url"])
                      : null,
                  backgroundColor: Colors.grey[900],
                ),
              ),
              SizedBox(width: isReply ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(p["username"] ?? AppL10n.user,
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            // ✏️ Düzenlendi etiketi
                            if (c['is_edited'] == true)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Text(
                                  AppL10n.edited,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white30,
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            Text(
                              timeago.format(DateTime.parse(c["created_at"]),
                                  locale: "en_short"),
                              style: GoogleFonts.poppins(
                                  color: Colors.white38, fontSize: 11),
                            ),
                            // ✏️ DÜZENLEME BUTONU (Sadece kendi yorumumsa)
                            if (isMine)
                              GestureDetector(
                                onTap: () => onEditComment(c),
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 10),
                                  child: Icon(Icons.edit_outlined,
                                      color: Colors.white30, size: 16),
                                ),
                              ),
                            if (canDelete) // Post sahibi veya yorum sahibi silebilir
                              GestureDetector(
                                onTap: () => onDeleteComment(id),
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 10),
                                  child: Icon(Icons.delete_outline,
                                      color: AppColors.accentRedAccent
                                          .withValues(alpha: 0.2),
                                      size: 16), // Rengi biraz kıstım
                                ),
                              )
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (isAudio)
                      GestureDetector(
                        onTap: () => onPlayPauseAudio(c["audio_url"], id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: isPlaying
                                ? AppColors.primary
                                : const Color(0xFF2C2C2C),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
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
                      )
                    else
                      Text(
                        c["content"] ?? "",
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontSize: 14),
                      ),
                    // 🆕 YANITLA BUTONU
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => onReplyToComment(c),
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
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
