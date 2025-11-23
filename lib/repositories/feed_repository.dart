import 'package:supabase_flutter/supabase_flutter.dart';

/// Sadece Supabase sorgularını yapan katman.
/// Arkadaş feed’i + keşfet feed’i burada.
class FeedRepository {
  final SupabaseClient _client;

  FeedRepository(this._client);

  /// Arkadaşlarının (ve senin) gönderilerini döner.
  /// Servis katmanında senin gönderilerini filtreleyeceğiz.
  Future<List<Map<String, dynamic>>> getFriendsFeed(
      String currentUserId) async {
    // 1) Accepted arkadaşlıkları al
    final friendships = await _client
        .from('friendships')
        .select('user_id, friend_id, status')
        .or('user_id.eq.$currentUserId,friend_id.eq.$currentUserId')
        .eq('status', 'accepted');

    final friendIds = <String>{};

    for (final row in friendships as List) {
      final userId = row['user_id'] as String;
      final friendId = row['friend_id'] as String;

      if (userId == currentUserId) {
        friendIds.add(friendId);
      } else if (friendId == currentUserId) {
        friendIds.add(userId);
      }
    }

    // kendini de ekle
    friendIds.add(currentUserId);

    if (friendIds.isEmpty) {
      return [];
    }

    // 2) Arkadaşların postlarını çek
    final posts = await _client
        .from('posts')
        .select('*, profiles(*)')
        .inFilter('user_id', friendIds.toList())
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(posts as List);
  }

  /// Herkese açık gönderiler (visibility = public)
  Future<List<Map<String, dynamic>>> getExploreFeed() async {
    final posts = await _client
        .from('posts')
        .select('*, profiles(*)')
        .eq('visibility', 'public')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(posts as List);
  }
}
