// Kinnect - Ayarlar Ekranı

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/language/language_manager.dart';
import '../../../core/language/app_l10n.dart';
import '../../../main.dart' show navigatorKey;
import '../../home/screens/home_screen.dart';
import '../../profile/screens/edit_profile_screen.dart';
import '../../auth/screens/change_password_screen.dart';

class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic>? profileData;
  const SettingsScreen({super.key, this.profileData});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ── Language ──
  String _lang = LanguageManager().localeNotifier.value.languageCode;
  bool get isEn => _lang == 'en';

  // ── Expansion state ──
  bool _privacyOpen = false;
  bool _notifOpen = false;
  bool _accountOpen = false;
  bool _supportOpen = false;

  // ── Privacy (Supabase) ──
  bool _showLastSeen = true;
  bool _showReadReceipts = true;

  // ── Notifications (SharedPreferences) ──
  bool _notifEnabled = true;
  bool _notifLikes = true;
  bool _notifComments = true;
  bool _notifFollowers = true;
  bool _notifMessages = true;

  // ── Profile ──
  Map<String, dynamic>? _profile;

  final _supabase = Supabase.instance.client;
  String get _uid => _supabase.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadNotifPrefs();
  }

  Future<void> _loadProfile() async {
    if (_uid.isEmpty) return;
    final data = await _supabase
        .from('profiles')
        .select('id, username, full_name, avatar_url, show_last_seen, show_read_receipts')
        .eq('id', _uid)
        .maybeSingle();
    if (mounted && data != null) {
      setState(() {
        _profile = data;
        _showLastSeen = data['show_last_seen'] ?? true;
        _showReadReceipts = data['show_read_receipts'] ?? true;
      });
    }
  }

  Future<void> _loadNotifPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notifEnabled = prefs.getBool('notif_enabled') ?? true;
        _notifLikes = prefs.getBool('notif_likes') ?? true;
        _notifComments = prefs.getBool('notif_comments') ?? true;
        _notifFollowers = prefs.getBool('notif_followers') ?? true;
        _notifMessages = prefs.getBool('notif_messages') ?? true;
      });
    }
  }

  Future<void> _saveNotifPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _updatePrivacy(String field, bool value) async {
    await _supabase.from('profiles').update({field: value}).eq('id', _uid);
  }

  Future<void> _switchLanguage(String lang) async {
    if (_lang == lang) return;
    await LanguageManager().setLocale(lang);
    if (mounted) {
      setState(() => _lang = lang);
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _confirmLogout() async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(AppL10n.signOut),
        content: Text(AppL10n.signOutConfirm),
        actions: [
          CupertinoDialogAction(
            child: Text(AppL10n.cancel),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(AppL10n.signOut),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _supabase.auth.signOut();
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(AppL10n.deleteAccount),
        content: Text(AppL10n.deleteAccountConfirm),
        actions: [
          CupertinoDialogAction(
            child: Text(AppL10n.cancel),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(AppL10n.deleteAccount),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _supabase.auth.signOut();
    }
  }

  static const _bg = Color(0xFF0A0A0F);
  static const _cardBg = Color(0xFF13131A);
  static const _accent = Color(0xFF7C6EFA);
  static const _border = Color(0xFF1E1E2A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 28),
                  _buildSectionLabel(AppL10n.language),
                  const SizedBox(height: 10),
                  _buildLanguagePicker(),
                  const SizedBox(height: 24),
                  _buildAccordion(
                    label: AppL10n.privacy,
                    icon: Icons.shield_outlined,
                    iconColor: const Color(0xFF30D158),
                    isOpen: _privacyOpen,
                    onToggle: () => setState(() => _privacyOpen = !_privacyOpen),
                    children: _privacyItems(),
                  ),
                  const SizedBox(height: 12),
                  _buildAccordion(
                    label: AppL10n.notificationsSettings,
                    icon: Icons.notifications_outlined,
                    iconColor: const Color(0xFFFF9F0A),
                    isOpen: _notifOpen,
                    onToggle: () => setState(() => _notifOpen = !_notifOpen),
                    children: _notifItems(),
                  ),
                  const SizedBox(height: 12),
                  _buildAccordion(
                    label: AppL10n.account,
                    icon: Icons.person_outline_rounded,
                    iconColor: _accent,
                    isOpen: _accountOpen,
                    onToggle: () => setState(() => _accountOpen = !_accountOpen),
                    children: _accountItems(),
                  ),
                  const SizedBox(height: 12),
                  _buildAccordion(
                    label: AppL10n.support,
                    icon: Icons.help_outline_rounded,
                    iconColor: const Color(0xFF636366),
                    isOpen: _supportOpen,
                    onToggle: () => setState(() => _supportOpen = !_supportOpen),
                    children: _supportItems(),
                  ),
                  const SizedBox(height: 32),
                  _buildSignOutButton(),
                  const SizedBox(height: 10),
                  _buildDeleteButton(),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Kinnect v1.0',
                      style: GoogleFonts.poppins(color: Colors.white24, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── APP BAR ──
  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      backgroundColor: _bg,
      elevation: 0,
      pinned: true,
      expandedHeight: 80,
      leading: Padding(
        padding: const EdgeInsets.all(10),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
        title: Text(
          AppL10n.settings,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 22),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_accent.withValues(alpha: 0.12), _bg],
            ),
          ),
        ),
      ),
    );
  }

  // ── PROFILE HEADER ──
  Widget _buildProfileHeader() {
    final name = _profile?['full_name'] ?? widget.profileData?['full_name'] ?? '';
    final username = _profile?['username'] ?? widget.profileData?['username'] ?? '';
    final avatar = _profile?['avatar_url'] ?? widget.profileData?['avatar_url'];

    return GestureDetector(
      onTap: () {
        final profile = _profile ?? widget.profileData;
        if (profile != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EditProfileScreen(currentProfile: profile)),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: _accent.withValues(alpha: 0.2),
              backgroundImage: avatar != null ? NetworkImage(avatar) : null,
              child: avatar == null
                  ? const Icon(Icons.person_rounded, color: _accent, size: 26)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (name.isNotEmpty)
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15,
                      ),
                    ),
                  Text(
                    '@$username',
                    style: GoogleFonts.poppins(color: Colors.white38, fontSize: 13),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _accent.withValues(alpha: 0.3)),
              ),
              child: Text(
                AppL10n.editProfileTitle,
                style: GoogleFonts.poppins(color: _accent, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── LANGUAGE PICKER ──
  Widget _buildSectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.poppins(
        color: Colors.white30, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildLanguagePicker() {
    return Row(
      children: [
        Expanded(child: _LanguageCard(flag: '🇹🇷', label: 'Türkçe', isSelected: !isEn, onTap: () => _switchLanguage('tr'))),
        const SizedBox(width: 12),
        Expanded(child: _LanguageCard(flag: '🇬🇧', label: 'English', isSelected: isEn, onTap: () => _switchLanguage('en'))),
      ],
    );
  }

  // ── ACCORDION ──
  Widget _buildAccordion({
    required String label,
    required IconData icon,
    required Color iconColor,
    required bool isOpen,
    required VoidCallback onToggle,
    required List<Widget> children,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOpen ? _accent.withValues(alpha: 0.3) : _border,
        ),
      ),
      child: Column(
        children: [
          // Header row
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isOpen ? 0.25 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: isOpen ? _accent : Colors.white30,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expandable content
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                Divider(height: 1, color: _border),
                ...children,
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── PRIVACY ITEMS ──
  List<Widget> _privacyItems() => [
    _ToggleTile(
      icon: Icons.visibility_outlined,
      iconColor: const Color(0xFF30D158),
      label: AppL10n.showLastSeen,
      subtitle: AppL10n.showLastSeenSubtitle,
      value: _showLastSeen,
      onChanged: (v) {
        setState(() => _showLastSeen = v);
        _updatePrivacy('show_last_seen', v);
      },
    ),
    _ItemDivider(),
    _ToggleTile(
      icon: Icons.done_all_rounded,
      iconColor: const Color(0xFF0A84FF),
      label: AppL10n.readReceipts,
      subtitle: AppL10n.readReceiptsSubtitle,
      value: _showReadReceipts,
      onChanged: (v) {
        setState(() => _showReadReceipts = v);
        _updatePrivacy('show_read_receipts', v);
      },
    ),
  ];

  // ── NOTIFICATION ITEMS ──
  List<Widget> _notifItems() => [
    _ToggleTile(
      icon: Icons.notifications_outlined,
      iconColor: const Color(0xFFFF9F0A),
      label: AppL10n.pushNotifications,
      value: _notifEnabled,
      onChanged: (v) {
        setState(() {
          _notifEnabled = v;
          _notifLikes = v;
          _notifComments = v;
          _notifFollowers = v;
          _notifMessages = v;
        });
        _saveNotifPref('notif_enabled', v);
        _saveNotifPref('notif_likes', v);
        _saveNotifPref('notif_comments', v);
        _saveNotifPref('notif_followers', v);
        _saveNotifPref('notif_messages', v);
      },
    ),
    _ItemDivider(),
    _ToggleTile(
      icon: Icons.local_fire_department_outlined,
      iconColor: const Color(0xFFFF453A),
      label: AppL10n.notifLikes,
      value: _notifEnabled && _notifLikes,
      enabled: _notifEnabled,
      onChanged: (v) { setState(() => _notifLikes = v); _saveNotifPref('notif_likes', v); },
    ),
    _ItemDivider(),
    _ToggleTile(
      icon: Icons.chat_bubble_outline_rounded,
      iconColor: const Color(0xFF64D2FF),
      label: AppL10n.notifComments,
      value: _notifEnabled && _notifComments,
      enabled: _notifEnabled,
      onChanged: (v) { setState(() => _notifComments = v); _saveNotifPref('notif_comments', v); },
    ),
    _ItemDivider(),
    _ToggleTile(
      icon: Icons.person_add_outlined,
      iconColor: _accent,
      label: AppL10n.notifFollowers,
      value: _notifEnabled && _notifFollowers,
      enabled: _notifEnabled,
      onChanged: (v) { setState(() => _notifFollowers = v); _saveNotifPref('notif_followers', v); },
    ),
    _ItemDivider(),
    _ToggleTile(
      icon: Icons.message_outlined,
      iconColor: const Color(0xFF30D158),
      label: AppL10n.notifMessages,
      value: _notifEnabled && _notifMessages,
      enabled: _notifEnabled,
      onChanged: (v) { setState(() => _notifMessages = v); _saveNotifPref('notif_messages', v); },
    ),
  ];

  // ── ACCOUNT ITEMS ──
  List<Widget> _accountItems() => [
    _NavTile(
      icon: Icons.lock_outline_rounded,
      iconColor: const Color(0xFFFF9F0A),
      label: AppL10n.changePassword,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
    ),
  ];

  // ── SUPPORT ITEMS ──
  List<Widget> _supportItems() => [
    _NavTile(
      icon: Icons.info_outline_rounded,
      iconColor: const Color(0xFF636366),
      label: AppL10n.about,
      onTap: _showAboutSheet,
    ),
    _ItemDivider(),
    _NavTile(
      icon: Icons.shield_outlined,
      iconColor: const Color(0xFF0A84FF),
      label: AppL10n.privacyPolicy,
      onTap: _showPrivacyPolicy,
    ),
  ];

  // ── SIGN OUT / DELETE ──
  Widget _buildSignOutButton() {
    return GestureDetector(
      onTap: _confirmLogout,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
            const SizedBox(width: 10),
            Text(
              AppL10n.signOut,
              style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 14.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return GestureDetector(
      onTap: _confirmDeleteAccount,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_forever_outlined, color: Colors.red.withValues(alpha: 0.4), size: 15),
            const SizedBox(width: 6),
            Text(
              AppL10n.deleteAccount,
              style: GoogleFonts.poppins(
                color: Colors.red.withValues(alpha: 0.4), fontSize: 12.5, fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── ABOUT SHEET ──
  void _showAboutSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AboutSheet(isEn: isEn),
    );
  }

  void _showPrivacyPolicy() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PrivacyPolicySheet(isEn: isEn),
    );
  }
}

// ── ABOUT SHEET ──
class _AboutSheet extends StatelessWidget {
  final bool isEn;
  const _AboutSheet({required this.isEn});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF1E1E2A)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)]),
            ),
            child: const Icon(Icons.all_inclusive_rounded, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 16),
          Text(
            'Kinnect',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            isEn ? 'Version 1.0' : 'Sürüm 1.0',
            style: GoogleFonts.poppins(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF7C6EFA).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF7C6EFA).withValues(alpha: 0.2)),
            ),
            child: Text(
              isEn
                  ? 'Kinnect is an AI-powered social platform that helps you discover people who truly resonate with you — not just who you follow, but who you genuinely connect with.\n\nUsing your posts, music, and lifestyle signals, our AI finds your real-life matches and tells you exactly why you two belong together.'
                  : 'Kinnect, sadece takip ettiklerini değil; gerçekten benzer olduğun insanları keşfetmeni sağlayan yapay zeka destekli bir sosyal platformdur.\n\nPaylaşımların, müziğin ve yaşam tarzı sinyallerin üzerinden yapay zeka, sana en uygun kişileri bulur ve neden bu kadar uyumlu olduğunuzu anlatır.',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, height: 1.6),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _FeatureBadge(isEn ? '🤖 AI Matching' : '🤖 AI Eşleşme'),
              const SizedBox(width: 8),
              _FeatureBadge(isEn ? '🔥 Social Feed' : '🔥 Sosyal Akış'),
              const SizedBox(width: 8),
              _FeatureBadge(isEn ? '💬 Chat' : '💬 Sohbet'),
            ],
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF7C6EFA).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF7C6EFA).withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Text(
                  AppL10n.close,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF7C6EFA), fontWeight: FontWeight.w600, fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureBadge extends StatelessWidget {
  final String label;
  const _FeatureBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(color: Colors.white60, fontSize: 11),
      ),
    );
  }
}

