import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../widgets/fuel_button.dart';
import '../services/feed_service.dart';
import '../screens/profile_screen.dart';

import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isExploreMode; // ⭐ Yeni parametre

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

  List<Map<String, dynamic>> comments = [];
  bool loadingComments = true;
  late bool isLiked;
  late bool isFueled;
  late int likeCount;
  late int fuelCount;
  late int commentCount;

  // Fuel Modu için 24 saat kontrolü
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

    // 🔥 24 Saat Kontrolü (Sönmüş mü?)
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

    // Ses bitince player reset
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
  // 🔥 YORUMLARI GETİR
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

  // *********************************************************
  // ❤️ BEĞENİ (NORMAL MOD) - isFuel: false
  // *********************************************************

  void _toggleLike() async {
    setState(() {
      isLiked = !isLiked;
      likeCount += isLiked ? 1 : -1;
    });

    // 🔥 DÜZELTME: Normal beğeni bildirimi gider
    await FeedService().toggleLike(widget.post["id"], isFuel: false);
  }

  // *********************************************************
  // 🔥 ATEŞ MODU (FUELBUTTON) - isFuel: true
  // *********************************************************

  void _toggleFuel() async {
    if (!isAlive) return; // Sönmüşse işlem yapma

    setState(() {
      isFueled = !isFueled;
      fuelCount += isFueled ? 1 : -1;
    });

    // 🔥 DÜZELTME: Harlama bildirimi gider
    await FeedService().toggleLike(widget.post["id"], isFuel: true);
  }

  // *********************************************************
  // 🗑️ YORUM SİLME
  // *********************************************************
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

  // *********************************************************
  // 💬 YORUM EKLE (METİN)
  // *********************************************************

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

      // Bildirim (Post sahibi değilsem)
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

  // *********************************************************
  // 🔊 SES KAYDI BAŞLAT
  // *********************************************************

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

  // *********************************************************
  // 🎤 SES KAYDI DURDUR
  // *********************************************************

  Future<void> _stopRecording() async {
    recordTimer?.cancel();
    if (!isRecording) return;

    final path = await audioRecorder.stop();
    setState(() => isRecording = false);

    if (path != null && recordDuration > 1) {
      _uploadAndSendAudio(path);
    }
  }

  // *********************************************************
  // 📤 SES YÜKLE & YORUM OLARAK EKLE
  // *********************************************************

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

  // *********************************************************
  // 🔊 SES OYNAT
  // *********************************************************

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

  // *********************************************************
  // 🔥 GÖNDERİ KARTI
  // *********************************************************

  Widget _buildPostCard() {
    final profile = widget.post["profiles"] ?? {};
    final text = widget.post["content"] ?? "";
    final image = widget.post["image_url"];

    final date = DateTime.tryParse(widget.post["created_at"] ?? "");
    final dateStr = date != null ? "${date.day}/${date.month}" : "";

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
          // PROFIL
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
              Text(dateStr,
                  style: GoogleFonts.poppins(
                      color: Colors.white54, fontSize: 12)),
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

          // ----------------------------------------------------
          //  ❤️ NORMAL MOD → KALP
          //  🔥 EXPLORE MOD → FUEL BUTTON
          // ----------------------------------------------------

          widget.isExploreMode
              ? Row(
            children: [
              FuelButton(
                isFueled: isFueled,
                count: fuelCount,
                isExpired: !isAlive, // 🔥 SÖNMÜŞSE
                onTap: _toggleFuel,
                size: 30,
              ),
              const SizedBox(width: 10),
              // Flexible taşmayı önler
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

  // *********************************************************
  // 💬 YORUM LİSTESİ
  // *********************************************************

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
              // PROFIL
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
                    // ÜST BİLGİ
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

                    // SESLİ YORUM
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

                    // METİN YORUM
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

  // *********************************************************
  // ✍️ YORUM YAZMA ALANI
  // *********************************************************

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

          // 🎤 SES KAYDI BUTONU / GÖNDER
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