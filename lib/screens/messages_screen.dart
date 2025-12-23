import 'dart:async'; // Timer için gerekli
import 'dart:io';
import 'dart:ui'; // Glassmorphism ve ImageFilter için gerekli
import 'dart:math'; // Flip animasyonu (pi) için gerekli
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

// Ses Paketleri
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

// Diğer ekranlar
import '../services/chat_service.dart';
import 'call_screen.dart';

// ==========================================
// 🎨 RENK PALETİ
// ==========================================
const Color kChatBackgroundColor = Color(0xFF1F1B24);
const Color kHeaderColor = Color(0xFF2D2638);
const Color kReceivedBubbleColor = Color(0xFF38304C);
const Color kInputBackgroundColor = Color(0xFF2D2638);
const Color kListBgColor = Color(0xFF1B1424);
const Color kSearchBtnColor = Color(0xFF292233);
const Color kTextWhite = Colors.white;
const Color kTextGrey = Colors.white54;
const Color kBadgeColor = Color(0xFF448AFF);
const Color kAccentColor = Color(0xFF6C63FF);
const Color kListCardColor = Color(0xFF2D2638);

// ==========================================
// 📱 1. EKRAN: MESAJLAR LİSTESİ (ANA EKRAN)
// ==========================================
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final ChatService _chatService = ChatService();
  late Future<List<Map<String, dynamic>>> _chatsFuture;

  // Arama Durumu
  String _searchQuery = "";
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // Header Animasyonu
  bool _showGreeting = true;
  String _firstName = "";
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _refreshChats();
    _loadUserData();

    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showGreeting = false);
      }
    });
  }

  Future<void> _loadUserData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    String name = 'Kullanıcı';
    String? avatar;

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null) {
        name = profile['full_name'] ?? profile['username'] ?? 'Kullanıcı';
        avatar = profile['avatar_url'];
      }
    } catch (_) {}

    String first = name.split(' ')[0];
    if (first.isNotEmpty) {
      first = "${first[0].toUpperCase()}${first.substring(1)}";
    }

    if (mounted) {
      setState(() {
        _firstName = first;
        _avatarUrl = avatar;
      });
    }
  }

  void _refreshChats() {
    setState(() {
      _chatsFuture = _chatService.getMyChats();
    });
  }

  // 🔥 SOHBETİ SİLME İŞLEMİ
  Future<void> _deleteChat(String roomId) async {
    try {
      await Supabase.instance.client
          .from('messages')
          .delete()
          .eq('room_id', roomId);
      _refreshChats(); // Listeyi yenile

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Sohbet temizlendi."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Hata: $e")));
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kListBgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _chatsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: kAccentColor));
                  }

                  final allChats = snapshot.data ?? [];
                  final filteredChats = allChats.where((chat) {
                    final otherUser = chat['other_user'] ?? {};
                    final name =
                        (otherUser['full_name'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery);
                  }).toList();

                  if (filteredChats.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 50, color: Colors.grey[700]),
                          const SizedBox(height: 16),
                          Text(
                              _searchQuery.isEmpty
                                  ? 'Henüz sohbet yok'
                                  : 'Sonuç bulunamadı',
                              style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredChats.length,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    itemBuilder: (context, index) {
                      final chat = filteredChats[index];
                      final otherUser = chat['other_user'] ?? {};
                      final lastUpdateRaw = chat['updated_at'];
                      final lastUpdate = lastUpdateRaw != null
                          ? DateTime.parse(lastUpdateRaw).toLocal()
                          : DateTime.now();

                      final unreadCount = 0;

                      // 🔥 ANİMASYONLU LİSTE + FLIP KART
                      return _SlideFadeTransition(
                        index: index,
                        child: FlippableChatCard(
                          chat: chat,
                          otherUser: otherUser,
                          lastUpdate: lastUpdate,
                          unreadCount: unreadCount,
                          onDeleteConfirm: () {
                            _deleteChat(chat['id'].toString());
                          },
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  roomId: chat['id'],
                                  otherUser: otherUser,
                                  heroTag: "list_avatar_${otherUser['id']}",
                                ),
                              ),
                            ).then((_) => _refreshChats());
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _isSearching
              ? Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: kSearchBtnColor,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    onChanged: (value) =>
                        setState(() => _searchQuery = value.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: "Sohbet ara...",
                      hintStyle:
                          TextStyle(color: Colors.white.withOpacity(0.5)),
                      prefixIcon:
                          const Icon(Icons.search, color: Colors.white70),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () {
                          setState(() {
                            _isSearching = false;
                            _searchQuery = "";
                            _searchController.clear();
                          });
                        },
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 22),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: kSearchBtnColor,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.search,
                            color: Colors.white70, size: 20),
                        onPressed: () => setState(() => _isSearching = true),
                      ),
                    ),
                  ],
                ),
          if (!_isSearching) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 800),
                  child: _showGreeting
                      ? Text(
                          "Merhaba, $_firstName",
                          key: const ValueKey('greeting'),
                          style: const TextStyle(
                              color: kTextWhite,
                              fontSize: 24,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 1.0),
                        )
                      : Container(
                          key: const ValueKey('avatar'),
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: kAccentColor, width: 2),
                              boxShadow: [
                                BoxShadow(
                                    color: kAccentColor.withOpacity(0.3),
                                    blurRadius: 15)
                              ]),
                          child: CircleAvatar(
                            radius: 35,
                            backgroundColor: Colors.grey[800],
                            backgroundImage: _avatarUrl != null
                                ? NetworkImage(_avatarUrl!)
                                : null,
                            child: _avatarUrl == null
                                ? Text(
                                    _firstName.isNotEmpty ? _firstName[0] : "K",
                                    style: const TextStyle(
                                        fontSize: 24,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold))
                                : null,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Sohbetler',
              style: TextStyle(
                  fontFamily: 'Sans',
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                  color: kTextWhite),
            ),
          ]
        ],
      ),
    );
  }
}

