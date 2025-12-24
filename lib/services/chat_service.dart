// Kinnect - Mesajlasma servisi

import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  final SupabaseClient client;

  ChatService({SupabaseClient? client})
      : client = client ?? Supabase.instance.client;

  String get _myId => client.auth.currentUser!.id;

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
      print('Chat Room Hatası: $e');
      rethrow;
    }
  }

  // 2. MESAJ GÖNDER (Ephemeral destek eklendi)
  Future<void> sendMessage(
    String roomId,
    String content,
    String receiverId, {
    bool isEphemeral = false,
    int ephemeralDuration = 5, // saniye
  }) async {
    try {
      // a. Mesajı Kaydet
      await client.from('messages').insert({
        'room_id': roomId,
        'sender_id': _myId,
        'receiver_id': receiverId,
        'content': content,
        'is_ephemeral': isEphemeral,
        'ephemeral_duration': ephemeralDuration,
        'is_viewed': false,
      });

      // b. Odayı Güncelle (Sıralama tetikleyici)
      await client.from('chat_rooms').update({
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', roomId);

      // c. BİLDİRİM GÖNDER
      if (receiverId != _myId) {
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
          print('Push bildirim hatası: $e');
        }
      }
    } catch (e) {
      print('Mesaj Gönderme Hatası: $e');
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
      print('Mesaj görüntüleme işareti hatası: $e');
    }
  }

  // 🔥 YENİ: EPHEMERAL MESAJI SİL (Süre dolunca çağrılır)
  Future<void> deleteEphemeralMessage(String messageId) async {
    try {
      await client.from('messages').delete().eq('id', messageId);
      print('🔥 Kül olan mesaj silindi: $messageId');
    } catch (e) {
      print('Ephemeral mesaj silme hatası: $e');
    }
  }

  // 🔥 YENİ: TEK MESAJ SİLME FONKSİYONU
  Future<void> deleteSingleMessage(String messageId) async {
    try {
      await client.from('messages').delete().eq('id', messageId);
    } catch (e) {
      print('Mesaj Silme Hatası: $e');
      rethrow;
    }
  }

  // 3. MESAJLARI İZLE
  Stream<List<Map<String, dynamic>>> getMessagesStream(String roomId) {
    return client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: true)
        .map((maps) => List<Map<String, dynamic>>.from(maps));
  }

  // 4. SOHBET LİSTESİ (Sıralama ve Saat Garantili ✅)
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

      for (var room in rooms) {
        // Her odanın içindeki SON mesajı çekiyoruz
        final lastMessageResponse = await client
            .from('messages')
            .select('created_at, content')
            .eq('room_id', room['id'])
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        // SADECE İÇİNDE MESAJ OLANLARI LİSTEYE AL
        if (lastMessageResponse != null) {
          final participants = List<String>.from(room['participants']);
          final otherId =
              participants.firstWhere((id) => id != _myId, orElse: () => '');

          if (otherId.isNotEmpty) {
            otherUserIds.add(otherId);

            finalChats.add({
              ...room,
              'other_user_id': otherId,
              'actual_last_message_at': lastMessageResponse['created_at'],
            });
          }
        }
      }

      if (finalChats.isEmpty) return [];

      final profilesResponse = await client
          .from('profiles')
          .select()
          .inFilter('id', otherUserIds.toList());

      final profilesMap = {
        for (var p in profilesResponse) p['id'] as String: p
      };

      List<Map<String, dynamic>> result = finalChats.map((chat) {
        return {
          ...chat,
          'other_user': profilesMap[chat['other_user_id']],
          'updated_at': chat[
              'actual_last_message_at'], // Görüntülenecek saat artık son mesaj saati
        };
      }).toList();

      // 🔥 EN SON MESAJ ATILAN EN ÜSTE (Tarih bazlı manuel sort)
      result.sort((a, b) {
        DateTime dateA = DateTime.parse(a['updated_at']);
        DateTime dateB = DateTime.parse(b['updated_at']);
        return dateB.compareTo(dateA);
      });

      return result;
    } catch (e) {
      print("Chat Listesi Hatası: $e");
      return [];
    }
  }
}
