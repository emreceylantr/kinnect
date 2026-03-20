// Kinnect - Yeni gönderi oluşturma

import 'dart:io';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_compress/video_compress.dart';
import '../../../shared/widgets/location_picker_sheet.dart';

import 'photo_tag_screen.dart';
import 'photo_editor_screen.dart';
import 'music_picker_screen.dart';
import '../widgets/image_preview_gallery.dart';
import '../widgets/selected_music_card.dart';
import '../widgets/create_post_bottom_bar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/feed_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final String _currentUserId =
      Supabase.instance.client.auth.currentUser?.id ?? '';

  List<File> _imageFiles = [];
  int _currentImageIndex = 0;
  bool _isLoading = false;
  String _visibility = 'public';
  String? _avatarUrl;
  String _currentHint = "";

  // 🆕 Fotoğrafa etiketlenen kişiler
  List<Map<String, dynamic>> _photoTags = [];

  // 🎧 Müzik bilgileri
  Map<String, dynamic>? _selectedMusic;

  // 📍 Konum bilgisi
  String? _location;
  bool _isGettingLocation = false;

  // 🎥 Video bilgisi
  File? _videoFile;
  VideoPlayerController? _videoController;
  bool _isVideoCompressing = false;

  double _hintOpacity = 0.0;

  late AnimationController _auroraController;

  // 🔥 ORTALANACAK KISA SÖZLER
  final Set<String> _centeredHints = {
    "Neler düşünüyorsun?",
    "Bugün nasılsın?",
    "Aklında ne var?",
    "Nasıl hissediyorsun?",
    "Günün nasıl geçti?",
    "Ne paylaşsam acaba…",
    "Kendime bir not bırakıyorum.",
    "Dur bak şimdi bir şey paylaşacağım…",
    "Takipçilerine bir mesajın var mı?",
    "İlham verici bir şeyler yaz...",
    "Paylaşmak istediğin bir şey mi var?",
  };

  // 🔥 TÜM LİSTE
  final List<String> _hintList = [
    "Neler düşünüyorsun?",
    "Bugün nasılsın?",
    "Aklında ne var?",
    "Nasıl hissediyorsun?",
    "Günün nasıl geçti?",
    "Ne paylaşsam acaba…",
    "Kendime bir not bırakıyorum.",
    "Dur bak şimdi bir şey paylaşacağım…",
    "Takipçilerine bir mesajın var mı?",
    "İlham verici bir şeyler yaz...",
    "Paylaşmak istediğin bir şey mi var?",
    "Bir şey yazacaktım… unuttum. Neyse yazıyorum.",
    "Düşündüğüm bazı şeyleri paylaşmam gerekiyor sanki.",
    "Buraya düşüncelerimden bir parça bırakıyorum.",
    "Bugün biraz fazla iyi görünüyorum, paylaşayım dedim 👀",
    "Şimdi öyle bir şey paylaşacağım ki… biri üstüne alınacak.",
    "Post seçmek bu kadar zorsa, kod yazmayı düşünemiyorum bile… kahve getiriyorum.",
    "Developerlarımız kadar yorulmadım ama post seçerken bile enerji tükendi, kahve şart."
  ];

  @override
  void initState() {
    super.initState();
    _fetchMyAvatar();
    _setRandomHint();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _hintOpacity = 1.0;
        });
      }
    });

    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  void _setRandomHint() {
    setState(() {
      _currentHint = _hintList[Random().nextInt(_hintList.length)];
    });
  }

  Future<void> _fetchMyAvatar() async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('avatar_url')
          .eq('id', _currentUserId)
          .single();
      if (mounted) {
        setState(() {
          _avatarUrl = data['avatar_url'];
        });
      }
    } catch (_) {}
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();

    if (source == ImageSource.gallery) {
      final List<XFile> images = await picker.pickMultiImage(imageQuality: 90);
      if (images.isNotEmpty && mounted) {
        List<File> editedFiles = [];

        // 📸 Her fotoğrafı düzenleme ekranından geçir
        for (final img in images) {
          final originalFile = File(img.path);

          // Fotoğraf düzenleme ekranına git
          final editedFile = await Navigator.push<File>(
            context,
            MaterialPageRoute(
              builder: (_) => PhotoEditorScreen(imageFile: originalFile),
            ),
          );

          if (editedFile != null) {
            editedFiles.add(editedFile);
          } else {
            // Kullanıcı iptal ettiyse orijinal dosyayı kullan
            editedFiles.add(originalFile);
          }

          if (!mounted) return;
        }

        // İlk fotoğraf için etiketleme ekranına git
        if (_imageFiles.isEmpty && editedFiles.isNotEmpty) {
          final tags = await Navigator.push<List<Map<String, dynamic>>>(
            context,
            MaterialPageRoute(
              builder: (_) => PhotoTagScreen(imageFile: editedFiles.first),
            ),
          );
          if (mounted) {
            setState(() {
              _imageFiles = [..._imageFiles, ...editedFiles].take(10).toList();
              _photoTags = tags ?? [];
            });
          }
        } else {
          setState(() {
            _imageFiles = [..._imageFiles, ...editedFiles].take(10).toList();
          });
        }
      }
    } else {
      final XFile? image =
          await picker.pickImage(source: source, imageQuality: 90);
      if (image != null && mounted) {
        final originalFile = File(image.path);

        // 📸 Fotoğraf düzenleme ekranına git
        final editedFile = await Navigator.push<File>(
          context,
          MaterialPageRoute(
            builder: (_) => PhotoEditorScreen(imageFile: originalFile),
          ),
        );

        final fileToUse = editedFile ?? originalFile;

        if (!mounted) return;

        if (_imageFiles.isEmpty) {
          final tags = await Navigator.push<List<Map<String, dynamic>>>(
            context,
            MaterialPageRoute(
              builder: (_) => PhotoTagScreen(imageFile: fileToUse),
            ),
          );
          if (mounted) {
            setState(() {
              _imageFiles.add(fileToUse);
              _photoTags = tags ?? [];
            });
          }
        } else if (_imageFiles.length < 10) {
          setState(() => _imageFiles.add(fileToUse));
        }
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imageFiles.removeAt(index);
      if (_currentImageIndex >= _imageFiles.length && _imageFiles.isNotEmpty) {
        _currentImageIndex = _imageFiles.length - 1;
      }
    });
  }

  Future<void> _pickVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 7),
    );
    if (video == null || !mounted) return;

    setState(() => _isVideoCompressing = true);
    try {
      // Validate duration
      final info = await VideoCompress.getMediaInfo(video.path);
      final durationMs = info.duration ?? 0;
      if (durationMs > 7500) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video en fazla 7 saniye olabilir. iOS trim arayüzünü kullanın.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      final file = File(video.path);
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      controller.setLooping(true);

      if (mounted) {
        setState(() {
          _videoFile = file;
          _videoController?.dispose();
          _videoController = controller;
          // Clear images when video selected
          _imageFiles = [];
        });
      }
    } finally {
      if (mounted) setState(() => _isVideoCompressing = false);
    }
  }

  void _removeVideo() {
    _videoController?.dispose();
    setState(() {
      _videoFile = null;
      _videoController = null;
    });
  }

  Future<void> _sharePost() async {
    if (_isLoading) return;
    final content = _textController.text.trim();
    if (content.isEmpty && _imageFiles.isEmpty && _videoFile == null) return;

    setState(() => _isLoading = true);

    try {
      await FeedService().createPost(
        content: content,
        imageFiles: _imageFiles,
        visibility: _visibility,
        selectedMusic: _selectedMusic,
        location: _location,
        photoTags: _photoTags,
        videoFile: _videoFile,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Gönderildi! 🚀"),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Hata: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // UI Helpers moved to sub-widgets

  // 🎥 VİDEO ÖNİZLEME
  Widget _buildVideoPreview() {
    if (_videoFile == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_videoController != null && _videoController!.value.isInitialized)
              AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
            // Play/Pause button
            GestureDetector(
              onTap: () {
                setState(() {
                  _videoController!.value.isPlaying
                      ? _videoController!.pause()
                      : _videoController!.play();
                });
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _videoController?.value.isPlaying == true
                      ? Icons.pause
                      : Icons.play_arrow,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            // Remove button
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: _removeVideo,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
            // Duration badge
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(_videoController?.value.duration.inSeconds ?? 0)}s',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
            // Compressing overlay
            if (_isVideoCompressing)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

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

  // ✍️ ELLE KONUM GİRİŞİ

  // Manual location dialog moved to LocationPickerSheet

  @override
  void dispose() {
    _textController.dispose();
    _auroraController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 DÜZELTME: Yazı boyutu 16'ya çekildi (Daha dengeli)
    final TextStyle commonTextStyle =
        GoogleFonts.poppins(color: Colors.white, fontSize: 16, height: 1.5);

    // 🔥 HİZALAMA MATEMATİĞİ:
    // Avatar (Radius 22) => Height 44px
    // Yazı (Font 16 * 1.5) => Height 24px
    // Fark = 20px. Ortalamak için üstten 10px boşluk gerekir.
    final double topPadding =
        _centeredHints.contains(_currentHint) ? 10.0 : 0.0;

    final bool showAurora = _textController.text.isEmpty && _imageFiles.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      body: Stack(
        children: [
          // 1. AURORA
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: showAurora ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 2000),
              curve: Curves.easeInOut,
              child: AnimatedBuilder(
                animation: _auroraController,
                builder: (context, child) {
                  final double t = _auroraController.value;
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1.0 + t * 0.5, -1.0),
                        end: Alignment(1.0 - t * 0.5, 1.0),
                        colors: [
                          Color.lerp(
                              AppColors.bgBlack, const Color(0xFF004D40), t)!,
                          Color.lerp(const Color(0xFF1A237E),
                              const Color(0xFF311B92), t)!,
                          Color.lerp(
                              AppColors.bgBlack, const Color(0xFF4A148C), t)!,
                        ],
                        stops: [0.0 + t * 0.2, 0.5, 1.0 - t * 0.2],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 2. İÇERİK
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 70), // Üst bar boşluğu

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PostInputArea(
                          avatarUrl: _avatarUrl,
                          controller: _textController,
                          hintText: _currentHint,
                          hintOpacity: _hintOpacity,
                          topPadding: topPadding,
                          commonTextStyle: commonTextStyle,
                          onChanged: () => setState(() {}),
                        ),
                        ImagePreviewGallery(
                          images: _imageFiles,
                          onRemove: _removeImage,
                        ),
                        _buildVideoPreview(),
                        // 🎧 Seçilen Müzik Gösterimi
                        if (_selectedMusic != null)
                          SelectedMusicCard(
                            music: _selectedMusic!,
                            onRemove: () =>
                                setState(() => _selectedMusic = null),
                          ),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. ÜST BAR (FLOATING)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: PostHeaderBar(
                onClose: () => Navigator.pop(context),
                visibility: _visibility,
                onVisibilityChanged: (val) => setState(() => _visibility = val),
              ),
            ),
          ),

          // 4. ALT BAR (PAYLAŞ VE MEDYA)
          CreatePostBottomBar(
            onPickFromGallery: () => _pickImage(ImageSource.gallery),
            onPickFromCamera: () => _pickImage(ImageSource.camera),
            onPickVideo: _pickVideo,
            onPickMusic: () async {
              final music = await Navigator.push<Map<String, dynamic>>(
                context,
                MaterialPageRoute(builder: (_) => const MusicPickerScreen()),
              );
              if (music != null) {
                setState(() => _selectedMusic = music);
              }
            },
            onPickLocation: _showLocationPicker,
            onShare: _sharePost,
            isGettingLocation: _isGettingLocation,
            isSharing: _isLoading,
          ),
        ],
      ),
    );
  }
}

