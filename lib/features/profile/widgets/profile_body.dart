// Kinnect - ProfileBody Widget
// Profil ekranının post listesi kısmı

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/language/app_l10n.dart';
import '../../../core/theme/app_colors.dart';

/// Profil gövdesi - post listesi gösterimi
class ProfileBody extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final bool isLoading;
  final Widget Function(Map<String, dynamic> post, int index)? postBuilder;

  const ProfileBody({
    super.key,
    required this.posts,
    this.isLoading = false,
    this.postBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    if (posts.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.photo_library_outlined,
                    color: Colors.white24, size: 60),
                const SizedBox(height: 16),
                Text(
                  AppL10n.noPostsYet,
                  style: GoogleFonts.poppins(
                    color: Colors.white38,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (postBuilder != null) {
            return postBuilder!(posts[index], index);
          }
          return const SizedBox.shrink();
        },
        childCount: posts.length,
      ),
    );
  }
}
