import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  final SupabaseClient client;

  ChatService({SupabaseClient? client})
      : client = client ?? Supabase.instance.client;

  String get _myId => client.auth.currentUser!.id;

  // 1. SOHBET ODASI BAŞLAT / GETİR (HATA DÜZELTİLDİ ✅)
  // Bu fonksiyon artık 'firstWhere' hatası vermez, for döngüsü ile güvenli kontrol yapar.
  Future<String> createOrGetChatRoom(String otherUserId) async {
    try {
      // a. Katılımcısı olduğum odaları çek
      final response = await client
          .from('chat_rooms')
          .select()
          .contains('participants', [_myId]);

      final List<dynamic> rooms = response as List<dynamic>;
      Map<String, dynamic>? existingRoom;

      // b. Güvenli Döngü: Diğer kişinin de olduğu odayı bul
      for (var room in rooms) {
        final participants = List<String>.from(room['participants']);
        if (participants.contains(otherUserId)) {
          existingRoom = room;
          break; // Odayı bulduk, döngüyü bitir
        }
      }

      // Varsa onun ID'sini döndür
      if (existingRoom != null) {
        return existingRoom['id'];
      }

      // c. Yoksa YENİ bir oda oluştur
      final newRoom = await client.from('chat_rooms').insert({
        'participants': [_myId, otherUserId],
      }).select().single();

      return newRoom['id'];
    } catch (e) {
      print('Chat Room Hatası: $e');
      rethrow;
    }
  }

  // 2. MESAJ GÖNDER
  Future<void> sendMessage(String roomId, String content) async {
    try {
      // Mesajı kaydet
      await client.from('messages').insert({
        'room_id': roomId,
        'sender_id': _myId,
        'content': content,
      });

      // Odanın 'updated_at' zamanını güncelle (Listede yukarı çıksın diye)
      await client.from('chat_rooms').update({
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', roomId);
    } catch (e) {
      print('Mesaj Gönderme Hatası: $e');
    }
  }

  // 3. MESAJLARI CANLI İZLE (Stream)
  Stream<List<Map<String, dynamic>>> getMessagesStream(String roomId) {
    return client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: true)
        .map((maps) => List<Map<String, dynamic>>.from(maps));
  }

  // 4. SOHBET LİSTEMİ GETİR (Gelen Kutusu)
  Future<List<Map<String, dynamic>>> getMyChats() async {
    try {
      // a. Benim dahil olduğum odaları çek
      final roomsResponse = await client
          .from('chat_rooms')
          .select()
          .contains('participants', [_myId])
          .order('updated_at', ascending: false);

      final rooms = List<Map<String, dynamic>>.from(roomsResponse as List);

      if (rooms.isEmpty) return [];

      // b. Diğer kişilerin ID'lerini bul
      final otherUserIds = <String>{};
      for (var room in rooms) {
        final participants = List<String>.from(room['participants']);
        final otherId = participants.firstWhere((id) => id != _myId, orElse: () => '');
        if (otherId.isNotEmpty) otherUserIds.add(otherId);
      }

      if (otherUserIds.isEmpty) return [];

      // c. Profil bilgilerini çek
      final profilesResponse = await client
          .from('profiles')
          .select()
          .inFilter('id', otherUserIds.toList());

      final profilesMap = {
        for (var p in profilesResponse) p['id'] as String: p
      };

      // d. Verileri birleştir
      return rooms.map((room) {
        final participants = List<String>.from(room['participants']);
        final otherId = participants.firstWhere((id) => id != _myId, orElse: () => '');
        final profile = profilesMap[otherId];

        return {
          ...room,
          'other_user': profile,
        };
      }).toList();
    } catch (e) {
      print("Sohbet listesi hatası: $e");
      return [];
    }
  }
}