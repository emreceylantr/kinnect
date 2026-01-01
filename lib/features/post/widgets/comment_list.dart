// Kinnect - Yorum Listesi Widget'ı
// post_detail_screen.dart'tan refactor edildi

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kinnect/shared/widgets/shimmer/comment_shimmer.dart';
import 'comment_item.dart';

/// Yorum listesini gösteren widget
/// Shimmer loading, boş durum ve yorum listesini yönetir
class CommentList extends StatelessWidget {
  final List<Map<String, dynamic>> comments;
  final bool isLoading;
  final bool isExploreMode;
  final String currentUserId;
  final String postOwnerId;
  final String? playingCommentId;

  // Callbacks
  final void Function(Map<String, dynamic> comment)? onEditComment;
  final void Function(String commentId)? onDeleteComment;
  final void Function(Map<String, dynamic> comment)? onReplyComment;
  final void Function(String audioUrl, String commentId)? onPlayPause;
  final void Function(String userId)? onAvatarTap;

  const CommentList({
    super.key,
    required this.comments,
    required this.isLoading,
    required this.currentUserId,
    required this.postOwnerId,
    this.isExploreMode = false,
    this.playingCommentId,
    this.onEditComment,
    this.onDeleteComment,
    this.onReplyComment,
    this.onPlayPause,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    // Loading durumu
    if (isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        itemBuilder: (context, index) => const CommentShimmer(),
      );
    }

    // Boş durum
    if (comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Text(
            isExploreMode ? 'İlk odunu sen at 🔥' : 'İlk yorumu sen yap!',
            style: GoogleFonts.poppins(color: Colors.white54),
          ),
        ),
      );
    }

    // Yorum listesi
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: comments.length,
      itemBuilder: (context, index) {
        final comment = comments[index];
        final commentId = comment['id'].toString();
        final isMyComment = comment['user_id'] == currentUserId;
        final isPostOwner = postOwnerId == currentUserId;
        final isPlaying = playingCommentId == commentId;

        return CommentItem(
          comment: comment,
          isMyComment: isMyComment,
          isPostOwner: isPostOwner,
          isPlaying: isPlaying,
          onEdit: isMyComment && onEditComment != null
              ? () => onEditComment!(comment)
              : null,
          onDelete: (isMyComment || isPostOwner) && onDeleteComment != null
              ? () => onDeleteComment!(commentId)
              : null,
          onReply:
              onReplyComment != null ? () => onReplyComment!(comment) : null,
          onPlayPause: comment['audio_url'] != null && onPlayPause != null
              ? () => onPlayPause!(comment['audio_url'], commentId)
              : null,
          onAvatarTap: onAvatarTap != null
              ? () => onAvatarTap!(comment['user_id'])
              : null,
        );
      },
    );
  }
}
