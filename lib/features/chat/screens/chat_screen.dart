// Kinnect - Sohbet Detayı Ekranı
// messages_screen.dart'tan refactor edildi

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

// Ses Paketleri
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

// Servisler ve Ekranlar
import '../../../data/services/chat_service.dart';
import 'call_screen.dart';
import '../widgets/chat_widgets.dart'; // Yardımcı widget'lar
import '../../profile/screens/profile_screen.dart'; // 👤 Profil Ekranı Eklendi

// ==========================================
// 🎨 RENK PALETİ
// ==========================================
const Color kChatBackgroundColor = Color(0xFF1F1B24);
const Color kHeaderColor = Color(0xFF2D2638);
const Color kReceivedBubbleColor = Color(0xFF38304C);
const Color kInputBackgroundColor = Color(0xFF2D2638);
const Color kAccentColor = Color(0xFF6C63FF);
const Color kListCardColor = Color(0xFF2D2638);

// ==========================================
// 💬 SOHBET DETAYI EKRANI
// ==========================================
class ChatScreen extends StatefulWidget {
  final String roomId;
  final Map<String, dynamic> otherUser;
  final String heroTag;
  final bool showReadReceipts;

  const ChatScreen({
    super.key,
    required this.roomId,
    required this.otherUser,
    this.heroTag = 'default_tag',
    this.showReadReceipts = true,
  });

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

  // 🎙️ Ses Kaydı Timer
  int _recordingDuration = 0;
  Timer? _recordingTimer;

  // 👁️ Son Görülme Bilgisi
  String _lastSeenText = '';
  // 🔒 Benim okundu bilgisi ayarım
  bool _myShowReadReceipts = true;
  // 🔒 Karşı tarafın okundu bilgisi ayarı
  bool _otherUserShowReadReceipts = true;

  @override
  void initState() {
    super.initState();
    _myShowReadReceipts = widget.showReadReceipts;
    _textController.addListener(_updateInputState);
    _loadLastSeen();
    _loadMyPrivacySettings();
    _loadOtherUserPrivacy();
    _markMessagesAsRead();
  }

  // 👁️ Son Görülme Bilgisini Yükle
  Future<void> _loadLastSeen() async {
    final userId = widget.otherUser['id']?.toString();
    if (userId == null) return;

    final lastSeen = await _chatService.getLastSeen(userId);
    if (lastSeen != null && mounted) {
      final now = DateTime.now();
      final diff = now.difference(lastSeen);

      String text;
      if (diff.inMinutes < 1) {
        text = 'Çevrimiçi';
      } else if (diff.inMinutes < 60) {
        text = '${diff.inMinutes} dk önce';
      } else if (diff.inHours < 24) {
        text = '${diff.inHours} saat önce';
      } else {
        text = '${diff.inDays} gün önce';
      }

      setState(() => _lastSeenText = text);
    }
  }

