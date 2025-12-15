import 'dart:async'; // Timer için gerekli
import 'dart:io';
import 'dart:ui'; // Glassmorphism ve ImageFilter için gerekli
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

// Ses Paketleri
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// Zego Paketleri
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

import '../services/chat_service.dart';
import 'call_screen.dart'; // Oda ekranı

// ==========================================
// RENK PALETİ
// ==========================================

// 1. CHAT EKRANI RENKLERİ
const Color kChatBackgroundColor = Color(0xFF1F1B24); // Çok Koyu Morumsu Gri (Zemin)
const Color kHeaderColor = Color(0xFF2D2638);         // Header
const Color kReceivedBubbleColor = Color(0xFF38304C); // Gelen Mesaj
const Color kInputBackgroundColor = Color(0xFF2D2638);// Input Alanı

// 2. LİSTE EKRANI RENKLERİ
const Color kListBgColor = Color(0xFF1B1424);         // Derin Mor Zemin
const Color kSearchBtnColor = Color(0xFF292233);      // Arama butonu arkaplanı
const Color kTextWhite = Colors.white;                // Ana Metin
const Color kTextGrey = Colors.white54;               // Alt Metin
const Color kBadgeColor = Color(0xFF448AFF);          // Mavi Bildirim Rengi
const Color kAccentColor = Color(0xFF6C63FF);         // Vurgu Rengi
const Color kListCardColor = Color(0xFF2D2638);       // Menüler için koyu renk

// ==========================================
// YARDIMCI GÖRSEL WIDGETLAR
// ==========================================

class FullScreenImage extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const FullScreenImage({super.key, required this.imageUrl, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4,
            child: Image.network(imageUrl),
          ),
        ),
      ),
    );
  }
}

// MESAJ BALONCUĞU
class ModernMessageBubble extends StatelessWidget {
  final String content;
  final bool isMe;
  final String time;
  final Widget? contentWidget;
  final bool isImage;
  final String? otherUserAvatar;
  final bool showAvatar;

