import 'package:flutter/material.dart';

/// Reusable widget for displaying badges - clean, no frame
class ProfileBadgeDisplay extends StatelessWidget {
  final String imagePath;
  final double size;
  final VoidCallback? onTap;

  const ProfileBadgeDisplay({
    super.key,
    required this.imagePath,
    this.size = 50,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: Image.asset(
          imagePath,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