// ==========================================
// 🔥🔥 FLIPPABLE CHAT CARD (3D DÖNEN KART) 🔥🔥
// ==========================================
class FlippableChatCard extends StatefulWidget {
  final Map<String, dynamic> chat;
  final Map<String, dynamic> otherUser;
  final DateTime lastUpdate;
  final int unreadCount;
  final VoidCallback onDeleteConfirm;
  final VoidCallback onTap;

  const FlippableChatCard({
    super.key,
    required this.chat,
    required this.otherUser,
    required this.lastUpdate,
    required this.unreadCount,
    required this.onDeleteConfirm,
    required this.onTap,
  });

  @override
  State<FlippableChatCard> createState() => _FlippableChatCardState();
}

class _FlippableChatCardState extends State<FlippableChatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    if (_isFlipped) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Sohbeti Sil",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text(
            "Bu sohbetin tüm mesajları silinecek. Emin misin?",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text("İptal", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.2),
                foregroundColor: Colors.redAccent,
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(context);
                widget.onDeleteConfirm();
              },
              child: const Text("Evet, Sil"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: _toggleFlip, // 🔥 UZUN BASINCA DÖNDÜR
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * pi;
          final isBack = angle >= (pi / 2);

          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(angle);

          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child: isBack
                ? Transform(
                    transform: Matrix4.identity()..rotateX(pi),
                    alignment: Alignment.center,
                    child: _buildBackSide(),
                  )
                : _buildFrontSide(),
          );
        },
      ),
    );
  }

  Widget _buildFrontSide() {
    final String heroTag = "list_avatar_${widget.otherUser['id']}";
    final bool hasUnread = widget.unreadCount > 0;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
          child: Row(
            children: [
              Hero(
                tag: heroTag,
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.grey[800],
                  backgroundImage: widget.otherUser['avatar_url'] != null
                      ? NetworkImage(widget.otherUser['avatar_url'])
                      : null,
                  child: widget.otherUser['avatar_url'] == null
                      ? const Icon(Icons.person,
                          color: Colors.white54, size: 26)
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.otherUser['full_name'] ?? 'Kullanıcı',
                      style: const TextStyle(
                          color: kTextWhite,
                          fontWeight: FontWeight.w600,
                          fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mesajları görüntülemek için dokun...',
                      style: TextStyle(
                        color: hasUnread ? Colors.white : kTextGrey,
                        fontWeight:
                            hasUnread ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('HH:mm').format(widget.lastUpdate),
                    style: const TextStyle(color: kTextGrey, fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  if (hasUnread)
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: kBadgeColor,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        widget.unreadCount.toString(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
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

  Widget _buildBackSide() {
    return GestureDetector(
      onTap: _toggleFlip, // Arkaya tıklayınca iptal et
      child: Container(
        height: 70,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(color: Colors.redAccent.withOpacity(0.1), blurRadius: 10)
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: widget.otherUser['avatar_url'] != null
                        ? NetworkImage(widget.otherUser['avatar_url'])
                        : null,
                    child: widget.otherUser['avatar_url'] == null
                        ? const Icon(Icons.person,
                            color: Colors.white54, size: 20)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.otherUser['full_name'] ?? 'Kullanıcı',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 15),
                      ),
                      const Text(
                        "Silmek için çöp kutusuna bas",
                        style: TextStyle(color: Colors.white30, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              GestureDetector(
                onTap: _showDeleteConfirmation,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.red.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 1)
                      ]),
                  child: const Icon(Icons.delete_forever,
                      color: Colors.white, size: 26),
                ),
              ),
            ],
          ),
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
  final String heroTag;

  const ChatScreen(
      {super.key,
      required this.roomId,
      required this.otherUser,
      this.heroTag = 'default_tag'});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isUploading = false;
  bool _isTextFieldEmpty = true;
  bool _isEphemeralMode = false; // 🔥 Kül Olan Mod

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
    if (_isTextFieldEmpty != isEmpty)
      setState(() => _isTextFieldEmpty = isEmpty);
  }

  void _sendMessage([String? fileUrl]) async {
    String content = fileUrl ?? _textController.text.trim();
    if (content.isEmpty) return;
    if (fileUrl == null) _textController.clear();
    try {
      final receiverId = widget.otherUser['id'].toString();
      await _chatService.sendMessage(
        widget.roomId,
        content,
        receiverId,
        isEphemeral: _isEphemeralMode,
        ephemeralDuration: 5,
      );

      // Ephemeral mod'u resetle
      if (_isEphemeralMode && mounted) {
        setState(() => _isEphemeralMode = false);
      }

      _scrollToBottom();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  // 🔥 TEK MESAJ SİLME DIALOG
  void _showDeleteMessageDialog(String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.redAccent),
            SizedBox(width: 8),
            Text("Mesajı Sil",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "Bu mesaj kalıcı olarak silinecek. Devam etmek istiyor musun?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.2),
              foregroundColor: Colors.redAccent,
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _chatService.deleteSingleMessage(messageId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Mesaj silindi"),
                    backgroundColor: Colors.redAccent,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text("Sil"),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut);
    }
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        final path = await _audioRecorder.stop();
        setState(() => _isRecording = false);
        if (path != null) _uploadAndSendAudio(path);
      } else {
        if (await _audioRecorder.hasPermission()) {
          final dir = await getApplicationDocumentsDirectory();
          final path =
              '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
          await _audioRecorder.start(const RecordConfig(), path: path);
          setState(() => _isRecording = true);
        }
      }
    } catch (_) {}
  }

  Future<void> _uploadAndSendAudio(String path) async {
    setState(() => _isUploading = true);
    try {
      final file = File(path);
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final uploadPath = 'chat_audio/$fileName';
      await Supabase.instance.client.storage
          .from('uploads')
          .upload(uploadPath, file);
      final audioUrl = Supabase.instance.client.storage
          .from('uploads')
          .getPublicUrl(uploadPath);
      _sendMessage(audioUrl);
    } catch (_) {
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image =
        await picker.pickImage(source: source, imageQuality: 70);
    if (image == null) return;
    setState(() => _isUploading = true);
    try {
      final fileExt = image.path.split('.').last;
      final fileName = 'chat_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final path = 'chat_images/$fileName';
      await Supabase.instance.client.storage
          .from('uploads')
          .upload(path, File(image.path));
      final imageUrl =
          Supabase.instance.client.storage.from('uploads').getPublicUrl(path);
      _sendMessage(imageUrl);
    } catch (_) {
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Container(
              color: kListCardColor,
              child: SafeArea(
                  child: Wrap(children: [
                ListTile(
                    leading: const Icon(Icons.camera_alt, color: Colors.white),
                    title: const Text("Kamera",
                        style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    }),
                ListTile(
                    leading:
                        const Icon(Icons.photo_library, color: Colors.white),
                    title: const Text("Galeri",
                        style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    }),
              ])),
            ),
          );
        });
  }

  void _startDirectCall(bool isVideo) async {
    final myId = Supabase.instance.client.auth.currentUser!.id;
    final otherId = widget.otherUser['id'].toString();
    final otherName = widget.otherUser['full_name']?.toString() ?? 'Kullanıcı';
    List<String> ids = [myId, otherId];
    ids.sort();
    final callId = ids.join("_");

    // 🔔 ARAMA BİLDİRİMİ GÖNDER
    try {
      await Supabase.instance.client.from('notifications').insert({
        'user_id': otherId, // Kime (aranan kişi)
        'actor_id': myId, // Kimden (arayan kişi)
        'type': 'call', // Tip: Arama
        'is_read': false,
      });

      // 🔔 PUSH BİLDİRİM GÖNDER
      final myProfile = await Supabase.instance.client
          .from('profiles')
          .select('username, full_name')
          .eq('id', myId)
          .single();
      final callerName =
          myProfile['full_name'] ?? myProfile['username'] ?? 'Birisi';

      await Supabase.instance.client.functions
          .invoke('send-push-notification', body: {
        'target_user_id': otherId,
        'title': isVideo ? '📹 Görüntülü Arama' : '📞 Sesli Arama',
        'body': '$callerName seni arıyor',
        'type': 'call',
        'target_id': callId,
      });
    } catch (e) {
      debugPrint('🔔 Arama bildirimi hatası: $e');
    }

    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CallScreen(
                callId: callId,
                otherUserName: otherName,
                isVideo: isVideo,
                otherUserAvatar: widget.otherUser['avatar_url']?.toString())));
  }

  @override
  Widget build(BuildContext context) {
    final targetName = widget.otherUser['full_name']?.toString() ?? 'Kullanıcı';
    return Scaffold(
      backgroundColor: kChatBackgroundColor,
      body: Column(children: [
        // HEADER
        Container(
          padding:
              const EdgeInsets.only(top: 40, bottom: 20, left: 10, right: 20),
          decoration: const BoxDecoration(
              color: kHeaderColor,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(50))),
          child: Row(children: [
            IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context)),
            Hero(
                tag: widget.heroTag,
                child: CircleAvatar(
                    radius: 22,
                    backgroundImage: widget.otherUser['avatar_url'] != null
                        ? NetworkImage(widget.otherUser['avatar_url'])
                        : null,
                    backgroundColor: Colors.grey[800],
                    child: widget.otherUser['avatar_url'] == null
                        ? const Icon(Icons.person, color: Colors.white70)
                        : null)),
            const SizedBox(width: 12),
            Expanded(
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(targetName,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                        overflow: TextOverflow.ellipsis))),
            _buildHeaderButton(
                Icons.videocam_outlined, () => _startDirectCall(true),
                iconSize: 20),
            const SizedBox(width: 10),
            _buildHeaderButton(
                Icons.phone_outlined, () => _startDirectCall(false),
                iconSize: 18),
          ]),
        ),
        // MESAJ LİSTESİ
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _chatService.getMessagesStream(widget.roomId),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(
                    child: CircularProgressIndicator(color: kAccentColor));
              final messages = snapshot.data!;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients &&
                    _scrollController.offset == 0) _scrollToBottom();
              });
              if (messages.isEmpty)
                return Center(
                    child: Text("Henüz mesaj yok.",
                        style:
                            TextStyle(color: Colors.white.withOpacity(0.3))));

              return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 0, vertical: 20),
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_id'] ==
                        Supabase.instance.client.auth.currentUser!.id;
                    bool showAvatar = true;
                    if (!isMe && index > 0) {
                      final prevMsg = messages[index - 1];
                      if (prevMsg['sender_id'] == msg['sender_id'])
                        showAvatar = false;
                    }

                    final isEphemeral = msg['is_ephemeral'] == true;
                    final isViewed = msg['is_viewed'] == true;

                    return _buildMessageBubble(
                      msg,
                      isMe,
                      showAvatar,
                      isEphemeral: isEphemeral,
                      isViewed: isViewed,
                    );
                  });
            },
          ),
        ),
        if (_isUploading)
          const LinearProgressIndicator(
              color: kAccentColor, backgroundColor: Colors.transparent),
        // INPUT
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
                color: kInputBackgroundColor,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5))
                ]),
            child: Row(children: [
              IconButton(
                  onPressed: _showAttachmentMenu,
                  icon: const Icon(Icons.attach_file, color: Colors.white54)),
              // 🔥 KÜL OLAN MOD BUTONU
              GestureDetector(
                onTap: () =>
                    setState(() => _isEphemeralMode = !_isEphemeralMode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isEphemeralMode
                        ? Colors.orange.withOpacity(0.2)
                        : Colors.transparent,
                    border: Border.all(
                      color:
                          _isEphemeralMode ? Colors.orange : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.local_fire_department,
                    color: _isEphemeralMode ? Colors.orange : Colors.white38,
                    size: 22,
                  ),
                ),
              ),
              Expanded(
                  child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                          hintText: _isEphemeralMode
                              ? '🔥 Kül olan mesaj...'
                              : 'Mesaj yaz...',
                          hintStyle: TextStyle(
                            color: _isEphemeralMode
                                ? Colors.orange.withOpacity(0.6)
                                : Colors.white38,
                          ),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 10)))),
              GestureDetector(
                onTap:
                    _isTextFieldEmpty ? _toggleRecording : () => _sendMessage(),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          colors: _isEphemeralMode
                              ? [Colors.orange, Colors.deepOrange]
                              : [
                                  const Color(0xFF9D89D9),
                                  const Color(0xFF335FA1)
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      boxShadow: [
                        BoxShadow(
                            color: (_isEphemeralMode
                                    ? Colors.orange
                                    : const Color(0xFF335FA1))
                                .withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ]),
                  child: Icon(
                      _isRecording
                          ? Icons.stop
                          : (_isTextFieldEmpty ? Icons.mic : Icons.send),
                      color: Colors.white,
                      size: 20),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildHeaderButton(IconData icon, VoidCallback onTap,
      {double iconSize = 18}) {
    return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white12),
            color: Colors.white.withOpacity(0.05)),
        child: IconButton(
            icon: Icon(icon, color: Colors.white, size: iconSize),
            onPressed: onTap,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints()));
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> msg,
    bool isMe,
    bool showAvatar, {
    bool isEphemeral = false,
    bool isViewed = false,
  }) {
    final content = msg['content'] as String;
    final messageId = msg['id'].toString();
    final createdAtRaw = msg['created_at'] as String;
    final ephemeralDuration = msg['ephemeral_duration'] as int? ?? 5;

    final time =
        DateFormat('HH:mm').format(DateTime.parse(createdAtRaw).toLocal());
    bool isImage = content.startsWith('http') &&
        (content.contains('.jpg') ||
            content.contains('.png') ||
            content.contains('image_picker'));
    bool isAudio = content.startsWith('http') &&
        (content.contains('.m4a') ||
            content.contains('.mp3') ||
            content.contains('audio_'));
    Widget? contentWidget;
    bool isImg = false;
    if (isImage) {
      isImg = true;
      contentWidget = GestureDetector(
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        FullScreenImage(imageUrl: content, heroTag: content)));
          },
          child: Hero(
              tag: content,
              child: Image.network(content,
                  fit: BoxFit.cover, height: 250, width: 220)));
    } else if (isAudio) {
      contentWidget = _AudioMessagePlayer(url: content, isMe: isMe);
    }

    // 🔥 Ephemeral mesaj ise özel widget kullan
    if (isEphemeral) {
      return EphemeralMessageBubble(
        messageId: messageId,
        content: content,
        isMe: isMe,
        time: time,
        durationSeconds: ephemeralDuration,
        isViewed: isViewed,
        otherUserAvatar: widget.otherUser['avatar_url'],
        showAvatar: showAvatar,
        contentWidget: contentWidget,
        isImage: isImg,
        chatService: _chatService,
        onBurned: () {
          // Mesaj yandığında bir şey yapmaya gerek yok, stream otomatik güncelleyecek
        },
      );
    }

    // Normal mesaj - long press ile silme
    return GestureDetector(
      onLongPress: isMe ? () => _showDeleteMessageDialog(messageId) : null,
      child: ModernMessageBubble(
        content: content,
        isMe: isMe,
        time: time,
        contentWidget: contentWidget,
        isImage: isImg,
        otherUserAvatar: widget.otherUser['avatar_url'],
        showAvatar: showAvatar,
      ),
    );
  }
}

