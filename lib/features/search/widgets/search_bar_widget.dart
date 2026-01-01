// Kinnect - Arama Çubuğu Widget'ı
// search_screen.dart'tan refactor edildi

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../co../../../core/theme/app_colors.dart';

/// Animasyonlu arama çubuğu
class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool isExpanded;
  final VoidCallback onTap;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.isExpanded,
    required this.onTap,
    required this.onChanged,
    this.focusNode,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      height: 50,
      decoration: BoxDecoration(
        color: isExpanded
            ? AppColors.bgCardLight.withOpacity(0.9)
            : AppColors.bgCardLight.withOpacity(0.6),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color:
              isExpanded ? AppColors.primary.withOpacity(0.3) : Colors.white10,
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: isExpanded
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
            color: isExpanded ? AppColors.primary : Colors.white38,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onTap: onTap,
              onChanged: onChanged,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Kullanıcı ara...',
                hintStyle: GoogleFonts.poppins(
                  color: Colors.white38,
                  fontSize: 15,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (controller.text.isNotEmpty && onClear != null) ...[
            GestureDetector(
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.close,
                  color: Colors.white54,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}
