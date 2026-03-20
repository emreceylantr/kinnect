import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

class CreatePostBottomBar extends StatefulWidget {
  final VoidCallback onPickFromGallery;
  final VoidCallback onPickFromCamera;
  final VoidCallback onPickVideo;
  final VoidCallback onPickMusic;
  final VoidCallback onPickLocation;
  final VoidCallback onShare;
  final bool isGettingLocation;
  final bool isSharing;

  const CreatePostBottomBar({
    super.key,
    required this.onPickFromGallery,
    required this.onPickFromCamera,
    required this.onPickVideo,
    required this.onPickMusic,
    required this.onPickLocation,
    required this.onShare,
    required this.isGettingLocation,
    required this.isSharing,
  });

  @override
  State<CreatePostBottomBar> createState() => _CreatePostBottomBarState();
}

class _BarIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _BarIcon(this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class _CreatePostBottomBarState extends State<CreatePostBottomBar> {
  bool _isShareButtonPressed = false;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.only(bottom: 30, left: 16, right: 16),
        height: 64,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.bgCard.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // İkonlar grubu
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _BarIcon(Icons.image_outlined, Colors.greenAccent, widget.onPickFromGallery),
                      const SizedBox(width: 18),
                      _BarIcon(Icons.camera_alt_outlined, Colors.blueAccent, widget.onPickFromCamera),
                      const SizedBox(width: 18),
                      _BarIcon(Icons.videocam_outlined, Colors.orangeAccent, widget.onPickVideo),
                      const SizedBox(width: 18),
                      _BarIcon(Icons.audiotrack_outlined, const Color(0xFF6C63FF), widget.onPickMusic),
                      const SizedBox(width: 18),
                      widget.isGettingLocation
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(color: Colors.orangeAccent, strokeWidth: 2))
                          : _BarIcon(Icons.location_on_outlined, Colors.orangeAccent, widget.onPickLocation),
                    ],
                  ),

                  // Paylaş butonu
                  GestureDetector(
                    onTapDown: (_) =>
                        setState(() => _isShareButtonPressed = true),
                    onTapUp: (_) {
                      setState(() => _isShareButtonPressed = false);
                      if (!widget.isSharing) widget.onShare();
                    },
                    onTapCancel: () =>
                        setState(() => _isShareButtonPressed = false),
                    child: AnimatedScale(
                      scale: _isShareButtonPressed ? 0.95 : 1.0,
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.easeInOut,
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, Color(0xFF9D89D9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(21),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: widget.isSharing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : Text('Paylaş',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
