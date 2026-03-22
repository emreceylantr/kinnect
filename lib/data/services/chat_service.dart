// Kinnect - Mesajlasma servisi

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  final SupabaseClient client;

  ChatService({SupabaseClient? client})
      : client = client ?? Supabase.instance.client;

  String get _myId => client.auth.currentUser?.id ?? '';

  // 1. SOHBET ODASI BAŞLAT / GETİR
  Future<String> createOrGetChatRoom(String otherUserId) async {
    try {
      final response = await client
          .from('chat_rooms')
          .select()
          .contains('participants', [_myId]);
      final List<dynamic> rooms = response as List<dynamic>;
      Map<String, dynamic>? existingRoom;

      for (var room in rooms) {
        final participants = List<String>.from(room['participants']);
        if (participants.contains(otherUserId)) {
          existingRoom = room;
          break;
        }
      }

      if (existingRoom != null) return existingRoom['id'];

      final newRoom = await client
          .from('chat_rooms')
          .insert({
            'participants': [_myId, otherUserId],
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return newRoom['id'];
    } catch (e) {
      debugPrint('Chat Room Hatası: $e');
      rethrow;
    }
  }

  // 2. MESAJ GÖNDER (Ephemeral + Reply destek, grup destekli)
  Future<void> sendMessage(
    String roomId,
    String content,
    String? receiverId, {
    bool isEphemeral = false,
    int ephemeralDuration = 5,
    String? replyToId,
    String? replyToContent,
    String? replyToSenderName,
  }) async {
    final hasReceiver =
        receiverId != null && receiverId.isNotEmpty && receiverId != _myId;

    try {
      // a. Mesajı Kaydet
      final insertData = {
        'room_id': roomId,
        'sender_id': _myId,
        if (hasReceiver) 'receiver_id': receiverId,
        'content': content,
        'is_ephemeral': isEphemeral,
        'ephemeral_duration': ephemeralDuration,
        'is_viewed': false,
        if (replyToId != null) 'reply_to_id': replyToId,
        if (replyToContent != null) 'reply_to_content': replyToContent,
        if (replyToSenderName != null) 'reply_to_sender_name': replyToSenderName,
      };
      await client.from('messages').insert(insertData);

      // b. Odayı Güncelle
      await client.from('chat_rooms').update({
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', roomId);

      // c. BİLDİRİM GÖNDER (sadece 1-1 sohbetlerde)
      if (hasReceiver) {
        await client.from('notifications').insert({
          'user_id': receiverId,
          'actor_id': _myId,
          'type': 'message',
          'is_read': false,
        });

        // 🔔 PUSH BİLDİRİM GÖNDER
        try {
          final myProfile = await client
              .from('profiles')
              .select('username')
              .eq('id', _myId)
              .single();
          final username = myProfile['username'] ?? 'Birisi';

          String notifBody = isEphemeral
              ? '$username sana kül olan bir mesaj gönderdi 🔥'
              : '$username: $content';

          await client.functions.invoke('send-push-notification', body: {
            'target_user_id': receiverId,
            'title': isEphemeral ? '🔥 Kül Olan Mesaj' : '💬 Yeni Mesaj',
            'body': notifBody,
            'type': 'message',
            'target_id': roomId,
          });
        } catch (e) {
          debugPrint('Push bildirim hatası: $e');
        }
      }
    } catch (e) {
      debugPrint('Mesaj Gönderme Hatası: $e');
    }
  }

  // ── GRUP CHAT ────────────────────────────────────────────────

  /// Grup sohbeti oluştur (oluşturan otomatik admin)
  Future<String> createGroupChat(
      String name, List<String> participantIds) async {
    final allParticipants = [...participantIds, _myId];
    final now = DateTime.now().toIso8601String();
    // member_since: herkese şu anki zaman (grup kurulunca hepsi aynı anda giriyor)
    final memberSince = {for (final id in allParticipants) id: now};
    final room = await client
        .from('chat_rooms')
        .insert({
          'participants': allParticipants,
          'is_group': true,
          'group_name': name,
          'created_by': _myId,
          'group_admins': [_myId],
          'member_since': memberSince,
          'updated_at': now,
        })
        .select()
        .single();
    return room['id'] as String;
  }

  /// Grubu terk et
  /// Grubu tamamen sil (sadece lider/kurucu)
  Future<void> deleteGroup(String roomId) async {
    final room = await client
        .from('chat_rooms')
        .select('created_by')
        .eq('id', roomId)
        .single();
    if (room['created_by'] != _myId) {
      throw Exception('Sadece grup lideri grubu silebilir');
    }
    // Önce mesajları sil, sonra odayı sil
    await client.from('messages').delete().eq('room_id', roomId);
    await client.from('chat_rooms').delete().eq('id', roomId);
  }

  Future<void> leaveGroup(String roomId) async {
    final room = await client
        .from('chat_rooms')
        .select('participants, group_admins, created_by')
        .eq('id', roomId)
        .single();

    final participants = List<String>.from(room['participants'])
      ..remove(_myId);
    final admins = List<String>.from(room['group_admins'] ?? [])
      ..remove(_myId);

    if (participants.isEmpty) {
      // Son kişiyse grubu sil
      await client.from('chat_rooms').delete().eq('id', roomId);
      return;
    }

    // Kurucu gidiyorsa ve başka admin yoksa ilk katılımcıyı admin yap
    if (admins.isEmpty) admins.add(participants.first);

    await client.from('chat_rooms').update({
      'participants': participants,
      'group_admins': admins,
    }).eq('id', roomId);
  }

  /// Gruptan üye çıkar (sadece admin)
  Future<void> removeGroupMember(String roomId, String userId) async {
    final room = await client
        .from('chat_rooms')
        .select('participants, group_admins, created_by')
        .eq('id', roomId)
        .single();

    final admins = List<String>.from(room['group_admins'] ?? []);
    final isCreator = room['created_by'] == _myId;
    if (!admins.contains(_myId) && !isCreator) return; // Sadece admin çıkarabilir

    final participants = List<String>.from(room['participants'])
      ..remove(userId);
    final newAdmins = List<String>.from(admins)..remove(userId);

    await client.from('chat_rooms').update({
      'participants': participants,
      'group_admins': newAdmins,
    }).eq('id', roomId);
  }

  /// Gruba üye ekle (sadece admin)
  Future<void> addGroupMember(String roomId, String userId) async {
    final room = await client
        .from('chat_rooms')
        .select('participants, group_admins, created_by, member_since')
        .eq('id', roomId)
        .single();

    final admins = List<String>.from(room['group_admins'] ?? []);
    final isCreator = room['created_by'] == _myId;
    if (!admins.contains(_myId) && !isCreator) return;

    final participants = List<String>.from(room['participants']);
    if (participants.contains(userId)) return;
    participants.add(userId);

    // Yeni üyenin katılma zamanını kaydet
    final memberSince = Map<String, dynamic>.from(room['member_since'] ?? {});
    memberSince[userId] = DateTime.now().toIso8601String();

    await client.from('chat_rooms').update({
      'participants': participants,
      'member_since': memberSince,
    }).eq('id', roomId);
  }

  /// Admin yap (sadece admin)
  Future<void> promoteToAdmin(String roomId, String userId) async {
    final room = await client
        .from('chat_rooms')
        .select('group_admins, created_by')
        .eq('id', roomId)
        .single();

    final admins = List<String>.from(room['group_admins'] ?? []);
    final isCreator = room['created_by'] == _myId;
    if (!admins.contains(_myId) && !isCreator) return;
    if (admins.contains(userId)) return;
    admins.add(userId);

    await client
        .from('chat_rooms')
        .update({'group_admins': admins}).eq('id', roomId);
  }

  /// Admin'den çıkar (sadece grup kurucusu yapabilir — created_by)
  Future<void> demoteAdmin(String roomId, String userId) async {
    final room = await client
        .from('chat_rooms')
        .select('group_admins, created_by')
        .eq('id', roomId)
        .single();

    if (room['created_by'] != _myId) return; // Sadece kurucu
    final admins = List<String>.from(room['group_admins'] ?? [])
      ..remove(userId);
    // Kurucu her zaman admin kalır
    if (!admins.contains(_myId)) admins.insert(0, _myId);

    await client
        .from('chat_rooms')
        .update({'group_admins': admins}).eq('id', roomId);
  }

  /// Grup adı ve/veya avatarını güncelle (sadece admin — UI tarafında kontrol edilir)
  Future<Map<String, dynamic>> updateGroupInfo(String roomId,
      {String? name, String? avatarUrl}) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['group_name'] = name;
    if (avatarUrl != null) updates['group_avatar_url'] = avatarUrl;
    if (updates.isEmpty) return {};

    // UPDATE (RETURNING olmadan — bazı RLS yapılarında zincirleme SELECT 0 row döner)
    await client.from('chat_rooms').update(updates).eq('id', roomId);

    // Ayrıca geri oku ve doğrula
    final result = await client
        .from('chat_rooms')
        .select('group_name, group_avatar_url')
        .eq('id', roomId)
        .maybeSingle();

    return result ?? {};
  }

  /// Grup bilgisini getir
  Future<Map<String, dynamic>?> getGroupInfo(String roomId) async {
    try {
      return await client
          .from('chat_rooms')
          .select()
          .eq('id', roomId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  /// Ortak arkadaşları getir (grup oluşturmak için)
  Future<List<Map<String, dynamic>>> getMutualFriends() async {
    try {
      final resp = await client
          .from('friendships')
          .select('friend_id')
          .eq('user_id', _myId)
          .eq('status', 'accepted');

      final ids = List<String>.from(
          (resp as List).map((r) => r['friend_id'] as String));
      if (ids.isEmpty) return [];

      final profiles =
          await client.from('profiles').select().inFilter('id', ids);
      return List<Map<String, dynamic>>.from(profiles);
    } catch (e) {
      debugPrint('Arkadaş listesi hatası: $e');
      return [];
    }
  }

  /// Grup katılımcılarını getir
  Future<List<Map<String, dynamic>>> getGroupParticipants(
      String roomId) async {
    try {
      final room = await client
          .from('chat_rooms')
          .select('participants')
          .eq('id', roomId)
          .single();
      final ids = List<String>.from(room['participants']);
      final profiles =
          await client.from('profiles').select().inFilter('id', ids);
      return List<Map<String, dynamic>>.from(profiles);
    } catch (_) {
      return [];
    }
  }

  // 📸 GÖNDERI PAYLAŞ
  Future<void> sendSharedPost({
    required String roomId,
    String? receiverId,
    required String postId,
    required Map<String, dynamic> sharedPostData,
  }) async {
    final hasReceiver =
        receiverId != null && receiverId.isNotEmpty && receiverId != _myId;
    try {
      await client.from('messages').insert({
        'room_id': roomId,
        'sender_id': _myId,
        if (hasReceiver) 'receiver_id': receiverId,
        'content': '📸 Bir gönderi paylaştı',
        'shared_post_id': postId,
        'shared_post_data': sharedPostData,
        'is_ephemeral': false,
        'is_viewed': false,
      });

      await client.from('chat_rooms').update({
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', roomId);

      if (hasReceiver) {
        await client.from('notifications').insert({
          'user_id': receiverId,
          'actor_id': _myId,
          'type': 'message',
          'is_read': false,
        });
        try {
          final myProfile = await client
              .from('profiles')
              .select('username, full_name')
              .eq('id', _myId)
              .single();
          final name = myProfile['full_name'] ?? myProfile['username'] ?? 'Birisi';
          await client.functions.invoke('send-push-notification', body: {
            'target_user_id': receiverId,
            'title': '📸 Gönderi Paylaşıldı',
            'body': '$name sana bir gönderi paylaştı',
            'type': 'message',
            'target_id': roomId,
          });
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Gönderi paylaşma hatası: $e');
      rethrow;
    }
  }

  // 💬 REAKSİYON EKLE/KALDIR (toggle)
  Future<void> toggleReaction(String messageId, String emoji) async {
    try {
      final msg = await client
          .from('messages')
          .select('reactions')
          .eq('id', messageId)
          .single();

      final Map<String, dynamic> raw =
          Map<String, dynamic>.from(msg['reactions'] ?? {});
      final List<String> users = List<String>.from(raw[emoji] ?? []);

      if (users.contains(_myId)) {
        users.remove(_myId);
      } else {
        users.add(_myId);
      }

      if (users.isEmpty) {
        raw.remove(emoji);
      } else {
        raw[emoji] = users;
      }

      await client
          .from('messages')
          .update({'reactions': raw}).eq('id', messageId);
    } catch (e) {
      debugPrint('Reaksiyon hatası: $e');
    }
  }

  // 🔥 YENİ: MESAJI GÖRÜNTÜLENMIŞ OLARAK İŞARETLE
  Future<void> markMessageAsViewed(String messageId) async {
    try {
      await client.from('messages').update({
        'is_viewed': true,
        'viewed_at': DateTime.now().toIso8601String(),
      }).eq('id', messageId);
    } catch (e) {
      debugPrint('Mesaj görüntüleme işareti hatası: $e');
    }
  }

  // 🔥 YENİ: EPHEMERAL MESAJI SİL (Süre dolunca çağrılır)
  Future<void> deleteEphemeralMessage(String messageId) async {
    try {
      await client.from('messages').delete().eq('id', messageId);
      debugPrint('🔥 Kül olan mesaj silindi: $messageId');
    } catch (e) {
      debugPrint('Ephemeral mesaj silme hatası: $e');
    }
  }

  // 🔥 YENİ: TEK MESAJ SİLME FONKSİYONU
  Future<void> deleteSingleMessage(String messageId) async {
    try {
      await client.from('messages').delete().eq('id', messageId);
    } catch (e) {
      debugPrint('Mesaj Silme Hatası: $e');
      rethrow;
    }
  }

  // 3. MESAJLARI İZLE
  Stream<List<Map<String, dynamic>>> getMessagesStream(String roomId,
      {DateTime? joinedAt}) {
    return client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: true)
        .map((maps) {
      final all = List<Map<String, dynamic>>.from(maps);
      if (joinedAt == null) return all;
      return all
          .where((m) {
            final createdAt = DateTime.tryParse(m['created_at'] ?? '');
            return createdAt != null && !createdAt.isBefore(joinedAt);
          })
          .toList();
    });
  }

  /// Kullanıcının gruba katılma zamanını döndür
  Future<DateTime?> getJoinedAt(String roomId) async {
    try {
      final room = await client
          .from('chat_rooms')
          .select('member_since')
          .eq('id', roomId)
          .maybeSingle();
      if (room == null) return null;
      final memberSince = room['member_since'] as Map<String, dynamic>?;
      final ts = memberSince?[_myId] as String?;
      return ts != null ? DateTime.tryParse(ts) : null;
    } catch (_) {
      return null;
    }
  }

  // 4. SOHBET LİSTESİ (Grup + 1-1, sıralama garantili ✅)
  Future<List<Map<String, dynamic>>> getMyChats() async {
    try {
      final roomsResponse = await client
          .from('chat_rooms')
          .select()
          .contains('participants', [_myId]);

      final rooms = List<Map<String, dynamic>>.from(roomsResponse as List);
      if (rooms.isEmpty) return [];

      List<Map<String, dynamic>> finalChats = [];
      Set<String> otherUserIds = {};

      final results = await Future.wait(rooms.map((room) async {
        final lastMsg = await client
            .from('messages')
            .select('created_at, content')
            .eq('room_id', room['id'])
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (lastMsg == null) return null;

        // Grup sohbeti
        if (room['is_group'] == true) {
          return {
            ...room,
            'actual_last_message_at': lastMsg['created_at'],
            'other_user': {
              'full_name': room['group_name'] ?? 'Grup',
              'avatar_url': room['group_avatar_url'],
              'group_avatar_url': room['group_avatar_url'],
              'group_name': room['group_name'] ?? 'Grup',
              'is_group': true,
              'participants': room['participants'],
              'participants_count':
                  (room['participants'] as List?)?.length ?? 0,
            },
          };
        }

        // 1-1 sohbet
        final participants = List<String>.from(room['participants']);
        final otherId =
            participants.firstWhere((id) => id != _myId, orElse: () => '');
        if (otherId.isEmpty) return null;

        otherUserIds.add(otherId);
        return {
          ...room,
          'other_user_id': otherId,
          'actual_last_message_at': lastMsg['created_at'],
        };
      }));

      for (final chat in results) {
        if (chat != null) finalChats.add(chat);
      }
      if (finalChats.isEmpty) return [];

      // Profilleri çek (sadece 1-1 için)
      if (otherUserIds.isNotEmpty) {
        final profilesResponse = await client
            .from('profiles')
            .select()
            .inFilter('id', otherUserIds.toList());
        final profilesMap = {
          for (var p in profilesResponse) p['id'] as String: p
        };

        for (var i = 0; i < finalChats.length; i++) {
          final otherId = finalChats[i]['other_user_id'] as String?;
          if (otherId != null && profilesMap.containsKey(otherId)) {
            finalChats[i] = {
              ...finalChats[i],
              'other_user': profilesMap[otherId],
            };
          }
        }
      }

      // Tarihe göre sırala
      for (var i = 0; i < finalChats.length; i++) {
        finalChats[i] = {
          ...finalChats[i],
          'updated_at': finalChats[i]['actual_last_message_at'],
        };
      }
      finalChats.sort((a, b) {
        final dateA = DateTime.parse(a['updated_at']);
        final dateB = DateTime.parse(b['updated_at']);
        return dateB.compareTo(dateA);
      });

      return finalChats;
    } catch (e) {
      debugPrint("Chat Listesi Hatası: $e");
      return [];
    }
  }

  // 👁️ SON GÖRÜLME GÜNCELLE
  Future<void> updateLastSeen() async {
    try {
      await client.from('profiles').update({
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('id', _myId);
    } catch (e) {
      debugPrint('Last seen güncelleme hatası: $e');
    }
  }

  // 👁️ SON GÖRÜLME BİLGİSİNİ ÇEK (Gizlilik kontrolü dahil)
  Future<DateTime?> getLastSeen(String userId) async {
    try {
      final response = await client
          .from('profiles')
          .select('last_seen, show_last_seen')
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        // 🔒 Gizlilik kontrolü - kullanıcı gizlediyse null döndür
        final showLastSeen = response['show_last_seen'] ?? true;
        if (!showLastSeen) return null;

        if (response['last_seen'] != null) {
          return DateTime.parse(response['last_seen']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Last seen çekme hatası: $e');
      return null;
    }
  }

  // 🔒 Karşı kullanıcının okundu bilgisi ayarını çek
  Future<bool> getReadReceiptSetting(String userId) async {
    try {
      final response = await client
          .from('profiles')
          .select('show_read_receipts')
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        return response['show_read_receipts'] ?? true;
      }
      return true; // Varsayılan açık
    } catch (e) {
      debugPrint('Privacy setting çekme hatası: $e');
      return true;
    }
  }

  // ✅ BİR SOHBETTEKİ TÜM OKUNMAMIŞ MESAJLARI OKUNDU OLARAK İŞARETLE
  Future<void> markAllMessagesAsRead(String roomId) async {
    try {
      // Sadece bana gelen ve okunmamış mesajları güncelle
      final result = await client.from('messages').update({
        'is_viewed': true,
        'viewed_at': DateTime.now().toIso8601String(),
      }).match({
        'room_id': roomId,
        'receiver_id': _myId,
        'is_viewed': false,
      }).select();
      debugPrint('📩 Okundu işaretlenen mesaj sayısı: ${result.length}');
    } catch (e) {
      debugPrint('Tüm mesajları okundu işaretleme hatası: $e');
    }
  }
}
