// Kinnect - Profil Aksiyon Butonları
// profile_screen.dart'tan refactor edildi

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../co../../../core/theme/app_colors.dart';

/// Profil sayfasındaki takip/mesaj butonları
class ProfileActionButtons extends StatelessWidget {
  final bool isMyProfile;
  final bool isFollowing;
  final bool isRequestPending;
  final bool isBlocked;
  final VoidCallback onEditProfile;
  final VoidCallback onFollowAction;
  final VoidCallback onMessage;

  const ProfileActionButtons({
    super.key,
    required this.isMyProfile,
    required this.isFollowing,
    required this.isRequestPending,
    required this.isBlocked,
    required this.onEditProfile,
    required this.onFollowAction,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (isMyProfile) {
      return _buildEditButton();
    }
    return _buildOtherProfileButtons();
  }

  Widget _buildEditButton() {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton(
        onPressed: onEditProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.bgCardLight,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          side: const BorderSide(color: Colors.white12),
        ),
        child: Text(
          'Profili Düzenle',
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildOtherProfileButtons() {
    String label = 'Takip Et';
    Color bgColor = AppColors.primary;
    Color textColor = Colors.white;

    if (isBlocked) {
      label = 'Engellendi';
      bgColor = Colors.grey;
    } else if (isFollowing) {
      label = 'Takip Ediliyor';
      bgColor = AppColors.bgCardLight;
    } else if (isRequestPending) {
      label = 'İstek Gönderildi';
      bgColor = AppColors.bgCardLight;
    }

    return Row(
      children: [
        // Takip butonu
        Expanded(
          child: SizedBox(
            height: 45,
            child: ElevatedButton(
              onPressed: isBlocked ? null : onFollowAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: bgColor,
                foregroundColor: textColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                side: BorderSide(
                  color: isFollowing || isRequestPending
                      ? Colors.white12
                      : Colors.transparent,
                ),
              ),
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Mesaj butonu
        SizedBox(
          height: 45,
          width: 45,
          child: ElevatedButton(
            onPressed: onMessage,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.bgCardLight,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              side: const BorderSide(color: Colors.white12),
              padding: EdgeInsets.zero,
            ),
            child: const Icon(Icons.mail_outline, size: 20),
          ),
        ),
      ],
    );
  }
}
