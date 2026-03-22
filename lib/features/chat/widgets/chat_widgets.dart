// Kinnect - Chat Yardımcı Widget'ları
// messages_screen.dart'tan refactor edildi

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/language/app_l10n.dart';
import '../../../data/services/chat_service.dart';

// ==========================================
// 🎨 RENK PALETİ
// ==========================================
const Color kReceivedBubbleColor = Color(0xFF38304C);

// ==========================================
// 💬 SWIPE TO REPLY WRAPPER
// ==========================================
class SwipeToReplyWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;

  const SwipeToReplyWrapper({
    super.key,
    required this.child,
    required this.onReply,
  });

  @override
  State<SwipeToReplyWrapper> createState() => _SwipeToReplyWrapperState();
}

class _SwipeToReplyWrapperState extends State<SwipeToReplyWrapper>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  bool _triggered = false;
  late AnimationController _snapController;
  late Animation<double> _snapAnimation;

  static const double _threshold = 60.0;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (details.delta.dx > 0) {
      setState(() {
        _dragOffset = (_dragOffset + details.delta.dx).clamp(0.0, _threshold + 10);
      });

      if (_dragOffset >= _threshold && !_triggered) {
        _triggered = true;
        HapticFeedback.mediumImpact();
      }
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (_triggered) {
      widget.onReply();
    }
    _triggered = false;

    _snapAnimation = Tween<double>(begin: _dragOffset, end: 0).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.elasticOut),
    )..addListener(() {
        setState(() => _dragOffset = _snapAnimation.value);
      });

    _snapController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Stack(
        children: [
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
          if (_dragOffset > 10)
            Positioned(
              left: _dragOffset - 30,
              top: 0,
              bottom: 0,
              child: Center(
                child: Opacity(
                  opacity: (_dragOffset / _threshold).clamp(0.0, 1.0),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.reply,
                      color: const Color(0xFF9D89D9),
                      size: 18 * (_dragOffset / _threshold).clamp(0.5, 1.0),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ==========================================
// 🖼️ TAM EKRAN RESİM GÖRÜNTÜLEYİCİ
// ==========================================
class FullScreenImage extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const FullScreenImage({
    super.key,
    required this.imageUrl,
    required this.heroTag,
  });

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

// ==========================================
// 💬 MODERN MESAJ BALONCUĞU
// ==========================================
class ModernMessageBubble extends StatelessWidget {
  final String content;
  final bool isMe;
  final String time;
  final Widget? contentWidget;
  final bool isImage;
  final String? otherUserAvatar;
  final bool showAvatar;
  final bool isViewed;
  final bool showReadReceipts;
  final bool otherUserShowReadReceipts;
  final VoidCallback? onAvatarTap;
  final Map<String, List<String>>? reactions;
  final String? myUserId;
  final String? replyToContent;
  final String? replyToSenderName;
  final Function(String emoji)? onReact;

  const ModernMessageBubble({
    super.key,
    required this.content,
    required this.isMe,
    required this.time,
    this.contentWidget,
    this.isImage = false,
    this.otherUserAvatar,
    this.showAvatar = true,
    this.isViewed = false,
    this.showReadReceipts = true,
    this.otherUserShowReadReceipts = true,
    this.onAvatarTap,
    this.reactions,
    this.myUserId,
    this.replyToContent,
    this.replyToSenderName,
    this.onReact,
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
                GestureDetector(
                  onTap: onAvatarTap,
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: otherUserAvatar != null ? NetworkImage(otherUserAvatar!) : null,
                    child: otherUserAvatar == null ? const Icon(Icons.person, size: 16, color: Colors.white) : null,
                  ),
                )
              else
                const SizedBox(width: 28),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: isImage
                        ? const EdgeInsets.all(4)
                        : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isMe
                          ? const LinearGradient(
                              colors: [Color(0xFF9D89D9), Color(0xFF899DD9), Color(0xFF335FA1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight)
                          : null,
                      color: isMe ? null : kReceivedBubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: isMe ? const Radius.circular(20) : (showAvatar ? Radius.zero : const Radius.circular(20)),
                        bottomRight: isMe ? (showAvatar ? Radius.zero : const Radius.circular(20)) : const Radius.circular(20),
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: isImage
                        ? ClipRRect(borderRadius: BorderRadius.circular(16), child: _buildImageContent(context))
                        : _buildTextOrAudioContent(),
                  ),
                  if (reactions != null && reactions!.isNotEmpty)
                    _buildReactionsRow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionsRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        children: reactions!.entries.map((entry) {
          final emoji = entry.key;
          final users = entry.value;
          final iReacted = myUserId != null && users.contains(myUserId);
          return GestureDetector(
            onTap: () => onReact?.call(emoji),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: iReacted
                    ? const Color(0xFF6C63FF).withOpacity(0.3)
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: iReacted ? const Color(0xFF6C63FF) : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Text('$emoji ${users.length}', style: const TextStyle(fontSize: 13)),
            ),
          );
        }).toList(),
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
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(time, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ),
    ]);
  }

  Widget _buildReplyPreview() {
    final rc = replyToContent!;
    final bool isImage = rc.startsWith('http') &&
        (rc.contains('.jpg') ||
            rc.contains('.png') ||
            rc.contains('image_picker') ||
            rc.contains('chat_images'));
    final bool isAudio = rc.startsWith('http') &&
        (rc.contains('.m4a') || rc.contains('audio_'));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(8),
        border: const Border(left: BorderSide(color: Color(0xFF6C63FF), width: 3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                rc,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white38,
                  size: 36,
                ),
              ),
            ),
          if (isImage) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  replyToSenderName ?? '',
                  style: const TextStyle(
                      color: Color(0xFF9D89D9),
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                if (isImage)
                  const Text('📷 Fotoğraf',
                      style: TextStyle(color: Colors.white54, fontSize: 12))
                else if (isAudio)
                  const Text('🎤 Ses mesajı',
                      style: TextStyle(color: Colors.white54, fontSize: 12))
                else
                  Text(
                    rc,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7), fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextOrAudioContent() {
    final isYouTube = content.contains('youtube.com') || content.contains('youtu.be');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (replyToContent != null) _buildReplyPreview(),
        if (contentWidget != null)
          contentWidget!
        else if (isYouTube)
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse(content.trim());
              if (await canLaunchUrl(uri)) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    content.trim(),
                    style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 14, decoration: TextDecoration.underline),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          )
        else
          Text(content, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(time, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w500)),
            if (isMe && showReadReceipts && otherUserShowReadReceipts) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.done_all,
                size: 14,
                color: isViewed ? const Color(0xFF53BDEB) : Colors.white.withOpacity(0.5),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ==========================================
// 🎙️ SES MESAJI OYNATICI
// ==========================================
class AudioMessagePlayer extends StatefulWidget {
  final String url;
  final bool isMe;
  final Color? color;
  final Color? backgroundColor;

  const AudioMessagePlayer({
    super.key,
    required this.url,
    required this.isMe,
    this.color,
    this.backgroundColor,
  });

  @override
  State<AudioMessagePlayer> createState() => _AudioMessagePlayerState();
}

class _AudioMessagePlayerState extends State<AudioMessagePlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _player.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
    _player.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

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
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

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
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                height: 4,
                decoration: BoxDecoration(
                    color:
                    widget.backgroundColor ?? Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                        color: widget.isMe
                            ? widget.color ?? const Color(0xFF9D89D9)
                            : widget.color ?? Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                  ),
                )),
            const SizedBox(height: 4),
            Text(
              isPlaying || _position.inSeconds > 0
                  ? '${_formatDuration(_position)} / ${_formatDuration(_duration)}'
                  : 'Ses',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    ]);
  }
}

