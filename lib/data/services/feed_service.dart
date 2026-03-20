// Kinnect - Feed Service
// Manages post feeds, comments, likes, and social interactions

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'safety_service.dart';

/// Ana akış ve keşfet sayfası için post yönetim servisi.
/// Engelleme filtreleri ve görünürlük kurallarını uygular.
class FeedService {
  final SupabaseClient client;
  final SafetyService _safetyService = SafetyService(); // 🔥 Servis örneği

  FeedService({SupabaseClient? client})
      : client = client ?? Supabase.instance.client;

  // Kullanıcı ID'sini güvenli şekilde al
  String get _myId {
    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('Kullanıcı oturumu kapalı!');
    }
    return user.id;
  }

  // --- 1. ANA AKIŞ (SADECE ARKADAŞLAR + PUBLIC OLMAYANLAR + ÇİFT TARAFLI ENGEL FİLTRESİ) ---
  Future<List<Map<String, dynamic>>> getFriendsFeed() async {
    try {
      // A. Engelleme Listelerini Al (Çift Yönlü)
      // Hem benim engellediklerim, hem de beni engelleyenler
      final myBlocks = await _safetyService.getIdsIBlocked();
      final blockedMe = await _safetyService.getIdsThatBlockedMe();

      // İki listeyi birleştirip tekil (unique) bir liste yapıyoruz
      final allHiddenIds = {...myBlocks, ...blockedMe};

      // B. Takip ettiklerimi (Arkadaşlarımı) bul
      final following = await client
          .from('friendships')
          .select('friend_id')
          .eq('user_id', _myId)
          .eq('status', 'accepted');

      final targetIds =
          (following as List).map((e) => e['friend_id'] as String).toList();

      // Kendi gönderilerimi de ana akışta göreyim
      targetIds.add(_myId);

      // 🔥 C. GİZLİ KULLANICILARI LİSTEDEN ÇIKAR
      // Eğer takip ettiğim biri engellendiyse, ID listesinden siliyoruz
      targetIds.removeWhere((id) => allHiddenIds.contains(id));

      if (targetIds.isEmpty) return [];

      final posts = await client
          .from('posts')
          .select('*, profiles(*), likes(user_id), comments(id)')
          .inFilter('user_id', targetIds)
          .neq('visibility', 'public') // Public olanları ana akıştan gizle
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(posts as List);
    } catch (e) {
      debugPrint('HATA (Arkadaş Akışı): $e');
      return [];
    }
  }

  // --- 2. KEŞFET (HERKES - SADECE PUBLIC OLANLAR + ÇİFT TARAFLI ENGEL FİLTRESİ) ---
  Future<List<Map<String, dynamic>>> getExploreFeed() async {
    try {
      // A. Engelleme Listelerini Al (Çift Yönlü)
      final myBlocks = await _safetyService.getIdsIBlocked();
      final blockedMe = await _safetyService.getIdsThatBlockedMe();
      final allHiddenIds = {...myBlocks, ...blockedMe};

      final response = await client
          .from('posts')
          .select('*, profiles(*), likes(user_id), comments(id)')
          .eq('visibility', 'public') // Sadece herkese açık olanlar
          .order('created_at', ascending: false)
          .limit(50);

      final List<Map<String, dynamic>> allPosts =
          List<Map<String, dynamic>>.from(response as List);

      // 🔥 B. GİZLİ KULLANICILARI FİLTRELE
      // Post sahibi bu "yasaklı listede" ise postu gösterme
      final filteredPosts = allPosts.where((post) {
        final postOwnerId = post['user_id'];
        return !allHiddenIds.contains(postOwnerId);
      }).toList();

      return filteredPosts;
    } catch (e) {
      debugPrint('HATA (Keşfet): $e');
      return [];
    }
  }

  // --- 3. PROFİL POSTLARI ---
  Future<List<Map<String, dynamic>>> getProfilePosts(String userId) async {
    try {
      final response = await client
          .from('posts')
          .select('*, profiles(*), likes(user_id), comments(id)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('HATA (Profil Postları): $e');
      return [];
    }
  }

  /// Post'a ait yorumları getir ve akıllı sıralama uygula
  Future<List<Map<String, dynamic>>> getCommentsWithSmartSorting(
      String postId) async {
    final res = await client
        .from("comments")
        .select("*, profiles(*)")
        .eq("post_id", postId)
        .order("created_at", ascending: true);

    final List<Map<String, dynamic>> rawList =
        List<Map<String, dynamic>>.from(res as List);
    final List<Map<String, dynamic>> sortedList = [];

    for (var comment in rawList) {
      final content = comment['content'] as String? ?? "";
      final match = RegExp(r"^@(\w+)").firstMatch(content);

      bool added = false;

      if (match != null) {
        final targetUsername = match.group(1);
        for (int i = sortedList.length - 1; i >= 0; i--) {
          final p = sortedList[i]['profiles'];
          if (p != null && p['username'] == targetUsername) {
            int insertIndex = i + 1;
            while (insertIndex < sortedList.length) {
              final nextContent =
                  sortedList[insertIndex]['content'] as String? ?? "";
              if (nextContent.startsWith("@")) {
                insertIndex++;
              } else {
                break;
              }
            }
            sortedList.insert(insertIndex, comment);
            added = true;
            break;
          }
        }
      }

      if (!added) {
        sortedList.add(comment);
      }
    }
    return sortedList;
  }

  // --- 4. YORUM STREAM ---
  Stream<List<Map<String, dynamic>>> getCommentsStream(String postId) {
    return client
        .from('comments')
        .stream(primaryKey: ['id'])
        .eq('post_id', postId)
        .order('created_at', ascending: true)
        .asyncMap((rows) async {
          if (rows.isEmpty) return [];

          final userIds =
              rows.map((r) => r['user_id'] as String).toSet().toList();
          final profiles =
              await client.from('profiles').select().inFilter('id', userIds);

          final profileMap = {for (final p in profiles) p['id'] as String: p};

          return rows
              .map((r) => {
                    ...r,
                    'profile': profileMap[r['user_id']] ?? <String, dynamic>{},
                  })
              .toList();
        });
  }

  // --- 5. YORUM EKLEME ---
  Future<void> addComment(String postId, String content) async {
    await client.from('comments').insert({
      'user_id': _myId,
      'post_id': postId,
      'content': content,
    });
  }

  /// Yorum ekle ve bildirimleri yönet
  Future<void> addCommentWithNotifications({
    required String postId,
    required String postOwnerId,
    required String content,
    String? audioUrl,
    Map<String, dynamic>? currentUserProfile,
  }) async {
    await client.from("comments").insert({
      "post_id": postId,
      "user_id": _myId,
      "content": content,
      "audio_url": audioUrl,
    });

    if (postOwnerId != _myId) {
      try {
        // Bildirim kaydı
        await client.from('notifications').insert({
          'user_id': postOwnerId,
          'actor_id': _myId,
          'type': 'comment',
          'post_id': postId,
          'is_read': false,
        });

        // Push bildirimi
        final username = currentUserProfile?['username'] ?? 'Birisi';
        await client.functions.invoke('send-push-notification', body: {
          'target_user_id': postOwnerId,
          'title': '💬 Yeni Yorum',
          'body': '$username gönderine yorum yaptı',
          'type': 'comment',
          'target_id': postId,
        });
      } catch (_) {}
    }
  }

  // --- 6. YORUM SİLME ---
  Future<void> deleteComment(String commentId) async {
    await client.from('comments').delete().eq('id', commentId);
  }

  // --- 7. BEĞENİ / HARLAMA (TOGGLE) ---
  Future<void> toggleLike(String postId, {bool isFuel = false}) async {
    try {
      final existing = await client
          .from('likes')
          .select()
          .eq('user_id', _myId)
          .eq('post_id', postId)
          .maybeSingle();

      if (existing != null) {
        // --- SİLME İŞLEMİ (SÖNDÜRME / VAZGEÇME) ---
        await client.from('likes').delete().eq('id', existing['id']);

        // Bildirimi de temizle
        final typeToDelete = isFuel ? 'fuel' : 'like';
        try {
          await client
              .from('notifications')
              .delete()
              .eq('post_id', postId)
              .eq('actor_id', _myId)
              .eq('type', typeToDelete);
        } catch (_) {}
      } else {
        // --- EKLEME İŞLEMİ (HARLAMA / BEĞENME) ---
        await client.from('likes').insert({
          'user_id': _myId,
          'post_id': postId,
        });

        // Bildirim Gönder (Post sahibi ben değilsem)
        final post = await client
            .from('posts')
            .select('user_id')
            .eq('id', postId)
            .single();
        if (post['user_id'] != _myId) {
          final notifType = isFuel ? 'fuel' : 'like';

          await client.from('notifications').insert({
            'user_id': post['user_id'],
            'actor_id': _myId,
            'type': notifType,
            'post_id': postId,
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

            await client.functions.invoke('send-push-notification', body: {
              'target_user_id': post['user_id'],
              'title': isFuel ? '🔥 Yeni Harlama!' : '❤️ Yeni Beğeni!',
              'body': '$username gönderini ${isFuel ? "harladı" : "beğendi"}',
              'type': notifType,
              'target_id': postId,
            });
          } catch (e) {
            debugPrint('Push bildirim hatası: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('HATA (Like/Fuel): $e');
    }
  }

  // --- 8. POST SİLME ---
  Future<void> deletePost(String postId) async {
    await client.from('posts').delete().eq('id', postId);
  }

  // --- 9. GÖRÜNÜRLÜK GÜNCELLEME ---
  Future<void> updatePostVisibility(String postId, String visibility) async {
    await client.from('posts').update({
      'visibility': visibility,
      'audience': visibility,
    }).eq('id', postId);
  }

  // --- 10. POST DÜZENLEME ---
  Future<void> updatePost(String postId, String newContent) async {
    await client.from('posts').update({
      'content': newContent,
      'is_edited': true,
      'edited_at': DateTime.now().toIso8601String(),
    }).eq('id', postId);
  }

  // --- 11. YORUM DÜZENLEME ---
  Future<void> updateComment(String commentId, String newContent) async {
    await client.from('comments').update({
      'content': newContent,
      'is_edited': true,
      'edited_at': DateTime.now().toIso8601String(),
    }).eq('id', commentId);
  }
  // --- 12. GELİŞMİŞ POST DÜZENLEME ---

  // Etiketleri Getir
  Future<List<Map<String, dynamic>>> getPostTags(String postId) async {
    try {
      final response = await client
          .from('post_tags')
          .select('*, profiles:tagged_user_id(*)') // İlişkili profil bilgisi
          .eq('post_id', postId);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('HATA (Etiketleri Getir): $e');
      return [];
    }
  }

  // Gelişmiş Güncelleme (Foto, Müzik, Etiket, Konum)
  Future<void> updatePostAdvanced({
    required String postId,
    required String content,
    required List<String> imageUrls,
    Map<String, dynamic>? musicData,
    required List<Map<String, dynamic>> tags,
    String? location, // 📍 Yeni: Konum
  }) async {
    // 1. Post içeriğini ve meta verilerini güncelle
    final Map<String, dynamic> updateData = {
      'content': content,
      'image_urls': imageUrls.isNotEmpty ? imageUrls : null,
      'image_url': imageUrls.isNotEmpty ? imageUrls.first : null,
      'location': location, // 📍
      'is_edited': true,
      'edited_at': DateTime.now().toIso8601String(),
    };

    // Müzik verisi varsa güncelle, yoksa null yap (sil)
    if (musicData != null) {
      updateData['spotify_track_id'] = musicData['id'];
      updateData['spotify_track_name'] = musicData['name'];
      updateData['spotify_artist_name'] = musicData['artist'];
      updateData['spotify_preview_url'] = musicData['preview_url'];
      updateData['spotify_album_image'] = musicData['album_image'];
    } else {
      updateData['spotify_track_id'] = null;
      updateData['spotify_track_name'] = null;
      updateData['spotify_artist_name'] = null;
      updateData['spotify_preview_url'] = null;
      updateData['spotify_album_image'] = null;
    }

    await client.from('posts').update(updateData).eq('id', postId);

    // 2. Etiketleri Yönet (Tamamen silip yeniden ekleme stratejisi - daha güvenli)
    // Önce mevcut etiketleri sil
    await client.from('post_tags').delete().eq('post_id', postId);

    // Yeni etiketleri ekle (Eğer varsa)
    if (tags.isNotEmpty) {
      for (final tag in tags) {
        // Tag yapısı: {user_id (tagged_user_id), x, y}
        // Gelen tag listesi 'profiles' içerebilir, ama insert ederken sadece ID lazım.
        // Edit ekranından gelen veri yapısına dikkat edilmeli.

        final String taggedUserId = tag['tagged_user_id'] ?? tag['user_id'];
        final double x = (tag['x_position'] ?? tag['x'] ?? 0.0) as double;
        final double y = (tag['y_position'] ?? tag['y'] ?? 0.0) as double;

        if (taggedUserId.isNotEmpty) {
          await client.from('post_tags').insert({
            'post_id': postId,
            'tagged_user_id': taggedUserId,
            'x_position': x,
            'y_position': y,
          });
        }
      }
    }
  }

  // ==========================================================================
  // 📸 EMOJİ TEPKİLERİ (POST REACTIONS)
  // ==========================================================================

  /// Post'a ait emoji tepkilerini getir
  Future<List<Map<String, dynamic>>> fetchEmojiReactions(String postId) async {
    try {
      final res = await client
          .from('post_reactions')
          .select(
              'id, post_id, user_id, emoji_url, emoji_type, created_at, profiles(*)')
          .eq('post_id', postId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      debugPrint('HATA (Emoji Tepkileri): $e');
      return [];
    }
  }

  /// Emoji tepkisi gönder (fotoğraflı)
  Future<void> sendEmojiReaction({
    required String postId,
    required String emojiUrl,
    required String emojiType,
  }) async {
    try {
      // Mevcut tepkiyi kontrol et ve varsa güncelle
      final existing = await client
          .from('post_reactions')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', _myId)
          .maybeSingle();

      if (existing != null) {
        // Güncelle
        await client.from('post_reactions').update({
          'emoji_url': emojiUrl,
          'emoji_type': emojiType,
        }).eq('id', existing['id']);
      } else {
        // Yeni ekle
        await client.from('post_reactions').insert({
          'post_id': postId,
          'user_id': _myId,
          'emoji_url': emojiUrl,
          'emoji_type': emojiType,
        });

        // Bildirim gönder
        final post = await client
            .from('posts')
            .select('user_id')
            .eq('id', postId)
            .single();

        if (post['user_id'] != _myId) {
          await client.from('notifications').insert({
            'user_id': post['user_id'],
            'actor_id': _myId,
            'type': 'reaction',
            'post_id': postId,
            'is_read': false,
          });
        }
      }
    } catch (e) {
      debugPrint('HATA (Emoji Tepki Gönder): $e');
      rethrow;
    }
  }

  /// Emoji tepkisini sil
  Future<void> deleteReaction(String reactionId) async {
    await client.from('post_reactions').delete().eq('id', reactionId);
  }

  // ==========================================================================
  // ❤️ BEĞENENLERİ GETİR
  // ==========================================================================

  /// Post'u beğenenlerin listesini getir
  Future<List<Map<String, dynamic>>> fetchLikers(String postId) async {
    try {
      final response = await client
          .from('likes')
          .select('user_id, created_at, profiles(*)')
          .eq('post_id', postId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('HATA (Beğenenler): $e');
      return [];
    }
  }

  // ==========================================================================
  // 🔊 SESLİ YORUM
  // ==========================================================================

  /// Sesli yorum gönder
  Future<void> addAudioComment({
    required String postId,
    required String audioUrl,
  }) async {
    await client.from('comments').insert({
      'user_id': _myId,
      'post_id': postId,
      'audio_url': audioUrl,
    });
  }

  // --- VIDEO UPLOAD ---
  Future<String> uploadVideo(File videoFile) async {
    final fileName = '$_myId/video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final bytes = await videoFile.readAsBytes();
    await client.storage.from('uploads').uploadBinary(
      fileName,
      bytes,
      fileOptions: const FileOptions(upsert: true, contentType: 'video/mp4'),
    );
    return client.storage.from('uploads').getPublicUrl(fileName);
  }

  // --- VIDEO FRAME EXTRACT & UPLOAD ---
  Future<List<String>> extractAndUploadVideoFrames(String videoPath) async {
    final List<String> frameUrls = [];
    final info = await VideoCompress.getMediaInfo(videoPath);
    final duration = info.duration?.toInt() ?? 7000; // ms
    final timestamps = [0, (duration * 0.5).toInt(), duration - 100];

    for (int i = 0; i < timestamps.length; i++) {
      try {
        final Uint8List? thumbData = await VideoThumbnail.thumbnailData(
          video: videoPath,
          imageFormat: ImageFormat.JPEG,
          timeMs: timestamps[i].clamp(0, duration),
          quality: 80,
        );
        if (thumbData == null) continue;
        final frameName = '$_myId/frame_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        await client.storage.from('uploads').uploadBinary(
          frameName,
          thumbData,
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );
        frameUrls.add(client.storage.from('uploads').getPublicUrl(frameName));
      } catch (_) {}
    }
    return frameUrls;
  }

  /// Yeni gönderi oluştur (Resim, Müzik, Etiket, Konum, Video)
  Future<String> createPost({
    required String content,
    required List<File> imageFiles,
    required String visibility,
    Map<String, dynamic>? selectedMusic,
    String? location,
    List<Map<String, dynamic>> photoTags = const [],
    File? videoFile, // NEW
  }) async {
    List<String> imageUrls = [];

    // 1. Resimleri Yükle
    for (int i = 0; i < imageFiles.length; i++) {
      final file = imageFiles[i];
      final fileExt = file.path.split('.').last;
      final fileName =
          '$_myId/${DateTime.now().millisecondsSinceEpoch}_$i.$fileExt';

      await client.storage.from('uploads').uploadBinary(
            fileName,
            await file.readAsBytes(),
            fileOptions: const FileOptions(upsert: true),
          );

      final url = client.storage.from('uploads').getPublicUrl(fileName);
      imageUrls.add(url);
    }

    // 1b. Video Yükle (varsa)
    String? videoUrl;
    List<String> videoFrameUrls = [];
    if (videoFile != null) {
      // Compress video
      final MediaInfo? compressed = await VideoCompress.compressVideo(
        videoFile.path,
        quality: VideoQuality.HighestQuality,
        deleteOrigin: false,
        includeAudio: true,
      );
      final fileToUpload = compressed?.file ?? videoFile;
      videoUrl = await uploadVideo(fileToUpload);
      videoFrameUrls = await extractAndUploadVideoFrames(videoFile.path);
      VideoCompress.cancelCompression();
    }

    // 2. Postu Oluştur
    final postResponse = await client
        .from('posts')
        .insert({
          'user_id': _myId,
          'content': content,
          'image_url': imageUrls.isNotEmpty ? imageUrls.first : null,
          'image_urls': imageUrls.isNotEmpty ? imageUrls : null,
          'visibility': visibility,
          if (selectedMusic != null) ...{
            'spotify_track_id': selectedMusic['id'],
            'spotify_track_name': selectedMusic['name'],
            'spotify_artist_name': selectedMusic['artist'],
            'spotify_preview_url': selectedMusic['preview_url'],
            'spotify_album_image': selectedMusic['album_image'],
          },
          'location': location,
          if (videoUrl != null) ...{
            'video_url': videoUrl,
            'video_frame_urls': videoFrameUrls,
          },
        })
        .select('id')
        .single();

    final postId = postResponse['id'];

    // 3. Etiketleri Kaydet ve Bildirim Gönder
    if (photoTags.isNotEmpty && imageUrls.isNotEmpty) {
      for (final tag in photoTags) {
        try {
          final taggedUserId = tag['user']['id'];
          await client.from('post_tags').insert({
            'post_id': postId,
            'tagged_user_id': taggedUserId,
            'x_position': tag['x'],
            'y_position': tag['y'],
          });

          // DB Bildirimi
          await client.from('notifications').insert({
            'user_id': taggedUserId,
            'actor_id': _myId,
            'type': 'tag',
            'post_id': postId,
            'is_read': false,
          });

          // Push Bildirim
          try {
            final myProfile = await client
                .from('profiles')
                .select('username')
                .eq('id', _myId)
                .single();
            final username = myProfile['username'] ?? 'Birisi';

            await client.functions.invoke('send-push-notification', body: {
              'target_user_id': taggedUserId,
              'title': '📸 Fotoğrafta Etiketlendin!',
              'body': '$username seni bir fotoğrafta etiketledi',
              'type': 'tag',
              'target_id': postId,
            });
          } catch (_) {}
        } catch (_) {}
      }
    }

    // Analizi arka planda tetikle (fire-and-forget)
    client.functions.invoke('analyze-user-profile', body: {'user_id': _myId}).ignore();

    return postId;
  }
}
