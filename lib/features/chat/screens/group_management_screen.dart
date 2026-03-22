// Kinnect - Grup Yönetim Ekranı

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/language/app_l10n.dart';
import '../../../data/services/chat_service.dart';
import '../../../core/theme/app_colors.dart';

class GroupManagementScreen extends StatefulWidget {
  final String roomId;

  const GroupManagementScreen({
    super.key,
    required this.roomId,
  });

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  final ChatService _chatService = ChatService();
  final _nameController = TextEditingController();
  final _currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';

  Map<String, dynamic>? _groupInfo;
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  bool _isCreator = false;
  bool _isSaving = false;

  // Bekleyen değişiklikler (henüz kaydedilmedi)
  XFile? _pendingAvatarFile; // seçilmiş ama upload edilmemiş fotoğraf
  String? _currentAvatarUrl; // kayıtlı avatar URL'si

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final info = await _chatService.getGroupInfo(widget.roomId);
      final members = await _chatService.getGroupParticipants(widget.roomId);

      if (mounted) {
        final admins = List<String>.from(info?['group_admins'] ?? []);
        final isCreator = info?['created_by'] == _currentUserId;
        setState(() {
          _groupInfo = info;
          _members = members;
          _isCreator = isCreator;
          _isAdmin = admins.contains(_currentUserId) || isCreator;
          _nameController.text = info?['group_name'] ?? '';
          _currentAvatarUrl = info?['group_avatar_url'] as String?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Sadece galeriden seç, henüz kaydetme — önizleme
  Future<void> _pickAvatar() async {
    if (!_isAdmin) return;
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image == null) return;
    setState(() => _pendingAvatarFile = image);
  }

  // ✓ butonuna basılınca: foto varsa yükle + ad varsa güncelle
  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    final hasNameChange = name.isNotEmpty && name != (_groupInfo?['group_name'] ?? '');
    final hasAvatarChange = _pendingAvatarFile != null;

    if (!hasNameChange && !hasAvatarChange) return;

    setState(() => _isSaving = true);
    try {
      String? newAvatarUrl;

      if (hasAvatarChange) {
        final file = File(_pendingAvatarFile!.path);
        final ext = _pendingAvatarFile!.path.split('.').last;
        final fileName = 'group_${widget.roomId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final storagePath = 'group_avatars/$fileName';
        await Supabase.instance.client.storage.from('uploads').upload(storagePath, file);
        newAvatarUrl = Supabase.instance.client.storage.from('uploads').getPublicUrl(storagePath);
      }

      final result = await _chatService.updateGroupInfo(
        widget.roomId,
        name: hasNameChange ? name : null,
        avatarUrl: newAvatarUrl,
      );

      if (mounted) {
        setState(() {
          if (hasNameChange) {
            final savedName = result['group_name'] as String? ?? name;
            _groupInfo = {...?_groupInfo, 'group_name': savedName};
            _nameController.text = savedName;
          }
          if (newAvatarUrl != null) {
            final savedUrl = result['group_avatar_url'] as String? ?? newAvatarUrl;
            _currentAvatarUrl = savedUrl;
            _groupInfo = {...?_groupInfo, 'group_avatar_url': savedUrl};
            _pendingAvatarFile = null;
          }
        });

        String msg;
        if (hasAvatarChange && hasNameChange) {
          msg = AppL10n.groupInfoUpdated;
        } else if (hasAvatarChange) {
          msg = AppL10n.groupAvatarUpdated;
        } else {
          msg = AppL10n.groupNameUpdated;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppL10n.saveFailed}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _kickMember(Map<String, dynamic> member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppL10n.kickMember, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          '${member['full_name'] ?? member['username']} ${AppL10n.kickConfirm}',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppL10n.cancel, style: const TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withValues(alpha: 0.2), foregroundColor: Colors.redAccent, elevation: 0),
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppL10n.kick),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _chatService.removeGroupMember(widget.roomId, member['id']);
      setState(() => _members.removeWhere((m) => m['id'] == member['id']));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppL10n.error}: $e')));
    }
  }

