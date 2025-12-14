import 'package:supabase_flutter/supabase_flutter.dart';

/// 🔥 ProfileScreen için TEK servis
/// Supabase Flutter v2 uyumlu
class ProfileScreenService {
  final SupabaseClient client;

  ProfileScreenService({SupabaseClient? client})
      : client = client ?? Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // PROFİL + İSTATİSTİKLER
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getProfileWithStats(String userId) async {
    // Profil
    final profile = await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();

    // Sayılar (v2 safe count)
    final postCount = await _count(
      table: 'posts',
      filters: {'user_id': userId},
    );

    final followersCount = await _count(
      table: 'friendships',
      filters: {
        'friend_id': userId,
        'status': 'accepted',
      },
    );

    final followingCount = await _count(
      table: 'friendships',
      filters: {
        'user_id': userId,
        'status': 'accepted',
      },
    );

    return {
      'profile': profile,
      'post_count': postCount,
      'followers_count': followersCount,
      'following_count': followingCount,
    };
  }

  // ---------------------------------------------------------------------------
  // PROFİL GÖNDERİLERİ (REALTIME – v2 SAFE)
  // ---------------------------------------------------------------------------

  Stream<List<Map<String, dynamic>>> getUserPostsStream({
    required String userId,
    bool includePrivate = true,
  }) {
    return client
        .from('posts')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .asyncMap((rows) async {
      // Gizli post filtreleme
      if (!includePrivate) {
        rows = rows
            .where((r) => r['visibility'] == 'public')
            .toList();
      }

      if (rows.isEmpty) return [];

      // Profil bilgileri
      final userIds =
      rows.map((r) => r['user_id'] as String).toSet().toList();

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
  // TEK SEFERLİK FETCH (STREAM YOK)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getUserPostsOnce({
    required String userId,
    bool includePrivate = true,
  }) async {
    final rows = await client
        .from('posts')
        .select('*, profiles(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    // Gizli post filtresi (client-side, v2 safe)
    final filtered = includePrivate
        ? rows
        : rows.where((r) => r['visibility'] == 'public').toList();

    return List<Map<String, dynamic>>.from(filtered);
  }

  // ---------------------------------------------------------------------------
  // COUNT HELPER (SUPABASE FLUTTER v2 SAFE)
  // ---------------------------------------------------------------------------

  Future<int> _count({
    required String table,
    required Map<String, dynamic> filters,
  }) async {
    var query = client.from(table).select();

    for (final entry in filters.entries) {
      query = query.eq(entry.key, entry.value);
    }

    final data = await query;
    return data.length;
  }
}
