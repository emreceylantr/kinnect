// ==========================================
// 📸 PHOTO EMOJI MODEL
// BeReal RealMoji benzeri fotoğraf-emoji sistemi
// ==========================================

/// Kullanılabilir emoji tipleri
enum PhotoEmojiType {
  smile, // 😊 Gülümse
  cry, // 😢 Ağla
  laugh, // 😂 Kahkaha
  surprise, // 😮 Şaşkın
  thumbsUp, // 👍 Beğeni
  love, // 😍 Aşk
}

/// PhotoEmojiType için yardımcı extension
extension PhotoEmojiTypeExtension on PhotoEmojiType {
  /// Emoji türünün Türkçe adı
  String get label {
    switch (this) {
      case PhotoEmojiType.smile:
        return 'Gülümse';
      case PhotoEmojiType.cry:
        return 'Ağla';
      case PhotoEmojiType.laugh:
        return 'Kahkaha';
      case PhotoEmojiType.surprise:
        return 'Şaşkın';
      case PhotoEmojiType.thumbsUp:
        return 'Beğeni';
      case PhotoEmojiType.love:
        return 'Aşk';
    }
  }

  /// Varsayılan emoji karakteri
  String get defaultEmoji {
    switch (this) {
      case PhotoEmojiType.smile:
        return '😊';
      case PhotoEmojiType.cry:
        return '😢';
      case PhotoEmojiType.laugh:
        return '😂';
      case PhotoEmojiType.surprise:
        return '😮';
      case PhotoEmojiType.thumbsUp:
        return '👍';
      case PhotoEmojiType.love:
        return '😍';
    }
  }

  /// Storage key (yerel depolama için)
  String get storageKey => 'photo_emoji_${name}';
}

/// Kullanıcının tüm fotoğraf emojilerini tutan model
class UserPhotoEmojis {
  final String userId;
  final Map<PhotoEmojiType, String?> emojiPaths;

  UserPhotoEmojis({
    required this.userId,
    Map<PhotoEmojiType, String?>? emojiPaths,
  }) : emojiPaths = emojiPaths ?? {};

  /// Belirli bir emoji tipi için fotoğraf var mı?
  bool hasEmoji(PhotoEmojiType type) => emojiPaths[type] != null;

  /// Belirli bir emoji tipinin fotoğraf yolu
  String? getPath(PhotoEmojiType type) => emojiPaths[type];

  /// Yeni fotoğraf ekle veya güncelle
  UserPhotoEmojis copyWith({
    String? userId,
    Map<PhotoEmojiType, String?>? emojiPaths,
  }) {
    return UserPhotoEmojis(
      userId: userId ?? this.userId,
      emojiPaths: emojiPaths ?? Map.from(this.emojiPaths),
    );
  }

  /// Tek bir emoji güncelle
  UserPhotoEmojis updateEmoji(PhotoEmojiType type, String? path) {
    final newMap = Map<PhotoEmojiType, String?>.from(emojiPaths);
    newMap[type] = path;
    return UserPhotoEmojis(userId: userId, emojiPaths: newMap);
  }

  /// Kaç tane emoji doldurulmuş
  int get filledCount => emojiPaths.values.where((p) => p != null).length;

  /// Toplam emoji sayısı
  int get totalCount => PhotoEmojiType.values.length;
}
