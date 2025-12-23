import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/photo_emoji.dart';
import '../services/photo_emoji_service.dart';

// ==========================================
// 📸 PHOTO EMOJI PICKER
// Post/Mesaj altında tepki seçmek için kullanılır
// ==========================================

// 🎨 RENK PALETİ
const Color _kPickerBg = Color(0xFF1A1A24);
const Color _kAccentPurple = Color(0xFF8B5CF6);

/// Photo Emoji Picker'ı bottom sheet olarak göster
/// Dönüş: {"path": String, "type": String} veya null
Future<Map<String, String>?> showPhotoEmojiPicker(BuildContext context) async {
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const PhotoEmojiPicker(),
  );
}

class PhotoEmojiPicker extends StatefulWidget {
  const PhotoEmojiPicker({super.key});

  @override
  State<PhotoEmojiPicker> createState() => _PhotoEmojiPickerState();
}

class _PhotoEmojiPickerState extends State<PhotoEmojiPicker> {
  final PhotoEmojiService _service = PhotoEmojiService();
  final ImagePicker _picker = ImagePicker();

  UserPhotoEmojis? _userEmojis;
  bool _isLoading = true;
  PhotoEmojiType? _capturingType;

  @override
  void initState() {
    super.initState();
    _loadEmojis();
  }

  Future<void> _loadEmojis() async {
    final emojis = await _service.getAllPhotoEmojis();
    if (mounted) {
      setState(() {
        _userEmojis = emojis;
        _isLoading = false;
      });
    }
  }

  Future<void> _captureAndSelect(PhotoEmojiType type) async {
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
            backgroundColor: _kPickerBg,
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
              'Tepki göndermek için kamera izni gerekli. Lütfen ayarlardan iznini aç.',
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
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 80,
        maxWidth: 500,
        maxHeight: 500,
      );

      if (photo != null && mounted) {
        // Fotoğrafı kaydet
        final success = await _service.savePhotoEmoji(type, photo.path);

        if (success) {
          // Listeyi yenile ve UI'ı güncelle
          await _loadEmojis();
          if (mounted) {
            setState(() {
              // _loadEmojis içinde setState olmayabilir, o yüzden burada garantiye al
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Fotoğraf çekim hatası: $e');
    } finally {
      if (mounted) setState(() => _capturingType = null);
    }
  }

  void _selectEmoji(String path, PhotoEmojiType type) {
    Navigator.pop(context, {'path': path, 'type': type.name});
  }

  // Kayıtlı emojiyi sil
  Future<void> _deleteEmoji(PhotoEmojiType type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kPickerBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${type.label} Emojisini Sil',
            style: const TextStyle(color: Colors.white)),
        content: Text(
          '${type.defaultEmoji} ${type.label} emojisini silmek istiyor musun? Yeni bir tane çekebilirsin.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.deletePhotoEmoji(type);
      await _loadEmojis();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${type.label} emojisi silindi'),
            backgroundColor: _kAccentPurple,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kPickerBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tepki Ver',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '📸 Kendi Yüzünle',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Emoji Listesi
          SizedBox(
            height: 120,
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _kAccentPurple))
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: PhotoEmojiType.values.length,
                    itemBuilder: (context, index) {
                      final type = PhotoEmojiType.values[index];
                      final path = _userEmojis?.getPath(type);
                      final isCapturing = _capturingType == type;

                      return _PickerEmojiItem(
                        type: type,
                        imagePath: path,
                        isCapturing: isCapturing,
                        onTap: () {
                          if (path != null) {
                            _selectEmoji(path, type);
                          } else {
                            _captureAndSelect(type);
                          }
                        },
                        onLongPress:
                            path != null ? () => _deleteEmoji(type) : null,
                      );
                    },
                  ),
          ),

          // Alt bilgi
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Text(
              'Eksik emojilere dokunarak hemen oluşturabilirsin',
              style:
                  TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),

          // Safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

// 🔲 PICKER İÇİN TEK EMOJİ ÖĞESİ
class _PickerEmojiItem extends StatelessWidget {
  final PhotoEmojiType type;
  final String? imagePath;
  final bool isCapturing;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _PickerEmojiItem({
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
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Fotoğraf / İkon
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 60,
                  height: 60,
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
                          : Colors.grey.withOpacity(0.4),
                      width: hasPhoto ? 3 : 2,
                    ),
                    boxShadow: hasPhoto
                        ? [
                            BoxShadow(
                                color: _kAccentPurple.withOpacity(0.4),
                                blurRadius: 8)
                          ]
                        : null,
                  ),
                  child: !hasPhoto
                      ? Center(
                          child: Text(
                            type.defaultEmoji,
                            style: TextStyle(
                              fontSize: 28,
                              color: Colors.white.withOpacity(0.4),
                            ),
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
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: _kAccentPurple,
                        shape: BoxShape.circle,
                        border: Border.all(color: _kPickerBg, width: 2),
                      ),
                      child:
                          const Icon(Icons.add, color: Colors.white, size: 10),
                    ),
                  ),
                // Yükleniyor animasyonu
                if (isCapturing)
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.5),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: _kAccentPurple,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // Label
            Text(
              type.label,
              style: TextStyle(
                color: hasPhoto ? Colors.white : Colors.white.withOpacity(0.4),
                fontSize: 10,
                fontWeight: hasPhoto ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
