// Kinnect - Konum Seçici Butonu
// create_post_screen.dart'tan refactor edildi

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

/// Konum ekleme/gösterme butonu
class LocationPickerButton extends StatelessWidget {
  final String? location;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const LocationPickerButton({
    super.key,
    this.location,
    this.isLoading = false,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: location != null
              ? AppColors.primary.withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: location != null
                ? AppColors.primary.withOpacity(0.3)
                : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading) ...[
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ] else ...[
              Icon(
                location != null
                    ? Icons.location_on
                    : Icons.location_on_outlined,
                color: location != null ? AppColors.primary : Colors.white54,
                size: 18,
              ),
            ],
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                location ?? 'Konum Ekle',
                style: GoogleFonts.poppins(
                  color: location != null ? AppColors.primary : Colors.white54,
                  fontSize: 13,
                  fontWeight:
                      location != null ? FontWeight.w500 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (location != null && onClear != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.close,
                  color: Colors.white38,
                  size: 16,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
