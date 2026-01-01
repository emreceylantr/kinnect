// Kinnect - 3D Dönen Sohbet Kartı Widget'ı
// messages_screen.dart'tan refactor edildi

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/kinnect_image.dart';
import '../../profile/screens/profile_screen.dart';

// ==========================================
// 🎨 RENK PALETİ
// ==========================================
const Color kTextWhite = Colors.white;
const Color kTextGrey = Colors.white54;
const Color kBadgeColor = Color(0xFF448AFF);

// ==========================================
// 🔥 FLİPPABLE CHAT CARD (3D DÖNEN KART)
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
                backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
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
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
          child: Row(
            children: [
              Hero(
                tag: heroTag,
                child: GestureDetector(
                  onTap: () {
                    // Chat'i açmasını engelle, profile git
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ProfileScreen(userId: widget.otherUser['id'])));
                  },
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.grey[800],
                    child: widget.otherUser['avatar_url'] == null
                        ? const Icon(Icons.person,
                            color: Colors.white54, size: 26)
                        : KinnectImage(
                            imageUrl: widget.otherUser['avatar_url'],
                            width: 52,
                            height: 52,
                            isCircle: true,
                            fit: BoxFit.cover,
                          ),
                  ),
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
                    // 👁️ Son görülme bilgisi
                    Builder(builder: (context) {
                      final lastSeenRaw = widget.otherUser['last_seen'];
                      final showLastSeen =
                          widget.otherUser['show_last_seen'] ?? true;

                      if (!showLastSeen || lastSeenRaw == null) {
                        return Text(
                          'Mesajları görüntülemek için dokun...',
                          style: TextStyle(
                            color: hasUnread ? Colors.white : kTextGrey,
                            fontWeight:
                                hasUnread ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      }

                      final lastSeen = DateTime.parse(lastSeenRaw);
                      final now = DateTime.now();
                      final diff = now.difference(lastSeen);

                      String text;
                      bool isOnline = false;
                      if (diff.inMinutes < 5) {
                        text = 'Çevrimiçi';
                        isOnline = true;
                      } else if (diff.inMinutes < 60) {
                        text = '${diff.inMinutes} dk önce';
                      } else if (diff.inHours < 24) {
                        text = '${diff.inHours} saat önce';
                      } else {
                        text = '${diff.inDays} gün önce';
                      }

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isOnline)
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
                            text,
                            style: TextStyle(
                              color: isOnline
                                  ? const Color(0xFF00D26A)
                                  : kTextGrey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      );
                    }),
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
          color: Colors.redAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
                color: Colors.redAccent.withValues(alpha: 0.1), blurRadius: 10)
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ProfileScreen(
                                  userId: widget.otherUser['id'])));
                    },
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey[800],
                      child: widget.otherUser['avatar_url'] == null
                          ? const Icon(Icons.person,
                              color: Colors.white54, size: 20)
                          : KinnectImage(
                              imageUrl: widget.otherUser['avatar_url'],
                              width: 40,
                              height: 40,
                              isCircle: true,
                              fit: BoxFit.cover,
                            ),
                    ),
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
                            color: Colors.red.withValues(alpha: 0.4),
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
// 📜 SLIDE FADE ANİMASYONU (Liste için)
// ==========================================
class SlideFadeTransition extends StatefulWidget {
  final Widget child;
  final int index;

  const SlideFadeTransition({
    super.key,
    required this.child,
    required this.index,
  });

  @override
  State<SlideFadeTransition> createState() => _SlideFadeTransitionState();
}

class _SlideFadeTransitionState extends State<SlideFadeTransition>
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
