import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:video_player/video_player.dart';
import 'package:kinnect/shared/widgets/kinnect_image.dart';

import '../../../core/language/app_l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/border_colors.dart';
import 'profile_badges.dart';
import '../../spark/screens/spark_mode_screen.dart';

class ProfileHeader extends StatelessWidget {
  final Map<String, dynamic>? profileData;
  final bool isMe;
  final bool isAdmin;
  final String friendshipStatus; // 'none', 'pending', 'accepted'
  final int postCount;
  final int followersCount;
  final int followingCount;
  final bool showBackButton;

  // Live Video
  final bool hasLiveVideo;
  final bool isPlayingLiveVideo;
  final VideoPlayerController? videoController;

  // Actions
  final VoidCallback? onUpdateCoverPhoto;
  final VoidCallback? onLogout;
  final VoidCallback? onSettings;
  final VoidCallback? onBack;
  final Function(String) onMenuAction; // 'report', 'block'
  final Function(bool) onLiveVideoStateChange; // true = play, false = pause
  final Function(String, String) onOpenFollowList; // type, title
  final VoidCallback onEditProfile;
  final VoidCallback onFollowAction;
  final VoidCallback onMessage;

  const ProfileHeader({
    super.key,
    required this.profileData,
    required this.isMe,
    required this.isAdmin,
    required this.friendshipStatus,
    required this.postCount,
    required this.followersCount,
    required this.followingCount,
    this.showBackButton = true,
    required this.hasLiveVideo,
    required this.isPlayingLiveVideo,
    this.videoController,
    this.onUpdateCoverPhoto,
    this.onLogout,
    this.onSettings,
    this.onBack,
    required this.onMenuAction,
    required this.onLiveVideoStateChange,
    required this.onOpenFollowList,
    required this.onEditProfile,
    required this.onFollowAction,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final coverUrl = profileData?['cover_url'];

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // KAPAK FOTOĞRAFI
            Container(
              height: 380,
              width: double.infinity,
              foregroundDecoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xAA000000),
                    Color(0xFF000000)
                  ],
                  stops: [0.0, 0.4, 0.7, 1.0],
                ),
              ),
              child: coverUrl != null
                  ? KinnectImage(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 380,
                    )
                  : Container(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                          Colors.grey.shade900,
                          AppColors.bgBlack
                        ]))),
            ),

            // BUTONLAR (Top Bar)
            if (isMe) ...[
              // Kıvılcım Modu butonu 🔥
              Positioned(
                  top: 50,
                  right: 124,
                  child: GestureDetector(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SparkModeScreen())),
                      child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24)),
                          child: const Icon(Icons.local_fire_department,
                              color: AppColors.accentOrange, size: 18)))),
              Positioned(
                  top: 50,
                  right: 70,
                  child: GestureDetector(
                      onTap: onUpdateCoverPhoto,
                      child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24)),
                          child: const Icon(Icons.add_a_photo,
                              color: Colors.white, size: 18)))),
              Positioned(
                  top: 50,
                  right: 16,
                  child: GestureDetector(
                      onTap: onSettings,
                      child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24)),
                          child: const Icon(Icons.settings_outlined,
                              color: Colors.white, size: 18)))),
            ] else ...[
              if (showBackButton)
                Positioned(
                    top: 50,
                    left: 16,
                    child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new,
                            color: Colors.white),
                        onPressed: onBack ?? () => Navigator.pop(context))),
              Positioned(
                top: 50,
                right: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                    child: Container(
                      height: 36,
                      width: 36,
                      decoration: BoxDecoration(
                          color: AppColors.bgBlack.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 1)),
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.more_horiz,
                            color: Colors.white, size: 20),
                        color: AppColors.bgCardLight,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        onSelected: onMenuAction,
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                              value: 'report',
                              child: Row(children: [
                                const Icon(Icons.flag_outlined,
                                    color: Colors.white70, size: 18),
                                const SizedBox(width: 10),
                                Text(AppL10n.report,
                                    style: GoogleFonts.poppins(
                                        color: Colors.white, fontSize: 13))
                              ])),
                          PopupMenuItem(
                              value: 'block',
                              child: Row(children: [
                                const Icon(Icons.block,
                                    color: Colors.redAccent, size: 18),
                                const SizedBox(width: 10),
                                Text(AppL10n.block,
                                    style: GoogleFonts.poppins(
                                        color: Colors.redAccent, fontSize: 13))
                              ])),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],

            // PROFİL DETAYLARI
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🔥 AVATAR + LIVE PHOTO 🔥
                  GestureDetector(
                    onLongPressStart: (_) => onLiveVideoStateChange(true),
                    onLongPressEnd: (_) => onLiveVideoStateChange(false),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Simple CircleAvatar with dynamic border color
                        Builder(builder: (context) {
                          // 🎨 BorderColors.options kullanılıyor
                          final int borderIndex =
                              profileData?['border_color_index'] ?? 0;
                          final colors = BorderColors.getColors(borderIndex);

                          return Container(
                            width: 106,
                            height: 106,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: colors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: isPlayingLiveVideo
                                ? null
                                : (profileData?['avatar_url'] != null
                                    ? KinnectImage(
                                        imageUrl: profileData!['avatar_url'],
                                        width: 100,
                                        height: 100,
                                        isCircle: true,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        decoration: BoxDecoration(
                                            color: AppColors.bgCard,
                                            shape: BoxShape.circle),
                                        child: const Icon(Icons.person,
                                            size: 50, color: Colors.white30),
                                      )),
                          );
                        }),
                        // Live video overlay when pressed
                        if (hasLiveVideo &&
                            isPlayingLiveVideo &&
                            videoController != null &&
                            videoController!.value.isInitialized)
                          SizedBox(
                            width: 100,
                            height: 100,
                            child: ClipOval(
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: videoController!.value.size.width,
                                  height: videoController!.value.size.height,
                                  child: VideoPlayer(videoController!),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // 🔥 PROFİL İSMİ VE ADMIN ROZETİ
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(profileData?['full_name'] ?? AppL10n.unnamed,
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                    offset: Offset(0, 1),
                                    blurRadius: 4,
                                    color: AppColors.bgBlack)
                              ])),
                      if (isAdmin) ...[
                        const AdminBadge(size: 24),
                      ]
                    ],
                  ),

                  if (profileData?['username'] != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('@${profileData!['username']}',
                            style: GoogleFonts.poppins(
                                color: Colors.white60,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                shadows: [
                                  Shadow(
                                      offset: Offset(0, 1),
                                      blurRadius: 3,
                                      color: AppColors.bgBlack)
                                ]))),
                  if (profileData?['bio'] != null)
                    Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        child: Text(profileData!['bio'],
                            style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 13,
                                shadows: [
                                  Shadow(
                                      offset: Offset(0, 1),
                                      blurRadius: 3,
                                      color: AppColors.bgBlack)
                                ]),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis)),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStat(AppL10n.posts, postCount.toString(), null),
                      Container(width: 1, height: 20, color: Colors.white12),
                      _buildStat(AppL10n.followers, followersCount.toString(),
                          () => onOpenFollowList('followers', AppL10n.followersList)),
                      Container(width: 1, height: 20, color: Colors.white12),
                      _buildStat(
                          AppL10n.followingCount,
                          followingCount.toString(),
                          () =>
                              onOpenFollowList('following', AppL10n.followingList)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        // BUTONLAR
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 10),
              isMe
                  ? _buildMyProfileButtons(context)
                  : _buildOtherProfileButtons(),
              const SizedBox(height: 5),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStat(String label, String value, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 4,
                        color: AppColors.bgBlack)
                  ])),
          Text(label,
              style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMyProfileButtons(BuildContext context) {
    return const SizedBox.shrink();
  }

  Widget _buildOtherProfileButtons() {
    String label = AppL10n.follow;
    Color bgColor = AppColors.primary;
    Color txtColor = Colors.white;
    if (friendshipStatus == 'accepted') {
      label = AppL10n.following;
      bgColor = AppColors.bgCardLight;
    } else if (friendshipStatus == 'pending') {
      label = AppL10n.requested;
      bgColor = Colors.grey.shade900;
      txtColor = Colors.grey;
    }
    return Row(
      children: [
        Expanded(
            child: SizedBox(
                height: 45,
                child: ElevatedButton(
                    onPressed: onFollowAction,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: bgColor,
                        foregroundColor: txtColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0),
                    child: Text(label,
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600))))),
        const SizedBox(width: 10),
        Expanded(
            child: SizedBox(
                height: 45,
                child: ElevatedButton(
                    onPressed: onMessage,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.bgCardLight,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                        side: const BorderSide(color: Colors.white12)),
                    child: Text(AppL10n.sendMessage,
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.w600))))),
      ],
    );
  }
}