// ── TOGGLE TILE ──
class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.subtitle,
    required this.value,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11.5),
                    ),
                ],
              ),
            ),
            CupertinoSwitch(
              value: value,
              activeColor: const Color(0xFF7C6EFA),
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── NAV TILE ──
class _NavTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _NavTile({required this.icon, required this.iconColor, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ItemDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: Color(0xFF1E1E2A), indent: 56);
  }
}

// ── DİL KARTI ──
class _LanguageCard extends StatelessWidget {
  final String flag;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageCard({required this.flag, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7C6EFA).withValues(alpha: 0.12) : const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF7C6EFA) : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFF7C6EFA).withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 3))]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(flag, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.poppins(
                      color: isSelected ? const Color(0xFF7C6EFA) : Colors.white70,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF7C6EFA)),
                    child: const Icon(Icons.check, color: Colors.white, size: 12),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── PRIVACY POLICY SHEET ──
class _PrivacyPolicySheet extends StatelessWidget {
  final bool isEn;
  const _PrivacyPolicySheet({required this.isEn});

  static const _accent = Color(0xFF7C6EFA);
  static const _cardBg = Color(0xFF13131A);
  static const _border = Color(0xFF1E1E2A);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.97,
      minChildSize: 0.5,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_outlined, color: _accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEn ? 'Privacy Policy' : 'Gizlilik Politikası',
                          style: GoogleFonts.poppins(
                            color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          isEn ? 'Last updated: March 2026' : 'Son güncelleme: Mart 2026',
                          style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close, color: Colors.white54, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: _border, height: 1),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                children: isEn ? _enSections() : _trSections(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _enSections() => [
    _PolicySection(icon: '👋', title: 'Welcome',
      body: 'Kinnect ("we", "our", "us") is an AI-powered social platform that helps people discover genuine connections. This Privacy Policy explains what data we collect, how we use it, and your rights regarding it.\n\nBy using Kinnect, you agree to this policy.'),
    _PolicySection(icon: '📋', title: 'What We Collect',
      body: '• Account info: name, username, email, profile photo\n• Profile content: bio, interests, location tags you add\n• Posts & media: photos, videos, text posts, voice comments\n• Music data: Spotify and Apple Music connections — only what you choose to share\n• Interactions: likes, comments, follows, messages\n• Device info: type, OS version, push notification token\n• Usage data: screens visited, features used, session duration'),
    _PolicySection(icon: '🤖', title: 'How We Use Your Data',
      body: '• AI Matching: your posts, interests and music are analyzed to suggest compatible users\n• Personalized feed: showing content relevant to your interests\n• Social features: enabling follows, messaging and reactions\n• Push notifications: alerting you to new activity (you can disable in Settings)\n• Safety: detecting spam, abuse and policy violations\n• Service improvements: understanding how features are used'),
    _PolicySection(icon: '🔗', title: 'Third-Party Services',
      body: '• Supabase: our database and auth provider (stores your data securely)\n• Google Sign-In: optional login method\n• Spotify / Apple Music: optional music integrations — we only access what you explicitly authorize\n• Anthropic Claude API: powers AI matching analysis (no personal identifiers sent, only anonymized post summaries)\n• Firebase / APNs: push notification delivery'),
    _PolicySection(icon: '🔒', title: 'Data Security',
      body: 'All data is encrypted in transit (TLS) and at rest. We use Supabase Row-Level Security (RLS) to ensure users can only access their own data. Passwords are hashed and never stored in plain text.\n\nWe do not sell your personal data to third parties.'),
    _PolicySection(icon: '👁️', title: 'Your Privacy Controls',
      body: 'You have full control over:\n• Last Seen visibility\n• Read receipts\n• Notification preferences\n• Profile visibility\n\nUpdate these anytime in Settings → Privacy.'),
    _PolicySection(icon: '🗂️', title: 'Data Retention',
      body: 'We retain your data while your account is active. When you delete your account:\n• Profile, posts, and messages are permanently deleted within 30 days\n• Anonymized analytics may be retained longer\n• Request immediate deletion by contacting us'),
    _PolicySection(icon: '🧒', title: 'Age Requirement',
      body: 'Kinnect is for users aged 16 and older. We do not knowingly collect data from children under 16. If you believe a minor has created an account, please contact us immediately.'),
    _PolicySection(icon: '✉️', title: 'Contact',
      body: 'For privacy questions, data requests or deletion requests:\n\nEmail: emreceylan2316@gmail.com\n\nWe aim to respond within 72 hours.', isLast: true),
  ];

  List<Widget> _trSections() => [
    _PolicySection(icon: '👋', title: 'Hoş Geldiniz',
      body: 'Kinnect ("biz"), insanların gerçek bağlantılar kurmasına yardımcı olan yapay zeka destekli bir sosyal platformdur. Bu Gizlilik Politikası, hangi verileri topladığımızı, bunları nasıl kullandığımızı ve haklarınızı açıklar.\n\nKinnect\'i kullanarak bu politikayı kabul etmiş olursunuz.'),
    _PolicySection(icon: '📋', title: 'Topladığımız Veriler',
      body: '• Hesap bilgileri: ad, kullanıcı adı, e-posta, profil fotoğrafı\n• Profil içeriği: biyografi, ilgi alanları, eklediğiniz konum etiketleri\n• Paylaşımlar ve medya: fotoğraf, video, metin paylaşımları, sesli yorumlar\n• Müzik verileri: Spotify ve Apple Music bağlantıları — yalnızca paylaşmayı seçtikleriniz\n• Etkileşimler: beğeniler, yorumlar, takipler, mesajlar\n• Cihaz bilgileri: tür, işletim sistemi, bildirim tokeni\n• Kullanım verileri: ziyaret edilen ekranlar, kullanılan özellikler, oturum süresi'),
    _PolicySection(icon: '🤖', title: 'Verilerinizi Nasıl Kullanıyoruz',
      body: '• AI Eşleşme: paylaşımlarınız, ilgi alanlarınız ve müziğiniz analiz edilerek uyumlu kullanıcılar önerilir\n• Kişiselleştirilmiş akış: ilgi alanlarınıza uygun içerik\n• Sosyal özellikler: takip, mesajlaşma ve tepki gönderme\n• Anlık bildirimler: yeni aktiviteler için uyarılar (Ayarlar\'dan kapatabilirsiniz)\n• Güvenlik: spam, kötüye kullanım ve ihlal tespiti\n• Hizmet geliştirme: özelliklerin kullanımını anlama'),
    _PolicySection(icon: '🔗', title: 'Üçüncü Taraf Hizmetler',
      body: '• Supabase: veritabanı ve kimlik doğrulama sağlayıcımız\n• Google Sign-In: isteğe bağlı giriş yöntemi\n• Spotify / Apple Music: isteğe bağlı müzik entegrasyonları — yalnızca yetkilendirdiğiniz verilere erişilir\n• Anthropic Claude API: AI eşleşme analizi (kişisel tanımlayıcı gönderilmez)\n• Firebase / APNs: bildirim iletimi'),
    _PolicySection(icon: '🔒', title: 'Veri Güvenliği',
      body: 'Tüm veriler aktarımda (TLS) ve saklamada şifrelenir. Supabase Satır Düzeyi Güvenliği (RLS) ile kullanıcılar yalnızca kendi verilerine erişebilir. Şifreler hashlenir, düz metin olarak saklanmaz.\n\nKişisel verilerinizi üçüncü taraflara satmıyoruz.'),
    _PolicySection(icon: '👁️', title: 'Gizlilik Kontrolleriniz',
      body: 'Üzerinde tam kontrole sahipsiniz:\n• Son Görülme görünürlüğü\n• Okundu bilgisi\n• Bildirim tercihleri\n• Profil görünürlüğü\n\nBunları istediğiniz zaman Ayarlar → Gizlilik bölümünden güncelleyebilirsiniz.'),
    _PolicySection(icon: '🗂️', title: 'Veri Saklama',
      body: 'Hesabınız aktif olduğu sürece verilerinizi saklarız. Hesabınızı sildiğinizde:\n• Profil, paylaşımlar ve mesajlar 30 gün içinde kalıcı olarak silinir\n• Anonimleştirilmiş analizler daha uzun süre saklanabilir\n• Bize ulaşarak anında silme talebinde bulunabilirsiniz'),
    _PolicySection(icon: '🧒', title: 'Yaş Şartı',
      body: 'Kinnect 16 yaş ve üzeri kullanıcılar içindir. 16 yaşın altındaki çocuklardan bilerek veri toplamıyoruz. Bir reşit olmayan kişinin hesap açtığını düşünüyorsanız lütfen hemen iletişime geçin.'),
    _PolicySection(icon: '✉️', title: 'İletişim',
      body: 'Gizlilik soruları, veri talepleri veya silme talepleri için:\n\nE-posta: emreceylan2316@gmail.com\n\nTüm taleplere 72 saat içinde yanıt vermeye çalışıyoruz.', isLast: true),
  ];
}

class _PolicySection extends StatelessWidget {
  final String icon;
  final String title;
  final String body;
  final bool isLast;
  const _PolicySection({required this.icon, required this.title, required this.body, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Text(title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 10),
        Text(body, style: GoogleFonts.inter(color: Colors.white60, fontSize: 13.5, height: 1.7)),
        if (!isLast) ...[
          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFF1E1E2A)),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}
