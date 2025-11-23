// lib/services/feed_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class FeedService {
  final SupabaseClient client;

  FeedService({SupabaseClient? client})
      : client = client ?? Supabase.instance.client;

  String get _myId => client.auth.currentUser!.id;

  // --- ANA AKIŞ ---
  Future<List<Map<String, dynamic>>> getFriendsFeed() async {
    try {
      final following = await client.from('friendships')
          .select('friend_id').eq('user_id', _myId).eq('status', 'accepted');

      final targetIds = (following as List).map((e) => e['friend_id'] as String).toList();
      if (targetIds.isEmpty) return [];

      // YENİLİK: comments(id) ve likes(user_id) çekiyoruz ki sayılarını bulalım
      final posts = await client.from('posts')
          .select('*, profiles(*), likes(user_id), comments(id)')
          .inFilter('user_id', targetIds)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(posts);
    } catch (e) { return []; }
  }

  // --- KEŞFET ---
  Future<List<Map<String, dynamic>>> getExploreFeed() async {
    try {
      final following = await client.from('friendships')
          .select('friend_id').eq('user_id', _myId).eq('status', 'accepted');

      final excludedIds = (following as List).map((e) => e['friend_id'] as String).toList();
      excludedIds.add(_myId);

      final response = await client.from('posts')
          .select('*, profiles(*), likes(user_id), comments(id)')
          .eq('visibility', 'public')
          .order('created_at', ascending: false)
          .limit(50);

      final allPublicPosts = List<Map<String, dynamic>>.from(response as List);
      return allPublicPosts.where((p) => !excludedIds.contains(p['user_id'])).toList();
    } catch (e) { return []; }
  }

  // --- PROFİL POSTLARI ---
  Future<List<Map<String, dynamic>>> getProfilePosts(String userId) async {
    try {
      final response = await client.from('posts')
          .select('*, profiles(*), likes(user_id), comments(id)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) { return []; }
  }

  // --- DİĞER FONKSİYONLAR ---
  Stream<List<Map<String, dynamic>>> getCommentsStream(String postId) {
    return client.from('comments').stream(primaryKey: ['id']).eq('post_id', postId)
        .order('created_at', ascending: true).asyncMap((rows) async {
      if (rows.isEmpty) return [];
      final userIds = rows.map((r) => r['user_id'] as String).toSet().toList();
      final profiles = await client.from('profiles').select().inFilter('id', userIds);
      final profileMap = { for (final p in profiles) p['id'] as String: p };
      return rows.map((r) => { ...r, 'profile': profileMap[r['user_id']] ?? {} }).toList();
    });
  }

  Future<void> addComment(String postId, String content) async {
    await client.from('comments').insert({'user_id': _myId, 'post_id': postId, 'content': content});
  }

  Future<void> deleteComment(String commentId) async {
    await client.from('comments').delete().eq('id', commentId);
  }

  Future<bool> toggleLike(String postId) async {
    final existing = await client.from('likes').select().eq('user_id', _myId).eq('post_id', postId).maybeSingle();
    if (existing != null) {
      await client.from('likes').delete().eq('id', existing['id']);
      return false;
    } else {
      await client.from('likes').insert({'user_id': _myId, 'post_id': postId});
      return true;
    }
  }

  Future<void> deletePost(String postId) async {
    await client.from('posts').delete().eq('id', postId);
  }
}