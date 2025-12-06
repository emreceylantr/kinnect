import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  final SupabaseClient client;

  ChatService({SupabaseClient? client})
      : client = client ?? Supabase.instance.client;

  String get _myId => client.auth.currentUser!.id;

  // 1. SOHBET ODASI BAŞLAT / GETİR
  Future<String> createOrGetChatRoom(String otherUserId) async {
    try {
      final response = await client.from('chat_rooms').select().contains('participants', [_myId]);
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

      final newRoom = await client.from('chat_rooms').insert({
        'participants': [_myId, otherUserId],
      }).select().single();

      return newRoom['id'];
    } catch (e) {
      print('Chat Room Hatası: $e');
      rethrow;
    }
  }

  // 2. MESAJ GÖNDER (GÜNCELLENDİ: receiverId eklendi ve Bildirim Atıyor ✅)
  Future<void> sendMessage(String roomId, String content, String receiverId) async {
    try {
      // a. Mesajı Kaydet
      await client.from('messages').insert({
        'room_id': roomId,
        'sender_id': _myId,
        'content': content,
      });

      // b. Odayı Güncelle
      await client.from('chat_rooms').update({
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', roomId);

      // c. BİLDİRİM GÖNDER (Yeni)
      // Kendimize bildirim atmayalım
      if (receiverId != _myId) {
        await client.from('notifications').insert({
          'user_id': receiverId, // Kime
          'actor_id': _myId,     // Kimden
          'type': 'message',     // Tip: Mesaj
          'is_read': false,
        });
      }
    } catch (e) {
      print('Mesaj Gönderme Hatası: $e');
    }
  }

  // 3. MESAJLARI İZLE
  Stream<List<Map<String, dynamic>>> getMessagesStream(String roomId) {
    return client.from('messages').stream(primaryKey: ['id']).eq('room_id', roomId).order('created_at', ascending: true).map((maps) => List<Map<String, dynamic>>.from(maps));
  }

  // 4. SOHBET LİSTESİ
  Future<List<Map<String, dynamic>>> getMyChats() async {
    try {
      final roomsResponse = await client.from('chat_rooms').select().contains('participants', [_myId]).order('updated_at', ascending: false);
      final rooms = List<Map<String, dynamic>>.from(roomsResponse as List);
      if (rooms.isEmpty) return [];

      final otherUserIds = <String>{};
      for (var room in rooms) {
        final participants = List<String>.from(room['participants']);
        final otherId = participants.firstWhere((id) => id != _myId, orElse: () => '');
        if (otherId.isNotEmpty) otherUserIds.add(otherId);
      }
      if (otherUserIds.isEmpty) return [];

      final profilesResponse = await client.from('profiles').select().inFilter('id', otherUserIds.toList());
      final profilesMap = {for (var p in profilesResponse) p['id'] as String: p};

      return rooms.map((room) {
        final participants = List<String>.from(room['participants']);
        final otherId = participants.firstWhere((id) => id != _myId, orElse: () => '');
        final profile = profilesMap[otherId];
        return {...room, 'other_user': profile};
      }).toList();
    } catch (e) {
      return [];
    }
  }
}