  Future<void> _promoteMember(Map<String, dynamic> member) async {
    try {
      await _chatService.promoteToAdmin(widget.roomId, member['id']);
      final admins = List<String>.from(_groupInfo?['group_admins'] ?? []);
      admins.add(member['id']);
      setState(() => _groupInfo = {...?_groupInfo, 'group_admins': admins});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppL10n.error}: $e')));
    }
  }

  Future<void> _demoteMember(Map<String, dynamic> member) async {
    try {
      await _chatService.demoteAdmin(widget.roomId, member['id']);
      final admins = List<String>.from(_groupInfo?['group_admins'] ?? []);
      admins.remove(member['id']);
      setState(() => _groupInfo = {...?_groupInfo, 'group_admins': admins});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppL10n.error}: $e')));
    }
  }

  Future<void> _showAddMemberSheet() async {
    final allFriends = await _chatService.getMutualFriends();
    final memberIds = _members.map((m) => m['id'] as String).toSet();
    final available = allFriends.where((f) => !memberIds.contains(f['id'])).toList();

    if (!mounted) return;
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.noCommonFriends)),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _AddMemberSheet(
        friends: available,
        onAdd: (friend) async {
          await _chatService.addGroupMember(widget.roomId, friend['id']);
          setState(() => _members.add(friend));
        },
      ),
    );
  }

  Future<void> _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppL10n.leaveGroup, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(AppL10n.leaveGroupConfirm, style: GoogleFonts.poppins(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppL10n.cancel, style: const TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withValues(alpha: 0.2), foregroundColor: Colors.redAccent, elevation: 0),
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppL10n.leave),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _chatService.leaveGroup(widget.roomId);
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppL10n.error}: $e')));
    }
  }

  Future<void> _deleteGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppL10n.deleteGroup, style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text(
          AppL10n.deleteGroupConfirm,
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppL10n.cancel, style: const TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, elevation: 0),
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppL10n.yesDelete),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _chatService.deleteGroup(widget.roomId);
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppL10n.error}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(AppL10n.groupSettings, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                _buildGroupHeader(),
                const SizedBox(height: 24),
                _buildMembersSection(),
                const SizedBox(height: 12),
                if (_isAdmin) _buildAddMemberButton(),
                const SizedBox(height: 24),
                _buildLeaveButton(),
                if (_isCreator) ...[
                  const SizedBox(height: 12),
                  _buildDeleteButton(),
                ],
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildGroupHeader() {
    // Önce pending fotoğraf varsa onu göster, yoksa kayıtlı URL
    final hasPending = _pendingAvatarFile != null;
    final savedUrl = _currentAvatarUrl;

    return Column(
      children: [
        // Group avatar
        GestureDetector(
          onTap: _isAdmin ? _pickAvatar : null,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                  border: Border.all(
                    color: hasPending
                        ? const Color(0xFF6C63FF)
                        : const Color(0xFF6C63FF).withValues(alpha: 0.5),
                    width: hasPending ? 3 : 2,
                  ),
                ),
                child: hasPending
                    ? ClipOval(child: Image.file(File(_pendingAvatarFile!.path), fit: BoxFit.cover, width: 90, height: 90))
                    : (savedUrl != null
                        ? ClipOval(child: Image.network(savedUrl, fit: BoxFit.cover))
                        : const Icon(Icons.group, color: Color(0xFF6C63FF), size: 40)),
              ),
              if (_isAdmin)
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasPending ? Colors.green : const Color(0xFF6C63FF),
                    border: Border.all(color: AppColors.bgBlack, width: 2),
                  ),
                  child: Icon(hasPending ? Icons.check : Icons.camera_alt, color: Colors.white, size: 12),
                ),
            ],
          ),
        ),
        if (hasPending)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(AppL10n.saveToHitCheckmark, style: GoogleFonts.poppins(color: const Color(0xFF6C63FF), fontSize: 11)),
          ),
        const SizedBox(height: 16),
        // Group name
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: _isAdmin
              ? Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: AppL10n.groupNameHintField,
                          hintStyle: GoogleFonts.poppins(color: Colors.white38),
                          border: InputBorder.none,
                          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
                          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF6C63FF))),
                        ),
                      ),
                    ),
                    _isSaving
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF)))
                        : IconButton(
                            icon: const Icon(Icons.check_circle, color: Color(0xFF6C63FF), size: 24),
                            onPressed: _saveChanges,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                  ],
                )
              : Text(
                  _groupInfo?['group_name'] ?? AppL10n.group,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
        ),
        const SizedBox(height: 4),
        Text(
          AppL10n.members(_members.length),
          style: GoogleFonts.poppins(color: Colors.white38, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildMembersSection() {
    final admins = List<String>.from(_groupInfo?['group_admins'] ?? []);
    final creatorId = _groupInfo?['created_by'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(AppL10n.groupMembers, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
        ),
        ..._members.map((member) {
          final memberId = member['id'] as String;
          final isMemberAdmin = admins.contains(memberId);
          final isMemberCreator = memberId == creatorId;
          final isMe = memberId == _currentUserId;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: member['avatar_url'] != null ? NetworkImage(member['avatar_url']) : null,
                  backgroundColor: Colors.grey[800],
                  child: member['avatar_url'] == null ? const Icon(Icons.person, color: Colors.white54, size: 20) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            member['full_name'] ?? member['username'] ?? AppL10n.user,
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          if (isMemberCreator) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 10),
                                  const SizedBox(width: 3),
                                  Text(AppL10n.groupLeader, style: GoogleFonts.poppins(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ] else if (isMemberAdmin) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.shield, color: Color(0xFF6C63FF), size: 10),
                                  const SizedBox(width: 3),
                                  Text(AppL10n.groupAdmin, style: GoogleFonts.poppins(color: const Color(0xFF6C63FF), fontSize: 9, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (member['username'] != null)
                        Text('@${member['username']}', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
                // Action buttons (admin only, not on self or creator unless I'm creator)
                if (_isAdmin && !isMe && !(isMemberCreator && !_isCreator))
                  _buildMemberActions(member, isMemberAdmin, isMemberCreator),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMemberActions(Map<String, dynamic> member, bool isMemberAdmin, bool isMemberCreator) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert, color: Colors.white38, size: 18),
      color: const Color(0xFF2D2638),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (action) {
        if (action == 'kick') _kickMember(member);
        if (action == 'promote') _promoteMember(member);
        if (action == 'demote') _demoteMember(member);
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'kick',
          child: Row(children: [
            const Icon(Icons.person_remove, color: Colors.redAccent, size: 16),
            const SizedBox(width: 8),
            Text(AppL10n.kickMember, style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 13)),
          ]),
        ),
        if (!isMemberAdmin)
          PopupMenuItem(
            value: 'promote',
            child: Row(children: [
              const Icon(Icons.shield, color: Color(0xFF6C63FF), size: 16),
              const SizedBox(width: 8),
              Text(AppL10n.makeAdmin, style: GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
            ]),
          ),
        if (isMemberAdmin && _isCreator && !isMemberCreator)
          PopupMenuItem(
            value: 'demote',
            child: Row(children: [
              const Icon(Icons.shield_outlined, color: Colors.white54, size: 16),
              const SizedBox(width: 8),
              Text(AppL10n.removeAdmin, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13)),
            ]),
          ),
      ],
    );
  }

  Widget _buildAddMemberButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: _showAddMemberSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_add, color: Color(0xFF6C63FF), size: 18),
              const SizedBox(width: 8),
              Text(AppL10n.addMember, style: GoogleFonts.poppins(color: const Color(0xFF6C63FF), fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: _leaveGroup,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.exit_to_app, color: Colors.redAccent, size: 18),
              const SizedBox(width: 8),
              Text(AppL10n.leaveGroup, style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: _deleteGroup,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.delete_forever, color: Colors.red, size: 18),
              const SizedBox(width: 8),
              Text(AppL10n.deleteGroup, style: GoogleFonts.poppins(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// Üye Ekleme Sayfası (Bottom Sheet)
// ==========================================
class _AddMemberSheet extends StatefulWidget {
  final List<Map<String, dynamic>> friends;
  final Future<void> Function(Map<String, dynamic>) onAdd;

  const _AddMemberSheet({required this.friends, required this.onAdd});

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final Set<String> _adding = {};

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(AppL10n.addMember, style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.friends.length,
              itemBuilder: (_, i) {
                final friend = widget.friends[i];
                final isAdding = _adding.contains(friend['id']);
                return ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundImage: friend['avatar_url'] != null ? NetworkImage(friend['avatar_url']) : null,
                    backgroundColor: Colors.grey[800],
                    child: friend['avatar_url'] == null ? const Icon(Icons.person, color: Colors.white54, size: 20) : null,
                  ),
                  title: Text(friend['full_name'] ?? friend['username'] ?? AppL10n.user, style: GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
                  subtitle: friend['username'] != null ? Text('@${friend['username']}', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12)) : null,
                  trailing: isAdding
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6C63FF)))
                      : GestureDetector(
                          onTap: () async {
                            setState(() => _adding.add(friend['id']));
                            try {
                              await widget.onAdd(friend);
                              if (mounted) Navigator.pop(context);
                            } catch (_) {
                              if (mounted) setState(() => _adding.remove(friend['id']));
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.4)),
                            ),
                            child: Text(AppL10n.add, style: GoogleFonts.poppins(color: const Color(0xFF6C63FF), fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
