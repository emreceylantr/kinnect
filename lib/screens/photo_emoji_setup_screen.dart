import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/photo_emoji.dart';
import '../services/photo_emoji_service.dart';

// ==========================================
// 📸 PHOTO EMOJI SETUP SCREEN
// Kullanıcının emoji fotoğraflarını çektiği ekran
// ==========================================

// 🎨 RENK PALETİ
const Color _kBgColor = Color(0xFF0A0A0F);
const Color _kCardColor = Color(0xFF1A1A24);
const Color _kAccentPurple = Color(0xFF8B5CF6);
const Color _kAccentPink = Color(0xFFEC4899);

class PhotoEmojiSetupScreen extends StatefulWidget {
  const PhotoEmojiSetupScreen({super.key});

  @override
  State<PhotoEmojiSetupScreen> createState() => _PhotoEmojiSetupScreenState();
}

class _PhotoEmojiSetupScreenState extends State<PhotoEmojiSetupScreen> {
  final PhotoEmojiService _service = PhotoEmojiService();
  final ImagePicker _picker = ImagePicker();

  UserPhotoEmojis? _userEmojis;
  bool _isLoading = true;
  PhotoEmojiType? _capturingType; // Şu an çekim yapılan tip

  @override
  void initState() {
    super.initState();
    _loadEmojis();
  }

  Future<void> _loadEmojis() async {
    setState(() => _isLoading = true);
    final emojis = await _service.getAllPhotoEmojis();
    if (mounted) {
      setState(() {
        _userEmojis = emojis;
        _isLoading = false;
      });
    }
  }

  Future<void> _capturePhoto(PhotoEmojiType type) async {
    // Kamera izni kontrol et
    var status = await Permission.camera.status;

    if (status.isDenied) {
      status = await Permission.camera.request();
    }

    if (status.isPermanentlyDenied) {
      // Kalıcı olarak reddedilmiş - ayarlara yönlendir
      if (mounted) {
        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _kCardColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.camera_alt, color: _kAccentPurple),
                SizedBox(width: 12),
                Text('Kamera İzni', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: const Text(
              'Fotoğraf çekmek için kamera izni gerekli. Lütfen ayarlardan kamera iznini açın.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('İptal',
                    style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccentPurple,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Ayarları Aç'),
              ),
            ],
          ),
        );

        if (shouldOpenSettings == true) {
          await openAppSettings();
        }
      }
      return;
    }

    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kamera izni gerekli!'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    setState(() => _capturingType = type);

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front, // Ön kamera
        imageQuality: 80,
        maxWidth: 500,
        maxHeight: 500,
      );

      if (photo != null && mounted) {
        // Onay ekranı göster
        final confirmed = await _showConfirmationDialog(photo.path, type);

        if (confirmed == true) {
          final success = await _service.savePhotoEmoji(type, photo.path);
          if (success) {
            await _loadEmojis(); // Listeyi yenile
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${type.label} emojisi kaydedildi! 🎉'),
                  backgroundColor: _kAccentPurple,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Fotoğraf çekim hatası: $e');
    } finally {
      if (mounted) setState(() => _capturingType = null);
    }
  }

  Future<bool?> _showConfirmationDialog(String imagePath, PhotoEmojiType type) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _kCardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text(type.defaultEmoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Text(
              type.label,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: Image.file(
                File(imagePath),
                width: 150,
                height: 150,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Bu fotoğrafı kullanmak istiyor musun?',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tekrar Çek',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccentPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEmoji(PhotoEmojiType type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _kCardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Emoji Sil', style: TextStyle(color: Colors.white)),
        content: Text(
          '${type.label} emojisini silmek istediğine emin misin?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.deletePhotoEmoji(type);
      await _loadEmojis();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Emoji Oluştur',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _kAccentPurple))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _kAccentPurple.withOpacity(0.2),
                          _kAccentPink.withOpacity(0.2)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: _kAccentPurple.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _kAccentPurple.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child:
                              const Text('📸', style: TextStyle(fontSize: 28)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Kendi Emojilerini Oluştur',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_userEmojis?.filledCount ?? 0}/${_userEmojis?.totalCount ?? 6} tamamlandı',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.7)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Açıklama
                  Text(
                    'Her yuvaya dokun ve o duygu için yüz ifadeni çek:',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.6), fontSize: 14),
                  ),
                  const SizedBox(height: 20),

                  // Emoji Grid
                  Expanded(
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: PhotoEmojiType.values.length,
                      itemBuilder: (context, index) {
                        final type = PhotoEmojiType.values[index];
                        final path = _userEmojis?.getPath(type);
                        final isCapturing = _capturingType == type;

                        return _EmojiSlot(
                          type: type,
                          imagePath: path,
                          isCapturing: isCapturing,
                          onTap: () => _capturePhoto(type),
                          onLongPress:
                              path != null ? () => _deleteEmoji(type) : null,
                        );
                      },
                    ),
                  ),

                  // Alt bilgi
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _kCardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.white.withOpacity(0.5), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'İpucu: Silmek için bir emojiye uzun bas',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// 🔲 TEK EMOJİ YUVASI
class _EmojiSlot extends StatelessWidget {
  final PhotoEmojiType type;
  final String? imagePath;
  final bool isCapturing;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _EmojiSlot({
    required this.type,
    required this.imagePath,
    required this.isCapturing,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasPhoto = imagePath != null;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _kCardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasPhoto
                ? _kAccentPurple.withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
            width: hasPhoto ? 2 : 1,
          ),
          boxShadow: hasPhoto
              ? [
                  BoxShadow(
                      color: _kAccentPurple.withOpacity(0.2), blurRadius: 12)
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Fotoğraf / İkon
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasPhoto ? null : Colors.grey.withOpacity(0.2),
                    image: hasPhoto
                        ? DecorationImage(
                            image: FileImage(File(imagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                    border: Border.all(
                      color: hasPhoto
                          ? _kAccentPurple
                          : Colors.grey.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: !hasPhoto
                      ? Center(
                          child: Text(
                            type.defaultEmoji,
                            style: const TextStyle(fontSize: 32),
                          ),
                        )
                      : null,
                ),
                // + İşareti (boş yuva için)
                if (!hasPhoto)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _kAccentPurple,
                        shape: BoxShape.circle,
                        border: Border.all(color: _kCardColor, width: 2),
                      ),
                      child:
                          const Icon(Icons.add, color: Colors.white, size: 14),
                    ),
                  ),
                // Yükleniyor animasyonu
                if (isCapturing)
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.5),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: _kAccentPurple,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Label
            Text(
              type.label,
              style: TextStyle(
                color: hasPhoto ? Colors.white : Colors.white.withOpacity(0.5),
                fontSize: 12,
                fontWeight: hasPhoto ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
