import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 🎨 RENK PALETİ (Uygulama temasıyla uyumlu)
const Color kCallBgColor = Color(0xFF0A0A0F);
const Color kCallCardColor = Color(0xFF1F1B24);
const Color kCallAccentPurple = Color(0xFF6C63FF);
const Color kCallAccentGreen = Color(0xFF1DB954);
const Color kCallHeaderColor = Color(0xFF2D2638);

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

    // 🔥 Zego Config'i özelleştir
    final config = isVideo
        ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
        : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();

    // 🎨 Arka plan widget'ı - Gradient efektli
    config.background = _buildGradientBackground();

    // 🎨 Top Menu Bar - Minimal ve modern
    config.topMenuBar.isVisible = true;
    config.topMenuBar.backgroundColor = Colors.transparent;
    config.topMenuBar.style = ZegoCallMenuBarStyle.dark;

    // 🎨 Bottom Menu Bar - Glassmorphism efektli
    config.bottomMenuBar.backgroundColor = kCallCardColor.withOpacity(0.6);
    config.bottomMenuBar.style = ZegoCallMenuBarStyle.dark;
    
    // Sesli arama için butonları ayarla
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

    // 🎨 Avatar Builder - Gradient çerçeveli modern avatar
    config.avatarBuilder = (context, size, user, extraInfo) {
      return _buildGradientAvatar(user?.name ?? otherUserName, size);
    };

    // 🎨 Foreground builder - Glassmorphism efektli overlay
    config.foreground = _buildModernForeground(context, otherUserName, isVideo);

    // 🎨 Arama Sonu Callback
    config.onCallEnd = (event, defaultAction) {
      defaultAction.call();
    };

    // 🔊 Ses dalgası ve duration göster
    config.duration.isVisible = true;
    
    // 🎨 Audio/Video View Config
    if (!isVideo) {
      config.audioVideoView.backgroundBuilder = (context, size, user, extraInfo) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                kCallBgColor,
                kCallCardColor.withOpacity(0.8),
                kCallBgColor,
              ],
            ),
          ),
        );
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

  // 🎨 Gradient Arka Plan Widget
  Widget _buildGradientBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kCallBgColor,
            const Color(0xFF1A1625),
            kCallCardColor.withOpacity(0.5),
            kCallBgColor,
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Dekoratif gradient daireler
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kCallAccentPurple.withOpacity(0.3),
                    kCallAccentPurple.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kCallAccentGreen.withOpacity(0.2),
                    kCallAccentGreen.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          // Parıltı efekti
          Positioned(
            top: 150,
            left: 50,
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 Gradient Avatar Widget
  Widget _buildGradientAvatar(String name, Size size) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final avatarSize = size.width * 0.6;

    return Center(
      child: Container(
        width: avatarSize,
        height: avatarSize,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [kCallAccentPurple, kCallAccentGreen],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: kCallAccentPurple.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: kCallAccentGreen.withOpacity(0.3),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kCallCardColor,
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              initial,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: avatarSize * 0.4,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🎨 Modern Foreground Overlay
  Widget _buildModernForeground(BuildContext context, String userName, bool isVideo) {
    return SafeArea(
      child: Column(
        children: [
          // Üst kısım - Kullanıcı bilgisi (sadece sesli aramada göster)
          if (!isVideo)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Column(
                children: [
                  // Kullanıcı adı
                  Text(
                    userName,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Arama durumu
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kCallAccentGreen,
                          boxShadow: [
                            BoxShadow(
                              color: kCallAccentGreen.withOpacity(0.6),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Arama devam ediyor',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const Spacer(),
          // Alt kısım - Glassmorphism efektli bilgi kartı
          if (!isVideo)
            Padding(
              padding: const EdgeInsets.only(bottom: 120, left: 20, right: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                        Icon(
                          Icons.security,
                          color: kCallAccentPurple.withOpacity(0.8),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Uçtan uca şifreli arama',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
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