// lib/services/friend_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';

enum FollowStatus { self, following, notFollowing, pendingOutgoing, pendingIncoming }

class FollowNotification {
  final String id;
  final String userId;
  final Map<String, dynamic> userProfile;
  final DateTime createdAt;
  final String type;
  final String? postId;
  final String? postImage;
  final bool isRead;
  final String? friendshipStatus;

  FollowNotification({
    required this.id,
    required this.userId,
    required this.userProfile,
    required this.createdAt,
    required this.type,
    this.postId,
    this.postImage,
    required this.isRead,
    this.friendshipStatus,
  });
}

class FriendService {
  final SupabaseClient client;

  FriendService({SupabaseClient? client})
      : client = client ?? Supabase.instance.client;

  // --- DURUM SORGULA ---
  Future<FollowStatus> getFollowStatus({required String currentUserId, required String targetUserId}) async {
    if (currentUserId == targetUserId) return FollowStatus.self;

    final myRequest = await client.from('friendships').select()
        .eq('user_id', currentUserId).eq('friend_id', targetUserId).maybeSingle();

    if (myRequest != null) {
      return myRequest['status'] == 'accepted' ? FollowStatus.following : FollowStatus.pendingOutgoing;
    }

    final theirRequest = await client.from('friendships').select()
        .eq('user_id', targetUserId).eq('friend_id', currentUserId).eq('status', 'pending').maybeSingle();

    if (theirRequest != null) return FollowStatus.pendingIncoming;

    return FollowStatus.notFollowing;
  }

  // --- BİLDİRİM AKIŞI (FİLTRELİ) ---
  Stream<List<FollowNotification>> getNotificationsStream(String currentUserId) {
    return client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', currentUserId)
        .order('created_at', ascending: false)
        .asyncMap((rows) async {

      if (rows.isEmpty) return <FollowNotification>[];

      final actorIds = rows.map<String>((r) => r['actor_id'] as String).toList();
      final postIds = rows.where((r) => r['post_id'] != null).map((r) => r['post_id'] as String).toList();

      final profiles = await client.from('profiles').select().inFilter('id', actorIds);
      final profileMap = { for (final p in profiles as List) p['id'] as String: Map<String, dynamic>.from(p) };

      Map<String, String> postImages = {};
      if (postIds.isNotEmpty) {
        final postsData = await client.from('posts').select('id, image_url').inFilter('id', postIds);
        for (final p in postsData as List) {
          if (p['image_url'] != null) postImages[p['id']] = p['image_url'];
        }
      }

      final friendships = await client.from('friendships').select('user_id, status').eq('friend_id', currentUserId).inFilter('user_id', actorIds);
      final statusMap = { for (final f in friendships as List) f['user_id'] as String : f['status'] as String };

      List<FollowNotification> result = [];

      for (var r in rows) {
        final actorId = r['actor_id'] as String;
        final type = r['type'] ?? 'unknown';
        final fStatus = statusMap[actorId] ?? 'none';

        // --- FİLTRELEME MANTIĞI ---
        // Eğer bildirim tipi 'follow' İSE ve durumu 'pending' (bekliyor) İSE
        // Ana listeye ekleme (Çünkü yukarıdaki kutuda gözükecek)
        if (type == 'follow' && fStatus == 'pending') {
          continue;
        }

        result.add(FollowNotification(
          id: r['id'],
          userId: actorId,
          userProfile: profileMap[actorId] ?? {},
          createdAt: DateTime.tryParse(r['created_at'] ?? '') ?? DateTime.now(),
          type: type,
          postId: r['post_id'],
          postImage: postImages[r['post_id']],
          isRead: r['is_read'] ?? false,
          friendshipStatus: fStatus,
        ));
      }
      return result;
    });
  }

  // --- BEKLEYEN İSTEKLER ---
  Future<List<Map<String, dynamic>>> getPendingRequests(String currentUserId) async {
    try {
      final response = await client.from('friendships').select('user_id').eq('friend_id', currentUserId).eq('status', 'pending');
      if ((response as List).isEmpty) return [];
      final ids = response.map((e) => e['user_id'] as String).toList();
      final profiles = await client.from('profiles').select().inFilter('id', ids);
      return List<Map<String, dynamic>>.from(profiles);
    } catch (e) { return []; }
  }

  // --- DİĞER FONKSİYONLAR ---
  Future<void> sendFollowRequest({required String currentUserId, required String targetUserId}) async {
    final existing = await client.from('friendships').select().eq('user_id', currentUserId).eq('friend_id', targetUserId).maybeSingle();
    if (existing != null) return;
    await client.from('friendships').insert({'user_id': currentUserId, 'friend_id': targetUserId, 'status': 'pending', 'created_at': DateTime.now().toIso8601String()});
  }
  Future<void> acceptFollowRequest({required String currentUserId, required String targetUserId}) async {
    await client.from('friendships').update({'status': 'accepted'}).eq('user_id', targetUserId).eq('friend_id', currentUserId);
  }
  Future<void> removeFollowerOrDecline({required String currentUserId, required String targetUserId}) async {
    await client.from('friendships').delete().eq('user_id', targetUserId).eq('friend_id', currentUserId);
  }
  Future<void> unfollowOrCancel({required String currentUserId, required String targetUserId}) async {
    await client.from('friendships').delete().eq('user_id', currentUserId).eq('friend_id', targetUserId);
  }
  Future<void> removeFollower({required String currentUserId, required String targetUserId}) async {
    await removeFollowerOrDecline(currentUserId: currentUserId, targetUserId: targetUserId);
  }
  Future<int> getFollowerCount(String userId) async {
    return await client.from('friendships').count(CountOption.exact).eq('friend_id', userId).eq('status', 'accepted');
  }
  Future<int> getFollowingCount(String userId) async {
    return await client.from('friendships').count(CountOption.exact).eq('user_id', userId).eq('status', 'accepted');
  }
  Future<List<Map<String, dynamic>>> getFollowersList(String userId) async {
    try {
      final response = await client.from('friendships').select('user_id').eq('friend_id', userId).eq('status', 'accepted');
      if ((response as List).isEmpty) return [];
      final ids = response.map((e) => e['user_id'] as String).toList();
      final profiles = await client.from('profiles').select().inFilter('id', ids);
      return List<Map<String, dynamic>>.from(profiles);
    } catch (e) { return []; }
  }
  Future<List<Map<String, dynamic>>> getFollowingList(String userId) async {
    try {
      final response = await client.from('friendships').select('friend_id').eq('user_id', userId).eq('status', 'accepted');
      if ((response as List).isEmpty) return [];
      final ids = response.map((e) => e['friend_id'] as String).toList();
      final profiles = await client.from('profiles').select().inFilter('id', ids);
      return List<Map<String, dynamic>>.from(profiles);
    } catch (e) { return []; }
  }
  Future<List<Map<String, dynamic>>> getProfilePosts({required String targetUserId, required FollowStatus status}) async {
    bool canSee = (status == FollowStatus.self || status == FollowStatus.following);
    var query = client.from('posts').select('*, profiles(*), likes(user_id), comments(id)').eq('user_id', targetUserId);
    if (!canSee) query = query.eq('visibility', 'public');
    final res = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res as List);
  }
}