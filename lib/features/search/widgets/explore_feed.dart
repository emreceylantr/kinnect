// Kinnect - Explore Feed Widget
// Keşfet akışı - trend postlar ve normal post listesi

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/language/app_l10n.dart';
import '../../../core/theme/app_colors.dart';

/// Keşfet akışı - trend slider ve post grid
class ExploreFeed extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final bool isLoading;
  final Widget Function(Map<String, dynamic> post, int index)? postBuilder;
  final Widget Function(List<Map<String, dynamic>> topPosts)?
      trendSliderBuilder;

  const ExploreFeed({
    super.key,
    required this.posts,
    this.isLoading = false,
    this.postBuilder,
    this.trendSliderBuilder,
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
            Icon(Icons.explore_off, color: Colors.white24, size: 60),
            const SizedBox(height: 16),
            Text(
              AppL10n.noExploreContent,
              style: GoogleFonts.poppins(color: Colors.white38, fontSize: 16),
            ),
          ],
        ),
      );
    }

    // Top 3 post için trend slider
    final trendPosts = posts.take(3).toList();
    final remainingPosts = posts.skip(3).toList();

    return CustomScrollView(
      slivers: [
        // Trend Slider
        if (trendPosts.isNotEmpty && trendSliderBuilder != null)
          SliverToBoxAdapter(
            child: trendSliderBuilder!(trendPosts),
          ),

        // Normal Post Listesi
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (postBuilder != null) {
                return postBuilder!(remainingPosts[index], index);
              }
              return const SizedBox.shrink();
            },
            childCount: remainingPosts.length,
          ),
        ),
      ],
    );
  }
}