class AuroraBackground extends StatelessWidget {
  final bool showAurora;
  final AnimationController controller;

  const AuroraBackground({
    super.key,
    required this.showAurora,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: showAurora ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 2000),
      curve: Curves.easeInOut,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final double t = controller.value;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1.0 + t * 0.5, -1.0),
                end: Alignment(1.0 - t * 0.5, 1.0),
                colors: [
                  Color.lerp(AppColors.bgBlack, const Color(0xFF004D40), t)!,
                  Color.lerp(
                      const Color(0xFF1A237E), const Color(0xFF311B92), t)!,
                  Color.lerp(AppColors.bgBlack, const Color(0xFF4A148C), t)!,
                ],
                stops: [0.0 + t * 0.2, 0.5, 1.0 - t * 0.2],
              ),
            ),
          );
        },
      ),
    );
  }
}

class PostHeaderBar extends StatelessWidget {
  final VoidCallback onClose;
  final String visibility;
  final Function(String) onVisibilityChanged;

  const PostHeaderBar({
    super.key,
    required this.onClose,
    required this.visibility,
    required this.onVisibilityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: onClose,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                height: 40,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  children: [
                    _VisibilityOption(
                      value: 'public',
                      label: 'Herkes',
                      selectedVisibility: visibility,
                      onChanged: onVisibilityChanged,
                    ),
                    const SizedBox(width: 4),
                    _VisibilityOption(
                      value: 'friends',
                      label: 'Arkadaşlar',
                      selectedVisibility: visibility,
                      onChanged: onVisibilityChanged,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisibilityOption extends StatelessWidget {
  final String value;
  final String label;
  final String selectedVisibility;
  final Function(String) onChanged;

  const _VisibilityOption({
    required this.value,
    required this.label,
    required this.selectedVisibility,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedVisibility == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.white : Colors.grey[400],
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class PostInputArea extends StatelessWidget {
  final String? avatarUrl;
  final TextEditingController controller;
  final String hintText;
  final double hintOpacity;
  final double topPadding;
  final TextStyle commonTextStyle;
  final VoidCallback onChanged;

  const PostInputArea({
    super.key,
    required this.avatarUrl,
    required this.controller,
    required this.hintText,
    required this.hintOpacity,
    required this.topPadding,
    required this.commonTextStyle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final TextStyle hintStyle = commonTextStyle.copyWith(color: Colors.white54);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.bgCard,
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
          child: avatarUrl == null
              ? const Icon(Icons.person, color: Colors.white54)
              : null,
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: topPadding),
            child: Stack(
              alignment: Alignment.topLeft,
              children: [
                AnimatedOpacity(
                  opacity: controller.text.isEmpty ? hintOpacity : 0.0,
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOut,
                  child: Text(
                    hintText,
                    style: hintStyle,
                    maxLines: null,
                  ),
                ),
                TextField(
                  controller: controller,
                  style: commonTextStyle,
                  maxLines: null,
                  cursorColor: AppColors.primary,
                  onChanged: (val) => onChanged(),
                  decoration: const InputDecoration(
                    hintText: null,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
