import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SelectedMusicCard extends StatelessWidget {
  final Map<String, dynamic> music;
  final VoidCallback onRemove;

  const SelectedMusicCard({
    super.key,
    required this.music,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 15, left: 60, right: 20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFC3C44).withOpacity(0.15), // Apple Music Red
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFC3C44).withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            // Album art
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: music['album_image'] != null
                  ? Image.network(
                      music['album_image'],
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 44,
                      height: 44,
                      color: Colors.grey[800],
                      child:
                          const Icon(Icons.music_note, color: Colors.white54),
                    ),
            ),
            const SizedBox(width: 12),
            // Track info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    music['name'] ?? 'Şarkı',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    music['artist'] ?? 'Sanatçı',
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Kaldır butonu
            GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white54, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
