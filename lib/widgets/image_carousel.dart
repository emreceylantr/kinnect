// Kinnect - Çoklu Fotoğraf Carousel Widget (with Tags & Music on Tap)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/main/profile_screen.dart';

class ImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final double height;
  final BorderRadius borderRadius;
  final void Function(String url)? onImageTap;
  final String? musicTrackName;
  final String? musicArtistName;
  final String? postId;

  const ImageCarousel({
    super.key,
    required this.imageUrls,
    this.height = 350,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.onImageTap,
    this.musicTrackName,
    this.musicArtistName,
    this.postId,
  });

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  int _currentIndex = 0;
  bool _showOverlay = false;
  List<Map<String, dynamic>> _tags = [];

  @override
  void initState() {
    super.initState();
    if (widget.postId != null) _loadTags();
  }

  Future<void> _loadTags() async {
    try {
      final res = await Supabase.instance.client
          .from('post_tags')
          .select(
              '*, profiles:tagged_user_id(id, username, avatar_url, full_name)')
          .eq('post_id', widget.postId!);
      if (mounted) {
        setState(() => _tags = List<Map<String, dynamic>>.from(res));
      }
    } catch (_) {}
  }

  void _toggleOverlay() {
    setState(() => _showOverlay = !_showOverlay);
  }

  void _goToProfile(String userId) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) return const SizedBox.shrink();

    if (widget.imageUrls.length == 1) {
      return _buildSingleImage();
    }

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: _toggleOverlay,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: widget.borderRadius,
                      child: Image.network(
                        widget.imageUrls[index],
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                    // Overlay sadece ilk foto + gösterildiğinde
                    if (index == 0 && _showOverlay) ...[
                      if (widget.musicTrackName != null) _buildMusicOverlay(),
                      ..._buildTagOverlays(),
                    ],
                    // Etiket/müzik varsa indicator göster (gizliyken)
                    if (index == 0 &&
                        !_showOverlay &&
                        (_tags.isNotEmpty || widget.musicTrackName != null))
                      _buildTapHint(),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.imageUrls.length,
              (index) => Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: index == _currentIndex
                      ? const Color(0xFF6C63FF)
                      : Colors.white.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleImage() {
    return GestureDetector(
      onTap: _toggleOverlay,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: widget.borderRadius,
            child: Image.network(
              widget.imageUrls.first,
              height: widget.height,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          if (_showOverlay) ...[
            if (widget.musicTrackName != null) _buildMusicOverlay(),
            ..._buildTagOverlays(),
          ],
          if (!_showOverlay &&
              (_tags.isNotEmpty || widget.musicTrackName != null))
            _buildTapHint(),
        ],
      ),
    );
  }

  // 🔔 Tıkla ipucu
  Widget _buildTapHint() {
    return Positioned(
      bottom: 10,
      left: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_tags.isNotEmpty) ...[
              const Icon(Icons.person, color: Colors.white70, size: 12),
              const SizedBox(width: 2),
              Text('${_tags.length}',
                  style:
                      GoogleFonts.poppins(color: Colors.white70, fontSize: 10)),
            ],
            if (_tags.isNotEmpty && widget.musicTrackName != null)
              const SizedBox(width: 6),
            if (widget.musicTrackName != null)
              const Icon(Icons.music_note, color: Color(0xFF6C63FF), size: 12),
          ],
        ),
      ),
    );
  }

  // 🎵 Müzik overlay
  Widget _buildMusicOverlay() {
    return Positioned(
      bottom: 12,
      right: 12,
      child: AnimatedOpacity(
        opacity: _showOverlay ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.music_note, color: Color(0xFF6C63FF), size: 14),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  widget.musicTrackName ?? '',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🏷️ Etiket overlay'leri
  List<Widget> _buildTagOverlays() {
    return _tags.map((tag) {
      final profile = tag['profiles'] ?? {};
      final x = (tag['x_position'] as num?)?.toDouble() ?? 0.5;
      final y = (tag['y_position'] as num?)?.toDouble() ?? 0.5;

      return Positioned(
        left: (x * 300) - 30,
        top: (y * widget.height) - 12,
        child: GestureDetector(
          onTap: () => _goToProfile(profile['id']),
          child: AnimatedOpacity(
            opacity: _showOverlay ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF6C63FF), width: 1),
              ),
              child: Text(
                '@${profile['username'] ?? ''}',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}
