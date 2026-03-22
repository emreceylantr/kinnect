// Kinnect - Search Header Widget
// Arama ekranının header kısmı - avatar seçici ve arama çubuğu

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/language/app_l10n.dart';
import '../../../../core/theme/app_colors.dart';

/// Arama header - avatar seçici ve animasyonlu arama çubuğu
class SearchHeader extends StatelessWidget {
  final String selectedAvatar;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final bool isSearchFocused;
  final VoidCallback onAvatarTap;
  final ValueChanged<String> onSearchChanged;

  const SearchHeader({
    super.key,
    required this.selectedAvatar,
    required this.searchController,
    required this.searchFocus,
    required this.isSearchFocused,
    required this.onAvatarTap,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.bgBlack.withOpacity(0.9),
            AppColors.bgBlack.withOpacity(0.0),
          ],
        ),
      ),
      child: Column(
        children: [
          // Üst satır: Başlık + Avatar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppL10n.explore,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: onAvatarTap,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.bgBlack,
                    child: Lottie.asset(
                      selectedAvatar,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Arama çubuğu
          _buildSearchBar(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      height: 50,
      decoration: BoxDecoration(
        color: isSearchFocused
            ? AppColors.bgCardLight.withOpacity(0.9)
            : AppColors.bgCardLight.withOpacity(0.6),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: isSearchFocused
              ? AppColors.primary.withOpacity(0.3)
              : Colors.white10,
          width: isSearchFocused ? 1.5 : 1,
        ),
        boxShadow: isSearchFocused
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(
            Icons.search,
            color: isSearchFocused ? AppColors.primary : Colors.white38,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: searchController,
              focusNode: searchFocus,
              onChanged: onSearchChanged,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: AppL10n.searchUsers,
                hintStyle:
                    GoogleFonts.poppins(color: Colors.white38, fontSize: 15),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (searchController.text.isNotEmpty) ...[
            GestureDetector(
              onTap: () {
                searchController.clear();
                onSearchChanged('');
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.close, color: Colors.white54, size: 16),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}
