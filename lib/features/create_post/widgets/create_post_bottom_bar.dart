import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../co../../../core/theme/app_colors.dart';

class CreatePostBottomBar extends StatefulWidget {
  final VoidCallback onPickFromGallery;
  final VoidCallback onPickFromCamera;
  final VoidCallback onPickMusic;
  final VoidCallback onPickLocation;
  final VoidCallback onShare;
  final bool isGettingLocation;
  final bool isSharing;

  const CreatePostBottomBar({
    super.key,
    required this.onPickFromGallery,
    required this.onPickFromCamera,
    required this.onPickMusic,
    required this.onPickLocation,
    required this.onShare,
    required this.isGettingLocation,
    required this.isSharing,
  });

  @override
  State<CreatePostBottomBar> createState() => _CreatePostBottomBarState();
}

class _CreatePostBottomBarState extends State<CreatePostBottomBar> {
  bool _isShareButtonPressed = false;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.only(bottom: 30, left: 16, right: 16),
        height: 70,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(35),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.bgCard.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(35),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.onPickFromGallery,
                    icon: const Icon(Icons.image_outlined,
                        color: Colors.greenAccent, size: 28),
                    tooltip: 'Galeri',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: widget.onPickFromCamera,
                    icon: const Icon(Icons.camera_alt_outlined,
                        color: Colors.blueAccent, size: 28),
                    tooltip: 'Kamera',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: widget.onPickMusic,
                    icon: const Icon(
                      Icons.audiotrack_outlined,
                      color: Color(0xFF6C63FF),
                      size: 28,
                    ),
                    tooltip: 'Müzik Ekle',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: widget.onPickLocation,
                    icon: widget.isGettingLocation
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.orangeAccent, strokeWidth: 2))
                        : const Icon(
                            Icons.location_on_outlined,
                            color: Colors.orangeAccent,
                            size: 28,
                          ),
                    tooltip: 'Konum Ekle',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const Spacer(),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.primary,
                              Color(0xFF448AFF),
                              Color(0xFF69F0AE)
                            ],
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
                              : Text("Paylaş",
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
