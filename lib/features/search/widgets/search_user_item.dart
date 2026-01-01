// Kinnect - Arama Sonucu Kullanıcı Kartı
// search_screen.dart'tan refactor edildi

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../co../../../core/theme/app_colors.dart';

/// Arama sonuçlarında gösterilen kullanıcı kartı
class SearchUserItem extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onTap;

  const SearchUserItem({
    super.key,
    required this.user,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user['avatar_url'];
    final fullName = user['full_name'] ?? 'İsimsiz';
    final username = user['username'] ?? '';
    final isAdmin = user['is_admin'] == true;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.bgBlack,
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? const Icon(Icons.person, color: Colors.white38)
                    : null,
              ),
            ),
            const SizedBox(width: 14),

            // İsim ve kullanıcı adı
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        fullName,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.verified,
                          color: AppColors.primary,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '@$username',
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Chevron
            Icon(
              Icons.chevron_right,
              color: Colors.white24,
            ),
          ],
        ),
      ),
    );
  }
}
