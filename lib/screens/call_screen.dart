import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 🎨 SOFT NEON RENK PALETİ
const Color kSoftPurple = Color(0xFF8B5CF6);
const Color kSoftPink = Color(0xFFC084FC);
const Color kSoftBlue = Color(0xFF38BDF8);
const Color kDarkBg = Color(0xFF09090B);
const Color kDarkCard = Color(0xFF18181B);

class CallScreen extends StatelessWidget {
  final String callId;
  final String otherUserName;
  final bool isVideo;
  final String? otherUserAvatar;

  const CallScreen({
    super.key,
    required this.callId,
    required this.otherUserName,
    this.isVideo = false,
    this.otherUserAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final userName = currentUser?.userMetadata?['full_name'] ??
        currentUser?.email?.split('@')[0] ??
        'Kullanıcı';
    final userId = currentUser?.id ?? 'unknown_user';

    final config = isVideo
        ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
        : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();

    // 🎨 Ultra Soft Arka Plan
    config.background = _buildUltraSoftBackground();

    // 🎨 Top Menu Bar
    config.topMenuBar.isVisible = true;
    config.topMenuBar.backgroundColor = Colors.transparent;
    config.topMenuBar.style = ZegoCallMenuBarStyle.dark;

    // 🎨 Bottom Menu Bar
    config.bottomMenuBar.backgroundColor = kDarkCard.withOpacity(0.6);
    config.bottomMenuBar.style = ZegoCallMenuBarStyle.dark;
    
    if (!isVideo) {
      config.bottomMenuBar.buttons = [
        ZegoCallMenuBarButtonName.toggleMicrophoneButton,
        ZegoCallMenuBarButtonName.hangUpButton,
        ZegoCallMenuBarButtonName.showMemberListButton,
      ];
    } else {
      config.bottomMenuBar.buttons = [
        ZegoCallMenuBarButtonName.toggleCameraButton,
        ZegoCallMenuBarButtonName.toggleMicrophoneButton,
        ZegoCallMenuBarButtonName.hangUpButton,
        ZegoCallMenuBarButtonName.switchCameraButton,
      ];
    }

    // 🎨 Member List Config - Küçük ve isimli
    config.memberList.itemBuilder = (context, size, user, extraInfo) {
      return _buildCompactMemberItem(user, size);
    };
    
    // 🎨 Profil Fotoğraflı Büyük Avatar
    config.avatarBuilder = (context, size, user, extraInfo) {
      return _buildProfilePhotoAvatar(size, otherUserAvatar, otherUserName);
    };

    // 🎨 Minimal Foreground
    config.foreground = _buildMinimalForeground(context, otherUserName, isVideo, otherUserAvatar);

    // 🔊 Duration göster
    config.duration.isVisible = true;
    
    // 🎨 Audio View Background
    if (!isVideo) {
      config.audioVideoView.backgroundBuilder = (context, size, user, extraInfo) {
        return _buildUltraSoftBackground();
      };
    }

    return ZegoUIKitPrebuiltCall(
      appID: 1191288890,
      appSign: "REDACTED_ZEGO_APP_SIGN",
      userID: userId,
      userName: userName,
      callID: callId,
      config: config,
    );
  }

  // 🎨 ULTRA SOFT ARKA PLAN
  Widget _buildUltraSoftBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0F0F14),
            Color(0xFF0A0A0F),
            kDarkBg,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Çok hafif mor ışık - üst
          Positioned(
            top: -200,
            left: 0,
            right: 0,
            child: Container(
              height: 500,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    kSoftPurple.withOpacity(0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Çok hafif mavi ışık - alt
          Positioned(
            bottom: -250,
            left: 0,
            right: 0,
            child: Container(
              height: 400,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    kSoftBlue.withOpacity(0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 PROFİL FOTOĞRAFLI AVATAR
  Widget _buildProfilePhotoAvatar(Size size, String? avatarUrl, String name) {
    final avatarSize = size.width * 0.7;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Center(
      child: Container(
        width: avatarSize,
        height: avatarSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: kSoftPurple.withOpacity(0.25),
              blurRadius: 50,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                kSoftPurple.withOpacity(0.7),
                kSoftPink.withOpacity(0.5),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: ClipOval(
            child: Container(
              color: kDarkCard,
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      width: avatarSize,
                      height: avatarSize,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kSoftPurple.withOpacity(0.5),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Text(
                            initial,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: avatarSize * 0.3,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Text(
                        initial,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: avatarSize * 0.3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // 🎨 KOMPAKT MEMBER LİST ITEM
  Widget _buildCompactMemberItem(ZegoUIKitUser? user, Size size) {
    final displayName = user?.name ?? 'Kullanıcı';
    
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  kSoftPurple.withOpacity(0.6),
                  kSoftPink.withOpacity(0.4),
                ],
              ),
            ),
            child: Center(
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // İsim
          Expanded(
            child: Text(
              displayName,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Mikrofon durumu
          Icon(
            Icons.mic,
            color: Colors.white.withOpacity(0.5),
            size: 20,
          ),
        ],
      ),
    );
  }

  // 🎨 MİNİMAL FOREGROUND
  Widget _buildMinimalForeground(BuildContext context, String userName, bool isVideo, String? avatarUrl) {
    return SafeArea(
      child: Column(
        children: [
          if (!isVideo)
            Padding(
              padding: const EdgeInsets.only(top: 50),
              child: Column(
                children: [
                  // Profil fotoğrafı - üstte büyük
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: kSoftPurple.withOpacity(0.3),
                          blurRadius: 40,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            kSoftPurple.withOpacity(0.8),
                            kSoftPink.withOpacity(0.6),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: ClipOval(
                        child: Container(
                          color: kDarkCard,
                          child: avatarUrl != null && avatarUrl.isNotEmpty
                              ? Image.network(
                                  avatarUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: kSoftPurple.withOpacity(0.5),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildAvatarInitial(userName);
                                  },
                                )
                              : _buildAvatarInitial(userName),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Kullanıcı adı
                  Text(
                    userName,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Durum
                  _MinimalStatusIndicator(),
                  const SizedBox(height: 35),
                  // Ses dalgaları
                  _AudioWaveWidget(),
                ],
              ),
            ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildAvatarInitial(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Center(
      child: Text(
        initial,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 45,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// 🎨 Minimal Status Indicator
class _MinimalStatusIndicator extends StatefulWidget {
  @override
  State<_MinimalStatusIndicator> createState() => _MinimalStatusIndicatorState();
}

class _MinimalStatusIndicatorState extends State<_MinimalStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kSoftPurple,
                boxShadow: [
                  BoxShadow(
                    color: kSoftPurple.withOpacity(_animation.value * 0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Arama devam ediyor',
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.5),
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        );
      },
    );
  }
}

// 🎨 Audio Wave Widget
class _AudioWaveWidget extends StatefulWidget {
  @override
  State<_AudioWaveWidget> createState() => _AudioWaveWidgetState();
}

class _AudioWaveWidgetState extends State<_AudioWaveWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
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
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final delay = index * 0.12;
            final animValue = math.sin((_controller.value + delay) * math.pi * 2);
            final height = 10 + (animValue * 12).abs();
            
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 3,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: kSoftPurple.withOpacity(0.6),
              ),
            );
          }),
        );
      },
    );
  }
}