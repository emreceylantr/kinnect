import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> currentProfile;

  const EditProfileScreen({super.key, required this.currentProfile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();

  bool _isLoading = false;
  File? _imageFile; // Yeni seçilen resim dosyası

  @override
  void initState() {
    super.initState();
    // Mevcut verileri kutulara doldur
    _nameController.text = widget.currentProfile['full_name'] ?? '';
    _usernameController.text = widget.currentProfile['username'] ?? '';
    _bioController.text = widget.currentProfile['bio'] ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // --- RESİM SEÇME ---
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
      });
    }
  }

  // --- KAYDETME İŞLEMİ ---
  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    final userId = Supabase.instance.client.auth.currentUser!.id;

    try {
      String? avatarUrl = widget.currentProfile['avatar_url'];

      // 1. Yeni resim seçildiyse YÜKLE
      if (_imageFile != null) {
        final fileExt = _imageFile!.path.split('.').last;
        final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = 'avatars/$fileName';

        await Supabase.instance.client.storage.from('uploads').upload(filePath, _imageFile!);
        avatarUrl = Supabase.instance.client.storage.from('uploads').getPublicUrl(filePath);
      }

      // 2. Veritabanını GÜNCELLE
      await Supabase.instance.client.from('profiles').update({
        'full_name': _nameController.text.trim(),
        'username': _usernameController.text.trim(), // Benzersizlik kontrolü veritabanında yapılır
        'bio': _bioController.text.trim(),
        'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil güncellendi!')));
        Navigator.pop(context, true); // Geri dön ve sayfayı yenile sinyali ver (true)
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mevcut profil resmi (Yeni seçilen varsa onu göster, yoksa eskisini)
    final currentAvatarUrl = widget.currentProfile['avatar_url'];
    ImageProvider? bgImage;

    if (_imageFile != null) {
      bgImage = FileImage(_imageFile!);
    } else if (currentAvatarUrl != null) {
      bgImage = NetworkImage(currentAvatarUrl);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: const BackButton(color: Colors.white),
        title: Text('Profili Düzenle', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? const SizedBox(height: 15, width: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Kaydet', style: GoogleFonts.poppins(color: const Color(0xFF6C63FF), fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --- PROFİL FOTOĞRAFI DEĞİŞTİRME ---
            GestureDetector(
              onTap: _pickImage,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFF1F1F1F),
                    backgroundImage: bgImage,
                    child: bgImage == null ? const Icon(Icons.person, size: 50, color: Colors.white54) : null,
                  ),
                  const SizedBox(height: 10),
                  Text('Fotoğrafı Değiştir', style: GoogleFonts.poppins(color: const Color(0xFF6C63FF), fontWeight: FontWeight.w600)),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- FORMLAR ---
            _buildTextField("Adın", _nameController),
            const SizedBox(height: 20),
            _buildTextField("Kullanıcı Adı", _usernameController),
            const SizedBox(height: 20),
            _buildTextField("Biyografi", _bioController, maxLines: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: GoogleFonts.poppins(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1A1A1A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}