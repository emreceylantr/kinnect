import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // Tarih formatı için
import '../services/chat_service.dart'; // Service yolunu kontrol et

// ==========================================
// 1. EKRAN: MESAJ KUTUSU (Gelen Kutusu)
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
      backgroundColor: const Color(0xFF121212), // Derin Siyah
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Mesajlar',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, color: Colors.white),
        ),
        actions: [
          // Yeni mesaj başlatma ikonu
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Arkadaş listesinden veya profilden mesaj atabilirsin.')),
              );
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[900],
              ),
              child: const Icon(Icons.edit, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 16),
        ],
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
                  Text(
                    'Henüz mesajın yok',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
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
              final lastUpdate = DateTime.parse(chat['updated_at']).toLocal();

              return _buildChatTile(context, chat, otherUser, lastUpdate);
            },
          );
        },
      ),
    );
  }

  // Özel Tasarım Liste Elemanı
  Widget _buildChatTile(BuildContext context, Map<String, dynamic> chat,
      Map<String, dynamic> otherUser, DateTime lastUpdate) {
    return InkWell(
      onTap: () {
        // Sohbete Git -> ChatScreen'e yönlendiriyoruz
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              roomId: chat['id'],
              otherUser: otherUser,
            ),
          ),
        ).then((_) => _refreshChats()); // Dönünce listeyi yenile
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 1. Avatar (Büyük ve Yuvarlak)
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey[800],
                  backgroundImage: otherUser['avatar_url'] != null
                      ? NetworkImage(otherUser['avatar_url'])
                      : null,
                  child: otherUser['avatar_url'] == null
                      ? const Icon(Icons.person, color: Colors.white)
                      : null,
                ),
                // Online Durumu (Yeşil Nokta - Şimdilik süs)
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

            // 2. İsim ve Son Mesaj
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    otherUser['full_name'] ?? 'Kullanıcı',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sohbeti görüntülemek için dokun',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),

            // 3. Saat
            Text(
              DateFormat('HH:mm').format(lastUpdate),
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. EKRAN: SOHBET DETAYI (ChatScreen)
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

  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    try {
      await _chatService.sendMessage(widget.roomId, text);
      // Mesaj atınca en aşağı kaydır
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 60, // Biraz ekstra boşluk
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Tam siyah zemin (AMOLED dostu)

      // Üst Bar (Minimalist)
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: widget.otherUser['avatar_url'] != null
                  ? NetworkImage(widget.otherUser['avatar_url'])
                  : null,
              child: widget.otherUser['avatar_url'] == null
                  ? const Icon(Icons.person, size: 16) : null,
            ),
            const SizedBox(width: 10),
            Text(
              widget.otherUser['full_name'] ?? 'Kullanıcı',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
              onPressed: () {},
              icon: const Icon(Icons.more_vert, color: Colors.white)
          ),
        ],
      ),

      body: Column(
        children: [
          // --- MESAJ LİSTESİ (CANLI STREAM) ---
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _chatService.getMessagesStream(widget.roomId),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Hata: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));

                final messages = snapshot.data!;

                // İlk açılışta en aşağı kaydırmayı dene
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_id'] == _myId;
                    return _buildMessageBubble(msg['content'], isMe, msg['created_at']);
                  },
                );
              },
            ),
          ),

          // --- INPUT ALANI (Makromusic/Instagram Tarzı) ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              border: Border(top: BorderSide(color: Colors.grey[900]!)),
            ),
            child: Row(
              children: [
                // Kamera/Fotoğraf İkonu (Süs)
                IconButton(
                  onPressed: () {},
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),

                // Yazı Alanı
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Mesaj yaz...',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Gönder Butonu (Gradient)
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.purpleAccent, Colors.blueAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Modern Mesaj Baloncuğu
  Widget _buildMessageBubble(String content, bool isMe, String createdAtRaw) {
    final time = DateFormat('HH:mm').format(DateTime.parse(createdAtRaw).toLocal());

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          // BENİM MESAJIM: Gradient, Yuvarlak
          // ONUN MESAJI: Koyu Gri, Yuvarlak
          gradient: isMe
              ? const LinearGradient(
            colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)], // Mor -> Mavi
          )
              : null,
          color: isMe ? null : const Color(0xFF2A2A2A), // Koyu Gri
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end, // Saat hep sağ alta
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              content,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                  color: isMe ? Colors.white70 : Colors.grey[400],
                  fontSize: 10
              ),
            ),
          ],
        ),
      ),
    );
  }
}