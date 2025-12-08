import 'package:flutter/foundation.dart';
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

  // --- 1. ANA AKIŞ (SADECE ARKADAŞLAR + PUBLIC OLMAYANLAR) ---
  // Arkadaşının 'Public' (Herkes) attığı post buraya düşmez, sadece arkadaşlarına özel olanlar düşer.
  Future<List<Map<String, dynamic>>> getFriendsFeed() async {
    try {
      // Takip ettiklerimi (Arkadaşlarımı) bul
      final following = await client
          .from('friendships')
          .select('friend_id')
          .eq('user_id', _myId)
          .eq('status', 'accepted');

      final targetIds = (following as List).map((e) => e['friend_id'] as String).toList();

      // Kendi gönderilerimi de ana akışta göreyim
      targetIds.add(_myId);

      if (targetIds.isEmpty) return [];

      final posts = await client
          .from('posts')
          .select('*, profiles(*), likes(user_id), comments(id)')
          .inFilter('user_id', targetIds)
          .neq('visibility', 'public') // 🔥 ÖNEMLİ: Public olanları ana akıştan gizle!
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(posts as List);
    } catch (e) {
      debugPrint('HATA (Arkadaş Akışı): $e');
      return [];
    }
  }

  // --- 2. KEŞFET (HERKES - SADECE PUBLIC OLANLAR) ---
  Future<List<Map<String, dynamic>>> getExploreFeed() async {
    try {
      final response = await client
          .from('posts')
          .select('*, profiles(*), likes(user_id), comments(id)')
          .eq('visibility', 'public') // Sadece herkese açık olanlar
          .order('created_at', ascending: false)
          .limit(50);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('HATA (Keşfet): $e');
      return [];
    }
  }

  // --- 3. PROFİL POSTLARI ---
  Future<List<Map<String, dynamic>>> getProfilePosts(String userId) async {
    try {
      final response = await client
          .from('posts')
          .select('*, profiles(*), likes(user_id), comments(id)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('HATA (Profil Postları): $e');
      return [];
    }
  }

  // --- 4. YORUM STREAM ---
  Stream<List<Map<String, dynamic>>> getCommentsStream(String postId) {
    return client
        .from('comments')
        .stream(primaryKey: ['id'])
        .eq('post_id', postId)
        .order('created_at', ascending: true)
        .asyncMap((rows) async {
      if (rows.isEmpty) return [];

      final userIds = rows.map((r) => r['user_id'] as String).toSet().toList();
      final profiles = await client.from('profiles').select().inFilter('id', userIds);

      final profileMap = { for (final p in profiles) p['id'] as String: p };

      return rows.map((r) => {
        ...r,
        'profile': profileMap[r['user_id']] ?? <String, dynamic>{},
      }).toList();
    });
  }

  // --- 5. YORUM EKLEME ---
  Future<void> addComment(String postId, String content) async {
    await client.from('comments').insert({
      'user_id': _myId,
      'post_id': postId,
      'content': content,
    });
  }

  // --- 6. YORUM SİLME ---
  Future<void> deleteComment(String commentId) async {
    await client.from('comments').delete().eq('id', commentId);
  }

  // --- 7. BEĞENİ / HARLAMA (TOGGLE) ---
  // isFuel: true ise 'fuel' (Harlama) işlemi yapılır.
  // isFuel: false ise 'like' (Beğeni) işlemi yapılır.
  Future<void> toggleLike(String postId, {bool isFuel = false}) async {
    try {
      final existing = await client
          .from('likes')
          .select()
          .eq('user_id', _myId)
          .eq('post_id', postId)
          .maybeSingle();

      if (existing != null) {
        // --- SİLME İŞLEMİ (SÖNDÜRME / VAZGEÇME) ---
        await client.from('likes').delete().eq('id', existing['id']);

        // 🔥 GÜNCELLEME: Bildirimi de siliyoruz ki kirlilik olmasın
        final typeToDelete = isFuel ? 'fuel' : 'like';
        try {
          await client.from('notifications').delete()
              .eq('post_id', postId)
              .eq('actor_id', _myId)
              .eq('type', typeToDelete);
        } catch (_) {
          // Bildirim zaten yoksa hata vermesin devam etsin
        }

      } else {
        // --- EKLEME İŞLEMİ (HARLAMA / BEĞENME) ---
        await client.from('likes').insert({
          'user_id': _myId,
          'post_id': postId,
        });

        // Bildirim Gönder (Post sahibi ben değilsem)
        final post = await client.from('posts').select('user_id').eq('id', postId).single();
        if (post['user_id'] != _myId) {
          // 🔥 ÖNEMLİ: Eğer bu bir 'fuel' ise tipi 'fuel' kaydet, yoksa 'like' kaydet.
          final notifType = isFuel ? 'fuel' : 'like';

          await client.from('notifications').insert({
            'user_id': post['user_id'],
            'actor_id': _myId,
            'type': notifType,
            'post_id': postId,
            'is_read': false,
          });
        }
      }
    } catch (e) {
      debugPrint('HATA (Like/Fuel): $e');
      // Rethrow kaldırdım, UI çökmesin diye sadece loglasın.
    }
  }

  // --- 8. POST SİLME ---
  Future<void> deletePost(String postId) async {
    await client.from('posts').delete().eq('id', postId);
  }

  // --- 9. GÖRÜNÜRLÜK GÜNCELLEME ---
  Future<void> updatePostVisibility(String postId, String visibility) async {
    await client.from('posts').update({
      'visibility': visibility,
      'audience': visibility,
    }).eq('id', postId);
  }
}