// ==========================================
// 🧱 YARDIMCI WIDGETLAR (EKSİKLER TAMAMLANDI)
// ==========================================

class FullScreenImage extends StatelessWidget {
  final String imageUrl;
  final String heroTag;
  const FullScreenImage(
      {super.key, required this.imageUrl, required this.heroTag});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(color: Colors.white)),
      body: Center(
          child: Hero(
              tag: heroTag,
              child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4,
                  child: Image.network(imageUrl)))),
    );
  }
}

class ModernMessageBubble extends StatelessWidget {
  final String content;
  final bool isMe;
  final String time;
  final Widget? contentWidget;
  final bool isImage;
  final String? otherUserAvatar;
  final bool showAvatar;

  const ModernMessageBubble(
      {super.key,
      required this.content,
      required this.isMe,
      required this.time,
      this.contentWidget,
      this.isImage = false,
      this.otherUserAvatar,
      this.showAvatar = true});

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.70;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin:
            EdgeInsets.symmetric(vertical: showAvatar ? 6 : 2, horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              if (showAvatar)
                CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: otherUserAvatar != null
                        ? NetworkImage(otherUserAvatar!)
                        : null,
                    child: otherUserAvatar == null
                        ? const Icon(Icons.person,
                            size: 16, color: Colors.white)
                        : null)
              else
                const SizedBox(width: 28),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding: isImage
                    ? const EdgeInsets.all(4)
                    : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? const LinearGradient(colors: [
                          Color(0xFF9D89D9),
                          Color(0xFF899DD9),
                          Color(0xFF335FA1)
                        ], begin: Alignment.topLeft, end: Alignment.bottomRight)
                      : null,
                  color: isMe ? null : kReceivedBubbleColor,
                  borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: isMe
                          ? const Radius.circular(20)
                          : (showAvatar
                              ? Radius.zero
                              : const Radius.circular(20)),
                      bottomRight: isMe
                          ? (showAvatar
                              ? Radius.zero
                              : const Radius.circular(20))
                          : const Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ],
                ),
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: isImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _buildImageContent(context))
                    : _buildTextOrAudioContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageContent(BuildContext context) {
    return Stack(alignment: Alignment.bottomRight, children: [
      contentWidget!,
      Positioned(
          bottom: 6,
          right: 6,
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(time,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold))))
    ]);
  }

  Widget _buildTextOrAudioContent() {
    return Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.end,
        runSpacing: 4,
        children: [
          contentWidget ??
              Text(content,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, height: 1.4)),
          const SizedBox(width: 8),
          Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(time,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w500)))
        ]);
  }
}

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
      if (mounted) setState(() => isPlaying = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
          icon: Icon(
              isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: Colors.white,
              size: 35),
          onPressed: _togglePlay,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints()),
      const SizedBox(width: 8),
      Container(
          height: 3,
          width: 100,
          decoration: BoxDecoration(
              color: Colors.white54, borderRadius: BorderRadius.circular(10))),
      const SizedBox(width: 8),
      const Text("Ses", style: TextStyle(color: Colors.white70, fontSize: 12))
    ]);
  }
}

