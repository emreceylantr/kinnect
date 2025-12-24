// Kinnect - Etiketli Fotoğraf Gösterimi Widget'ı

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/main/profile_screen.dart';

class TaggablePostImage extends StatefulWidget {
  final String imageUrl;
  final String postId;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const TaggablePostImage({
    super.key,
    required this.imageUrl,
    required this.postId,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  State<TaggablePostImage> createState() => _TaggablePostImageState();
}

class _TaggablePostImageState extends State<TaggablePostImage> {
  final SupabaseClient client = Supabase.instance.client;
  final GlobalKey _imageKey = GlobalKey();

  List<Map<String, dynamic>> tags = [];
  bool showTags = false;
  bool loaded = false;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    try {
      final res = await client
          .from('post_tags')
          .select(
              '*, profiles:tagged_user_id(id, username, avatar_url, full_name)')
          .eq('post_id', widget.postId);

      if (mounted) {
        setState(() {
          tags = List<Map<String, dynamic>>.from(res);
          loaded = true;
        });
      }
    } catch (e) {
      debugPrint('Tag load error: $e');
      if (mounted) setState(() => loaded = true);
    }
  }

  void _toggleTags() {
    if (tags.isNotEmpty) {
      // Görüntü boyutunu al
      _updateImageSize();
      setState(() => showTags = !showTags);
    }
  }

  void _updateImageSize() {
    final RenderBox? renderBox =
        _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      _imageSize = renderBox.size;
    }
  }

  void _goToProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleTags,
      child: Stack(
        children: [
          // Fotoğraf
          ClipRRect(
            key: _imageKey,
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
            child: Image.network(
              widget.imageUrl,
              width: widget.width,
              height: widget.height,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  // Görüntü yüklendi, boyutunu güncelle
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_imageSize == null) _updateImageSize();
                  });
                  return child;
                }
                return Container(
                  width: widget.width ?? double.infinity,
                  height: widget.height ?? 200,
                  color: Colors.white.withOpacity(0.05),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: const Color(0xFF6C63FF),
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),

          // Etiket göstergesi (varsa)
          if (loaded && tags.isNotEmpty)
            Positioned(
              bottom: 10,
              left: 10,
              child: AnimatedOpacity(
                opacity: showTags ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${tags.length}',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Etiketler (gösterildiğinde)
          if (showTags && _imageSize != null)
            ...tags.map((tag) {
              final profile = tag['profiles'] ?? {};
              final x = (tag['x_position'] as num?)?.toDouble() ?? 0.5;
              final y = (tag['y_position'] as num?)?.toDouble() ?? 0.5;

              // Gerçek görüntü boyutuna göre pozisyon hesapla
              final left = (x * _imageSize!.width) - 40;
              final top = (y * _imageSize!.height) - 15;

              return Positioned(
                left: left.clamp(0, _imageSize!.width - 100),
                top: top.clamp(0, _imageSize!.height - 30),
                child: GestureDetector(
                  onTap: () => _goToProfile(profile['id']),
                  child: AnimatedOpacity(
                    opacity: showTags ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF6C63FF),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundImage: profile['avatar_url'] != null
                                ? NetworkImage(profile['avatar_url'])
                                : null,
                            backgroundColor: Colors.grey[800],
                            child: profile['avatar_url'] == null
                                ? const Icon(Icons.person,
                                    size: 12, color: Colors.white54)
                                : null,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '@${profile['username'] ?? 'user'}',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),

          // Etiketleri kapat butonu
          if (showTags && tags.isNotEmpty)
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: _toggleTags,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
