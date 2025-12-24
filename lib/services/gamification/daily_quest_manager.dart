/// Daily Quest System for Kinnect gamification
class DailyQuest {
  final String id;
  final String title;
  final String description;
  final String actionType; // 'post', 'like', 'comment', 'follow'
  final int targetCount;
  final int xpReward;

  const DailyQuest({
    required this.id,
    required this.title,
    required this.description,
    required this.actionType,
    required this.targetCount,
    required this.xpReward,
  });

  String get actionEmoji {
    switch (actionType) {
      case 'post':
        return '📝';
      case 'like':
        return '🔥';
      case 'comment':
        return '💬';
      case 'follow':
        return '👥';
      case 'share':
        return '📤';
      default:
        return '⭐';
    }
  }
}

class DailyQuestManager {
  static const List<DailyQuest> _questPool = [
    DailyQuest(
      id: 'q_post_1',
      title: 'Alev Yak',
      description: 'Bir gönderi paylaş',
      actionType: 'post',
      targetCount: 1,
      xpReward: 20,
    ),
    DailyQuest(
      id: 'q_like_3',
      title: 'Ateşi Yay',
      description: '3 postu beğen',
      actionType: 'like',
      targetCount: 3,
      xpReward: 15,
    ),
    DailyQuest(
      id: 'q_like_5',
      title: 'Yangın Çıkar',
      description: '5 postu beğen',
      actionType: 'like',
      targetCount: 5,
      xpReward: 25,
    ),
    DailyQuest(
      id: 'q_comment_1',
      title: 'Sesini Duyur',
      description: '1 yorum yap',
      actionType: 'comment',
      targetCount: 1,
      xpReward: 15,
    ),
    DailyQuest(
      id: 'q_comment_2',
      title: 'Sohbete Katıl',
      description: '2 yorum yap',
      actionType: 'comment',
      targetCount: 2,
      xpReward: 20,
    ),
    DailyQuest(
      id: 'q_follow_1',
      title: 'Bağlantı Kur',
      description: 'Birini takip et',
      actionType: 'follow',
      targetCount: 1,
      xpReward: 15,
    ),
  ];

  /// Rastgele 3 günlük görev seç
  static List<DailyQuest> generateDailyQuests() {
    final shuffled = List<DailyQuest>.from(_questPool)..shuffle();
    return shuffled.take(3).toList();
  }

  /// Günlük görevlerin sıfırlanma zamanını kontrol et
  static bool shouldResetQuests(DateTime? lastResetTime) {
    if (lastResetTime == null) return true;

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    return lastResetTime.isBefore(todayMidnight);
  }

  /// Bir sonraki sıfırlama zamanını hesapla
  static DateTime getNextResetTime() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1);
  }

  /// Sıfırlamaya kalan süreyi formatla
  static String formatTimeUntilReset() {
    final now = DateTime.now();
    final nextReset = getNextResetTime();
    final difference = nextReset.difference(now);

    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;

    return '${hours}s ${minutes}d';
  }
}
