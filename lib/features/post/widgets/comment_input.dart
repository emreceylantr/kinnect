// Kinnect - Yorum Giriş Widget'ı
// post_detail_screen.dart'tan refactor edildi

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:kinnect/core/theme/app_colors.dart';
import 'package:kinnect/core/language/app_l10n.dart';
import 'package:kinnect/shared/widgets/photo_emoji_picker.dart';

/// Yorum yazma alanı widget'ı
/// Metin girişi, emoji tepki ve sesli yorum özelliklerini destekler
class CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final Map<String, dynamic>? replyingTo;
  final Map<String, dynamic>? currentUserProfile;
  final bool isRecording;
  final int recordDuration;
  final bool isSending;
  final bool isExploreMode;

  // Callbacks
  final VoidCallback onSendText;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final void Function(String emojiPath, String emojiType) onSendEmoji;
  final VoidCallback? onCancelReply;
  final void Function(String) onTextChanged;

  const CommentInput({
    super.key,
    required this.controller,
    required this.onSendText,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onSendEmoji,
    required this.onTextChanged,
    this.replyingTo,
    this.currentUserProfile,
    this.isRecording = false,
    this.recordDuration = 0,
    this.isSending = false,
    this.isExploreMode = false,
    this.onCancelReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Yanıtlanan yorum gösterimi
          if (replyingTo != null) _buildReplyPreview(),

          // Emoji tepki satırı
          _buildEmojiRow(context),

          const SizedBox(height: 12),

          // Metin girişi ve butonlar
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withValues(alpha: 0.3),
                backgroundImage: currentUserProfile?['avatar_url'] != null
                    ? NetworkImage(currentUserProfile!['avatar_url'])
                    : null,
                child: currentUserProfile?['avatar_url'] == null
                    ? const Icon(Icons.person, color: Colors.white54, size: 16)
                    : null,
              ),
              const SizedBox(width: 12),

              // Metin alanı
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: TextField(
                    controller: controller,
                    style:
                        GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                    onChanged: onTextChanged,
                    decoration: InputDecoration(
                      hintText: replyingTo != null
                          ? AppL10n.replyToUserHint(replyingTo!['profiles']?['username'] ?? AppL10n.user)
                          : (isExploreMode
                              ? AppL10n.exploreCommentHint
                              : AppL10n.commentHint),
                      hintStyle: GoogleFonts.poppins(color: Colors.white38),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    minLines: 1,
                    maxLines: 4,
                  ),
                ),
              ),

              // Gönder/Kayıt butonu
              const SizedBox(width: 8),
              _buildActionButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview() {
    final username = replyingTo?['profiles']?['username'] ?? AppL10n.user;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppL10n.replyingToUser(username),
              style: GoogleFonts.poppins(
                color: AppColors.primary,
                fontSize: 12,
              ),
            ),
          ),
          if (onCancelReply != null)
            GestureDetector(
              onTap: onCancelReply,
              child: Icon(Icons.close, color: Colors.white54, size: 18),
            ),
        ],
      ),
    );
  }

  Widget _buildEmojiRow(BuildContext context) {
    // Emoji seçimi için bottom sheet açılacak
    return GestureDetector(
      onTap: () async {
        final result = await showPhotoEmojiPicker(context);
        if (result != null) {
          onSendEmoji(result['path']!, result['type']!);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_reaction_outlined, color: Colors.white54, size: 18),
            const SizedBox(width: 8),
            Text(
              AppL10n.emojiReaction,
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    // Kayıt durumu
    if (isRecording) {
      return GestureDetector(
        onTap: onStopRecording,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.accentRedAccent,
            shape: BoxShape.circle,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.stop, color: Colors.white, size: 20),
              const SizedBox(width: 4),
              Text(
                '${recordDuration}s',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Metin varsa gönder, yoksa mikrofon
    final hasText = controller.text.trim().isNotEmpty;

    return GestureDetector(
      onTap: hasText ? onSendText : null,
      onLongPress: hasText ? null : onStartRecording,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: hasText ? AppColors.primary : Colors.white12,
          shape: BoxShape.circle,
        ),
        child: isSending
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                hasText ? Icons.send : Icons.mic,
                color: Colors.white,
                size: 20,
              ),
      ),
    );
  }
}
