// lib/repositories/friend_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

/// Arkadaşlık ilişkisi durumu
enum FriendStatus {
  self,       // Kendi profilin
  none,       // Hiç ilişki yok
  outgoing,   // Ben istek gönderdim, karşı taraf bekliyor
  incoming,   // Karşı taraf bana istek gönderdi
  friends,    // Karşılıklı arkadaşız (accepted)
}

class FriendRepository {
  final SupabaseClient client;

  FriendRepository(this.client);

  /// Tek bir friendship satırını (varsa) döndürür.
  Future<Map<String, dynamic>?> _getFriendshipRow({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final data = await client
        .from('friendships')
        .select()
        .or(
      'and(user_id.eq.$currentUserId,friend_id.eq.$otherUserId),'
          'and(user_id.eq.$otherUserId,friend_id.eq.$currentUserId)',
    )
        .limit(1)
        .maybeSingle();

    return data;
  }

  /// İki kullanıcı arasındaki arkadaşlık durumunu hesaplar.
  Future<FriendStatus> getFriendStatus({
    required String currentUserId,
    required String otherUserId,
  }) async {
    if (currentUserId == otherUserId) {
      return FriendStatus.self;
    }

    final row = await _getFriendshipRow(
      currentUserId: currentUserId,
      otherUserId: otherUserId,
    );

    if (row == null) {
      return FriendStatus.none;
    }

    final status = (row['status'] as String?) ?? 'pending';
    final senderId = row['user_id'] as String;

    if (status == 'accepted') {
      return FriendStatus.friends;
    }

    if (status == 'pending') {
      if (senderId == currentUserId) {
        // İsteği ben göndermişim
        return FriendStatus.outgoing;
      } else {
        // İstek bana gelmiş
        return FriendStatus.incoming;
      }
    }

    return FriendStatus.none;
  }

  /// Arkadaşlık isteği gönder.
  Future<void> sendFriendRequest({
    required String currentUserId,
    required String toUserId,
  }) async {
    if (currentUserId == toUserId) return;

    await client.from('friendships').insert({
      'user_id': currentUserId,
      'friend_id': toUserId,
      'status': 'pending',
    });
  }

  /// Bana gelen isteği kabul et.
  Future<void> acceptFriendRequest({
    required String currentUserId,
    required String fromUserId,
  }) async {
    await client
        .from('friendships')
        .update({'status': 'accepted'})
        .eq('user_id', fromUserId)
        .eq('friend_id', currentUserId)
        .eq('status', 'pending');
  }

  /// Arkadaşlığı kaldır (iki yönden de sil).
  Future<void> removeFriendship({
    required String currentUserId,
    required String otherUserId,
  }) async {
    await client
        .from('friendships')
        .delete()
        .or(
      'and(user_id.eq.$currentUserId,friend_id.eq.$otherUserId),'
          'and(user_id.eq.$otherUserId,friend_id.eq.$currentUserId)',
    );
  }

  /// Benim gönderdiğim bekleyen isteği iptal et.
  Future<void> cancelFriendRequest({
    required String currentUserId,
    required String toUserId,
  }) async {
    await client
        .from('friendships')
        .delete()
        .eq('user_id', currentUserId)
        .eq('friend_id', toUserId)
        .eq('status', 'pending');
  }
}
