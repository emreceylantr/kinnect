import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepository {
  final SupabaseClient _client;

  ProfileRepository(this._client);

  // --------------------------------------------------
  // 1) Profil getirme
  // --------------------------------------------------
  Future<Map<String, dynamic>?> getProfileById(String userId) async {
    final res = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (res == null) return null;
    return Map<String, dynamic>.from(res);
  }

  // --------------------------------------------------
  // 2) Sadece repository içinde kullanılan avatar upload
  // --------------------------------------------------
  Future<String?> _uploadAvatar(String userId, File file) async {
    final fileExt = file.path.split('.').last;
    final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final filePath = 'avatars/$fileName';

    await _client.storage.from('avatars').upload(
      filePath,
      file,
      fileOptions: const FileOptions(upsert: true),
    );

    final publicUrl = _client.storage.from('avatars').getPublicUrl(filePath);
    return publicUrl;
  }

  // --------------------------------------------------
  // 3) Profil oluştur / güncelle (upsert)
  // --------------------------------------------------
  Future<void> upsertProfile({
    required String userId,
    required String username,
    required String fullName,
    String? bio,
    File? avatarFile,
  }) async {
    String? avatarUrl;

    if (avatarFile != null) {
      avatarUrl = await _uploadAvatar(userId, avatarFile);
    }

    final data = <String, dynamic>{
      'id': userId,
      'username': username,
      'full_name': fullName,
      'bio': bio ?? '',
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (avatarUrl != null) {
      data['avatar_url'] = avatarUrl;
    }

    await _client.from('profiles').upsert(data);
  }

  // --------------------------------------------------
  // 4) Profil istatistikleri
  // --------------------------------------------------
  Future<int> getPostCount(String userId) async {
    final res = await _client
        .from('posts')
        .select('id')
        .eq('user_id', userId);

    if (res is List) return res.length;
    return 0;
  }

  Future<int> getFollowersCount(String userId) async {
    final res = await _client
        .from('friendships')
        .select('user_id')
        .eq('friend_id', userId)
        .eq('status', 'accepted');

    if (res is List) return res.length;
    return 0;
  }

  Future<int> getFollowingCount(String userId) async {
    final res = await _client
        .from('friendships')
        .select('friend_id')
        .eq('user_id', userId)
        .eq('status', 'accepted');

    if (res is List) return res.length;
    return 0;
  }

  Future<(int, int, int)> getProfileStats(String userId) async {
    final posts = await getPostCount(userId);
    final followers = await getFollowersCount(userId);
    final following = await getFollowingCount(userId);
    return (posts, followers, following);
  }

  // --------------------------------------------------
  // 5) Kullanıcı adı ile arama (SELECT + Stream.fromFuture)
  //    -> .stream() kullanmıyoruz, ilike hatasından kaçıyoruz
  // --------------------------------------------------
  Stream<List<Map<String, dynamic>>> searchProfilesByUsername(
      String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const Stream.empty();
    }

    return Stream.fromFuture(
      _client
          .from('profiles')
          .select()
          .ilike('username', '%$trimmed%'),
    ).map((rows) {
      final list = rows as List<dynamic>;
      return list
          .map<Map<String, dynamic>>(
              (e) => Map<String, dynamic>.from(e as Map))
          .toList();
    });
  }
}
