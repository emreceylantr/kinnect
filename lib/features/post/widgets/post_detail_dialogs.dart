// Kinnect - Post Yardımcı Widget'ları
// post_detail_screen.dart'tan refactor edildi

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kinnect/features/profile/screens/profile_screen.dart';
import 'package:kinnect/core/theme/app_colors.dart';

// ==========================================
// 📸 TÜM TEPKİLERİ GÖSTEREN DİALOG
// ==========================================

/// Emoji tepkilerini gösteren bottom sheet
class ReactionsBottomSheet extends StatelessWidget {
  final List<Map<String, dynamic>> reactions;
  final String currentUserId;
  final void Function(Map<String, dynamic> reaction)? onDeleteReaction;

  const ReactionsBottomSheet({
    super.key,
    required this.reactions,
    required this.currentUserId,
    this.onDeleteReaction,
  });

  /// Emoji tipinden varsayılan emoji karakterini al
  String _getEmojiIcon(String? emojiType) {
    if (emojiType == null) return '📸';
    switch (emojiType) {
      case 'smile':
        return '😊';
      case 'cry':
        return '😢';
      case 'laugh':
        return '😂';
      case 'surprise':
        return '😮';
      case 'thumbsUp':
        return '👍';
      case 'love':
        return '😍';
      default:
        return '📸';
    }
  }

  static void show(
    BuildContext context, {
    required List<Map<String, dynamic>> reactions,
    required String currentUserId,
    void Function(Map<String, dynamic> reaction)? onDeleteReaction,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ReactionsBottomSheet(
        reactions: reactions,
        currentUserId: currentUserId,
        onDeleteReaction: onDeleteReaction,
      ),
    );
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
          // Handle
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
          // Başlık
          Text(
            '📸 Tepkiler (${reactions.length})',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Grid tepkiler
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
              itemCount: reactions.length,
              itemBuilder: (context, index) {
                final reaction = reactions[index];
                final profile = reaction['profiles'] ?? {};
                final isMyReaction = reaction['user_id'] == currentUserId;
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
                  onLongPress: isMyReaction && onDeleteReaction != null
                      ? () {
                          Navigator.pop(context);
                          onDeleteReaction!(reaction);
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
                        profile['username'] ?? 'Kullanıcı',
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

// ==========================================
// ❤️ BEĞENENLERİ GÖSTEREN DİALOG
// ==========================================

/// Beğenenleri gösteren bottom sheet
class LikersBottomSheet extends StatelessWidget {
  final List<Map<String, dynamic>> likers;
  final int totalCount;
  final bool isLoading;
  final String? errorMessage;

  const LikersBottomSheet({
    super.key,
    required this.likers,
    required this.totalCount,
    this.isLoading = false,
    this.errorMessage,
  });

  static void show(
    BuildContext context, {
    required Future<List<Map<String, dynamic>>> Function() fetchLikers,
    required int likeCount,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchLikers(),
        builder: (context, snapshot) {
          return LikersBottomSheet(
            likers: snapshot.data ?? [],
            totalCount: likeCount,
            isLoading: snapshot.connectionState == ConnectionState.waiting,
            errorMessage: snapshot.hasError ? 'Yüklenemedi' : null,
          );
        },
      ),
    );
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
          // Handle
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
          // Başlık
          Text(
            '❤️ Beğenenler ($totalCount)',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // Liste
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (errorMessage != null)
            Center(
              child: Text(
                errorMessage!,
                style: GoogleFonts.poppins(color: Colors.white54),
              ),
            )
          else if (likers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Henüz kimse beğenmedi',
                  style: GoogleFonts.poppins(color: Colors.white54),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: likers.length,
                itemBuilder: (context, index) {
                  final liker = likers[index];
                  final profile = liker['profiles'] ?? {};
                  final username = profile['username'] ?? 'Kullanıcı';
                  final avatarUrl = profile['avatar_url'];
                  final userId = liker['user_id'];

                  return ListTile(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(userId: userId),
                        ),
                      );
                    },
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.bgCard,
                      backgroundImage:
                          avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null
                          ? const Icon(Icons.person,
                              color: Colors.white54, size: 20)
                          : null,
                    ),
                    title: Text(
                      username,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.white38,
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

// ==========================================
// 🛡️ ŞİKAYET DİALOGU
// ==========================================

/// Genel amaçlı şikayet dialogu
class ReportDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> reasons;
  final void Function(String reason) onReasonSelected;

  const ReportDialog({
    super.key,
    this.title = 'Şikayet Et',
    required this.subtitle,
    required this.reasons,
    required this.onReasonSelected,
  });

  static void show(
    BuildContext context, {
    String title = 'Şikayet Et',
    required String subtitle,
    required List<String> reasons,
    required void Function(String reason) onReasonSelected,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => ReportDialog(
        title: title,
        subtitle: subtitle,
        reasons: reasons,
        onReasonSelected: (reason) {
          Navigator.pop(ctx);
          onReasonSelected(reason);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.bgCardLight,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.bgBlack.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 5,
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: List.generate(reasons.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => onReasonSelected(reasons[index]),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                reasons[index],
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 12.5,
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.white24,
                                size: 12,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Vazgeç',
                  style: GoogleFonts.poppins(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 🗑️ SİLME ONAY DİALOGU
// ==========================================

/// Genel amaçlı silme onay dialogu
class ConfirmDeleteDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onConfirm;
  final String confirmText;
  final Color confirmColor;

  const ConfirmDeleteDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onConfirm,
    this.confirmText = 'Sil',
    this.confirmColor = AppColors.accentRedAccent,
  });

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
    String confirmText = 'Sil',
    Color confirmColor = AppColors.accentRedAccent,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => ConfirmDeleteDialog(
        title: title,
        message: message,
        onConfirm: () {
          Navigator.pop(ctx);
          onConfirm();
        },
        confirmText: confirmText,
        confirmColor: confirmColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      content: Text(message, style: const TextStyle(color: Colors.white70)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: onConfirm,
          child: Text(confirmText, style: TextStyle(color: confirmColor)),
        ),
      ],
    );
  }
}
