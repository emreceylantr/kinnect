import 'dart:async';
import 'dart:io';
import 'dart:ui'; // 🔥 BUZLU CAM İÇİN GEREKLİ
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../widgets/fuel_button.dart';
import '../services/feed_service.dart';
import '../services/safety_service.dart'; // Güvenlik servisi (Şikayet için)
import '../services/toxicity_service.dart'; // 🤖 AI Toxic yorum kontrolü
import '../screens/profile_screen.dart';

import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

import '../widgets/photo_emoji_picker.dart'; // 📸 Photo Emoji Tepkileri

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
  final SupabaseClient client = Supabase.instance.client;
  final TextEditingController commentController = TextEditingController();
  final AudioRecorder audioRecorder = AudioRecorder();
  final AudioPlayer audioPlayer = AudioPlayer();
  final SafetyService _safetyService = SafetyService();
  final ToxicityService _toxicityService = ToxicityService(); // 🤖 AI servisi

  List<Map<String, dynamic>> comments = [];
  bool loadingComments = true;
  late bool isLiked;
  late bool isFueled;
  late int likeCount;
  late int fuelCount;
  late int commentCount;

  bool isAlive = true;
  bool isRecording = false;
  Timer? recordTimer;
  int recordDuration = 0;
  String? playingCommentId;
  bool isComposing = false;

  // 📸 Emoji tepkileri
  List<Map<String, dynamic>> emojiReactions = [];

  String get myId => client.auth.currentUser!.id;

  // 📸 Emoji tipinden varsayılan emoji karakterini al
  String _getEmojiIcon(String? emojiType) {
    if (emojiType == null) return '📸';

    // PhotoEmojiType enum değerlerine göre eşleştir
    switch (emojiType) {
      case 'smile':
        return '😊';
      case 'cry':
        return '😢';
      case 'laugh':
        return '😂';
      case 'surprise':
        return '😮';
      case 'thumbsUp':
        return '👍';
      case 'love':
        return '😍';
      default:
        return '📸';
    }
  }

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
    _fetchEmojiReactions(); // 📸 Emoji tepkilerini yükle

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
    recordTimer?.cancel();
    super.dispose();
  }

  // *********************************************************
  // 🛡️ ŞİKAYET ETME FONKSİYONLARI
  // *********************************************************

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final reasons = [
          "Spam veya Yanıltıcı",
          "Çıplaklık veya Cinsellik",
          "Nefret Söylemi",
          "Şiddet veya Tehlikeli",
          "Zorbalık veya Taciz",
          "Diğer"
        ];
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: const Color(0xFF252525),
                borderRadius: BorderRadius.circular(24),
                border:
                    Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5)
                ]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Şikayet Et",
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text("Bu gönderiyi neden bildiriyorsun?",
                    style: GoogleFonts.poppins(
                        color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 20),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: List.generate(reasons.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(ctx);
                              _showReportDetailsDialog(reasons[index]);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(reasons[index],
                                      style: GoogleFonts.poppins(
                                          color: Colors.white70,
                                          fontSize: 12.5)),
                                  const Icon(Icons.arrow_forward_ios_rounded,
                                      color: Colors.white24, size: 12),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: Text("Vazgeç",
                        style: GoogleFonts.poppins(
                            color: Colors.white38, fontSize: 13)),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReportDetailsDialog(String reason) {
    final TextEditingController detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: const Color(0xFF252525),
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: Colors.white.withOpacity(0.08), width: 1),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5)
              ]),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Text("Ek Açıklama",
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600))),
              const SizedBox(height: 15),
              Text("Seçilen: $reason",
                  style:
                      GoogleFonts.poppins(color: Colors.orange, fontSize: 12)),
              const SizedBox(height: 5),
              Text("Detay eklemek istersen aşağıya yazabilirsin.",
                  style:
                      GoogleFonts.poppins(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 15),
              TextField(
                controller: detailsController,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Buraya yaz...",
                  hintStyle:
                      GoogleFonts.poppins(color: Colors.white24, fontSize: 14),
                  filled: true,
                  fillColor: Colors.black26,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: Text("Vazgeç",
                          style: GoogleFonts.poppins(
                              color: Colors.white38, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _submitReport(reason, detailsController.text.trim());
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0),
                      child: Text("Gönder",
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitReport(String reason, String description) async {
    try {
      await _safetyService.reportContent(
        targetId: widget.post['id'],
        type: 'post',
        reason: reason,
        description: description.isEmpty ? null : description,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Bildirimin alındı. Teşekkürler! 🛡️"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Hata: $e"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // *********************************************************
  // 🔥 YORUMLAR VE DİĞER İŞLEMLER
  // *********************************************************

  Future<void> _fetchComments() async {
    try {
      final res = await client
          .from("comments")
          .select("*, profiles(*)")
          .eq("post_id", widget.post['id'])
          .order("created_at", ascending: true);

      if (mounted) {
        setState(() {
          comments = List<Map<String, dynamic>>.from(res as List);
          commentCount = comments.length;
          loadingComments = false;
        });
      }
    } catch (_) {}
  }

  // 📸 EMOJİ TEPKİLERİNİ ÇEK
  Future<void> _fetchEmojiReactions() async {
    try {
      final res = await client
          .from("post_reactions")
          .select(
              "id, post_id, user_id, emoji_url, emoji_type, created_at, profiles(*)") // Açıkça belirt
          .eq("post_id", widget.post['id'])
          .order("created_at", ascending: false);

      if (mounted) {
        setState(() {
          emojiReactions = List<Map<String, dynamic>>.from(res as List);
        });
      }
    } catch (e) {
      debugPrint("Emoji tepkileri yüklenirken hata: $e");
    }
  }

  void _toggleLike() async {
    setState(() {
      isLiked = !isLiked;
      likeCount += isLiked ? 1 : -1;
    });
    await FeedService().toggleLike(widget.post["id"], isFuel: false);
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
      await client.from('comments').delete().eq('id', commentId);
      setState(() {
        comments.removeWhere((c) => c['id'] == commentId);
        commentCount--;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Yorum silindi.')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Silinemedi.')));
    }
  }

  void _confirmDelete(String commentId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
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
            child: const Text("Sil", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  // 📸 EMOJİ TEPKİSİNİ SİL
  Future<void> _deleteReaction(String reactionId) async {
    try {
      await client.from('post_reactions').delete().eq('id', reactionId);
      _fetchEmojiReactions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tepki silindi! 🗑️'),
            backgroundColor: Color(0xFF6C63FF),
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
        backgroundColor: const Color(0xFF1E1E1E),
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
            child: const Text("Sil", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendTextComment() async {
    final msg = commentController.text.trim();
    if (msg.isEmpty) return;

    // 🤖 ML-BASED TOXIC KONTROL
    final isToxic = await _toxicityService.checkToxicity(msg);

    if (isToxic) {
      // Yorumu silme ve uyarı göster
      if (mounted) {
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
      return; // Yorumu gönderme!
    }

    commentController.clear();
    setState(() => isComposing = false);

    try {
      await client.from("comments").insert({
        "post_id": widget.post["id"],
        "user_id": myId,
        "content": msg,
        "audio_url": null,
      });

      if (widget.post['user_id'] != myId) {
        try {
          await client.from('notifications').insert({
            'user_id': widget.post['user_id'],
            'actor_id': myId,
            'type': 'comment',
            'post_id': widget.post['id'],
            'is_read': false,
          });

          // 🔔 PUSH BİLDİRİM GÖNDER
          final myProfile = await client
              .from('profiles')
              .select('username')
              .eq('id', myId)
              .single();
          final username = myProfile['username'] ?? 'Birisi';

          await client.functions.invoke('send-push-notification', body: {
            'target_user_id': widget.post['user_id'],
            'title': '💬 Yeni Yorum',
            'body': '$username gönderine yorum yaptı',
            'type': 'comment',
            'target_id': widget.post['id'],
          });
        } catch (_) {}
      }

      _fetchComments();
    } catch (e) {
      debugPrint("Yorum hatası: $e");
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
            backgroundColor: Color(0xFF6C63FF),
          ),
        );
      }
    } catch (e) {
      debugPrint("Emoji tepki hatası: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // 📸 TÜM TEPKİLERİ GÖSTEREN DİALOG
  void _showAllReactionsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Başlık
            Text(
              '📸 Tepkiler (${emojiReactions.length})',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Grid tepkiler
            Expanded(
              child: GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.all(12), // Taşma payı için padding
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 16, // Daha geniş aralık
                  mainAxisSpacing: 24, // Dikeyde daha geniş aralık (taşma için)
                  childAspectRatio: 0.75, // Daha uzun dikey alan
                ),
                itemCount: emojiReactions.length,
                itemBuilder: (context, index) {
                  final reaction = emojiReactions[index];
                  final profile = reaction['profiles'] ?? {};
                  final isMyReaction = reaction['user_id'] == myId;
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ProfileScreen(userId: reaction['user_id']),
                        ),
                      );
                    },
                    onLongPress: isMyReaction
                        ? () {
                            Navigator.pop(context);
                            _confirmDeleteReaction(reaction);
                          }
                        : null,
                    child: Column(
                      children: [
                        // Fotoğraf ve emoji tipi göstergesi
                        // Fotoğraf ve emoji tipi göstergesi
                        Stack(
                          clipBehavior: Clip
                              .none, // BeReal efekti için taşmayı serbest bırak
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF6C63FF),
                                  width: 2,
                                ),
                                image: DecorationImage(
                                  image:
                                      NetworkImage(reaction['emoji_url'] ?? ''),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            // Emoji tipi göstergesi (sağ alt + taşan)
                            Positioned(
                              right: -8,
                              bottom: -8,
                              child: Text(
                                _getEmojiIcon(reaction['emoji_type']),
                                style: const TextStyle(
                                    fontSize: 30), // DAHA BÜYÜK EMOJİ
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile['username'] ?? 'Kullanıcı',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
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
      final name = "comment_${DateTime.now().millisecondsSinceEpoch}.m4a";

      await client.storage.from("uploads").upload("comment_audio/$name", file);

      final url =
          client.storage.from("uploads").getPublicUrl("comment_audio/$name");

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: const BackButton(color: Colors.white),
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.isExploreMode ? "Ateşin Başı 🔥" : "Gönderi",
          style: GoogleFonts.poppins(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildPostCard(),
                  _buildComments(),
                ],
              ),
            ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  // 🔥 BUZLU CAM (GLASSMORPHISM) VE MOR KALP TEMALI DETAY KARTI 🔥
  Widget _buildPostCard() {
    final profile = widget.post["profiles"] ?? {};
    final text = widget.post["content"] ?? "";
    final image = widget.post["image_url"];
    final date = DateTime.tryParse(widget.post["created_at"] ?? "");
    final dateStr = date != null ? "${date.day}/${date.month}" : "";

    final isMyPost = widget.post["user_id"] == myId;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      color: Colors.transparent, // Efekt için şeffaf
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0), // 🔥 Buzlanma
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08), // Yarı saydam
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1), // İnce çerçeve
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- HEADER ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ProfileScreen(
                                    userId: widget.post["user_id"]))),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundImage: profile["avatar_url"] != null
                              ? NetworkImage(profile["avatar_url"])
                              : null,
                          backgroundColor: Colors.grey[900],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(profile["full_name"] ?? "İsimsiz",
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            Text("@${profile["username"]}",
                                style: GoogleFonts.poppins(
                                    color: Colors.grey.shade400, fontSize: 12)),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(dateStr,
                              style: GoogleFonts.poppins(
                                  color: Colors.grey.shade400, fontSize: 12)),
                          if (!isMyPost) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                shape: BoxShape.circle,
                              ),
                              child: PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.more_horiz,
                                    color: Colors.white70, size: 18),
                                color: const Color(0xFF2C2C2C),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                onSelected: (value) {
                                  if (value == 'report') _showReportDialog();
                                },
                                itemBuilder: (BuildContext context) {
                                  return [
                                    PopupMenuItem(
                                      value: 'report',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.flag_outlined,
                                              color: Colors.white70, size: 18),
                                          const SizedBox(width: 10),
                                          Text("Şikayet Et",
                                              style: GoogleFonts.poppins(
                                                  color: Colors.white,
                                                  fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  ];
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // --- İÇERİK ---
                if (text.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(text,
                        style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 15)),
                  ),
                ],

                // --- GÖRSEL ---
                if (image != null) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(image),
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // --- AKSİYON BAR ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: widget.isExploreMode
                      ? Row(
                          children: [
                            FuelButton(
                              isFueled: isFueled,
                              count: fuelCount,
                              isExpired: !isAlive,
                              onTap: _toggleFuel,
                              size: 30,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                "$fuelCount Odun",
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Spacer(),
                            const Icon(FontAwesomeIcons.comment,
                                color: Colors.grey, size: 22),
                            const SizedBox(width: 6),
                            Text("$commentCount",
                                style: GoogleFonts.poppins(
                                    color: Colors.grey, fontSize: 14)),
                          ],
                        )
                      : Row(
                          // 🔥 NORMAL MOD: MOR KALP VE HİZALAMA
                          children: [
                            GestureDetector(
                              onTap: _toggleLike,
                              child: Container(
                                color: Colors.transparent,
                                child: Row(
                                  children: [
                                    Icon(
                                      isLiked
                                          ? FontAwesomeIcons.solidHeart
                                          : FontAwesomeIcons.heart,
                                      color: isLiked
                                          ? const Color(0xFF6C63FF)
                                          : Colors.grey.shade400, // Mor Kalp
                                      size: 22,
                                    ),
                                    if (likeCount > 0) ...[
                                      const SizedBox(width: 6),
                                      Text("$likeCount",
                                          style: GoogleFonts.poppins(
                                              color: isLiked
                                                  ? const Color(0xFF6C63FF)
                                                  : Colors.grey.shade400,
                                              fontWeight: FontWeight.w600)),
                                    ]
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Container(
                              color: Colors.transparent,
                              child: Row(
                                children: [
                                  Icon(FontAwesomeIcons.comment,
                                      color: Colors.grey.shade400, size: 22),
                                  if (commentCount > 0) ...[
                                    const SizedBox(width: 6),
                                    Text("$commentCount",
                                        style: GoogleFonts.poppins(
                                            color: Colors.grey.shade400,
                                            fontWeight: FontWeight.w600)),
                                  ]
                                ],
                              ),
                            ),
                            // 📸 Emoji Tepkileri - Sağda
                            if (emojiReactions.isNotEmpty) ...[
                              const Spacer(),
                              GestureDetector(
                                onTap: () => _showAllReactionsDialog(),
                                child: Row(
                                  children: [
                                    // Üst üste binen avatarlar (max 3)
                                    SizedBox(
                                      width: (emojiReactions.length > 3
                                                  ? 3
                                                  : emojiReactions.length) *
                                              22 +
                                          10,
                                      height: 28,
                                      child: Stack(
                                        children: [
                                          for (int i = 0;
                                              i <
                                                  (emojiReactions.length > 3
                                                      ? 3
                                                      : emojiReactions.length);
                                              i++)
                                            Positioned(
                                              left: i * 18.0,
                                              child: Stack(
                                                children: [
                                                  Container(
                                                    width: 28,
                                                    height: 28,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                          color: Colors.black,
                                                          width: 2),
                                                      image: DecorationImage(
                                                        image: NetworkImage(
                                                            emojiReactions[i][
                                                                    'emoji_url'] ??
                                                                ''),
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  ),
                                                  Positioned(
                                                    right: 0,
                                                    bottom: 0,
                                                    child: Container(
                                                      width: 12,
                                                      height: 12,
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                            0xFF1A1A24),
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                            color: const Color(
                                                                0xFF6C63FF),
                                                            width: 1),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          _getEmojiIcon(
                                                              emojiReactions[i][
                                                                  'emoji_type']),
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 6),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (emojiReactions.length > 3) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        "+${emojiReactions.length - 3}",
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey.shade400,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComments() {
    if (loadingComments) {
      return const Padding(
        padding: EdgeInsets.all(30),
        child:
            Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
      );
    }

    if (comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Text(
            widget.isExploreMode
                ? "İlk odunu sen at 🔥"
                : "İlk yorumu sen yap!",
            style: GoogleFonts.poppins(color: Colors.white54),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: comments.length,
      itemBuilder: (_, i) {
        final c = comments[i];
        final p = c["profiles"] ?? {};
        final id = c["id"].toString();
        final isAudio = c["audio_url"] != null;
        final isMine = c["user_id"] == myId;
        final isPlaying = playingCommentId == id;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ProfileScreen(userId: c['user_id']))),
                child: CircleAvatar(
                  radius: 18,
                  backgroundImage: p["avatar_url"] != null
                      ? NetworkImage(p["avatar_url"])
                      : null,
                  backgroundColor: Colors.grey[900],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(p["username"] ?? "Kullanıcı",
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Text(
                              timeago.format(DateTime.parse(c["created_at"]),
                                  locale: "en_short"),
                              style: GoogleFonts.poppins(
                                  color: Colors.white38, fontSize: 11),
                            ),
                            if (isMine)
                              GestureDetector(
                                onTap: () => _confirmDelete(id),
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 10),
                                  child: Icon(Icons.delete_outline,
                                      color: Colors.white30, size: 16),
                                ),
                              )
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (isAudio)
                      GestureDetector(
                        onTap: () => _playPause(c["audio_url"], id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: isPlaying
                                ? const Color(0xFF6C63FF)
                                : const Color(0xFF2C2C2C),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isPlaying ? "Çalıyor..." : "Sesli Yorum",
                                style: GoogleFonts.poppins(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Text(
                        c["content"] ?? "",
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontSize: 14),
                      )
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: Platform.isIOS ? 32 : 14,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          // 📸 Foto Emoji butonu
          GestureDetector(
            onTap: () async {
              final result = await showPhotoEmojiPicker(context);
              if (result != null) {
                _sendEmojiReaction(result['path']!, result['type']!);
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                shape: BoxShape.circle,
                border:
                    Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
              ),
              child: const Icon(
                Icons.face_retouching_natural,
                color: Color(0xFF6C63FF),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: commentController,
                style: const TextStyle(color: Colors.white),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: isRecording
                      ? "Kaydediliyor... ($recordDuration)"
                      : "Yorum yaz...",
                  hintStyle:
                      const TextStyle(color: Colors.white38, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onLongPress: isComposing ? null : _startRecording,
            onLongPressUp: _stopRecording,
            onTap: isComposing ? _sendTextComment : null,
            child: CircleAvatar(
              radius: 22,
              backgroundColor:
                  isRecording ? Colors.redAccent : const Color(0xFF6C63FF),
              child: Icon(
                isComposing ? Icons.send : Icons.mic,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
