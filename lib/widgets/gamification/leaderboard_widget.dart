import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/gamification/leaderboard_service.dart';

/// Leaderboard list widget with fire-themed design
class LeaderboardWidget extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  final String? currentUserId;

  const LeaderboardWidget({
    super.key,
    required this.entries,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isTopThree = entry.rank <= 3;
        final isCurrentUser = entry.userId == currentUserId;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: isTopThree
                ? LinearGradient(
                    colors: [
                      _getRankColor(entry.rank).withOpacity(0.2),
                      Colors.transparent,
                    ],
                  )
                : null,
            color: isTopThree
                ? null
                : isCurrentUser
                    ? Colors.orange.withOpacity(0.1)
                    : const Color(0xFF16161F),
            borderRadius: BorderRadius.circular(12),
            border: isTopThree
                ? Border.all(color: _getRankColor(entry.rank).withOpacity(0.5))
                : isCurrentUser
                    ? Border.all(color: Colors.orange.withOpacity(0.3))
                    : null,
          ),
          child: Row(
            children: [
              // Rank
              SizedBox(
                width: 36,
                child: isTopThree
                    ? Text(
                        entry.rankEmoji,
                        style: const TextStyle(fontSize: 22),
                      )
                    : Text(
                        '#${entry.rank}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isCurrentUser ? Colors.orange : Colors.white54,
                        ),
                      ),
              ),
              const SizedBox(width: 12),

              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.grey.shade800,
                    backgroundImage: entry.avatarUrl != null
                        ? NetworkImage(entry.avatarUrl!)
                        : null,
                    child: entry.avatarUrl == null
                        ? Icon(Icons.person,
                            size: 22, color: Colors.grey.shade600)
                        : null,
                  ),
                  // Level badge on avatar
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16161F),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${entry.level}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Username
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            entry.username,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color:
                                  isCurrentUser ? Colors.orange : Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (isCurrentUser) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Sen',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      'Seviye ${entry.level}',
                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // XP
              Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  Text(
                    '${entry.totalXP}',
                    style: GoogleFonts.poppins(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return Colors.grey;
    }
  }
}
