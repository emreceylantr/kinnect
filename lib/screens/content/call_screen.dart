import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

// 🎨 MODERN VE SOFT RENK PALETİ
const Color kCallPrimary = Color(0xFF8E84FF); // Soft mor
const Color kCallAccent = Color(0xFF4DD0E1); // Soft turkuaz
const Color kCallPink = Color(0xFFFF80AB); // Pastel pembe
const Color kCallDark = Color(0xFF1F2235); // Lacivert-Siyah taban
const Color kCallSuccess = Color(0xFF00E676);

class CallScreen extends StatefulWidget {
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
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late Future<String> _userNameFuture;

  @override
  void initState() {
    super.initState();
    _userNameFuture = _fetchLocalUserName();
  }

  Future<String> _fetchLocalUserName() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      return 'Misafir';
    }

    try {
      // profiles tablosundan ismi çek
      final response = await Supabase.instance.client
          .from('profiles')
          .select('full_name, username')
          .eq('id', currentUser.id)
          .single();

      // Önce full_name'e bak, yoksa username'e
      if (response['full_name'] != null &&
          response['full_name'].toString().isNotEmpty) {
        return response['full_name'];
      } else if (response['username'] != null &&
          response['username'].toString().isNotEmpty) {
        return response['username'];
      } else {
        // Fallback: metadata'dan dene
        final metadata = currentUser.userMetadata;
        if (metadata != null) {
          if (metadata['full_name'] != null &&
              metadata['full_name'].toString().isNotEmpty) {
            return metadata['full_name'];
          } else if (metadata['name'] != null &&
              metadata['name'].toString().isNotEmpty) {
            return metadata['name'];
          } else if (metadata['username'] != null &&
              metadata['username'].toString().isNotEmpty) {
            return metadata['username'];
          }
        }
        return 'Misafir';
      }
    } catch (e) {
      print('Kullanıcı ismi çekilemedi: $e');
      return 'Misafir';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _userNameFuture,
      builder: (context, snapshot) {
        // İsim yüklenene kadar loading göster
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2B32B2),
                    Color(0xFF1488CC),
                    Color(0xFF1F2235),
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: kCallPrimary),
                    const SizedBox(height: 16),
                    Text(
                      'Arama hazırlanıyor...',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // İsim yüklendi, artık Zego widget'ını göster
        final localUserName = snapshot.data ?? 'Misafir';
        return _buildCallUI(context, localUserName);
      },
    );
  }

  Widget _buildCallUI(BuildContext context, String localUserName) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final userId = currentUser?.id ?? 'unknown_user';

    // Video veya Ses konfigürasyonu
    final config = widget.isVideo
        ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
        : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();

    // 🎨 Arka Plan
    config.background = _buildModernBackground();

    // 👥 MEMBER LIST - SADECE İSİM (KÜÇÜK VE KOMPAKT)
    config.memberListConfig = ZegoMemberListConfig(
      itemBuilder: (BuildContext context, Size size, user, extraInfo) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 15),
          padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              // Küçük Avatar
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kCallPrimary,
                  boxShadow: [
                    BoxShadow(
                        color: kCallPrimary.withOpacity(0.3), blurRadius: 4)
                  ],
                ),
                child: Center(
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // İsim Alanı
              Expanded(
                child: Text(
                  user.name,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );

    // 🎨 Menü Barları
    config.topMenuBar.isVisible = true;
    config.topMenuBar.backgroundColor = Colors.transparent;
    config.topMenuBar.style = ZegoCallMenuBarStyle.dark;

    config.bottomMenuBar.backgroundColor = Colors.transparent;
    config.bottomMenuBar.style = ZegoCallMenuBarStyle.dark;

    if (!widget.isVideo) {
      config.bottomMenuBar.buttons = [
        ZegoCallMenuBarButtonName.toggleMicrophoneButton,
        ZegoCallMenuBarButtonName.hangUpButton,
        ZegoCallMenuBarButtonName.showMemberListButton,
      ];
      // 🔊 Layout Ayarı - Sesli aramada kendi görüntünü gizle
      config.audioVideoView.showMicrophoneStateOnView = false;

      // Küçük ekranı tamamen gizlemek için boyutunu sıfır yap
      config.layout = ZegoLayout.pictureInPicture(
        isSmallViewDraggable: false,
        switchLargeOrSmallViewByClick: false,
        smallViewSize: const Size(0, 0), // Boyutu sıfırla
        smallViewPosition: ZegoViewPosition.bottomRight, // Köşeye at
      );
    } else {
      config.bottomMenuBar.buttons = [
        ZegoCallMenuBarButtonName.toggleCameraButton,
        ZegoCallMenuBarButtonName.toggleMicrophoneButton,
        ZegoCallMenuBarButtonName.hangUpButton,
        ZegoCallMenuBarButtonName.switchCameraButton,
      ];
    }

    // 🎨 Avatar Builder - Local ve Remote user ayrımı yap
    config.avatarBuilder = (context, size, user, extraInfo) {
      // Eğer user yoksa veya video ise varsayılan avatar göster
      if (user == null || widget.isVideo) {
        return _buildAvatarWithPhoto(widget.otherUserName, size);
      }

      // Local user mı kontrol et (userId ile karşılaştır)
      final isLocalUser = user.id == userId;

      if (isLocalUser) {
        // Local user'ı sesli aramada gizle (boş widget döndür)
        return const SizedBox.shrink();
      } else {
        // Remote user için otherUserAvatar kullan
        return widget.otherUserAvatar != null
            ? _AnimatedProfileAvatar(
                avatarUrl: widget.otherUserAvatar,
                userName: widget.otherUserName)
            : _buildAvatarWithPhoto(widget.otherUserName, size);
      }
    };

    // 🎨 Foreground
    if (!widget.isVideo) {
      config.foreground = _buildModernForeground(context);
    }

    // 🔊 Süre Göstergesi
    config.duration.isVisible = true;

    // 🎨 Audio View Arka Planı
    if (!widget.isVideo) {
      config.audioVideoView.backgroundBuilder =
          (context, size, user, extraInfo) {
        return _buildModernBackground();
      };
    }

    return ZegoUIKitPrebuiltCall(
      appID: 1191288890,
      appSign:
          "REDACTED_ZEGO_APP_SIGN",
      userID: userId,
      userName: localUserName, // Users tablosundan çekilen isim
      callID: widget.callId,
      config: config,
      events: ZegoUIKitPrebuiltCallEvents(
        onCallEnd: (event, defaultAction) {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  // 🎨 SOFT GRADIENT ARKA PLAN
  Widget _buildModernBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2B32B2), // Derin mavi
            Color(0xFF1488CC), // Soft mavi
            Color(0xFF1F2235), // Koyu taban
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withOpacity(0.2)),
          ),
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.purpleAccent.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.blueAccent.withOpacity(0.2),
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

  // 🎨 STANDART AVATAR
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
              color: kCallPrimary.withOpacity(0.3),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [kCallPrimary, kCallPink.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kCallDark,
            ),
            child: widget.otherUserAvatar != null &&
                    widget.otherUserAvatar!.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: widget.otherUserAvatar!,
                      fit: BoxFit.cover,
                      width: avatarSize - 8,
                      height: avatarSize - 8,
                      placeholder: (context, url) => CircularProgressIndicator(
                        color: kCallPrimary,
                        strokeWidth: 2,
                      ),
                      errorWidget: (context, url, error) => Center(
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

  // 🎨 ÖN YÜZ
  Widget _buildModernForeground(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 220),
          Text(
            widget.otherUserName,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          // Bağlanıyor yazısı kaldırıldı
          const SizedBox(height: 32),
          _ModernAudioWave(),
          const Spacer(),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}

// 🖼️ ANİMASYONLU AVATAR
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
      duration: const Duration(seconds: 4),
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
                              child: CachedNetworkImage(
                                imageUrl: widget.avatarUrl!,
                                fit: BoxFit.cover,
                                width: 114,
                                height: 114,
                                placeholder: (context, url) =>
                                    CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                                errorWidget: (context, url, error) => Center(
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

// 🎵 SES DALGALARI
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
            final delay = index * 0.15;
            final animValue =
                math.sin((_controller.value + delay) * math.pi * 2);
            final height = 10 + (animValue * 15).abs();

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 4,
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withOpacity(0.8),
                boxShadow: [
                  BoxShadow(
                    color: kCallPrimary.withOpacity(0.4),
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
