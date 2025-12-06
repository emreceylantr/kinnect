import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

// Ses Paketleri
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// Zego Paketleri (Sadece Arayüz için tutuyoruz, karmaşık servisler kaldırıldı)
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

import '../services/chat_service.dart';
import 'call_screen.dart'; // Oda ekranı

// ==========================================
// 1. EKRAN: MESAJ KUTUSU (LİSTE)
// ==========================================
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final ChatService _chatService = ChatService();
  late Future<List<Map<String, dynamic>>> _chatsFuture;

  @override
  void initState() {
    super.initState();
    _refreshChats();
  }

  void _refreshChats() {
    setState(() {
      _chatsFuture = _chatService.getMyChats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text(
          'Mesajlar',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, color: Colors.white),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _chatsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
          }
          final chats = snapshot.data ?? [];

          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.forum_outlined, size: 80, color: Colors.grey[800]),
                  const SizedBox(height: 16),
                  Text('Henüz mesajın yok', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: chats.length,
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemBuilder: (context, index) {
              final chat = chats[index];
              final otherUser = chat['other_user'] ?? {};
              final lastUpdateRaw = chat['updated_at'];
              final lastUpdate = lastUpdateRaw != null ? DateTime.parse(lastUpdateRaw).toLocal() : DateTime.now();
              return _buildChatTile(context, chat, otherUser, lastUpdate);
            },
          );
        },
      ),
    );
  }

  Widget _buildChatTile(BuildContext context, Map<String, dynamic> chat, Map<String, dynamic> otherUser, DateTime lastUpdate) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(roomId: chat['id'], otherUser: otherUser),
          ),
        ).then((_) => _refreshChats());
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey[800],
                  backgroundImage: otherUser['avatar_url'] != null ? NetworkImage(otherUser['avatar_url']) : null,
                  child: otherUser['avatar_url'] == null ? const Icon(Icons.person, color: Colors.white) : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF121212), width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    otherUser['full_name'] ?? 'Kullanıcı',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text('Sohbeti görüntülemek için dokun', style: TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            ),
            Text(DateFormat('HH:mm').format(lastUpdate), style: TextStyle(color: Colors.grey[700], fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. EKRAN: SOHBET DETAYI (CHAT)
// ==========================================
class ChatScreen extends StatefulWidget {
  final String roomId;
  final Map<String, dynamic> otherUser;

  const ChatScreen({super.key, required this.roomId, required this.otherUser});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String _myId = Supabase.instance.client.auth.currentUser!.id;

  // Ses Kayıt Değişkenleri
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isUploading = false;
  bool _isTextFieldEmpty = true; // Metin kutusu boş mu kontrolü

  @override
  void initState() {
    super.initState();
    _textController.addListener(_updateInputState);
  }

  @override
  void dispose() {
    _textController.removeListener(_updateInputState);
    _textController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _updateInputState() {
    final isEmpty = _textController.text.trim().isEmpty;
    if (_isTextFieldEmpty != isEmpty) {
      setState(() {
        _isTextFieldEmpty = isEmpty;
      });
    }
  }

  // --- MESAJ GÖNDERME ---
  void _sendMessage([String? fileUrl]) async {
    String content = fileUrl ?? _textController.text.trim();
    if (content.isEmpty) return;

    if (fileUrl == null) _textController.clear();

    try {
      final receiverId = widget.otherUser['id'].toString();
      await _chatService.sendMessage(widget.roomId, content, receiverId);
      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // --- SES KAYDETME VE GÖNDERME ---
  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        final path = await _audioRecorder.stop();
        setState(() => _isRecording = false);
        if (path != null) {
          _uploadAndSendAudio(path);
        }
      } else {
        if (await _audioRecorder.hasPermission()) {
          final dir = await getApplicationDocumentsDirectory();
          final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

          await _audioRecorder.start(const RecordConfig(), path: path);
          setState(() => _isRecording = true);
        }
      }
    } catch (e) {
      debugPrint("Kayıt hatası: $e");
    }
  }

  Future<void> _uploadAndSendAudio(String path) async {
    setState(() => _isUploading = true);
    try {
      final file = File(path);
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final uploadPath = 'chat_audio/$fileName';

      await Supabase.instance.client.storage.from('uploads').upload(uploadPath, file);
      final audioUrl = Supabase.instance.client.storage.from('uploads').getPublicUrl(uploadPath);
      _sendMessage(audioUrl);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ses gönderilemedi: $e')));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // --- FOTOĞRAF SEÇME ---
  void _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 70);
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      final fileExt = image.path.split('.').last;
      final fileName = 'chat_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final path = 'chat_images/$fileName';

      await Supabase.instance.client.storage.from('uploads').upload(path, File(image.path));
      final imageUrl = Supabase.instance.client.storage.from('uploads').getPublicUrl(path);
      _sendMessage(imageUrl);
    } catch (_) {} finally {
      setState(() => _isUploading = false);
    }
  }

  // --- 1. RESİM SEÇME MENÜSÜNÜ AÇ ---
  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.purpleAccent),
                title: const Text("Kamera", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blueAccent),
                title: const Text("Galeri", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- MANUEL ARAMA (DÜZELTİLDİ: DIRECT JOIN) ---
  void _startDirectCall(bool isVideo) {
    final myId = _myId;
    final otherId = widget.otherUser['id'].toString();
    final otherName = widget.otherUser['full_name']?.toString() ?? 'Kullanıcı';

    // 1. Bildirim Gönder (Veritabanı)
    try {
      Supabase.instance.client.from('notifications').insert({
        'user_id': otherId,
        'actor_id': myId,
        'type': 'call',
        'is_read': false,
      });
    } catch (_) {}

    // 2. Direkt Arama Ekranına Git (Oda Mantığı)
    List<String> ids = [myId, otherId];
    ids.sort();
    final callId = ids.join("_");

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          callId: callId,
          otherUserName: otherName,
          isVideo: isVideo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final targetName = widget.otherUser['full_name']?.toString() ?? 'Kullanıcı';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: Row(children: [CircleAvatar(radius: 16, backgroundImage: widget.otherUser['avatar_url'] != null ? NetworkImage(widget.otherUser['avatar_url']) : null, child: widget.otherUser['avatar_url'] == null ? const Icon(Icons.person, size: 16) : null), const SizedBox(width: 10), Text(targetName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white))]),
        actions: [
          IconButton(onPressed: () => _startDirectCall(false), icon: const Icon(Icons.phone, color: Colors.white)),
          const SizedBox(width: 10),
          IconButton(onPressed: () => _startDirectCall(true), icon: const Icon(Icons.videocam, color: Colors.white)),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _chatService.getMessagesStream(widget.roomId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
                final messages = snapshot.data!;
                WidgetsBinding.instance.addPostFrameCallback((_) { if(_scrollController.hasClients && _scrollController.offset == 0) _scrollToBottom(); });
                return ListView.builder(
                  controller: _scrollController, itemCount: messages.length, padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_id'] == Supabase.instance.client.auth.currentUser!.id;
                    return _buildMessageBubble(msg['content'], isMe, msg['created_at']);
                  },
                );
              },
            ),
          ),

          if (_isUploading) const LinearProgressIndicator(color: Colors.purpleAccent, backgroundColor: Colors.transparent),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFF1E1E1E), border: Border(top: BorderSide(color: Colors.grey[900]!))),
            child: Row(children: [
              // ARTI MENÜ BUTONU
              IconButton(onPressed: _showAttachmentMenu, icon: const Icon(Icons.add_circle_outline, color: Colors.white)),

              // YAZI ALANI
              Expanded(child: Container(decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(24)), child: TextField(controller: _textController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Mesaj yaz...', hintStyle: TextStyle(color: Colors.grey), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12))))),

              const SizedBox(width: 8),

              // MİKROFON veya GÖNDER BUTONU (DİNAMİK)
              GestureDetector(
                onTap: _isTextFieldEmpty
                    ? _toggleRecording
                    : () => _sendMessage(),
                child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording ? Colors.redAccent : const Color(0xFF6C63FF)
                    ),
                    child: Icon(
                        _isRecording ? Icons.stop : (_isTextFieldEmpty ? Icons.mic : Icons.send),
                        color: Colors.white, size: 20
                    )
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String content, bool isMe, String createdAtRaw) {
    final time = DateFormat('HH:mm').format(DateTime.parse(createdAtRaw).toLocal());

    // TİP KONTROLÜ
    bool isImage = content.startsWith('http') && (content.contains('.jpg') || content.contains('.png') || content.contains('image_picker'));
    bool isAudio = content.startsWith('http') && (content.contains('.m4a') || content.contains('.mp3') || content.contains('audio_'));

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          gradient: isMe ? const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)]) : null,
          color: isMe ? null : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isImage)
              ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(content, height: 200, width: 200, fit: BoxFit.cover))
            else if (isAudio)
              _AudioMessagePlayer(url: content, isMe: isMe)
            else
              Text(content, style: const TextStyle(color: Colors.white, fontSize: 16)),

            const SizedBox(height: 4),
            Text(time, style: TextStyle(color: isMe ? Colors.white70 : Colors.grey[400], fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// --- SES OYNATICI WIDGET (AYNEN KORUNDU) ---
class _AudioMessagePlayer extends StatefulWidget {
  final String url;
  final bool isMe;
  const _AudioMessagePlayer({required this.url, required this.isMe});

  @override
  State<_AudioMessagePlayer> createState() => _AudioMessagePlayerState();
}

class _AudioMessagePlayerState extends State<_AudioMessagePlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool isPlaying = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    if (isPlaying) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.url));
    }
    setState(() => isPlaying = !isPlaying);

    _player.onPlayerComplete.listen((event) {
      if(mounted) setState(() => isPlaying = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.white, size: 35),
          onPressed: _togglePlay,
        ),
        Container(
            height: 3, width: 100,
            decoration: BoxDecoration(
                color: widget.isMe ? Colors.white54 : Colors.grey,
                borderRadius: BorderRadius.circular(10)
            )
        ),
        const SizedBox(width: 8),
        const Text("Sesli Mesaj", style: TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}