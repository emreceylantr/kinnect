import 'package:supabase_flutter/supabase_flutter.dart';
import 'level_calculator.dart';
import '../../models/achievement.dart';

/// Main gamification service that manages XP, levels, and achievements
class GamificationService {
  final SupabaseClient _client;

  GamificationService(this._client);

  /// Get current user's progress
  Future<UserProgress?> getUserProgress(String userId) async {
    try {
      final response = await _client
          .from('user_progress')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return UserProgress.fromJson(response);
    } catch (e) {
      print('Error getting user progress: $e');
      return null;
    }
  }

  /// Get user's unlocked achievements
  Future<Set<String>> getUnlockedAchievements(String userId) async {
    try {
      final response = await _client
          .from('user_achievements')
          .select('achievement_id')
          .eq('user_id', userId);

      return Set<String>.from(
          response.map((item) => item['achievement_id'] as String));
    } catch (e) {
      print('Error getting achievements: $e');
      return {};
    }
  }

  /// Add XP and check for level up
  Future<XPResult> addXP(String userId, int amount, String actionType) async {
    try {
      // Call the stored procedure
      final response = await _client.rpc('add_xp', params: {
        'p_user_id': userId,
        'p_xp_amount': amount,
        'p_action_type': actionType,
      });

      return XPResult(
        newXP: response['new_xp'] ?? 0,
        newLevel: response['new_level'] ?? 1,
        leveledUp: response['level_up'] ?? false,
        nextLevelXP: response['next_level_xp'] ?? 0,
      );
    } catch (e) {
      print('Error adding XP: $e');
      return XPResult(
          newXP: 0, newLevel: 1, leveledUp: false, nextLevelXP: 100);
    }
  }

  /// Check and unlock eligible achievements
  Future<List<Achievement>> checkAchievements(String userId) async {
    final progress = await getUserProgress(userId);
    if (progress == null) return [];

    final unlockedIds = await getUnlockedAchievements(userId);
    final newUnlocks = <Achievement>[];

    for (final achievement in kinnectAchievements) {
      if (unlockedIds.contains(achievement.id)) continue;

      bool shouldUnlock = false;

      switch (achievement.conditionType) {
        case 'followers':
          // Need to fetch follower count
          final followers = await _getFollowerCount(userId);
          shouldUnlock = followers >= achievement.conditionValue;
          break;
        case 'posts':
          shouldUnlock = progress.totalPosts >= achievement.conditionValue;
          break;
        case 'likes_given':
          shouldUnlock = progress.totalLikesGiven >= achievement.conditionValue;
          break;
        case 'daily_streak':
          shouldUnlock = progress.dailyStreak >= achievement.conditionValue;
          break;
      }

      if (shouldUnlock) {
        await _unlockAchievement(userId, achievement.id);
        await addXP(userId, achievement.xpReward, 'achievement');
        newUnlocks.add(achievement);
      }
    }

    return newUnlocks;
  }

  Future<int> _getFollowerCount(String userId) async {
    try {
      final response =
          await _client.from('follows').select().eq('following_id', userId);
      return response.length;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _unlockAchievement(String userId, String achievementId) async {
    await _client.from('user_achievements').upsert({
      'user_id': userId,
      'achievement_id': achievementId,
    });
  }

  /// Update daily streak
  Future<int> updateDailyStreak(String userId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final progress = await getUserProgress(userId);
      if (progress == null) return 0;

      final lastActive = progress.lastActiveDate;
      int newStreak = 1;

      if (lastActive != null) {
        final yesterday = today.subtract(const Duration(days: 1));
        if (lastActive.year == yesterday.year &&
            lastActive.month == yesterday.month &&
            lastActive.day == yesterday.day) {
          // Consecutive day
          newStreak = progress.dailyStreak + 1;
        } else if (lastActive.year == today.year &&
            lastActive.month == today.month &&
            lastActive.day == today.day) {
          // Same day, don't reset
          newStreak = progress.dailyStreak;
        }
        // Else: streak broken, reset to 1
      }

      await _client.from('user_progress').update({
        'daily_streak': newStreak,
        'last_active_date': today.toIso8601String(),
      }).eq('user_id', userId);

      return newStreak;
    } catch (e) {
      print('Error updating streak: $e');
      return 0;
    }
  }
}

class UserProgress {
  final String userId;
  final int totalXP;
  final int currentLevel;
  final int dailyStreak;
  final DateTime? lastActiveDate;
  final int totalPosts;
  final int totalLikesGiven;
  final int totalComments;

  UserProgress({
    required this.userId,
    required this.totalXP,
    required this.currentLevel,
    required this.dailyStreak,
    this.lastActiveDate,
    required this.totalPosts,
    required this.totalLikesGiven,
    required this.totalComments,
  });

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      userId: json['user_id'],
      totalXP: json['total_xp'] ?? 0,
      currentLevel: json['current_level'] ?? 1,
      dailyStreak: json['daily_streak'] ?? 0,
      lastActiveDate: json['last_active_date'] != null
          ? DateTime.tryParse(json['last_active_date'])
          : null,
      totalPosts: json['total_posts'] ?? 0,
      totalLikesGiven: json['total_likes_given'] ?? 0,
      totalComments: json['total_comments'] ?? 0,
    );
  }

  double get progressPercent => LevelCalculator.progressToNextLevel(totalXP);
  String get levelTitle => LevelCalculator.getLevelTitle(currentLevel);
}

class XPResult {
  final int newXP;
  final int newLevel;
  final bool leveledUp;
  final int nextLevelXP;

  XPResult({
    required this.newXP,
    required this.newLevel,
    required this.leveledUp,
    required this.nextLevelXP,
  });
}
