import 'package:supabase_flutter/supabase_flutter.dart';

/// Kullanıcı profili tabanlı AI eşleştirme servisi
class MatchingService {
  final SupabaseClient _client = Supabase.instance.client;

  String get _currentUserId => _client.auth.currentUser?.id ?? '';

  /// Mevcut kullanıcıya benzer profildeki kullanıcıları bulur
  Future<List<Map<String, dynamic>>> getMatchedUsers({int maxResults = 25}) async {
    if (_currentUserId.isEmpty) return [];

    try {
      final response = await _client.functions.invoke(
        'match-users',
        body: {'user_id': _currentUserId},
      );

      if (response.status != 200 || response.data == null) return [];

      final List<dynamic> matches = response.data is List
          ? response.data
          : (response.data['matches'] ?? []);

      return matches
          .whereType<Map<String, dynamic>>()
          .where((m) => m['profile'] != null)
          .take(maxResults)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// İki kullanıcının neden eşleştiğini Claude'a açıklattır (gerçek postlarla)
  Future<String> getAiExplanation({
    required String otherUserId,
    required String otherUserName,
    required String otherUserProfile,
    required List<String> otherInterests,
    List<String> matchReasons = const [],
  }) async {
    try {
      final myProfileData = await _client
          .from('user_profiles')
          .select('profile_summary, interests')
          .eq('user_id', _currentUserId)
          .maybeSingle();

      final myBasicProfile = await _client
          .from('profiles')
          .select('full_name, username')
          .eq('id', _currentUserId)
          .maybeSingle();

      final myName =
          myBasicProfile?['full_name'] ?? myBasicProfile?['username'] ?? 'Ben';
      final myProfile = myProfileData?['profile_summary'] ?? '';
      final myInterests = List<String>.from(myProfileData?['interests'] ?? []);

      final response = await _client.functions.invoke(
        'explain-match',
        body: {
          'user1_id':        _currentUserId,
          'user2_id':        otherUserId,
          'user1_name':      myName,
          'user2_name':      otherUserName,
          'user1_profile':   myProfile,
          'user2_profile':   otherUserProfile,
          'user1_interests': myInterests,
          'user2_interests': otherInterests,
          'match_reasons':   matchReasons,
        },
      );

      if (response.status == 200 && response.data != null) {
        return response.data['explanation'] as String;
      }
      return '$otherUserName ile çok şey ortak görünüyor!';
    } catch (e) {
      return '$otherUserName harika biri gibi görünüyor, tanışmaya değer!';
    }
  }

  /// Kullanıcının profilini analiz et / güncelle
  Future<Map<String, dynamic>?> analyzeUserProfile(String userId) async {
    try {
      final response = await _client.functions.invoke(
        'analyze-user-profile',
        body: {'user_id': userId},
      );
      if (response.status == 200) return response.data as Map<String, dynamic>;
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Mevcut kullanıcının profil durumunu kontrol et
  Future<Map<String, dynamic>?> getMyProfile() async {
    if (_currentUserId.isEmpty) return null;
    return await _client
        .from('user_profiles')
        .select('profile_summary, interests, analyzed_post_count, updated_at')
        .eq('user_id', _currentUserId)
        .maybeSingle();
  }
}
