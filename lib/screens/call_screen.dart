import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 🎨 MODERN RENK PALETİ
const Color kCallPrimary = Color(0xFF6C63FF);
const Color kCallAccent = Color(0xFF00D4FF);
const Color kCallPink = Color(0xFFFF6B9D);
const Color kCallDark = Color(0xFF0A0A0F);
const Color kCallCard = Color(0xFF1A1A2E);
const Color kCallSuccess = Color(0xFF00C853);

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

    // 🎨 Modern Gradient Arka Plan
    config.background = _buildModernBackground();

    // 🎨 Top Menu Bar
    config.topMenuBar.isVisible = true;
    config.topMenuBar.backgroundColor = Colors.transparent;
    config.topMenuBar.style = ZegoCallMenuBarStyle.dark;

    // 🎨 Bottom Menu Bar
    config.bottomMenuBar.backgroundColor = Colors.transparent;
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

    // 🎨 Avatar Builder
    config.avatarBuilder = (context, size, user, extraInfo) {
      return _buildAvatarWithPhoto(user?.name ?? otherUserName, size);
    };

    // 🎨 Modern Foreground with Profile Picture
    config.foreground = _buildModernForeground(context);

    // 🔊 Duration göster
    config.duration.isVisible = true;

    // 🎨 Audio View Background
    if (!isVideo) {
      config.audioVideoView.backgroundBuilder =
          (context, size, user, extraInfo) {
        return _buildModernBackground();
      };
    }

    return ZegoUIKitPrebuiltCall(
      appID: 1191288890,
      appSign:
          "d2dab541744a6fd9318bb74be82c7789f0635d063b774e923afba4249d8a8d4a",
      userID: userId,
      userName: userName,
      callID: callId,
      config: config,
    );
  }

  // 🎨 MODERN GRADIENT ARKA PLAN
  Widget _buildModernBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A1A2E),
            Color(0xFF0F0F1A),
            Color(0xFF0A0A0F),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Soft glow - top
          Positioned(
            top: -150,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kCallPrimary.withOpacity(0.3),
                    kCallPrimary.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          // Soft glow - bottom right
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kCallAccent.withOpacity(0.15),
                    kCallAccent.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 AVATAR WITH PHOTO
  Widget _buildAvatarWithPhoto(String name, Size size) {
    final avatarSize = size.width * 0.55;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Center(
      child: Container(
        width: avatarSize,
        height: avatarSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: kCallPrimary.withOpacity(0.4),
              blurRadius: 40,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [kCallPrimary, kCallPink, kCallAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kCallDark,
            ),
            child: otherUserAvatar != null && otherUserAvatar!.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      otherUserAvatar!,
                      fit: BoxFit.cover,
                      width: avatarSize - 8,
                      height: avatarSize - 8,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Text(
                          initial,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: avatarSize * 0.3,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      initial,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: avatarSize * 0.3,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // 🎨 MODERN FOREGROUND
  Widget _buildModernForeground(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          if (!isVideo) ...[
            const SizedBox(height: 60),
            // 🖼️ BÜYÜK PROFİL FOTOĞRAFI
            _AnimatedProfileAvatar(
              avatarUrl: otherUserAvatar,
              userName: otherUserName,
            ),
            const SizedBox(height: 24),
            // 👤 KULLANICI ADI
            Text(
              otherUserName,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // 📞 ARAMA DURUMU
            _CallStatusIndicator(),
            const SizedBox(height: 32),
            // 🎵 SES DALGALARI
            _ModernAudioWave(),
          ],
          const Spacer(),
          // 🔒 GÜVENLİ BAĞLANTI KARTI
          if (!isVideo)
            Padding(
              padding: const EdgeInsets.only(bottom: 140, left: 32, right: 32),
              child: _buildSecurityCard(),
            ),
        ],
      ),
    );
  }

  // 🔒 GÜVENLİK KARTI
  Widget _buildSecurityCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kCallSuccess.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_rounded,
                  color: kCallSuccess,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Uçtan uca şifreli',
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 🖼️ ANİMASYONLU PROFİL AVATARI
class _AnimatedProfileAvatar extends StatefulWidget {
  final String? avatarUrl;
  final String userName;

  const _AnimatedProfileAvatar({
    required this.avatarUrl,
    required this.userName,
  });

  @override
  State<_AnimatedProfileAvatar> createState() => _AnimatedProfileAvatarState();
}

class _AnimatedProfileAvatarState extends State<_AnimatedProfileAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
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
    final initial =
        widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : '?';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Dönen halka 1
              Transform.rotate(
                angle: _controller.value * 2 * math.pi,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: kCallPrimary.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                ),
              ),
              // Dönen halka 2 (ters yön)
              Transform.rotate(
                angle: -_controller.value * 2 * math.pi,
                child: Container(
                  width: 145,
                  height: 145,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: kCallAccent.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              // Profil fotoğrafı
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [kCallPrimary, kCallPink],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kCallPrimary.withOpacity(0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(3),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kCallDark,
                  ),
                  child:
                      widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                widget.avatarUrl!,
                                fit: BoxFit.cover,
                                width: 114,
                                height: 114,
                                errorBuilder: (context, error, stackTrace) =>
                                    Center(
                                  child: Text(
                                    initial,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                initial,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// 📞 ARAMA DURUMU İNDİKATÖRÜ
class _CallStatusIndicator extends StatefulWidget {
  @override
  State<_CallStatusIndicator> createState() => _CallStatusIndicatorState();
}

class _CallStatusIndicatorState extends State<_CallStatusIndicator>
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
                color: kCallSuccess,
                boxShadow: [
                  BoxShadow(
                    color: kCallSuccess.withOpacity(_animation.value),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Aranıyor...',
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }
}

// 🎵 MODERN SES DALGALARI
class _ModernAudioWave extends StatefulWidget {
  @override
  State<_ModernAudioWave> createState() => _ModernAudioWaveState();
}

class _ModernAudioWaveState extends State<_ModernAudioWave>
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
            final animValue =
                math.sin((_controller.value + delay) * math.pi * 2);
            final height = 12 + (animValue * 18).abs();

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 4,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    kCallPrimary,
                    kCallAccent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: kCallPrimary.withOpacity(0.3),
                    blurRadius: 6,
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
