// EditPostScreen - Gelişmiş Post Düzenleme
// Kinnect

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/language/app_l10n.dart';
import '../../../shared/widgets/location_picker_sheet.dart';
import '../../../data/services/feed_service.dart';
import 'music_picker_screen.dart';
import 'photo_tag_screen.dart'; // 🆕 Etiketleme Ekranı

class EditPostScreen extends StatefulWidget {
  final Map<String, dynamic> post;

  const EditPostScreen({super.key, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final TextEditingController _textController = TextEditingController();
  final FeedService _feedService = FeedService();

  // State Variables
  bool _isLoading = false;
  List<String> _imageUrls = [];
  int _currentImageIndex = 0;

  // Müzik verisi
  Map<String, dynamic>? _selectedMusic;

  // 📍 Konum verisi
  String? _location;
  bool _isGettingLocation = false;

  // Etiketler (Post Tags)
  List<Map<String, dynamic>> _tags = [];
  bool _tagsLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    // 1. İçerik
    _textController.text = widget.post['content'] ?? '';

    // 2. Görseller
    final imgs = widget.post['image_urls'];
    if (imgs != null && (imgs as List).isNotEmpty) {
      _imageUrls = List<String>.from(imgs);
    } else if (widget.post['image_url'] != null) {
      _imageUrls = [widget.post['image_url']];
    }

    // 3. Müzik
    if (widget.post['spotify_track_id'] != null) {
      _selectedMusic = {
        'id': widget.post['spotify_track_id'],
        'name': widget.post['spotify_track_name'],
        'artist': widget.post['spotify_artist_name'],
        'preview_url': widget.post['spotify_preview_url'],
        'album_image': widget.post['spotify_album_image'],
      };
    }

    // 📍 4. Konum
    _location = widget.post['location'];

    // 5. Etiketleri Çek
    _fetchTags();
  }

  Future<void> _fetchTags() async {
    try {
      final tags = await _feedService.getPostTags(widget.post['id']);
      if (mounted) {
        setState(() {
          _tags = tags;
          _tagsLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Etiket hatası: $e");
      if (mounted) setState(() => _tagsLoading = false);
    }
  }

  // --- Görsel Kaldırma ---
  void _removeImage(int index) {
    setState(() {
      _imageUrls.removeAt(index);
      if (_currentImageIndex >= _imageUrls.length && _imageUrls.isNotEmpty) {
        _currentImageIndex = _imageUrls.length - 1;
      }
    });
  }

  // --- Etiket Kaldırma ---
  void _removeTag(int index) {
    setState(() {
      _tags.removeAt(index);
    });
  }

  // --- Kaydetme ---
  Future<void> _saveChanges() async {
    if (_imageUrls.isEmpty && _textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.mediaRequired)),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _feedService.updatePostAdvanced(
        postId: widget.post['id'],
        content: _textController.text.trim(),
        imageUrls: _imageUrls,
        musicData: _selectedMusic,
        tags: _tags,
        location: _location,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppL10n.editsSaved),
            backgroundColor: Color(0xFF6C63FF),
          ),
        );
        Navigator.pop(context, true); // true: sayfayı yenile
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Location logic simplified via LocationService and shared widgets

  // 📍 KONUM SEÇİCİ
  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => LocationPickerSheet(
        onLocationSelected: (loc) => setState(() => _location = loc),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: const BackButton(color: Colors.white),
        title: Text(AppL10n.edit,
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (_isLoading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                        color: Color(0xFF6C63FF), strokeWidth: 2)))
          else
            TextButton(
              onPressed: _saveChanges,
              child: Text(
                "Kaydet",
                style: GoogleFonts.poppins(
                    color: const Color(0xFF6C63FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Metin Alanı
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _textController,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
                maxLines: null,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: AppL10n.writeHint,
                  hintStyle: GoogleFonts.poppins(color: Colors.white38),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 2. Görsel Alanı (Görsel varsa)
            if (_imageUrls.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppL10n.imagesCount(_imageUrls.length),
                      style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 300,
                    child: PageView.builder(
                      itemCount: _imageUrls.length,
                      onPageChanged: (i) =>
                          setState(() => _currentImageIndex = i),
                      itemBuilder: (_, index) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            // Görsel
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(_imageUrls[index],
                                  fit: BoxFit.cover),
                            ),

                            // Silme Butonu
                            Positioned(
                              top: 10,
                              right: 10,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: const Icon(Icons.delete_outline,
                                      color: Colors.redAccent, size: 20),
                                ),
                              ),
                            ),

                            // Sayfa Sayısı
                            if (_imageUrls.length > 1)
                              Positioned(
                                top: 10,
                                left: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${index + 1}/${_imageUrls.length}',
                                    style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),

                            // 🆕 Etiketleme Butonu / İpucu
                            Positioned(
                              bottom: 10,
                              right: 10,
                              child: GestureDetector(
                                onTap: () async {
                                  // Etiketleri fototag ekranının beklediği formata çevir
                                  final convertedTags = _tags.map((t) {
                                    // DB'den gelen format: profiles: {...}, x_position, y_position
                                    // Beklenen format: user: {...}, x, y
                                    return {
                                      'user': t['profiles'] ?? {},
                                      'x': t['x_position'] ?? 0.5,
                                      'y': t['y_position'] ?? 0.5,
                                    };
                                  }).toList();

                                  // Etiketleme ekranına git
                                  final newTags = await Navigator.push<
                                      List<Map<String, dynamic>>>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PhotoTagScreen(
                                        imageUrl: _imageUrls[index],
                                        initialTags: convertedTags,
                                      ),
                                    ),
                                  );

                                  if (newTags != null) {
                                    // Geri dönenleri DB formatına çevir (Kaydetme için)
                                    // Yeni eklenenlerin id'si olmayacak, kaydederken halledeceğiz
                                    setState(() {
                                      _tags = newTags.map((t) {
                                        return {
                                          'profiles': t['user'],
                                          'tagged_user_id': t['user']['id'],
                                          'x_position': t['x'],
                                          'y_position': t['y'],
                                        };
                                      }).toList();
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person_add,
                                          color: Colors.white, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Etiketle",
                                        style: GoogleFonts.poppins(
                                            color: Colors.white, fontSize: 12),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_imageUrls.length > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                          _imageUrls.length,
                          (i) => Container(
                                width: 6,
                                height: 6,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: i == _currentImageIndex
                                      ? const Color(0xFF6C63FF)
                                      : Colors.white24,
                                  shape: BoxShape.circle,
                                ),
                              )),
                    ),
                ],
              ),

            const SizedBox(height: 24),

            // 3. Müzik Yönetimi
            Text(AppL10n.music,
                style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final music = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(builder: (_) => const MusicPickerScreen()),
                );
                if (music != null) setState(() => _selectedMusic = music);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _selectedMusic != null
                      ? const Color(0xFFFC3C44).withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedMusic != null
                        ? const Color(0xFFFC3C44).withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    // Icon / Album Art
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _selectedMusic != null &&
                              _selectedMusic!['album_image'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                  _selectedMusic!['album_image'],
                                  fit: BoxFit.cover),
                            )
                          : const Icon(Icons.music_note, color: Colors.white54),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedMusic != null
                                ? _selectedMusic!['name']
                                : AppL10n.addMusicOptional,
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _selectedMusic != null
                                ? _selectedMusic!['artist']
                                : AppL10n.tapToSelect,
                            style: GoogleFonts.poppins(
                                color: Colors.white54, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Silme veya Ekleme ikonu
                    if (_selectedMusic != null)
                      GestureDetector(
                        onTap: () => setState(() => _selectedMusic = null),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white70, size: 16),
                        ),
                      )
                    else
                      const Icon(Icons.add_circle_outline,
                          color: Colors.white54),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 📍 4. Konum Yönetimi
            Text("Konum",
                style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _showLocationPicker,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _location != null
                      ? Colors.orangeAccent.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _location != null
                        ? Colors.orangeAccent.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _isGettingLocation
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.orangeAccent))
                          : Icon(Icons.location_on,
                              color: _location != null
                                  ? Colors.orangeAccent
                                  : Colors.white54,
                              size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _location ?? "Konum Ekle",
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                    ),
                    if (_location != null)
                      GestureDetector(
                        onTap: () => setState(() => _location = null),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white70, size: 16),
                        ),
                      )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 5. Etiket Yönetimi
            if (!_tagsLoading && _tags.isNotEmpty) ...[
              Text(AppL10n.taggedCount(_tags.length),
                  style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _tags.length,
                itemBuilder: (_, i) {
                  final t = _tags[i];
                  final profile = t['profiles'] ?? {};

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundImage: profile['avatar_url'] != null
                              ? NetworkImage(profile['avatar_url'])
                              : null,
                          backgroundColor: Colors.grey[800],
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(profile['username'] ?? 'Kullanıcı',
                                style: GoogleFonts.poppins(
                                    color: Colors.white, fontSize: 13))),
                        GestureDetector(
                          onTap: () => _removeTag(i),
                          child: const Icon(Icons.delete_outline,
                              color: Colors.redAccent, size: 20),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ]
          ],
        ),
      ),
    );
  }
}
