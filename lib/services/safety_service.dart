import 'package:supabase_flutter/supabase_flutter.dart';

class SafetyService {
  final SupabaseClient _client = Supabase.instance.client;

  // --- 1. KULLANICIYI ENGELLE ---
  Future<void> blockUser(String targetUserId) async {
    final myId = _client.auth.currentUser!.id;
    if (myId == targetUserId) throw Exception("Kendini engelleyemezsin.");

    try {
      // Engelleme kaydı
      await _client.from('blocked_users').upsert({
        'user_id': myId,
        'blocked_user_id': targetUserId,
      });

      // Bağları kopar (İki taraflı takibi sil)
      await _client.from('friendships').delete().match({'user_id': myId, 'friend_id': targetUserId});
      await _client.from('friendships').delete().match({'user_id': targetUserId, 'friend_id': myId});

    } catch (e) {
      throw Exception("Engelleme hatası: $e");
    }
  }

  // --- 2. ENGELİ KALDIR ---
  Future<void> unblockUser(String targetUserId) async {
    final myId = _client.auth.currentUser!.id;
    try {
      await _client.from('blocked_users').delete().eq('user_id', myId).eq('blocked_user_id', targetUserId);
    } catch (e) {
      throw Exception("Engel kaldırma hatası: $e");
    }
  }

  // --- 3. ŞİKAYET ET ---
  Future<void> reportContent({
    required String targetId,
    required String type,
    required String reason,
    String? description,
  }) async {
    final myId = _client.auth.currentUser!.id;
    try {
      await _client.from('reports').insert({
        'reporter_id': myId,
        'target_id': targetId,
        'type': type,
        'reason': reason,
        'description': description,
      });
    } catch (e) {
      throw Exception("Şikayet hatası: $e");
    }
  }

  // 🔥 4. BENİ ENGELLEYENLER (Aramada ve Listelerde GİZLE) 🔥
  // Bu kişiler beni engellediği için onları hiçbir yerde görmemeliyim.
  Future<List<String>> getIdsThatBlockedMe() async {
    final myId = _client.auth.currentUser!.id;
    try {
      // 'blocked_users' tablosunda, user_id (engelleyen) ONLAR, blocked_user_id (engellenen) BEN.
      final response = await _client
          .from('blocked_users')
          .select('user_id')
          .eq('blocked_user_id', myId);

      final List<dynamic> data = response;
      return data.map((e) => e['user_id'] as String).toList();
    } catch (e) {
      return [];
    }
  }

  // 🔥 5. BENİM ENGELLEDİKLERİM (Feed'de GİZLE) 🔥
  // Bunları ben engelledim. Postlarını görmemeliyim ama profilini bulup engelini kaldırabilmeliyim.
  Future<List<String>> getIdsIBlocked() async {
    final myId = _client.auth.currentUser!.id;
    try {
      final response = await _client
          .from('blocked_users')
          .select('blocked_user_id')
          .eq('user_id', myId);

      final List<dynamic> data = response;
      return data.map((e) => e['blocked_user_id'] as String).toList();
    } catch (e) {
      return [];
    }
  }

  // --- 6. TEKİL KONTROL (Profil Sayfası İçin) ---
  Future<bool> isUserBlocked(String targetUserId) async {
    final myId = _client.auth.currentUser!.id;
    // Ben onu engelledim mi?
    final response = await _client.from('blocked_users').select().eq('user_id', myId).eq('blocked_user_id', targetUserId).maybeSingle();
    return response != null;
  }
}