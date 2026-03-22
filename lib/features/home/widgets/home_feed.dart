// Kinnect - Home Feed Widget
// Ana akış - arkadaş postları listesi

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/language/app_l10n.dart';
import '../../../core/theme/app_colors.dart';

/// Ana akış - post listesi
class HomeFeed extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final bool isLoading;
  final Widget Function(Map<String, dynamic> post, int index)? postBuilder;
  final Future<void> Function()? onRefresh;

  const HomeFeed({
    super.key,
    required this.posts,
    this.isLoading = false,
    this.postBuilder,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, color: Colors.white24, size: 60),
            const SizedBox(height: 16),
            Text(
              AppL10n.noPostsInFeed,
              style: GoogleFonts.poppins(color: Colors.white38, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              AppL10n.followFriendsPrompt,
              style: GoogleFonts.poppins(color: Colors.white24, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      color: AppColors.primary,
      backgroundColor: AppColors.bgCard,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 10, bottom: 100),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          if (postBuilder != null) {
            return postBuilder!(posts[index], index);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