  const ModernMessageBubble({
    super.key,
    required this.content,
    required this.isMe,
    required this.time,
    this.contentWidget,
    this.isImage = false,
    this.otherUserAvatar,
    this.showAvatar = true,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.70;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: showAvatar ? 6 : 2, horizontal: 16),
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
                      ? const Icon(Icons.person, size: 16, color: Colors.white)
                      : null,
                )
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
                      ? const LinearGradient(
                    colors: [Color(0xFF9D89D9), Color(0xFF899DD9), Color(0xFF335FA1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                      : null,
                  color: isMe ? null : kReceivedBubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: isMe ? const Radius.circular(20) : (showAvatar ? Radius.zero : const Radius.circular(20)),
                    bottomRight: isMe ? (showAvatar ? Radius.zero : const Radius.circular(20)) : const Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: isImage
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildImageContent(context),
                )
                    : _buildTextOrAudioContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageContent(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        contentWidget!,
        Positioned(
          bottom: 6,
          right: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              time,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextOrAudioContent() {
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.end,
      runSpacing: 4,
      children: [
        contentWidget ?? Text(
          content,
          style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            time,
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 1. EKRAN: SOHBETLER LİSTESİ (FİNAL HEADER TASARIMI)
// ==========================================
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final ChatService _chatService = ChatService();
  late Future<List<Map<String, dynamic>>> _chatsFuture;
  String _searchQuery = "";

  // Arama durumu kontrolü
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // Animasyon ve Kullanıcı Verisi
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
        setState(() {
          _showGreeting = false;
        });
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
      } else {
        final meta = user.userMetadata;
        if (meta != null) {
          name = meta['full_name']?.toString() ?? name;
          avatar = meta['avatar_url']?.toString();
        }
      }
    } catch (_) {
      final meta = user.userMetadata;
      if (meta != null) {
        name = meta['full_name']?.toString() ?? name;
        avatar = meta['avatar_url']?.toString();
      }
    }

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kListBgColor, // Derin Mor Zemin
      body: SafeArea(
        child: Column(
          children: [
            // ================= FİNAL HEADER =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SATIR 1: Sol Üst (Geri) ve Sağ Üst (Arama) ---
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
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: "Sohbet ara...",
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                        prefixIcon: const Icon(Icons.search, color: Colors.white70),
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
                      // Sol Üst: Zarif Geri Oku
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),

                      // Sağ Üst: Arama Butonu
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: kSearchBtnColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.search, color: Colors.white70, size: 20),
                          onPressed: () {
                            setState(() {
                              _isSearching = true;
                            });
                          },
                        ),
                      ),
                    ],
                  ),

                  // --- SADECE ARAMA YAPILMIYORSA GÖSTER ---
                  if (!_isSearching) ...[
                    const SizedBox(height: 10),

                    // --- SATIR 2: ORTA KISIM (Merhaba / Avatar Animasyonu) ---
                    SizedBox(
                      height: 80,
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 800),
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            return FadeTransition(opacity: animation, child: child);
                          },
                          child: _showGreeting
                              ? Text(
                            "Merhaba, $_firstName",
                            key: const ValueKey('greeting'),
                            style: const TextStyle(
                              color: kTextWhite,
                              fontSize: 24,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 1.0,
                            ),
                          )
                              : Container(
                            key: const ValueKey('avatar'),
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: kAccentColor, width: 2),
                                boxShadow: [
                                  BoxShadow(color: kAccentColor.withOpacity(0.3), blurRadius: 15)
                                ]
                            ),
                            child: CircleAvatar(
                              radius: 35,
                              backgroundColor: Colors.grey[800],
                              backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                                  ? NetworkImage(_avatarUrl!)
                                  : null,
                              child: _avatarUrl == null || _avatarUrl!.isEmpty
                                  ? Text(
                                _firstName.isNotEmpty ? _firstName[0] : "K",
                                style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                              )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // --- SATIR 3: ALT KISIM (Sohbetler Yazısı - Sola Yaslı) ---
                    const Text(
                      'Sohbetler',
                      style: TextStyle(
                        fontFamily: 'Sans',
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                        color: kTextWhite,
                      ),
                    ),
                  ]
                ],
              ),
            ),
            // ================= HEADER BİTİŞ =================

            // --- LİSTE ---
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
                    final name = (otherUser['full_name'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery);
                  }).toList();

                  if (filteredChats.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 50, color: Colors.grey[700]),
                          const SizedBox(height: 16),
                          Text(
                              _searchQuery.isEmpty ? 'Sohbet yok' : 'Sonuç bulunamadı',
                              style: TextStyle(color: Colors.grey[600])
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredChats.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final chat = filteredChats[index];
                      final otherUser = chat['other_user'] ?? {};
                      final lastUpdateRaw = chat['updated_at'];
                      final lastUpdate = lastUpdateRaw != null
                          ? DateTime.parse(lastUpdateRaw).toLocal()
                          : DateTime.now();

                      final unreadCount = 0;

                      return _SlideFadeTransition(
                        index: index,
                        child: _buildListCard(context, chat, otherUser, lastUpdate, unreadCount),
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

  // Liste Elemanı (GÜNCELLENMİŞ: KÜÇÜLTÜLMÜŞ VE SİYAH OLMAYAN KART)
  Widget _buildListCard(BuildContext context, Map<String, dynamic> chat,
      Map<String, dynamic> otherUser, DateTime lastUpdate, int unreadCount) {
    final String heroTag = "list_avatar_${otherUser['id']}";
    final bool hasUnread = unreadCount > 0;

    return Container(
      // Kartlar arası boşluk azaltıldı (20 -> 10)
      margin: const EdgeInsets.only(bottom: 10),
      // --- YENİ DECORATION: Siyah yerine Şeffaf Beyaz ---
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05), // Hafif yarı şeffaf beyaz (Glass effect)
        borderRadius: BorderRadius.circular(20),
        // Siyah gölge kaldırıldı veya çok hafifletildi
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  roomId: chat['id'],
                  otherUser: otherUser,
                  heroTag: heroTag,
                ),
              ),
            ).then((_) => _refreshChats());
          },
          // İç boşluk azaltıldı (12 -> 8)
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
            child: Row(
              children: [
                Hero(
                  tag: heroTag,
                  child: CircleAvatar(
                    radius: 26, // Profil resmi küçültüldü (30 -> 26)
                    backgroundColor: Colors.grey[800],
                    backgroundImage: otherUser['avatar_url'] != null
                        ? NetworkImage(otherUser['avatar_url'])
                        : null,
                    child: otherUser['avatar_url'] == null
                        ? const Icon(Icons.person, color: Colors.white54, size: 26)
                        : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        otherUser['full_name'] ?? 'Kullanıcı',
                        style: const TextStyle(
                          color: kTextWhite,
                          fontWeight: FontWeight.w600,
                          fontSize: 16, // İsim boyutu küçültüldü (18 -> 16)
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sohbeti görüntüle...',
                        style: TextStyle(
                          color: hasUnread ? Colors.white : kTextGrey,
                          fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13, // Mesaj boyutu küçültüldü (14 -> 13)
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
                      DateFormat('HH:mm').format(lastUpdate),
                      style: TextStyle(color: kTextGrey, fontSize: 11), // Saat küçültüldü
                    ),
                    const SizedBox(height: 6),
                    if (hasUnread)
                      Container(
                        width: 18, // Rozet küçültüldü
                        height: 18,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: kBadgeColor,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unreadCount.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- YARDIMCI: LİSTE ANİMASYON WIDGET'I ---
class _SlideFadeTransition extends StatefulWidget {
  final Widget child;
  final int index;

  const _SlideFadeTransition({required this.child, required this.index});

  @override
  State<_SlideFadeTransition> createState() => _SlideFadeTransitionState();
}

class _SlideFadeTransitionState extends State<_SlideFadeTransition> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _offsetAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _offsetAnim = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _fadeAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeIn));

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
      child: SlideTransition(
        position: _offsetAnim,
        child: widget.child,
      ),
    );
  }
}

// ==========================================
// 2. EKRAN: SOHBET DETAYI (CHAT) - (KORUNDU)
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

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        final path = await _audioRecorder.stop();
        setState(() => _isRecording = false);
        if (path != null) _uploadAndSendAudio(path);
      } else {
        if (await _audioRecorder.hasPermission()) {
          final dir = await getApplicationDocumentsDirectory();
          final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
          await _audioRecorder.start(const RecordConfig(), path: path);
          setState(() => _isRecording = true);
        }
      }
    } catch (e) { debugPrint("Kayıt hatası: $e"); }
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
    } catch (e) { } finally { setState(() => _isUploading = false); }
  }

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
    } catch (_) {} finally { setState(() => _isUploading = false); }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Container(
            color: kListCardColor, // Menü Koyu Gri
            child: SafeArea(
              child: Wrap(
                children: [
                  ListTile(
                    leading: const Icon(Icons.camera_alt, color: Colors.white),
                    title: const Text("Kamera", style: TextStyle(color: Colors.white)),
                    onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library, color: Colors.white),
                    title: const Text("Galeri", style: TextStyle(color: Colors.white)),
                    onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _startDirectCall(bool isVideo) {
    final myId = Supabase.instance.client.auth.currentUser!.id;
    final otherId = widget.otherUser['id'].toString();
    final otherName = widget.otherUser['full_name']?.toString() ?? 'Kullanıcı';
    List<String> ids = [myId, otherId]; ids.sort(); final callId = ids.join("_");
    Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(callId: callId, otherUserName: otherName, isVideo: isVideo)));
  }

  @override
  Widget build(BuildContext context) {
    final targetName = widget.otherUser['full_name']?.toString() ?? 'Kullanıcı';

    return Scaffold(
      backgroundColor: kChatBackgroundColor,
      body: Column(
        children: [
          // --- HEADER (SOLA YASLI İSİM + 12px BOŞLUK) ---
          Container(
            padding: const EdgeInsets.only(top: 40, bottom: 20, left: 10, right: 20),
            decoration: const BoxDecoration(
              color: kHeaderColor,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(50),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Hero(
                  tag: widget.heroTag,
                  child: CircleAvatar(
                    radius: 22,
                    backgroundImage: widget.otherUser['avatar_url'] != null
                        ? NetworkImage(widget.otherUser['avatar_url'])
                        : null,
                    child: widget.otherUser['avatar_url'] == null
                        ? const Icon(Icons.person, color: Colors.white70)
                        : null,
                    backgroundColor: Colors.grey[800],
                  ),
                ),
                const SizedBox(width: 12), // BOŞLUK 12 OLARAK AYARLANDI
                Expanded(
                  child: Align( // SOLA YASLAMA
                    alignment: Alignment.centerLeft,
                    child: Text(
                      targetName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // Butonlar
                _buildHeaderButton(Icons.videocam_outlined, () => _startDirectCall(true), iconSize: 20),
                const SizedBox(width: 10),
                _buildHeaderButton(Icons.phone_outlined, () => _startDirectCall(false), iconSize: 18),
              ],
            ),
          ),

          // --- MESAJLAR ---
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _chatService.getMessagesStream(widget.roomId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: kAccentColor));
                }
                final messages = snapshot.data!;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients && _scrollController.offset == 0) _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 20),
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_id'] == Supabase.instance.client.auth.currentUser!.id;
                    bool showAvatar = true;
                    if (!isMe && index > 0) {
                      final prevMsg = messages[index - 1];
                      if (prevMsg['sender_id'] == msg['sender_id']) showAvatar = false;
                    }
                    return _buildMessageBubble(msg['content'], isMe, msg['created_at'], showAvatar);
                  },
                );
              },
            ),
          ),

          if (_isUploading) const LinearProgressIndicator(color: kAccentColor, backgroundColor: Colors.transparent),

          // --- INPUT ALANI ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: kInputBackgroundColor,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _showAttachmentMenu,
                    icon: const Icon(Icons.attach_file, color: Colors.white54),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Mesaj yaz...',
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ),

                  // --- GRADIENT SES BUTONU ---
                  GestureDetector(
                    onTap: _isTextFieldEmpty ? _toggleRecording : () => _sendMessage(),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF9D89D9), // Açık Mor
                            Color(0xFF335FA1), // Koyu Mavi
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF335FA1).withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop : (_isTextFieldEmpty ? Icons.mic : Icons.send),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton(IconData icon, VoidCallback onTap, {double iconSize = 18}) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white12),
        color: Colors.white.withOpacity(0.05),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: iconSize),
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }

  Widget _buildMessageBubble(String content, bool isMe, String createdAtRaw, bool showAvatar) {
    final time = DateFormat('HH:mm').format(DateTime.parse(createdAtRaw).toLocal());
    bool isImage = content.startsWith('http') && (content.contains('.jpg') || content.contains('.png') || content.contains('image_picker'));
    bool isAudio = content.startsWith('http') && (content.contains('.m4a') || content.contains('.mp3') || content.contains('audio_'));

    Widget? contentWidget;
    bool isImg = false;

    if (isImage) {
      isImg = true;
      contentWidget = GestureDetector(
        onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImage(imageUrl: content, heroTag: content))); },
        child: Hero(tag: content, child: Image.network(content, fit: BoxFit.cover, height: 250, width: 220)),
      );
    } else if (isAudio) {
      contentWidget = _AudioMessagePlayer(url: content, isMe: isMe);
    }

    return ModernMessageBubble(
      content: content,
      isMe: isMe,
      time: time,
      contentWidget: contentWidget,
      isImage: isImg,
      otherUserAvatar: widget.otherUser['avatar_url'],
      showAvatar: showAvatar,
    );
  }
}

// --- SES OYNATICI ---
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
  void dispose() { _player.dispose(); super.dispose(); }

  void _togglePlay() async {
    if (isPlaying) { await _player.pause(); } else { await _player.play(UrlSource(widget.url)); }
    setState(() => isPlaying = !isPlaying);
    _player.onPlayerComplete.listen((event) { if (mounted) setState(() => isPlaying = false); });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: Colors.white, size: 35),
          onPressed: _togglePlay, padding: EdgeInsets.zero, constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),
        Container(height: 3, width: 100, decoration: BoxDecoration(color: Colors.white54, borderRadius: BorderRadius.circular(10))),
        const SizedBox(width: 8),
        const Text("Ses", style: TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}