// ==========================================
// 📸 PAYLAŞILAN GÖNDERI BALONCUĞU
// ==========================================
class SharedPostBubble extends StatelessWidget {
  final Map<String, dynamic> sharedPostData;
  final bool isMe;
  final String time;
  final String? otherUserAvatar;
  final bool showAvatar;
  final bool isViewed;
  final bool showReadReceipts;
  final bool otherUserShowReadReceipts;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onTap;

  const SharedPostBubble({
    super.key,
    required this.sharedPostData,
    required this.isMe,
    required this.time,
    this.otherUserAvatar,
    this.showAvatar = true,
    this.isViewed = false,
    this.showReadReceipts = true,
    this.otherUserShowReadReceipts = true,
    this.onAvatarTap,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.72;
    final posterName = sharedPostData['poster_name'] as String? ?? 'Kullanıcı';
    final posterUsername = sharedPostData['poster_username'] as String?;
    final posterAvatar = sharedPostData['poster_avatar'] as String?;
    final imageUrl = sharedPostData['image_url'] as String?;
    final caption = sharedPostData['content'] as String? ?? '';
    final displayName = (posterUsername?.isNotEmpty == true) ? '@$posterUsername' : posterName;

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
                GestureDetector(
                  onTap: onAvatarTap,
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: otherUserAvatar != null ? NetworkImage(otherUserAvatar!) : null,
                    child: otherUserAvatar == null ? const Icon(Icons.person, size: 16, color: Colors.white) : null,
                  ),
                )
              else
                const SizedBox(width: 28),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFF3D3460) : const Color(0xFF2A2440),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: isMe ? const Radius.circular(18) : (showAvatar ? Radius.zero : const Radius.circular(18)),
                      bottomRight: isMe ? (showAvatar ? Radius.zero : const Radius.circular(18)) : const Radius.circular(18),
                    ),
                    border: Border.all(
                      color: isMe
                          ? const Color(0xFF6C63FF).withOpacity(0.4)
                          : Colors.white.withOpacity(0.08),
                      width: 1,
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Poster başlık satırı
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 13,
                              backgroundColor: Colors.white12,
                              backgroundImage: posterAvatar != null ? NetworkImage(posterAvatar) : null,
                              child: posterAvatar == null ? const Icon(Icons.person, size: 14, color: Colors.white54) : null,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Görsel
                      if (imageUrl != null)
                        Stack(
                          children: [
                            ClipRRect(
                              child: Image.network(
                                imageUrl,
                                width: maxWidth,
                                height: 190,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                              ),
                            ),
                            // Üstte hafif gradient
                            Positioned(
                              bottom: 0, left: 0, right: 0,
                              child: Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      // Caption
                      if (caption.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: Text(
                            caption,
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, height: 1.3),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      // Alt bar: "Gönderiye git" + saat
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                        child: Row(
                          children: [
                            Text(
                              AppL10n.goToPost,
                              style: TextStyle(
                                color: const Color(0xFF9D89D9).withOpacity(0.8),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(Icons.arrow_forward_ios_rounded,
                                size: 9, color: const Color(0xFF9D89D9).withOpacity(0.8)),
                            const Spacer(),
                            Text(
                              time,
                              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                            ),
                            if (isMe && showReadReceipts && otherUserShowReadReceipts) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.done_all,
                                size: 13,
                                color: isViewed ? const Color(0xFF53BDEB) : Colors.white.withOpacity(0.4),
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
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 🔥 EPHEMERAL MESAJ BALONCUĞU (KÜL OLAN MESAJ)
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
  final VoidCallback? onAvatarTap; // 👇 EKLENDİ

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
    this.onAvatarTap, // 👇 EKLENDİ
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

    if (!widget.isMe && !widget.isViewed) {
      _startViewing();
    } else if (!widget.isMe && widget.isViewed) {
      _startBurning();
    }
  }

  void _startViewing() async {
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
              // 👇 GÜNCELLENDİ: Tıklanabilir Avatar
                GestureDetector(
                  onTap: widget.onAvatarTap,
                  child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.grey[800],
                      backgroundImage: widget.otherUserAvatar != null
                          ? NetworkImage(widget.otherUserAvatar!)
                          : null,
                      child: widget.otherUserAvatar == null
                          ? const Icon(Icons.person,
                          size: 16, color: Colors.white)
                          : null),
                )
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
              AppL10n.messageAshes,
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