  // 🔒 Benim gizlilik ayarımı çek
  Future<void> _loadMyPrivacySettings() async {
    try {
      final myId = Supabase.instance.client.auth.currentUser?.id;
      if (myId == null) return;

      final response = await Supabase.instance.client
          .from('profiles')
          .select('show_read_receipts')
          .eq('id', myId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _myShowReadReceipts = response['show_read_receipts'] ?? true;
        });
      }
    } catch (_) {}
  }

  // 🔒 Karşı tarafın ayarını çek
  Future<void> _loadOtherUserPrivacy() async {
    final show =
        await _chatService.getReadReceiptSetting(widget.otherUser['id']);
    if (mounted) setState(() => _otherUserShowReadReceipts = show);
  }

  // ✅ Sohbete girince tüm mesajları okundu işaretle
  Future<void> _markMessagesAsRead() async {
    await _chatService.markAllMessagesAsRead(widget.roomId);
  }

  @override
  void dispose() {
    _textController.removeListener(_updateInputState);
    _textController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _updateInputState() {
    final isEmpty = _textController.text.trim().isEmpty;
    if (_isTextFieldEmpty != isEmpty) {
      setState(() => _isTextFieldEmpty = isEmpty);
    }
  }

  // 👤 PROFİLE GİTME FONKSİYONU
  void _goToProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)),
    );
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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
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
              backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
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
        // Kaydı durdur
        _recordingTimer?.cancel();
        final path = await _audioRecorder.stop();
        setState(() {
          _isRecording = false;
          _recordingDuration = 0;
        });
        if (path != null) _uploadAndSendAudio(path);
      } else {
        if (await _audioRecorder.hasPermission()) {
          final dir = await getApplicationDocumentsDirectory();
          final path =
              '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
          await _audioRecorder.start(const RecordConfig(), path: path);
          setState(() {
            _isRecording = true;
            _recordingDuration = 0;
          });
          // Timer başlat
          _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (mounted) {
              setState(() => _recordingDuration++);
            }
          });
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
        await picker.pickImage(source: source, imageQuality: 90);
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
    final myId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final otherId = widget.otherUser['id'].toString();
    final otherName = widget.otherUser['full_name']?.toString() ?? 'Kullanıcı';
    List<String> ids = [myId, otherId];
    ids.sort();
    final callId = ids.join("_");

    // 🔔 ARAMA BİLDİRİMİ GÖNDER
    try {
      await Supabase.instance.client.from('notifications').insert({
        'user_id': otherId,
        'actor_id': myId,
        'type': 'call',
        'is_video': isVideo,
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
        _buildHeader(targetName),
        // MESAJ LİSTESİ
        Expanded(child: _buildMessageList()),
        if (_isUploading)
          const LinearProgressIndicator(
              color: kAccentColor, backgroundColor: Colors.transparent),
        // INPUT
        _buildInputArea(),
      ]),
    );
  }

  Widget _buildHeader(String targetName) {
    return Container(
      padding: const EdgeInsets.only(top: 40, bottom: 20, left: 10, right: 20),
      decoration: const BoxDecoration(
          color: kHeaderColor,
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(50))),
      child: Row(children: [
        IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context)),

        // 👤 PROFİL FOTOĞRAFI (Tıklanabilir)
        GestureDetector(
          onTap: () {
            final userId = widget.otherUser['id']?.toString();
            if (userId != null) _goToProfile(userId);
          },
          child: Hero(
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
        ),

        const SizedBox(width: 12),

        // 👤 İSİM (Tıklanabilir)
        Expanded(
            child: GestureDetector(
                onTap: () {
                  final userId = widget.otherUser['id']?.toString();
                  if (userId != null) _goToProfile(userId);
                },
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(targetName,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                            overflow: TextOverflow.ellipsis),
                        if (_lastSeenText.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_lastSeenText == 'Çevrimiçi')
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF00D26A),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              Text(
                                _lastSeenText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _lastSeenText == 'Çevrimiçi'
                                      ? const Color(0xFF00D26A)
                                      : Colors.white54,
                                ),
                              ),
                            ],
                          ),
                      ],
                    )))),
        _buildHeaderButton(
            Icons.videocam_outlined, () => _startDirectCall(true),
            iconSize: 20),
        const SizedBox(width: 10),
        _buildHeaderButton(Icons.phone_outlined, () => _startDirectCall(false),
            iconSize: 18),
      ]),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _chatService.getMessagesStream(widget.roomId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: kAccentColor));
        }
        final messages = snapshot.data!;

        // Yeni mesaj geldiğinde otomatik scroll
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });

        if (messages.isEmpty) {
          return Center(
              child: Text("Henüz mesaj yok.",
                  style:
                      TextStyle(color: Colors.white.withValues(alpha: 0.3))));
        }

        // 🔥 Duplicate mesajları filtrele
        final seenIds = <String>{};
        final uniqueMessages = messages.where((m) {
          final id = m['id']?.toString() ?? '';
          if (seenIds.contains(id)) return false;
          seenIds.add(id);
          return true;
        }).toList();

        return ListView.builder(
            controller: _scrollController,
            itemCount: uniqueMessages.length,
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 20),
            itemBuilder: (context, index) {
              final msg = uniqueMessages[index];
              final isMe = msg['sender_id'] ==
                  (Supabase.instance.client.auth.currentUser?.id ?? '');

              // Avatar için önceki mesaja bak
              bool showAvatar = true;
              if (!isMe && index > 0) {
                final prevMsg = uniqueMessages[index - 1];
                if (prevMsg['sender_id'] == msg['sender_id']) {
                  showAvatar = false;
                }
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
    );
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
            color: kInputBackgroundColor,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5))
            ]),
        child: Row(children: [
          IconButton(
              onPressed: _showAttachmentMenu,
              icon: const Icon(Icons.attach_file, color: Colors.white54)),
          // 🔥 KÜL OLAN MOD BUTONU
          GestureDetector(
            onTap: () => setState(() => _isEphemeralMode = !_isEphemeralMode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isEphemeralMode
                    ? Colors.orange.withValues(alpha: 0.2)
                    : Colors.transparent,
                border: Border.all(
                  color: _isEphemeralMode ? Colors.orange : Colors.transparent,
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
                            ? Colors.orange.withValues(alpha: 0.6)
                            : Colors.white38,
                      ),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10)))),
          GestureDetector(
            onTap: _isTextFieldEmpty ? _toggleRecording : () => _sendMessage(),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      colors: _isEphemeralMode
                          ? [Colors.orange, Colors.deepOrange]
                          : [const Color(0xFF9D89D9), const Color(0xFF335FA1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  boxShadow: [
                    BoxShadow(
                        color: (_isEphemeralMode
                                ? Colors.orange
                                : const Color(0xFF335FA1))
                            .withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]),
              child: _isRecording
                  ? Text(
                      '$_recordingDuration',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    )
                  : Icon(
                      _isTextFieldEmpty ? Icons.mic : Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ]),
      ),
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
            color: Colors.white.withValues(alpha: 0.05)),
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
    final senderId = msg['sender_id'].toString();
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
      contentWidget = AudioMessagePlayer(url: content, isMe: isMe);
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
        onBurned: () {},
        // 👤 MESAJDAKİ PROFİLE TIKLAMA (Eğer widget destekliyorsa)
        onAvatarTap: () => _goToProfile(senderId),
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
        isViewed: isViewed,
        showReadReceipts: _myShowReadReceipts,
        otherUserShowReadReceipts: _otherUserShowReadReceipts,
        // 👤 MESAJDAKİ PROFİLE TIKLAMA (Eğer widget destekliyorsa)
        onAvatarTap: () => _goToProfile(senderId),
      ),
    );
  }
}
