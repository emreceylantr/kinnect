import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../widgets/fuel_button.dart';
import '../services/feed_service.dart';
import '../services/safety_service.dart'; // Güvenlik servisi (Şikayet için)
import '../screens/profile_screen.dart';

import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

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

  String get myId => client.auth.currentUser!.id;

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
  // 🛡️ ŞİKAYET ETME FONKSİYONLARI (MODERN TASARIM 🔥)
  // *********************************************************

  // 1. ADIM: SEBEP SEÇME
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
                border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5)]
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Şikayet Et", style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text("Bu gönderiyi neden bildiriyorsun?", style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11)),
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
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(reasons[index], style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12.5)),
                                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 12),
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
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text("Vazgeç", style: GoogleFonts.poppins(color: Colors.white38, fontSize: 13)),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // 2. ADIM: EK AÇIKLAMA YAZMA (GÜNCELLENMİŞ ESTETİK)
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
              border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5)]
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Text("Ek Açıklama", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))), // Font büyütüldü
              const SizedBox(height: 15),
              Text("Seçilen: $reason", style: GoogleFonts.poppins(color: Colors.orange, fontSize: 12)), // Font büyütüldü
              const SizedBox(height: 5),
              Text("Detay eklemek istersen aşağıya yazabilirsin.", style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12)), // Font büyütüldü
              const SizedBox(height: 15),
              TextField(
                controller: detailsController,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14), // Font büyütüldü
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Buraya yaz...",
                  hintStyle: GoogleFonts.poppins(color: Colors.white24, fontSize: 14),
                  filled: true,
                  fillColor: Colors.black26,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),

              // 🔥 HİZALI VE KİBAR BUTONLAR
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10), // Daha küçük buton
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      child: Text("Vazgeç", style: GoogleFonts.poppins(color: Colors.white38, fontSize: 13)),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10), // Daha küçük buton
                          elevation: 0
                      ),
                      child: Text("Gönder", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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

  // 3. ADIM: GÖNDERME İŞLEMİ
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
          SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.redAccent),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yorum silindi.')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Silinemedi.')));
    }
  }

  void _confirmDelete(String commentId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Yorumu Sil", style: TextStyle(color: Colors.white)),
        content: const Text("Bu yorumu silmek istediğine emin misin?", style: TextStyle(color: Colors.white70)),
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

  Future<void> _sendTextComment() async {
    final msg = commentController.text.trim();
    if (msg.isEmpty) return;

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
        } catch (_) {}
      }

      _fetchComments();
    } catch(e) {
      debugPrint("Yorum hatası: $e");
    }
  }

  Future<void> _startRecording() async {
    if (await audioRecorder.hasPermission()) {
      final dir = await getApplicationDocumentsDirectory();
      final path = "${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a";

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

      await client.storage
          .from("uploads")
          .upload("comment_audio/$name", file);

      final url = client.storage
          .from("uploads")
          .getPublicUrl("comment_audio/$name");

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
        backgroundColor: Colors.black,
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

  Widget _buildPostCard() {
    final profile = widget.post["profiles"] ?? {};
    final text = widget.post["content"] ?? "";
    final image = widget.post["image_url"];
    final date = DateTime.tryParse(widget.post["created_at"] ?? "");
    final dateStr = date != null ? "${date.day}/${date.month}" : "";

    // Post Sahibi miyim?
    final isMyPost = widget.post["user_id"] == myId;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            ProfileScreen(userId: widget.post["user_id"]))),
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
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),

              // 🔥 YENİ MODERN HEADER: Eğer post benimse menü yok, başkasınınsa var.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(dateStr, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12)),
                  // Sadece başkasının postuysa şikayet menüsü göster
                  if (!isMyPost) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05), // Çok hafif arka plan
                        shape: BoxShape.circle,
                      ),
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.more_horiz, color: Colors.white70, size: 18),
                        color: const Color(0xFF2C2C2C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (value) {
                          if (value == 'report') _showReportDialog();
                        },
                        itemBuilder: (BuildContext context) {
                          return [
                            PopupMenuItem(
                              value: 'report',
                              child: Row(
                                children: [
                                  const Icon(Icons.flag_outlined, color: Colors.white70, size: 18),
                                  const SizedBox(width: 10),
                                  Text("Şikayet Et", style: GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
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

          if (text.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(text,
                style:
                GoogleFonts.poppins(color: Colors.white, fontSize: 15)),
          ],

          if (image != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(image),
            ),
          ],

          const SizedBox(height: 14),

          widget.isExploreMode
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
            children: [
              GestureDetector(
                onTap: _toggleLike,
                child: Icon(
                  isLiked
                      ? FontAwesomeIcons.solidHeart
                      : FontAwesomeIcons.heart,
                  color:
                  isLiked ? Colors.redAccent : Colors.white54,
                  size: 24,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text("$likeCount",
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        color: Colors.white54, fontSize: 14)),
              ),

              const Spacer(),
              const Icon(FontAwesomeIcons.comment,
                  color: Colors.grey, size: 22),
              const SizedBox(width: 6),
              Flexible(
                child: Text("$commentCount",
                    style: GoogleFonts.poppins(
                        color: Colors.grey, fontSize: 14)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComments() {
    if (loadingComments) {
      return const Padding(
        padding: EdgeInsets.all(30),
        child: Center(
            child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    if (comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Text(
            widget.isExploreMode ? "İlk odunu sen at 🔥" : "İlk yorumu sen yap!",
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
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: c['user_id']))),
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
                              timeago.format(
                                  DateTime.parse(c["created_at"]),
                                  locale: "en_short"),
                              style: GoogleFonts.poppins(
                                  color: Colors.white38, fontSize: 11),
                            ),
                            if (isMine)
                              GestureDetector(
                                onTap: () => _confirmDelete(id),
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 10),
                                  child: Icon(Icons.delete_outline, color: Colors.white30, size: 16),
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
                                ? Colors.orange
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
                                style: GoogleFonts.poppins(
                                    color: Colors.white),
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
                  TextStyle(color: Colors.white38, fontSize: 14),
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
              isRecording ? Colors.redAccent : Colors.orange,
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