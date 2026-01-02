import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../co../../../core/theme/app_colors.dart';

// Callback typedefs
typedef OnSendTextComment = void Function();
typedef OnStartRecording = void Function();
typedef OnStopRecording = void Function();
typedef OnCancelReply = void Function();
typedef OnShowPhotoEmojiPicker = Future<Map<String, String>?> Function(
    BuildContext context);
typedef OnSendEmojiReaction = void Function(String path, String type);

class CommentInputArea extends StatelessWidget {
  final TextEditingController controller;
  final bool isComposing;
  final bool isRecording;
  final int recordDuration;
  final Map<String, dynamic>? replyingToComment;

  // Callbacks
  final OnSendTextComment onSendTextComment;
  final OnStartRecording onStartRecording;
  final OnStopRecording onStopRecording;
  final OnCancelReply onCancelReply;
  final OnShowPhotoEmojiPicker onShowPhotoEmojiPicker;
  final OnSendEmojiReaction onSendEmojiReaction;

  const CommentInputArea({
    super.key,
    required this.controller,
    required this.isComposing,
    required this.isRecording,
    required this.recordDuration,
    this.replyingToComment,
    required this.onSendTextComment,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onCancelReply,
    required this.onShowPhotoEmojiPicker,
    required this.onSendEmojiReaction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: Platform.isIOS ? 32 : 14,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🆕 YANITLA GÖSTERGESİ
          if (replyingToComment != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.reply, color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "@${replyingToComment!['profiles']?['username'] ?? 'kullanıcı'} yanıtlıyorsun",
                      style: GoogleFonts.poppins(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onCancelReply,
                    child: const Icon(Icons.close,
                        color: Colors.white54, size: 18),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              // 📸 Foto Emoji butonu
              GestureDetector(
                onTap: () async {
                  final result = await onShowPhotoEmojiPicker(context);
                  if (result != null) {
                    onSendEmojiReaction(result['path']!, result['type']!);
                  }
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(
                    Icons.face_retouching_natural,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: TextField(
                    controller: controller,
                    style: const TextStyle(color: Colors.white),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      hintText: isRecording
                          ? "Kaydediliyor... ($recordDuration)"
                          : "Yorum yaz...",
                      hintStyle:
                          const TextStyle(color: Colors.white38, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onLongPress: isComposing ? null : onStartRecording,
                onLongPressUp: onStopRecording,
                onTap: isComposing ? onSendTextComment : null,
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: isRecording
                      ? AppColors.accentRedAccent
                      : AppColors.primary,
                  child: Icon(
                    isComposing ? Icons.send : Icons.mic,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
