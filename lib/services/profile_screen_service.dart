import 'package:supabase_flutter/supabase_flutter.dart';

/// 🔥 ProfileScreen için TEK servis
/// - Profil bilgisi
/// - İstatistikler
/// - Gönderiler (realtime)
class ProfileScreenService {
  final SupabaseClient client;

  ProfileScreenService({SupabaseClient? client})
      : client = client ?? Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // PROFİL + İSTATİSTİKLER
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getProfileWithStats(String userId) async {
    // 🔹 Profil
    final profile = await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();

    // 🔹 Gönderi sayısı (COUNT)
    final postCount = await client
        .from('posts')
        .count(CountOption.exact)
        .eq('user_id', userId);

    // 🔹 Takipçi sayısı
    final followersCount = await client
        .from('friendships')
        .count(CountOption.exact)
        .eq('friend_id', userId)
        .eq('status', 'accepted');

    // 🔹 Takip edilen sayısı
    final followingCount = await client
        .from('friendships')
        .count(CountOption.exact)
        .eq('user_id', userId)
        .eq('status', 'accepted');

    return {
      'profile': profile,
      'post_count': postCount,
      'followers_count': followersCount,
      'following_count': followingCount,
    };
  }

  // ---------------------------------------------------------------------------
  // PROFİL GÖNDERİLERİ (REALTIME)
  // ---------------------------------------------------------------------------

  Stream<List<Map<String, dynamic>>> getUserPostsStream({
    required String userId,
    bool includePrivate = true,
  }) {
    var query = client
        .from('posts')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    if (!includePrivate) {
      query = query.eq('visibility', 'public');
    }

    return query.asyncMap((rows) async {
      if (rows.isEmpty) return [];

      final userIds = rows
          .map((r) => r['user_id'] as String)
          .toSet()
          .toList();

      final profiles = await client
          .from('profiles')
          .select()
          .inFilter('id', userIds);

      final profileMap = {
        for (final p in profiles) p['id'] as String: p,
      };

      return rows.map((row) {
        return {
          ...row,
          'profiles': profileMap[row['user_id']] ?? {},
        };
      }).toList();
    });
  }

  // ---------------------------------------------------------------------------
  // TEK SEFERLİK FETCH (STREAM İSTEMEZSEN)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getUserPostsOnce({
    required String userId,
    bool includePrivate = true,
  }) async {
    var query = client
        .from('posts')
        .select('*, profiles(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    if (!includePrivate) {
      query = query.eq('visibility', 'public');
    }

    final rows = await query;
    return List<Map<String, dynamic>>.from(rows);
  }
}
