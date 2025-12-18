import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 🎨 NEON CYBERPUNK RENK PALETİ - Yumuşak tonlar
const Color kNeonPurple = Color(0xFF9D4EDD);
const Color kNeonPink = Color(0xFFE040FB);
const Color kNeonBlue = Color(0xFF00B4D8);
const Color kDarkBg = Color(0xFF0A0A12);
const Color kDarkCard = Color(0xFF151520);

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

    // 🎨 Yumuşak Gradient Arka Plan
    config.background = _buildSoftGradientBackground();

    // 🎨 Top Menu Bar
    config.topMenuBar.isVisible = true;
    config.topMenuBar.backgroundColor = Colors.transparent;
    config.topMenuBar.style = ZegoCallMenuBarStyle.dark;

    // 🎨 Bottom Menu Bar
    config.bottomMenuBar.backgroundColor = kDarkCard.withOpacity(0.7);
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

    // 🎨 Büyük Profil Fotoğraflı Avatar
    config.avatarBuilder = (context, size, user, extraInfo) {
      return _buildLargeProfileAvatar(user?.name ?? otherUserName, size, otherUserAvatar);
    };

    // 🎨 Minimal Foreground
    config.foreground = _buildMinimalForeground(context, otherUserName, isVideo);

    // 🔊 Duration göster
    config.duration.isVisible = true;
    
    // 🎨 Audio View Background
    if (!isVideo) {
      config.audioVideoView.backgroundBuilder = (context, size, user, extraInfo) {
        return _buildSoftGradientBackground();
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

  // 🎨 YUMUŞAK GEÇİŞLİ ARKA PLAN
  Widget _buildSoftGradientBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.5,
          colors: [
            const Color(0xFF1A1025),
            const Color(0xFF0F0A15),
            kDarkBg,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Yumuşak mor ışık - üst
          Positioned(
            top: -150,
            left: -50,
            right: -50,
            child: Container(
              height: 400,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    kNeonPurple.withOpacity(0.15),
                    kNeonPurple.withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Yumuşak mavi ışık - alt
          Positioned(
            bottom: -200,
            left: -100,
            right: -100,
            child: Container(
              height: 500,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    kNeonBlue.withOpacity(0.08),
                    kNeonBlue.withOpacity(0.02),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // İnce parıltılar
          ..._buildSubtleSparkles(),
        ],
      ),
    );
  }

  // Hafif parıltılar
  List<Widget> _buildSubtleSparkles() {
    final random = math.Random(42);
    return List.generate(8, (index) {
      return Positioned(
        top: random.nextDouble() * 700,
        left: random.nextDouble() * 400,
        child: Container(
          width: 2,
          height: 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.3 + random.nextDouble() * 0.3),
          ),
        ),
      );
    });
  }

  // 🎨 BÜYÜK PROFİL FOTOĞRAFLI AVATAR
  Widget _buildLargeProfileAvatar(String name, Size size, String? avatarUrl) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final avatarSize = size.width * 0.7; // Daha büyük avatar

    return Center(
      child: Container(
        width: avatarSize,
        height: avatarSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: kNeonPurple.withOpacity(0.4),
              blurRadius: 40,
              spreadRadius: 8,
            ),
            BoxShadow(
              color: kNeonPink.withOpacity(0.2),
              blurRadius: 60,
              spreadRadius: 15,
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                kNeonPurple.withOpacity(0.8),
                kNeonPink.withOpacity(0.6),
                kNeonBlue.withOpacity(0.5),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kDarkBg,
            ),
            child: ClipOval(
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      width: avatarSize,
                      height: avatarSize,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildInitialAvatar(initial, avatarSize);
                      },
                    )
                  : _buildInitialAvatar(initial, avatarSize),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInitialAvatar(String initial, double size) {
    return Container(
      width: size,
      height: size,
      color: kDarkCard,
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: size * 0.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // 🎨 MİNİMAL FOREGROUND
  Widget _buildMinimalForeground(BuildContext context, String userName, bool isVideo) {
    return SafeArea(
      child: Column(
        children: [
          // Üst kısım - Minimal kullanıcı bilgisi
          if (!isVideo)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Column(
                children: [
                  // Kullanıcı adı - Minimal font
                  Text(
                    userName,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Arama durumu
                  _MinimalStatusIndicator(),
                  const SizedBox(height: 50),
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
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
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
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kNeonPurple,
                boxShadow: [
                  BoxShadow(
                    color: kNeonPurple.withOpacity(_animation.value * 0.6),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Arama devam ediyor',
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        );
      },
    );
  }
}

// 🎨 Audio Wave Widget - Animasyonlu ses dalgaları
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
      duration: const Duration(milliseconds: 1000),
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
            final delay = index * 0.15;
            final animValue = math.sin((_controller.value + delay) * math.pi * 2);
            final height = 12 + (animValue * 15).abs();
            
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 3,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    kNeonPurple.withOpacity(0.8),
                    kNeonBlue.withOpacity(0.6),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}