import 'package:supabase_flutter/supabase_flutter.dart';

/// AI destekli kullanıcı eşleştirme servisi
/// Gemini embedding vektörleri üzerinden benzer kullanıcıları bulur
class MatchingService {
  final SupabaseClient _client = Supabase.instance.client;

  String get _currentUserId => _client.auth.currentUser?.id ?? '';

  /// Giriş yapmış kullanıcının tüm postlarındaki embedding'leri alıp
  /// bunlara en benzer diğer kullanıcıları döndürür.
  /// Sonuçta her kullanıcı bir kere görünür (en yüksek benzerlik skoru ile).
  Future<List<Map<String, dynamic>>> getMatchedUsers({
    double threshold = 0.60,
    int maxResults = 25,
  }) async {
    if (_currentUserId.isEmpty) return [];

    // 1. Kullanıcının kendi embedding'lerini çek (Boşları filtrele ve görsel al)
    final myEmbeddings = await _client
        .from('post_embeddings')
        .select('embedding, content_summary, post_id, posts(image_url)')
        .eq('user_id', _currentUserId)
        .neq('content_summary', 'İçerik yok.')
        .not('content_summary', 'is', null);

    if (myEmbeddings.isEmpty) return [];

    // 2. Her embedding için benzerleri bul ve birleştir
    final Map<String, Map<String, dynamic>> userScores = {};

    for (final emb in myEmbeddings) {
      final embeddingRaw = emb['embedding'];
      final myPostId = emb['post_id'] as String;
      final myPostImageUrl = (emb['posts'] as Map?)?['image_url'] as String?;
      final myContentSummary = emb['content_summary'] ?? '';
      List<double> vector;

      if (embeddingRaw is String) {
        final cleaned = embeddingRaw.replaceAll('[', '').replaceAll(']', '');
        vector = cleaned.split(',').map((s) => double.parse(s.trim())).toList();
      } else {
        vector = List<double>.from(embeddingRaw);
      }

      try {
        final matches = await _client.rpc('match_users_by_post', params: {
          'query_embedding': vector,
          'match_threshold': threshold,
          'match_count': maxResults,
          'exclude_user_id': _currentUserId,
        });

        for (final match in (matches as List)) {
          final userId = match['user_id'] as String;
          final similarity = (match['similarity'] as num).toDouble();
          final summary = match['content_summary'] ?? '';
          final matchedPostId = match['post_id'] as String;

          if (!userScores.containsKey(userId) ||
              similarity > (userScores[userId]!['similarity'] as double)) {
            userScores[userId] = {
              'user_id': userId,
              'similarity': similarity,
              'best_match_summary': summary,
              'match_pairs': <Map<String, dynamic>>[],
            };
          }

          final matchPairs =
              userScores[userId]!['match_pairs'] as List<Map<String, dynamic>>;

          // Çeşitlilik & Deduplication Mantığı:
          // 1. Aynı 'other_post_id' zaten eklenmişse geç (karşı tarafın postu eşsiz olsun)
          // 2. Benim aynı 'my_post_id'im bu kullanıcı için zaten 2 kere kullanılmışsa geç (çeşitlilik)
          final myPostOccurrence =
              matchPairs.where((p) => p['my_post_id'] == myPostId).length;

          if (summary.isNotEmpty &&
              summary != 'İçerik yok.' &&
              !matchPairs.any((p) => p['other_post_id'] == matchedPostId) &&
              myPostOccurrence < 2) {
            matchPairs.add({
              'my_post_id': myPostId,
              'my_summary': myContentSummary,
              'my_image': myPostImageUrl,
              'other_post_id': matchedPostId,
              'other_summary': summary,
              'other_image': null, // Sonradan dolacak
              'similarity': similarity,
            });
          }
        }
      } catch (e) {
        continue;
      }
    }

    // 3. Karşı tarafın post görsellerini toplu çek
    final List<String> allOtherPostIds = [];
    for (var userMatch in userScores.values) {
      final pairs = userMatch['match_pairs'] as List<Map<String, dynamic>>;
      for (var p in pairs) {
        allOtherPostIds.add(p['other_post_id']);
      }
    }

    if (allOtherPostIds.isNotEmpty) {
      try {
        final postImages = await _client
            .from('posts')
            .select('id, image_url')
            .inFilter('id', allOtherPostIds);

        final Map<String, String?> imageMap = {
          for (var p in postImages) p['id'] as String: p['image_url'] as String?
        };

        for (var userMatch in userScores.values) {
          final pairs = userMatch['match_pairs'] as List<Map<String, dynamic>>;
          for (var p in pairs) {
            p['other_image'] = imageMap[p['other_post_id']];
          }
        }
      } catch (e) {
        // Hata durumunda görselsiz devam et
      }
    }

    // 4. Kullanıcı profil bilgilerini çek
    final userIds = userScores.keys.toList();
    if (userIds.isEmpty) return [];

    final profiles = await _client
        .from('profiles')
        .select('id, username, full_name, avatar_url')
        .inFilter('id', userIds);

    // 5. Profil bilgilerini birleştir
    final results = <Map<String, dynamic>>[];
    for (final profile in profiles) {
      final userId = profile['id'] as String;
      if (userScores.containsKey(userId)) {
        results.add({
          ...userScores[userId]!,
          'profile': profile,
        });
      }
    }

    results.sort((a, b) =>
        (b['similarity'] as double).compareTo(a['similarity'] as double));

    return results;
  }

  /// İki kullanıcı arasındaki ortak ilgi alanlarını Gemini'ye sorarak açıklar
  Future<String> getAiExplanation({
    required String otherUserId,
    required String otherUserName,
    required List<Map<String, dynamic>> matchPairs,
  }) async {
    try {
      if (matchPairs.isEmpty) return "Ortak paylaşımlarınız harika görünüyor!";

      final myProfile = await _client
          .from('profiles')
          .select('full_name, username')
          .eq('id', _currentUserId)
          .maybeSingle();
      final myName = myProfile?['full_name'] ?? myProfile?['username'] ?? 'Ben';

      // Çiftleri formatlayarak gönder
      final List<String> pairTexts = matchPairs.take(3).map((p) {
        return "Benim Postum: ${p['my_summary']} <-> Onun Postu: ${p['other_summary']}";
      }).toList();

      final response = await _client.functions.invoke(
        'explain-match',
        body: {
          'user1_name': myName,
          'user2_name': otherUserName,
          'match_pairs': pairTexts,
        },
      );

      if (response.status == 200 && response.data != null) {
        return response.data['explanation'] as String;
      }
      return "İkiniz de benzer içerikler paylaşıyorsunuz, hemen iletişime geçin!";
    } catch (e) {
      return "İkinizin de harika paylaşımları var, ortak bir şeyler bulabileceğinize eminim!";
    }
  }
}
