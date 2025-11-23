import 'package:supabase_flutter/supabase_flutter.dart';

/// ProfileScreen'e özel: profil verisi + istatistik + gönderiler
class ProfileScreenService {
  final SupabaseClient client;

  ProfileScreenService({SupabaseClient? client})
      : client = client ?? Supabase.instance.client;

  /// Profil + gönderi sayısı + takipçi/takip edilen sayıları
  Future<Map<String, dynamic>> getProfileWithStats(String userId) async {
    // Profil
    final profile = await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();

    // Gönderi sayısı
    final posts = await client
        .from('posts')
        .select('id')
        .eq('user_id', userId);

    final postCount = (posts as List).length;

    // Takipçi sayısı
    final followersRows = await client
        .from('friendships')
        .select('id')
        .eq('friend_id', userId)
        .eq('status', 'accepted');

    final followersCount = (followersRows as List).length;

    // Takip edilen sayısı
    final followingRows = await client
        .from('friendships')
        .select('id')
        .eq('user_id', userId)
        .eq('status', 'accepted');

    final followingCount = (followingRows as List).length;

    return {
      'profile': profile,
      'post_count': postCount,
      'followers_count': followersCount,
      'following_count': followingCount,
    };
  }

  /// Kullanıcının gönderileri (profil akışı)
  Stream<List<Map<String, dynamic>>> getUserPostsStream(String userId) {
    return Stream.fromFuture(_getUserPostsOnce(userId));
  }

  Future<List<Map<String, dynamic>>> _getUserPostsOnce(String userId) async {
    final rows = await client
        .from('posts')
        .select('*, profiles(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }
}
