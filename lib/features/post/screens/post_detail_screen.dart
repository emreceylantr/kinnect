// Kinnect - Post detay ve yorumlar (post_detail_screen.dart)

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kinnect/shared/widgets/photo_emoji_picker.dart';
import '../../../co../../../core/theme/app_colors.dart';

import '../../../data/services/feed_service.dart';
import '../../../data/services/safety_service.dart';
import '../../../data/services/toxicity_service.dart';

import '../../create_post/screens/edit_post_screen.dart';

import '../widgets/post_detail_card.dart';
import '../widgets/post_comments_list.dart';
import '../widgets/comment_input_area.dart';
import '../widgets/post_report_dialogs.dart';
import '../widgets/likers_sheet.dart';
import '../widgets/reactions_sheet.dart';

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isExploreMode;

  const PostDetailScreen({
    super.key,
    required this.post,
    this.isExploreMode = false,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  // 🔧 SERVİSLER
  final FeedService _feedService = FeedService();
  final SafetyService _safetyService = SafetyService();
  final ToxicityService _toxicityService = ToxicityService();

  // 🔌 SUPAbase (sadece gerekli yerlerde)
  final SupabaseClient client = Supabase.instance.client;

  // 🎤 SES KAYIT
  final TextEditingController commentController = TextEditingController();
  final AudioRecorder audioRecorder = AudioRecorder();
  final AudioPlayer audioPlayer = AudioPlayer();

  List<Map<String, dynamic>> comments = [];
  bool loadingComments = true;
  late bool isLiked;
  late bool isFueled;
  late int likeCount;
  late int fuelCount;
  late int commentCount;

  bool isAlive = true;
  bool isRecording = false;
  bool _isSendingComment = false; // 🔒 Çift yorum engelleme
  Timer? recordTimer;
  int recordDuration = 0;
  String? playingCommentId;
  bool isComposing = false;

  // 🆕 Yanıtla özelliği
  Map<String, dynamic>? replyingToComment;

  // 📸 Emoji tepkileri
  List<Map<String, dynamic>> emojiReactions = [];

  // 🎧 Müzik oynatıcı state
  final AudioPlayer _musicPlayer = AudioPlayer();
  bool _isMusicPlaying = false;
  bool _isMusicMuted = false; // 🔊 Başlangıçta sesli

  // ✏️ Post düzenleme state
  String? _editedPostContent;

  // 👤 Kullanıcı Profili (Optimistic UI için)
  Map<String, dynamic>? _currentUserProfile;

  // ✏️ Yorum düzenleme state
  final TextEditingController _editCommentController = TextEditingController();

  String get myId => client.auth.currentUser!.id;

  // 📸 Emoji tipinden varsayılan emoji karakterini al

  @override
  void initState() {
    super.initState();

    final likes = widget.post['likes'] as List<dynamic>? ?? [];

    isLiked = likes.any((l) => l["user_id"] == myId);
    isFueled = isLiked;
    likeCount = likes.length;
    fuelCount = likeCount;

    final date = DateTime.tryParse(widget.post['created_at'] ?? '')?.toLocal();
    if (date != null && DateTime.now().difference(date).inHours >= 24) {
      isAlive = false;
    }

    commentCount = (widget.post['comments'] as List?)?.length ?? 0;
    _fetchComments();
    _fetchEmojiReactions(); // 📸 Emoji tepkileri

    // 🎧 MÜZİK OTOMATİK OYNATMA (SESLİ BAŞLA)
    final previewUrl = widget.post['spotify_preview_url'];
    if (previewUrl != null) {
      // Sayfa açıldıktan 0.5sn sonra başlat - SESLİ
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (mounted) {
          await _musicPlayer.setVolume(1.0); // 🔊 Sesli başla
          await _musicPlayer.play(UrlSource(previewUrl));
          setState(() {
            _isMusicPlaying = true;
            _isMusicMuted = false;
          });

          // 30 saniye sonra dur
          Future.delayed(const Duration(seconds: 30), () {
            if (mounted && _isMusicPlaying) {
              _musicPlayer.stop();
              setState(() => _isMusicPlaying = false);
            }
          });
        }
      });
    }

    _loadCurrentUserProfile();

    commentController.addListener(() {
      setState(() {
        isComposing = commentController.text.trim().isNotEmpty;
      });
    });

    audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) setState(() => playingCommentId = null);
    });
  }

  @override
  void dispose() {
    commentController.dispose();
    audioRecorder.dispose();
    audioPlayer.dispose();
    _musicPlayer.dispose(); // 🎧 Müzik player temizle
    recordTimer?.cancel();
    super.dispose();
  }

  // *********************************************************
  // 🛡️ ŞİKAYET ETME FONKSİYONLARI
  // *********************************************************

  Future<void> _submitReport(String reason, String? description) async {
    try {
      await _safetyService.reportContent(
        targetId: widget.post['id'],
        type: 'post',
        reason: reason,
        description:
            (description == null || description.isEmpty) ? null : description,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Bildirimin alındı. Teşekkürler! 🛡️"),
            backgroundColor: AppColors.accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Hata: $e"),
              backgroundColor: AppColors.accentRedAccent),
        );
      }
    }
  }

  // *********************************************************
  // 🔥 YORUMLAR VE DİĞER İŞLEMLER (GÜNCELLENDİ)
  // *********************************************************

  Future<void> _fetchComments() async {
    try {
      final sortedList =
          await _feedService.getCommentsWithSmartSorting(widget.post['id']);

      if (mounted) {
        setState(() {
          comments = sortedList;
          commentCount = comments.length;
          loadingComments = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => loadingComments = false);
      }
    }
  }

  // 📸 EMOJİ TEPKİLERİNİ ÇEK
  Future<void> _fetchEmojiReactions() async {
    final reactions = await _feedService.fetchEmojiReactions(widget.post['id']);
    if (mounted) {
      setState(() => emojiReactions = reactions);
    }
  }

  void _toggleLike() async {
    setState(() {
      isLiked = !isLiked;
      likeCount += isLiked ? 1 : -1;
    });
    await _feedService.toggleLike(widget.post["id"], isFuel: false);
  }

  void _toggleFuel() async {
    if (!isAlive) return;
    setState(() {
      isFueled = !isFueled;
      fuelCount += isFueled ? 1 : -1;
    });
    await FeedService().toggleLike(widget.post["id"], isFuel: true);
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await _feedService.deleteComment(commentId);
      if (!mounted) return;
      setState(() {
        comments.removeWhere((c) => c['id'] == commentId);
        commentCount--;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Yorum silindi.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Silinemedi.')));
      }
    }
  }

  void _confirmDelete(String commentId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text("Yorumu Sil", style: TextStyle(color: Colors.white)),
        content: const Text("Bu yorumu silmek istediğine emin misin?",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteComment(commentId);
            },
            child: const Text("Sil",
                style: TextStyle(color: AppColors.accentRedAccent)),
          ),
        ],
      ),
    );
  }

  // ✏️ POST DÜZENLEME EKRANINA GİT
  Future<void> _showEditPostDialog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditPostScreen(post: widget.post),
      ),
    );

    if (result == true) {
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  // 🗑️ POST SİLME
  void _confirmDeletePost() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            const Text("Gönderiyi Sil", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Bu gönderiyi silmek istediğine emin misin? Bu işlem geri alınamaz.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deletePost();
            },
            child: const Text("Sil",
                style: TextStyle(color: AppColors.accentRedAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost() async {
    try {
      await FeedService().deletePost(widget.post['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gönderi silindi! 🗑️'),
            backgroundColor: AppColors.accentRedAccent,
          ),
        );
        Navigator.pop(context, true); // Feed'i yenilemek için true döndür
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: AppColors.accentRedAccent),
        );
      }
    }
  }

  // ✏️ YORUM DÜZENLEME DIALOG'U
  void _showEditCommentDialog(Map<String, dynamic> comment) {
    _editCommentController.text = comment['content'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.bgCardLight,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.08), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  "Yorumu Düzenle",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _editCommentController,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Yorumun...",
                  hintStyle: GoogleFonts.poppins(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.black26,
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "Vazgeç",
                        style: GoogleFonts.poppins(
                            color: Colors.white38, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final newContent = _editCommentController.text.trim();
                        if (newContent.isEmpty) return;

                        Navigator.pop(ctx);
                        await _updateComment(comment['id'], newContent);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      child: Text(
                        "Kaydet",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✏️ YORUM GÜNCELLEME
  Future<void> _updateComment(String commentId, String newContent) async {
    try {
      await _feedService.updateComment(commentId, newContent);
      // Yorumları yenile
      _fetchComments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yorum güncellendi! ✏️'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: AppColors.accentRedAccent),
        );
      }
    }
  }

  // 📸 EMOİJİ TEPKİSİNİ SİL
  Future<void> _deleteReaction(String reactionId) async {
    try {
      await _feedService.deleteReaction(reactionId);
      _fetchEmojiReactions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tepki silindi! 🗑️'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      debugPrint("Tepki silme hatası: $e");
    }
  }

  void _confirmDeleteReaction(Map<String, dynamic> reaction) {
    // Sadece kendi tepkimizi silebiliriz
    if (reaction['user_id'] != myId) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Tepkiyi Sil", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: NetworkImage(reaction['emoji_url'] ?? ''),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text("Bu tepkiyi silmek istediğine emin misin?",
                style: TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteReaction(reaction['id']);
            },
            child: const Text("Sil",
                style: TextStyle(color: AppColors.accentRedAccent)),
          ),
        ],
      ),
    );
  }

  // 👤 Yorum kartında görünmesi için profilimi çek
  Future<void> _loadCurrentUserProfile() async {
    try {
      final res =
          await client.from('profiles').select().eq('id', myId).maybeSingle();
      if (mounted && res != null) {
        setState(() => _currentUserProfile = res);
      }
    } catch (_) {}
  }

  Future<void> _sendTextComment() async {
    final msg = commentController.text.trim();
    if (msg.isEmpty) return;

    if (_isSendingComment) return;
    setState(() => _isSendingComment = true);

    final replyToUsername = replyingToComment?['profiles']?['username'];
    final finalMsg = replyToUsername != null ? "@$replyToUsername $msg" : msg;
    final tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';

    // 🚀 ÖNCE Optimistic UI update - ANINDA göster
    final optimisticComment = {
      'id': tempId,
      'content': finalMsg,
      'created_at': DateTime.now().toIso8601String(),
      'user_id': myId,
      'profiles': _currentUserProfile ??
          {'username': '...', 'avatar_url': null, 'full_name': '...'},
    };

    setState(() {
      comments.add(optimisticComment);
      commentCount++;
      commentController.clear();
      isComposing = false;
      replyingToComment = null;
      _isSendingComment = false;
    });

    FocusScope.of(context).unfocus();

    // 🔒 Arka planda toxicity check
    final isToxic = await _toxicityService.checkToxicity(msg);
    if (isToxic) {
      // Toxic ise yorumu kaldır
      if (mounted) {
        setState(() {
          comments.removeWhere((c) => c['id'] == tempId);
          commentCount--;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.block, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '⛔ Bu yorum uygunsuz içerik barındırıyor!',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // ✅ Temiz ise veritabanına gönder
    try {
      await _feedService.addCommentWithNotifications(
        postId: widget.post['id'],
        postOwnerId: widget.post['user_id'],
        content: finalMsg,
        currentUserProfile: _currentUserProfile,
      );
      // Gerçek veriyi çek ama sessiz ol
      if (mounted) _fetchComments();
    } catch (e) {
      if (mounted) {
        // Hata olursa optimistic yorumu kaldır
        setState(() {
          comments.removeWhere((c) => c['id'] == tempId);
          commentCount--;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Yorum gönderilemedi ❌")));
      }
    }
  }

  // 📸 YENİ: FOTOĞRAF EMOJİ TEPKİSİ GÖNDER
  Future<void> _sendEmojiReaction(String emojiPath, String emojiType) async {
    // Upsert kullanıldığı için buradaki manuel kontrolü kaldırıyoruz.
    // Böylece kullanıcı tepkisini değiştirebilir/güncelleyebilir.

    try {
      // Fotoğrafı Supabase Storage'a yükle
      final file = File(emojiPath);
      final fileName = 'reaction_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = 'post_reactions/$fileName';

      await client.storage.from('uploads').upload(storagePath, file);
      final imageUrl = client.storage.from('uploads').getPublicUrl(storagePath);

      // post_reactions tablosuna kaydet (varsa güncelle - upsert)
      await client.from("post_reactions").upsert({
        "post_id": widget.post["id"],
        "user_id": myId,
        "emoji_url": imageUrl,
        "emoji_type": emojiType, // Emoji tipi (happy, sad, love vs.)
      }, onConflict: 'post_id,user_id');

      // Bildirim gönder
      if (widget.post['user_id'] != myId) {
        try {
          await client.from('notifications').insert({
            'user_id': widget.post['user_id'],
            'actor_id': myId,
            'type': 'reaction',
            'post_id': widget.post['id'],
            'is_read': false,
          });

          final myProfile = await client
              .from('profiles')
              .select('username')
              .eq('id', myId)
              .single();
          final username = myProfile['username'] ?? 'Birisi';

          await client.functions.invoke('send-push-notification', body: {
            'target_user_id': widget.post['user_id'],
            'title': '📸 Foto Tepki',
            'body': '$username gönderine tepki verdi',
            'type': 'reaction',
            'target_id': widget.post['id'],
          });
        } catch (_) {}
      }

      // Tepkileri yenile
      _fetchEmojiReactions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tepki gönderildi! 📸'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      debugPrint("Emoji tepki hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppColors.accentRedAccent,
          ),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    if (await audioRecorder.hasPermission()) {
      final dir = await getApplicationDocumentsDirectory();
      final path =
          "${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a";

      await audioRecorder.start(const RecordConfig(), path: path);

      setState(() {
        isRecording = true;
        recordDuration = 0;
      });

      recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => recordDuration++);
        if (recordDuration >= 15) _stopRecording();
      });
    }
  }

  Future<void> _stopRecording() async {
    recordTimer?.cancel();
    if (!isRecording) return;

    final path = await audioRecorder.stop();
    setState(() => isRecording = false);

    if (path != null && recordDuration > 1) {
      _uploadAndSendAudio(path);
    }
  }

  Future<void> _uploadAndSendAudio(String filePath) async {
    try {
      final file = File(filePath);
      final name = "comment_audio/${DateTime.now().millisecondsSinceEpoch}.m4a";

      await client.storage.from("uploads").upload(name, file);

      final url = client.storage.from("uploads").getPublicUrl(name);

      await client.from("comments").insert({
        "post_id": widget.post["id"],
        "user_id": myId,
        "content": "🎤 Sesli Yorum",
        "audio_url": url,
      });

      _fetchComments();
    } catch (e) {
      debugPrint("Ses yükleme hatası: $e");
    }
  }

  Future<void> _playPause(String url, String id) async {
    if (playingCommentId == id) {
      await audioPlayer.stop();
      setState(() => playingCommentId = null);
    } else {
      await audioPlayer.stop();
      setState(() => playingCommentId = id);
      await audioPlayer.play(UrlSource(url));
    }
  }

  // *********************************************************
  // 🧱 UI
  // *********************************************************

  // 🔊 Müzik sesini aç/kapat
  void _toggleMusicMute() {
    if (_isMusicPlaying) {
      setState(() {
        _isMusicMuted = !_isMusicMuted;
        _musicPlayer.setVolume(_isMusicMuted ? 0.0 : 1.0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 👆 Sağa swipe ile geri git
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
          Navigator.of(context).pop();
        }
      },
      // 👆 Ekrana tap ile müzik aç/kapat
      onTap: _toggleMusicMute,
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: BackButton(color: Colors.white),
          elevation: 0,
          centerTitle: true,
          title: Text(
            widget.isExploreMode ? "Ateşin Başı 🔥" : "Gönderi",
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
          // 🔊 Müzik muted göstergesi
          actions: [
            if (_isMusicPlaying)
              IconButton(
                icon: Icon(
                  _isMusicMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white70,
                ),
                onPressed: _toggleMusicMute,
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    PostDetailCard(
                      post: widget.post,
                      myId: myId,
                      isAlive: isAlive,
                      isExploreMode: widget.isExploreMode,
                      isLiked: isLiked,
                      isFueled: isFueled,
                      likeCount: likeCount,
                      fuelCount: fuelCount,
                      commentCount: commentCount,
                      isEdited: widget.post['is_edited'] == true ||
                          _editedPostContent != null,
                      emojiReactions: emojiReactions,
                      onToggleLike: _toggleLike,
                      onToggleFuel: _toggleFuel,
                      onShowLikers: () => LikersSheet.show(
                        context,
                        likersFuture:
                            _feedService.fetchLikers(widget.post['id']),
                        likeCount: likeCount,
                      ),
                      onShowReport: () => PostReportDialog.show(
                        context,
                        onReportSubmit: _submitReport,
                      ),
                      onShowEdit: _showEditPostDialog,
                      onDeletePost: _confirmDeletePost,
                      onShowAllReactions: () => ReactionsSheet.show(
                        context,
                        emojiReactions: emojiReactions,
                        myId: myId,
                        onDeleteReaction: _confirmDeleteReaction,
                      ),
                      onShowPhotoEmojiPicker: showPhotoEmojiPicker,
                      onSendEmojiReaction: (path, type) =>
                          _sendEmojiReaction(path, type),
                    ),
                    PostCommentsList(
                      loadingComments: loadingComments,
                      comments: comments,
                      myId: myId,
                      postOwnerId: widget.post['user_id'],
                      isExploreMode: widget.isExploreMode,
                      playingCommentId: playingCommentId,
                      onEditComment: _showEditCommentDialog,
                      onDeleteComment: _confirmDelete,
                      onPlayPauseAudio: _playPause,
                      onReplyToComment: (comment) {
                        setState(() {
                          replyingToComment = comment;
                        });
                        FocusScope.of(context).requestFocus(FocusNode());
                      },
                    ),
                  ],
                ),
              ),
            ),
            CommentInputArea(
              controller: commentController,
              isComposing: isComposing,
              isRecording: isRecording,
              recordDuration: recordDuration,
              replyingToComment: replyingToComment,
              isSending: _isSendingComment,
              onSendTextComment: _sendTextComment,
              onStartRecording: _startRecording,
              onStopRecording: _stopRecording,
              onCancelReply: () => setState(() => replyingToComment = null),
              onShowPhotoEmojiPicker: showPhotoEmojiPicker,
              onSendEmojiReaction: (path, type) =>
                  _sendEmojiReaction(path, type),
            ),
          ],
        ),
      ),
    );
  }
}
