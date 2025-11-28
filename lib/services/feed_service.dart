// lib/services/feed_service.dart

import 'package:flutter/foundation.dart'; // Hata çıktıları için debugPrint eklendi
import 'package:supabase_flutter/supabase_flutter.dart';

class FeedService {
  final SupabaseClient client;

  FeedService({SupabaseClient? client})
      : client = client ?? Supabase.instance.client;

  // Kullanıcı ID'sini güvenli şekilde al
  String get _myId {
    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('Kullanıcı oturumu kapalı!');
    }
    return user.id;
  }

  // --- ANA AKIŞ (SADECE ARKADAŞLAR) ---
  Future<List<Map<String, dynamic>>> getFriendsFeed() async {
    try {
      final following = await client
          .from('friendships')
          .select('friend_id')
          .eq('user_id', _myId)
          .eq('status', 'accepted');

      final targetIds =
      (following as List).map((e) => e['friend_id'] as String).toList();

      if (targetIds.isEmpty) return [];

      final posts = await client
          .from('posts')
          .select('*, profiles(*), likes(user_id), comments(id)')
          .inFilter('user_id', targetIds)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(posts as List);
    } catch (e) {
      debugPrint('HATA (Arkadaş Akışı): $e'); // Hatayı konsola yazdırır
      return [];
    }
  }

  // --- KEŞFET (HERKESE AÇIK GÖNDERİLER) ---
  Future<List<Map<String, dynamic>>> getExploreFeed() async {
    try {
      // 1. Arkadaş listesini çek
      final following = await client
          .from('friendships')
          .select('friend_id')
          .eq('user_id', _myId)
          .eq('status', 'accepted');

      final excludedIds =
      (following as List).map((e) => e['friend_id'] as String).toList();

      // 2. Kendimi de hariç tutulacaklara ekle (kendi postumu keşfette görmiyim)
      excludedIds.add(_myId);

      // 3. Public postları çek
      final response = await client
          .from('posts')
          .select('*, profiles(*), likes(user_id), comments(id)')
          .eq('visibility', 'public')
          .order('created_at', ascending: false)
          .limit(50);

      final allPublicPosts = List<Map<String, dynamic>>.from(response as List);

      // 4. Flutter tarafında filtrele (Hariç tutulanları listeden çıkar)
      return allPublicPosts
          .where((p) => !excludedIds.contains(p['user_id']))
          .toList();
    } catch (e) {
      debugPrint('HATA (Keşfet): $e');
      return [];
    }
  }

  // --- PROFİL POSTLARI (Sorun yaşadığın yer burası olabilir) ---
  Future<List<Map<String, dynamic>>> getProfilePosts(String userId) async {
    try {
      final response = await client
          .from('posts')
          .select('*, profiles(*), likes(user_id), comments(id)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      // BURASI ÇOK ÖNEMLİ: Hata varsa terminalde göreceksin
      debugPrint('HATA (Profil Postları): $e');
      return [];
    }
  }

  // --- YORUM STREAM ---
  Stream<List<Map<String, dynamic>>> getCommentsStream(String postId) {
    return client
        .from('comments')
        .stream(primaryKey: ['id'])
        .eq('post_id', postId)
        .order('created_at', ascending: true)
        .asyncMap((rows) async {
      if (rows.isEmpty) return [];

      final userIds =
      rows.map((r) => r['user_id'] as String).toSet().toList();

      final profiles =
      await client.from('profiles').select().inFilter('id', userIds);

      final profileMap = {
        for (final p in profiles) p['id'] as String: p,
      };

      return rows
          .map((r) => {
        ...r,
        'profile': profileMap[r['user_id']] ?? <String, dynamic>{},
      })
          .toList();
    });
  }

  // --- YORUM EKLE ---
  Future<void> addComment(String postId, String content) async {
    await client.from('comments').insert({
      'user_id': _myId,
      'post_id': postId,
      'content': content,
    });
  }

  // --- YORUM SİL ---
  Future<void> deleteComment(String commentId) async {
    await client.from('comments').delete().eq('id', commentId);
  }

  // --- LIKE TOGGLE (BEĞEN / BEĞENME) ---
  Future<bool> toggleLike(String postId) async {
    try {
      final existing = await client
          .from('likes')
          .select()
          .eq('user_id', _myId)
          .eq('post_id', postId)
          .maybeSingle();

      if (existing != null) {
        await client.from('likes').delete().eq('id', existing['id']);
        return false; // Beğeni geri alındı
      } else {
        await client.from('likes').insert({
          'user_id': _myId,
          'post_id': postId,
        });
        return true; // Beğenildi
      }
    } catch (e) {
      debugPrint('HATA (Like): $e');
      rethrow;
    }
  }

  // --- POST SİL ---
  Future<void> deletePost(String postId) async {
    await client.from('posts').delete().eq('id', postId);
  }

  // --- POST GÖRÜNÜRLÜĞÜ GÜNCELLE ---
  Future<void> updatePostVisibility(
      String postId,
      String visibility,
      ) async {
    await client
        .from('posts')
        .update({
      'visibility': visibility,
      'audience': visibility,
    })
        .eq('id', postId);
  }
}