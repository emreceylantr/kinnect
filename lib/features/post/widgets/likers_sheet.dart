import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../profile/screens/profile_screen.dart';
import '../../../shared/widgets/kinnect_image.dart';

class LikersSheet extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> likersFuture;
  final int likeCount;

  const LikersSheet({
    super.key,
    required this.likersFuture,
    required this.likeCount,
  });

  static void show(BuildContext context,
      {required Future<List<Map<String, dynamic>>> likersFuture,
      required int likeCount}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => LikersSheet(
        likersFuture: likersFuture,
        likeCount: likeCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '❤️ Beğenenler ($likeCount)',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: likersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Yüklenemedi',
                      style: GoogleFonts.poppins(color: Colors.white54),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Henüz kimse beğenmedi',
                        style: GoogleFonts.poppins(color: Colors.white54),
                      ),
                    ),
                  );
                } else {
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final liker = snapshot.data![index];
                      final profile = liker['profiles'] ?? {};
                      final username = profile['username'] ?? 'Kullanıcı';
                      final avatarUrl = profile['avatar_url'];
                      final userId = liker['user_id'];

                      return ListTile(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileScreen(userId: userId),
                            ),
                          );
                        },
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.bgCard,
                          child: avatarUrl != null
                              ? ClipOval(
                                  child: KinnectImage(
                                    imageUrl: avatarUrl,
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Icon(Icons.person,
                                  color: Colors.white54, size: 20),
                        ),
                        title: Text(
                          username,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.white38,
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