class _SlideFadeTransition extends StatefulWidget {
  final Widget child;
  final int index;
  const _SlideFadeTransition({required this.child, required this.index});
  @override
  State<_SlideFadeTransition> createState() => _SlideFadeTransitionState();
}

class _SlideFadeTransitionState extends State<_SlideFadeTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _offsetAnim;
  late Animation<double> _fadeAnim;
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _offsetAnim = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeIn));
    Future.delayed(Duration(milliseconds: widget.index * 80), () {
      if (mounted) _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(position: _offsetAnim, child: widget.child));
  }
}

// ==========================================
// 🔥 EPHEMERAL MESSAGE BUBBLE (KÜL OLAN MESAJ)
// ==========================================
class EphemeralMessageBubble extends StatefulWidget {
  final String messageId;
  final String content;
  final bool isMe;
  final String time;
  final int durationSeconds;
  final bool isViewed;
  final String? otherUserAvatar;
  final bool showAvatar;
  final Widget? contentWidget;
  final bool isImage;
  final ChatService chatService;
  final VoidCallback onBurned;

  const EphemeralMessageBubble({
    super.key,
    required this.messageId,
    required this.content,
    required this.isMe,
    required this.time,
    required this.durationSeconds,
    required this.isViewed,
    required this.chatService,
    required this.onBurned,
    this.otherUserAvatar,
    this.showAvatar = true,
    this.contentWidget,
    this.isImage = false,
  });

