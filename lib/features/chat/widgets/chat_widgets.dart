// Kinnect - Chat Yardımcı Widget'ları
// messages_screen.dart'tan refactor edildi

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../data/services/chat_service.dart';

// ==========================================
// 🎨 RENK PALETİ
// ==========================================
const Color kReceivedBubbleColor = Color(0xFF38304C);

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
  });

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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(time,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.w500)),
                  if (isMe &&
                      showReadReceipts &&
                      otherUserShowReadReceipts) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.done_all,
                      size: 14,
                      color: isViewed
                          ? const Color(0xFF53BDEB)
                          : Colors.white.withOpacity(0.5),
                    ),
                  ],
                ],
              ))
        ]);
  }
}

// ==========================================
// 🎙️ SES MESAJI OYNATICI
// ==========================================
class AudioMessagePlayer extends StatefulWidget {
  final String url;
  final bool isMe;
  final Color? color; // Added color property
  final Color? backgroundColor; // Added backgroundColor property

  const AudioMessagePlayer({
    super.key,
    required this.url,
    required this.isMe,
    this.color, // Initialize color
    this.backgroundColor, // Initialize backgroundColor
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
                            ? widget.color ??
                                const Color(
                                    0xFF9D89D9) // Assuming AppColors.primary is this color
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
