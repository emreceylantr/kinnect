import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image/image.dart' as img;
import '../models/photo_emoji.dart';

// ==========================================
// 📸 PHOTO EMOJI SERVICE
// Fotoğraf emojilerini yerel depolamada yönetir
// ==========================================

class PhotoEmojiService {
  static final PhotoEmojiService _instance = PhotoEmojiService._internal();
  factory PhotoEmojiService() => _instance;
  PhotoEmojiService._internal();

  // Cache: Memory'de tutarak performansı artır
  UserPhotoEmojis? _cachedEmojis;

  /// Mevcut kullanıcının ID'si
  String get _userId =>
      Supabase.instance.client.auth.currentUser?.id ?? 'guest';

  /// Fotoğraf emojilerinin saklandığı klasör yolu
  Future<Directory> get _emojiDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final emojiDir = Directory('${appDir.path}/photo_emojis/$_userId');
    if (!await emojiDir.exists()) {
      await emojiDir.create(recursive: true);
    }
    return emojiDir;
  }

  /// Tek bir emoji için dosya yolu
  Future<String> _getEmojiFilePath(PhotoEmojiType type) async {
    final dir = await _emojiDirectory;
    return '${dir.path}/${type.name}.jpg';
  }

  /// Selfie fotoğrafını yatay olarak çevir (ön kamera mirror düzeltmesi)
  Future<File> _flipImageHorizontally(String imagePath) async {
    final file = File(imagePath);
    final bytes = await file.readAsBytes();

    // Image paketi ile decode et
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return file;

    // Yatay olarak çevir
    final flipped = img.flipHorizontal(image);

    // Yeni dosyaya kaydet
    final dir = await _emojiDirectory;
    final flippedPath =
        '${dir.path}/temp_flipped_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final flippedFile = File(flippedPath);
    await flippedFile.writeAsBytes(img.encodeJpg(flipped, quality: 85));

    return flippedFile;
  }

  /// Tüm fotoğraf emojileri yükle
  Future<UserPhotoEmojis> getAllPhotoEmojis() async {
    // Cache varsa döndür
    if (_cachedEmojis != null && _cachedEmojis!.userId == _userId) {
      return _cachedEmojis!;
    }

    final prefs = await SharedPreferences.getInstance();
    final Map<PhotoEmojiType, String?> emojiPaths = {};

    for (final type in PhotoEmojiType.values) {
      final key = '${_userId}_${type.storageKey}';
      final path = prefs.getString(key);

      // Dosya hala var mı kontrol et
      if (path != null && await File(path).exists()) {
        emojiPaths[type] = path;
      } else {
        emojiPaths[type] = null;
        // Eğer kayıt varsa ama dosya yoksa, kaydı temizle
        if (path != null) {
          await prefs.remove(key);
        }
      }
    }

    _cachedEmojis = UserPhotoEmojis(userId: _userId, emojiPaths: emojiPaths);
    return _cachedEmojis!;
  }

  /// Belirli bir emoji tipi için fotoğraf yolu getir
  Future<String?> getPhotoEmoji(PhotoEmojiType type) async {
    final emojis = await getAllPhotoEmojis();
    return emojis.getPath(type);
  }

  /// Fotoğraf emojiyi kaydet (ön kamera selfie'leri için flip uygular)
  Future<bool> savePhotoEmoji(PhotoEmojiType type, String sourceImagePath,
      {bool flipHorizontally = true}) async {
    try {
      final targetPath = await _getEmojiFilePath(type);
      File sourceFile = File(sourceImagePath);

      // Kaynak dosya var mı kontrol et
      if (!await sourceFile.exists()) {
        debugPrint('❌ PhotoEmoji: Kaynak dosya bulunamadı: $sourceImagePath');
        return false;
      }

      // Ön kamera selfie'si için yatay çevir
      if (flipHorizontally) {
        try {
          sourceFile = await _flipImageHorizontally(sourceImagePath);
          debugPrint('🔄 PhotoEmoji: Fotoğraf yatay olarak çevrildi');
        } catch (e) {
          debugPrint('⚠️ Flip hatası, orijinal dosya kullanılıyor: $e');
        }
      }

      // Eski dosyayı sil (varsa)
      final targetFile = File(targetPath);
      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      // Yeni dosyayı kopyala
      await sourceFile.copy(targetPath);

      // SharedPreferences'a kaydet
      final prefs = await SharedPreferences.getInstance();
      final key = '${_userId}_${type.storageKey}';
      await prefs.setString(key, targetPath);

      // Cache'i güncelle
      if (_cachedEmojis != null) {
        _cachedEmojis = _cachedEmojis!.updateEmoji(type, targetPath);
      }

      debugPrint('✅ PhotoEmoji: ${type.name} kaydedildi: $targetPath');
      return true;
    } catch (e) {
      debugPrint('❌ PhotoEmoji kaydetme hatası: $e');
      return false;
    }
  }

  /// Belirli bir emoji fotoğrafını sil
  Future<bool> deletePhotoEmoji(PhotoEmojiType type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_userId}_${type.storageKey}';
      final path = prefs.getString(key);

      // Dosyayı sil
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }

      // SharedPreferences'tan kaldır
      await prefs.remove(key);

      // Cache'i güncelle
      if (_cachedEmojis != null) {
        _cachedEmojis = _cachedEmojis!.updateEmoji(type, null);
      }

      debugPrint('🗑️ PhotoEmoji: ${type.name} silindi');
      return true;
    } catch (e) {
      debugPrint('❌ PhotoEmoji silme hatası: $e');
      return false;
    }
  }

  /// Tüm emoji fotoğraflarını sil
  Future<void> deleteAllPhotoEmojis() async {
    for (final type in PhotoEmojiType.values) {
      await deletePhotoEmoji(type);
    }
    _cachedEmojis = null;
  }

  /// Cache'i temizle (kullanıcı değiştiğinde çağrılmalı)
  void clearCache() {
    _cachedEmojis = null;
  }

  /// Kaç tane emoji doldurulmuş
  Future<int> getFilledCount() async {
    final emojis = await getAllPhotoEmojis();
    return emojis.filledCount;
  }
}
