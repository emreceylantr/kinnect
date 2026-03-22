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
import '../../../core/language/app_l10n.dart';
import '../../../data/services/chat_service.dart';
import 'call_screen.dart';
import 'group_management_screen.dart';
import '../widgets/chat_widgets.dart'; // Yardımcı widget'lar
import '../../profile/screens/profile_screen.dart'; // 👤 Profil Ekranı Eklendi
import '../../post/screens/post_detail_screen.dart';

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
  Map<String, dynamic>? _replyToMsg; // 💬 Yanıtlanan mesaj
  String _currentUserId = '';

  // 🎙️ Ses Kaydı Timer
  int _recordingDuration = 0;
  Timer? _recordingTimer;

  // 👁️ Son Görülme Bilgisi
  String _lastSeenText = '';
  // 🔒 Benim okundu bilgisi ayarım
  bool _myShowReadReceipts = true;
  // 🔒 Karşı tarafın okundu bilgisi ayarı
  bool _otherUserShowReadReceipts = true;

  // 👥 Grup chat desteği
  bool _isGroup = false;
  DateTime? _joinedAt; // Gruba katılma zamanı (önceki mesajları gizlemek için)
  final Map<String, Map<String, dynamic>> _senderProfiles = {};

  // 💬 Yazıyor... göstergesi + canlı online durumu
  RealtimeChannel? _presenceChannel;
  bool _otherUserTyping = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
    _myShowReadReceipts = widget.showReadReceipts;
    _isGroup = widget.otherUser['is_group'] == true;
    _textController.addListener(_onTextChanged);
    if (!_isGroup) {
      _loadLastSeen();
      _loadOtherUserPrivacy();
      _subscribePresence();
    } else {
      _loadJoinedAt();
    }
    _loadMyPrivacySettings();
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
        text = AppL10n.online;
      } else if (diff.inMinutes < 60) {
        text = AppL10n.minsAgo(diff.inMinutes);
      } else if (diff.inHours < 24) {
        text = AppL10n.hoursAgo(diff.inHours);
      } else {
        text = AppL10n.daysAgo(diff.inDays);
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
    final otherId = widget.otherUser['id']?.toString();
    if (otherId == null || otherId.isEmpty) return;
    final show = await _chatService.getReadReceiptSetting(otherId);
    if (mounted) setState(() => _otherUserShowReadReceipts = show);
  }

  // 👥 Gruba katılma zamanını yükle
  Future<void> _loadJoinedAt() async {
    final t = await _chatService.getJoinedAt(widget.roomId);
    if (mounted && t != null) setState(() => _joinedAt = t);
  }

  // 👤 Gönderici profilini yükle (grup mesajları için)
  Future<void> _loadSenderProfile(String senderId) async {
    if (_senderProfiles.containsKey(senderId)) return;
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('id, username, full_name, avatar_url')
          .eq('id', senderId)
          .maybeSingle();
      if (profile != null && mounted) {
        setState(() => _senderProfiles[senderId] = profile);
      }
    } catch (_) {}
  }

  // ✅ Sohbete girince tüm mesajları okundu işaretle
  Future<void> _markMessagesAsRead() async {
    await _chatService.markAllMessagesAsRead(widget.roomId);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _scrollController.dispose();
    _recordingTimer?.cancel();
    _typingTimer?.cancel();
    if (_isRecording) {
      _audioRecorder.stop().ignore();
    }
    _audioRecorder.dispose();
    _presenceChannel?.unsubscribe();
    super.dispose();
  }

  void _updateInputState() {
    final isEmpty = _textController.text.trim().isEmpty;
    if (_isTextFieldEmpty != isEmpty) {
      setState(() => _isTextFieldEmpty = isEmpty);
    }
  }

  void _onTextChanged() {
    _updateInputState();
    _typingTimer?.cancel();
    _presenceChannel?.track({'user_id': _currentUserId, 'typing': true}).ignore();
    _typingTimer = Timer(const Duration(milliseconds: 1500), () {
      _presenceChannel?.track({'user_id': _currentUserId, 'typing': false}).ignore();
    });
  }

  void _subscribePresence() {
    _presenceChannel = Supabase.instance.client
        .channel('chat_presence:${widget.roomId}');

    _presenceChannel!
        .onPresenceSync((_) => _updatePresenceState())
        .onPresenceJoin((_) => _updatePresenceState())
        .onPresenceLeave((_) {
          _updatePresenceState();
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted && _lastSeenText == AppL10n.online) _loadLastSeen();
          });
        })
        .subscribe((status, error) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            await _presenceChannel!.track({
              'user_id': _currentUserId,
              'typing': false,
            });
          }
        });
  }

  void _updatePresenceState() {
    if (!mounted) return;
    final otherId = widget.otherUser['id']?.toString();
    if (otherId == null) return;

    final state = _presenceChannel?.presenceState() ?? [];
    bool isOtherOnline = false;
    bool isOtherTyping = false;

    for (final singleState in state) {
      for (final presence in singleState.presences) {
        if (presence.payload['user_id'] == otherId) {
          isOtherOnline = true;
          if (presence.payload['typing'] == true) isOtherTyping = true;
        }
      }
    }

    setState(() {
      _otherUserTyping = isOtherTyping;
      if (isOtherOnline) _lastSeenText = AppL10n.online;
    });
  }

  // 👤 PROFİLE GİTME FONKSİYONU
  void _goToProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId)),
    );
  }

  // 📸 PAYLAŞILAN GÖNDERIYI AÇ
  Future<void> _openSharedPost(Map<String, dynamic> sharedPostData) async {
    final postId = sharedPostData['post_id']?.toString();
    if (postId == null) return;
    try {
      final post = await Supabase.instance.client
          .from('posts')
          .select('*, profiles(*), likes(*), comments(*)')
          .eq('id', postId)
          .single();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.postNotFound)),
      );
    }
  }

  void _sendMessage([String? fileUrl]) async {
    String content = fileUrl ?? _textController.text.trim();
    if (content.isEmpty) return;
    if (fileUrl == null) _textController.clear();

    // Reply bilgilerini al ve state'i temizle
    final replyId = _replyToMsg?['id']?.toString();
    final replyContent = _replyToMsg?['content']?.toString();
    final isMyReplyMsg = _replyToMsg?['sender_id'] == _currentUserId;
    final replySenderName = isMyReplyMsg ? AppL10n.you : (widget.otherUser['full_name'] ?? AppL10n.user);
    if (_replyToMsg != null) setState(() => _replyToMsg = null);

    try {
      final receiverId = widget.otherUser['id']?.toString();
      await _chatService.sendMessage(
        widget.roomId,
        content,
        receiverId,
        isEphemeral: _isEphemeralMode,
        ephemeralDuration: 5,
        replyToId: replyId,
        replyToContent: replyContent,
        replyToSenderName: replyId != null ? replySenderName : null,
      );

      // Ephemeral mod'u resetle
      if (_isEphemeralMode && mounted) {
        setState(() => _isEphemeralMode = false);
      }

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${AppL10n.error}: $e')));
      }
    }
  }

  // 💬 MESAJ SEÇENEKLERİ (long press)
  void _showMessageOptions(Map<String, dynamic> msg, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF2D2638),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Emoji reaksiyon satırı
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['❤️', '😂', '😮', '😢', '😡', '👍'].map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _chatService.toggleReaction(msg['id'].toString(), emoji);
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 32)),
                  );
                }).toList(),
              ),
            ),
            const Divider(color: Colors.white12, height: 8),
            // Yanıtla
            ListTile(
              leading: const Icon(Icons.reply, color: Colors.white70),
              title: Text(AppL10n.reply, style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyToMsg = msg);
              },
            ),
            // Sil (sadece benim mesajım)
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: Text(AppL10n.delete, style: const TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteMessageDialog(msg['id'].toString());
                },
              ),
          ],
        ),
      ),
    );
  }

  // 💬 YANIT ÖNZL BAR
  Widget _buildReplyBar() {
    if (_replyToMsg == null) return const SizedBox.shrink();
    final content = _replyToMsg!['content'] as String? ?? '';
    final isMyMsg = _replyToMsg!['sender_id'] == _currentUserId;
    final senderName = isMyMsg ? AppL10n.you : (widget.otherUser['full_name'] ?? AppL10n.user);

    final bool isImage = content.startsWith('http') &&
        (content.contains('.jpg') ||
            content.contains('.png') ||
            content.contains('image_picker') ||
            content.contains('chat_images'));
    final bool isAudio = content.startsWith('http') &&
        (content.contains('.m4a') || content.contains('audio_'));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2638),
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: Color(0xFF6C63FF), width: 3)),
      ),
      child: Row(
        children: [
          // Resim önizlemesi
          if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                content,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white38,
                  size: 40,
                ),
              ),
            ),
          if (isImage) const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(senderName,
                    style: const TextStyle(
                        color: Color(0xFF9D89D9),
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                if (isImage)
                  Text(AppL10n.photo,
                      style: const TextStyle(color: Colors.white54, fontSize: 12))
                else if (isAudio)
                  Text(AppL10n.voiceMessage,
                      style: const TextStyle(color: Colors.white54, fontSize: 12))
                else
                  Text(content,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 18),
            onPressed: () => setState(() => _replyToMsg = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // 🔥 TEK MESAJ SİLME DIALOG
  void _showDeleteMessageDialog(String messageId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text(AppL10n.deleteMessage,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          AppL10n.deleteMessageConfirm,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppL10n.cancel, style: const TextStyle(color: Colors.white54)),
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
                  SnackBar(
                    content: Text(AppL10n.messageDeleted),
                    backgroundColor: Colors.redAccent,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Text(AppL10n.delete),
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
                    title: Text(AppL10n.camera,
                        style: const TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    }),
                ListTile(
                    leading:
                        const Icon(Icons.photo_library, color: Colors.white),
                    title: Text(AppL10n.gallery,
                        style: const TextStyle(color: Colors.white)),
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
    final otherName = widget.otherUser['full_name']?.toString() ?? AppL10n.user;
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

  // 📞 GRUP ARAMASI
  void _startGroupCall(bool isVideo) async {
    final myId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final groupName = widget.otherUser['group_name']?.toString() ?? 'Grup';
    // Grup aramaları için roomId'yi call ID olarak kullan
    final callId = 'group_${widget.roomId}';

    // Tüm katılımcılara bildirim gönder
    try {
      final participants = List<String>.from(widget.otherUser['participants'] ?? []);
      final myProfile = await Supabase.instance.client
          .from('profiles')
          .select('username, full_name')
          .eq('id', myId)
          .single();
      final callerName = myProfile['full_name'] ?? myProfile['username'] ?? 'Birisi';

      for (final participantId in participants) {
        if (participantId == myId) continue;
        try {
          await Supabase.instance.client.functions
              .invoke('send-push-notification', body: {
            'target_user_id': participantId,
            'title': isVideo ? '📹 Grup Görüntülü Arama' : '📞 Grup Sesli Arama',
            'body': '$callerName $groupName grubunu arıyor',
            'type': 'call',
            'target_id': callId,
          });
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Grup arama bildirimi hatası: $e');
    }

    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CallScreen(
                callId: callId,
                otherUserName: groupName,
                isVideo: isVideo,
                otherUserAvatar: widget.otherUser['group_avatar_url'] ?? widget.otherUser['avatar_url'])));
  }

  @override
  Widget build(BuildContext context) {
    final targetName = widget.otherUser['full_name']?.toString() ?? AppL10n.user;
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

        if (_isGroup) ...[
          // 👥 GRUP AVATARI (tıklayınca full screen)
          GestureDetector(
            onTap: () {
              final avatarUrl = widget.otherUser['group_avatar_url'] ?? widget.otherUser['avatar_url'];
              if (avatarUrl != null) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => FullScreenImage(imageUrl: avatarUrl, heroTag: widget.heroTag),
                ));
              }
            },
            child: Hero(
              tag: widget.heroTag,
              child: CircleAvatar(
                radius: 22,
                backgroundImage: (widget.otherUser['group_avatar_url'] ?? widget.otherUser['avatar_url']) != null
                    ? NetworkImage(widget.otherUser['group_avatar_url'] ?? widget.otherUser['avatar_url'])
                    : null,
                backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                child: (widget.otherUser['group_avatar_url'] ?? widget.otherUser['avatar_url']) == null
                    ? const Icon(Icons.group, color: Color(0xFF6C63FF), size: 22)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.otherUser['group_name'] ?? targetName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.otherUser['participants_count'] != null)
                  Text(
                    AppL10n.members(widget.otherUser['participants_count'] as int),
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
              ],
            ),
          ),
          _buildHeaderButton(Icons.videocam_outlined, () => _startGroupCall(true), iconSize: 20),
          const SizedBox(width: 6),
          _buildHeaderButton(Icons.phone_outlined, () => _startGroupCall(false), iconSize: 18),
          const SizedBox(width: 6),
          _buildHeaderButton(Icons.settings_outlined, () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroupManagementScreen(roomId: widget.roomId),
              ),
            );
          }, iconSize: 18),
        ] else ...[
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
                          if (_otherUserTyping)
                            _TypingIndicator()
                          else if (_lastSeenText.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_lastSeenText == AppL10n.online)
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
                                    color: _lastSeenText == AppL10n.online
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
        ],
      ]),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _chatService.getMessagesStream(widget.roomId, joinedAt: _joinedAt),
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
          final otherName = widget.otherUser['full_name']?.toString() ?? AppL10n.user;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kAccentColor.withValues(alpha: 0.1),
                    border: Border.all(color: kAccentColor.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.waving_hand_outlined,
                      color: kAccentColor, size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  '$otherName ${AppL10n.chatStarted}',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                Text(
                  AppL10n.sendFirstMessage,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
                ),
              ],
            ),
          );
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

              // Grup chatinde gönderici profilini yükle
              if (_isGroup && !isMe) {
                _loadSenderProfile(msg['sender_id'].toString());
              }

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildReplyBar(),
        _buildInputRow(),
      ],
    );
  }

  Widget _buildInputRow() {
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
                          ? AppL10n.typeEphemeralMessage
                          : AppL10n.typeMessage,
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

    // Grup chatinde gönderici bilgileri
    final senderProfile = _isGroup && !isMe ? _senderProfiles[senderId] : null;
    final senderAvatar = senderProfile?['avatar_url'] ?? widget.otherUser['avatar_url'];
    final senderDisplayName = senderProfile?['full_name'] ?? senderProfile?['username'] ?? AppL10n.user;
    final createdAtRaw = msg['created_at'] as String;
    final ephemeralDuration = msg['ephemeral_duration'] as int? ?? 5;

    final time =
        DateFormat('HH:mm').format(DateTime.parse(createdAtRaw).toLocal());

    // Reaksiyon ve reply verileri
    final reactionsRaw = msg['reactions'] as Map<String, dynamic>? ?? {};
    final reactions = reactionsRaw.map((k, v) => MapEntry(k, List<String>.from(v)));
    final replyToContent = msg['reply_to_content'] as String?;
    final replyToSenderName = msg['reply_to_sender_name'] as String?;

    // 📸 Paylaşılan gönderi mi?
    final sharedPostData = msg['shared_post_data'] as Map<String, dynamic>?;
    if (sharedPostData != null) {
      final sharedBubble = SwipeToReplyWrapper(
        onReply: () => setState(() => _replyToMsg = msg),
        child: GestureDetector(
          onLongPress: () => _showMessageOptions(msg, isMe),
          child: SharedPostBubble(
            sharedPostData: sharedPostData,
            isMe: isMe,
            time: time,
            otherUserAvatar: senderAvatar,
            showAvatar: showAvatar,
            isViewed: isViewed,
            showReadReceipts: _myShowReadReceipts,
            otherUserShowReadReceipts: _otherUserShowReadReceipts,
            onAvatarTap: () => _goToProfile(senderId),
            onTap: () => _openSharedPost(sharedPostData),
          ),
        ),
      );
      if (_isGroup && !isMe && showAvatar) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 52, bottom: 2),
              child: Text(senderDisplayName, style: const TextStyle(color: Color(0xFF9D89D9), fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            sharedBubble,
          ],
        );
      }
      return sharedBubble;
    }

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

    void triggerReply() {
      setState(() => _replyToMsg = msg);
    }

    // 🔥 Ephemeral mesaj ise özel widget kullan
    if (isEphemeral) {
      final bubble = SwipeToReplyWrapper(
        onReply: triggerReply,
        child: GestureDetector(
          onLongPress: () => _showMessageOptions(msg, isMe),
          child: EphemeralMessageBubble(
            messageId: messageId,
            content: content,
            isMe: isMe,
            time: time,
            durationSeconds: ephemeralDuration,
            isViewed: isViewed,
            otherUserAvatar: senderAvatar,
            showAvatar: showAvatar,
            contentWidget: contentWidget,
            isImage: isImg,
            chatService: _chatService,
            onBurned: () {},
            onAvatarTap: () => _goToProfile(senderId),
          ),
        ),
      );
      if (_isGroup && !isMe && showAvatar) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 52, bottom: 2),
              child: Text(senderDisplayName, style: const TextStyle(color: Color(0xFF9D89D9), fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            bubble,
          ],
        );
      }
      return bubble;
    }

    // Normal mesaj - swipe + long press
    final normalBubble = SwipeToReplyWrapper(
      onReply: triggerReply,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(msg, isMe),
        child: ModernMessageBubble(
          content: content,
          isMe: isMe,
          time: time,
          contentWidget: contentWidget,
          isImage: isImg,
          otherUserAvatar: senderAvatar,
          showAvatar: showAvatar,
          isViewed: isViewed,
          showReadReceipts: _myShowReadReceipts,
          otherUserShowReadReceipts: _otherUserShowReadReceipts,
          onAvatarTap: () => _goToProfile(senderId),
          reactions: reactions,
          myUserId: _currentUserId,
          replyToContent: replyToContent,
          replyToSenderName: replyToSenderName,
          onReact: (emoji) => _chatService.toggleReaction(messageId, emoji),
        ),
      ),
    );

    if (_isGroup && !isMe && showAvatar) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 52, bottom: 2),
            child: Text(senderDisplayName, style: const TextStyle(color: Color(0xFF9D89D9), fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          normalBubble,
        ],
      );
    }
    return normalBubble;
  }
}

// ==========================================
// 💬 YAZILIYOR ANİMASYONU
// ==========================================
class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final dots = '.' * ((_controller.value * 3).floor() + 1);
        return Text(
          'Yazıyor$dots',
          style: const TextStyle(
            fontSize: 12,
            color: kAccentColor,
            fontStyle: FontStyle.italic,
          ),
        );
      },
    );
  }
}
