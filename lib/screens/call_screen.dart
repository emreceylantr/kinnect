import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 🎨 NEON CYBERPUNK RENK PALETİ
const Color kNeonPurple = Color(0xFFBF00FF);
const Color kNeonPink = Color(0xFFFF00FF);
const Color kNeonBlue = Color(0xFF00D4FF);
const Color kDarkBg = Color(0xFF0D0D1A);
const Color kDarkCard = Color(0xFF1A1A2E);

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

    // 🎨 Neon Cyberpunk Arka Plan
    config.background = _buildCyberpunkBackground();

    // 🎨 Top Menu Bar
    config.topMenuBar.isVisible = true;
    config.topMenuBar.backgroundColor = Colors.transparent;
    config.topMenuBar.style = ZegoCallMenuBarStyle.dark;

    // 🎨 Bottom Menu Bar - Neon efektli
    config.bottomMenuBar.backgroundColor = kDarkCard.withOpacity(0.8);
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

    // 🎨 Neon Avatar Builder
    config.avatarBuilder = (context, size, user, extraInfo) {
      return _buildNeonAvatar(user?.name ?? otherUserName, size);
    };

    // 🎨 Cyberpunk Foreground
    config.foreground = _buildCyberpunkForeground(context, otherUserName, isVideo);

    // 🔊 Duration göster
    config.duration.isVisible = true;
    
    // 🎨 Audio View Background
    if (!isVideo) {
      config.audioVideoView.backgroundBuilder = (context, size, user, extraInfo) {
        return _buildCyberpunkBackground();
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

  // 🎨 CYBERPUNK ARKA PLAN
  Widget _buildCyberpunkBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D0D1A),
            Color(0xFF1A0A2E),
            Color(0xFF16213E),
            Color(0xFF0D0D1A),
          ],
          stops: [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Grid çizgileri efekti
          CustomPaint(
            size: const Size(double.infinity, double.infinity),
            painter: _GridPainter(),
          ),
          // Neon mor ışık - sol üst
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: kNeonPurple.withOpacity(0.4),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          // Neon mavi ışık - sağ alt
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: kNeonBlue.withOpacity(0.3),
                    blurRadius: 120,
                    spreadRadius: 60,
                  ),
                ],
              ),
            ),
          ),
          // Neon pembe ışık - orta
          Positioned(
            top: 200,
            right: 50,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: kNeonPink.withOpacity(0.25),
                    blurRadius: 60,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          // Parıltı noktaları
          ..._buildSparkles(),
        ],
      ),
    );
  }

  // Parıltı noktaları
  List<Widget> _buildSparkles() {
    final random = math.Random(42);
    return List.generate(15, (index) {
      return Positioned(
        top: random.nextDouble() * 600,
        left: random.nextDouble() * 400,
        child: Container(
          width: 3,
          height: 3,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.6 + random.nextDouble() * 0.4),
            boxShadow: [
              BoxShadow(
                color: (index % 2 == 0 ? kNeonPurple : kNeonBlue).withOpacity(0.8),
                blurRadius: 6,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      );
    });
  }

  // 🎨 NEON AVATAR
  Widget _buildNeonAvatar(String name, Size size) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final avatarSize = size.width * 0.55;

    return Center(
      child: Container(
        width: avatarSize,
        height: avatarSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            // Dış neon glow
            BoxShadow(
              color: kNeonPurple.withOpacity(0.6),
              blurRadius: 30,
              spreadRadius: 5,
            ),
            BoxShadow(
              color: kNeonPink.withOpacity(0.4),
              blurRadius: 50,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [kNeonPurple, kNeonPink, kNeonBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kDarkBg,
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                initial,
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: avatarSize * 0.35,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: kNeonPurple,
                      blurRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🎨 CYBERPUNK FOREGROUND
  Widget _buildCyberpunkForeground(BuildContext context, String userName, bool isVideo) {
    return SafeArea(
      child: Column(
        children: [
          // Üst kısım - Kullanıcı bilgisi
          if (!isVideo)
            Padding(
              padding: const EdgeInsets.only(top: 80),
              child: Column(
                children: [
                  // Kullanıcı adı - Neon efektli
                  Text(
                    userName.toUpperCase(),
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      shadows: [
                        Shadow(
                          color: kNeonPurple,
                          blurRadius: 20,
                        ),
                        Shadow(
                          color: kNeonPink.withOpacity(0.5),
                          blurRadius: 40,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Arama durumu - Animasyonlu
                  _NeonStatusIndicator(),
                  const SizedBox(height: 40),
                  // Ses dalgaları
                  _AudioWaveWidget(),
                ],
              ),
            ),
          const Spacer(),
          // Alt bilgi kartı
          if (!isVideo)
            Padding(
              padding: const EdgeInsets.only(bottom: 130, left: 24, right: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: kDarkCard.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: kNeonPurple.withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: kNeonPurple.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: kNeonBlue,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'ENCRYPTED CONNECTION',
                          style: GoogleFonts.orbitron(
                            color: kNeonBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
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

// 🎨 Grid Painter - Cyberpunk grid efekti
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kNeonPurple.withOpacity(0.05)
      ..strokeWidth = 0.5;

    // Yatay çizgiler
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Dikey çizgiler
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 🎨 Neon Status Indicator
class _NeonStatusIndicator extends StatefulWidget {
  @override
  State<_NeonStatusIndicator> createState() => _NeonStatusIndicatorState();
}

class _NeonStatusIndicatorState extends State<_NeonStatusIndicator>
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
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kNeonPink,
                boxShadow: [
                  BoxShadow(
                    color: kNeonPink.withOpacity(_animation.value),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'CALLING',
              style: GoogleFonts.orbitron(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 3,
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
      duration: const Duration(milliseconds: 800),
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
          children: List.generate(7, (index) {
            final delay = index * 0.1;
            final animValue = math.sin((_controller.value + delay) * math.pi * 2);
            final height = 15 + (animValue * 20).abs();
            
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 4,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    kNeonPink,
                    kNeonPurple,
                    kNeonBlue,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: kNeonPurple.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}