  @override
  State<EphemeralMessageBubble> createState() => _EphemeralMessageBubbleState();
}

class _EphemeralMessageBubbleState extends State<EphemeralMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Timer? _burnTimer;
  int _remainingSeconds = 0;
  bool _isBurning = false;
  bool _isBurned = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.durationSeconds;
    _animController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.durationSeconds),
    );

    // Eğer ben gönderdiyseM veya zaten görüntülendiyse yanma başlat
    if (!widget.isMe && !widget.isViewed) {
      // Karşı taraf henüz görmedi, görüntüleme başlat
      _startViewing();
    } else if (!widget.isMe && widget.isViewed) {
      // Zaten görüntülenmiş, yanma devam ediyor demek
      _startBurning();
    }
  }

  void _startViewing() async {
    // Mesajı görüntülenmiş olarak işaretle
    await widget.chatService.markMessageAsViewed(widget.messageId);
    _startBurning();
  }

  void _startBurning() {
    if (_isBurning || _isBurned) return;
    setState(() => _isBurning = true);

    _animController.forward();

    _burnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        _burnMessage();
      }
    });
  }

  void _burnMessage() async {
    setState(() => _isBurned = true);
    await widget.chatService.deleteEphemeralMessage(widget.messageId);
    widget.onBurned();
  }

  @override
  void dispose() {
    _burnTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isBurned) {
      // Yandı - duman efekti
      return _buildBurnedPlaceholder();
    }

    final maxWidth = MediaQuery.of(context).size.width * 0.70;

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(
            vertical: widget.showAvatar ? 6 : 2, horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!widget.isMe) ...[
              if (widget.showAvatar)
                CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: widget.otherUserAvatar != null
                        ? NetworkImage(widget.otherUserAvatar!)
                        : null,
                    child: widget.otherUserAvatar == null
                        ? const Icon(Icons.person,
                            size: 16, color: Colors.white)
                        : null)
              else
                const SizedBox(width: 28),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Stack(
                children: [
                  Container(
                    padding: widget.isImage
                        ? const EdgeInsets.all(4)
                        : const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B00), Color(0xFFFF4500)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: widget.isMe
                            ? const Radius.circular(20)
                            : (widget.showAvatar
                                ? Radius.zero
                                : const Radius.circular(20)),
                        bottomRight: widget.isMe
                            ? (widget.showAvatar
                                ? Radius.zero
                                : const Radius.circular(20))
                            : const Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.isImage && widget.contentWidget != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: widget.contentWidget,
                          )
                        else
                          Text(
                            widget.content,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 15),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.time,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 10),
                            ),
                            const SizedBox(width: 6),
                            // 🔥 Ateş + Geri Sayım
                            if (_isBurning) ...[
                              const Icon(Icons.local_fire_department,
                                  color: Colors.yellow, size: 14),
                              const SizedBox(width: 2),
                              Text(
                                '${_remainingSeconds}s',
                                style: const TextStyle(
                                    color: Colors.yellow,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ] else ...[
                              const Icon(Icons.local_fire_department,
                                  color: Colors.white54, size: 14),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 🔥 Yanma Progress Göstergesi
                  if (_isBurning)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        child: AnimatedBuilder(
                          animation: _animController,
                          builder: (context, child) {
                            return LinearProgressIndicator(
                              value: _animController.value,
                              backgroundColor: Colors.transparent,
                              valueColor:
                                  const AlwaysStoppedAnimation(Colors.yellow),
                              minHeight: 3,
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBurnedPlaceholder() {
    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[800]?.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[700]!, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_fire_department,
                color: Colors.grey[600], size: 16),
            const SizedBox(width: 6),
            Text(
              'Mesaj küle döndü 🔥',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
