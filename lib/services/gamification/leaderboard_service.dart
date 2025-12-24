import 'package:supabase_flutter/supabase_flutter.dart';

class LeaderboardEntry {
  final String userId;
  final String username;
  final String? avatarUrl;
  final int totalXP;
  final int level;
  final int rank;

  LeaderboardEntry({
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.totalXP,
    required this.level,
    required this.rank,
  });

  String get rankEmoji {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '#$rank';
    }
  }
}

class LeaderboardService {
  final SupabaseClient _client;

  LeaderboardService(this._client);

  /// Haftalık liderlik tablosu
  Future<List<LeaderboardEntry>> getWeeklyLeaderboard({int limit = 50}) async {
    final response = await _client
        .from('user_progress')
        .select(
            'user_id, total_xp, current_level, profiles(username, avatar_url)')
        .order('total_xp', ascending: false)
        .limit(limit);

    return List.generate(response.length, (i) {
      final item = response[i];
      return LeaderboardEntry(
        userId: item['user_id'],
        username: item['profiles']['username'] ?? 'Anonim',
        avatarUrl: item['profiles']['avatar_url'],
        totalXP: item['total_xp'] ?? 0,
        level: item['current_level'] ?? 1,
        rank: i + 1,
      );
    });
  }

  /// Kullanıcının sıralamasını getir
  Future<int?> getUserRank(String userId) async {
    final response = await _client
        .from('user_progress')
        .select('user_id, total_xp')
        .order('total_xp', ascending: false);

    for (int i = 0; i < response.length; i++) {
      if (response[i]['user_id'] == userId) {
        return i + 1;
      }
    }
    return null;
  }
}
