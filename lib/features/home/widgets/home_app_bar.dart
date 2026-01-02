// Kinnect - Home AppBar Widget
// Ana ekran app bar'ı - bildirimler ve mesajlar

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'appbar_buttons.dart';

/// Ana ekran app bar'ı
class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int unreadNotifications;
  final VoidCallback onNotificationTap;
  final VoidCallback onMessageTap;

  const HomeAppBar({
    super.key,
    this.unreadNotifications = 0,
    required this.onNotificationTap,
    required this.onMessageTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: Text(
        'Kinnect',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        // Bildirimler
        LottieBellButton(
          notificationCount: unreadNotifications,
          onTap: onNotificationTap,
        ),
        const SizedBox(width: 4),
        // Mesajlar
        CyberMessageButton(
          onTap: onMessageTap,
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
