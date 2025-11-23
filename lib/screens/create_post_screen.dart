import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _textController = TextEditingController();
  File? _imageFile;
  bool _isLoading = false;

  // GÖRÜNÜRLÜK STATE'İ: 'public' veya 'friends'
  String _visibility = 'public';

  final Map<String, String> _visibilityOptions = {
    'public': 'Herkes',
    'friends': 'Arkadaşlar',
  };

  // --- FOTOĞRAF SEÇME ---
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _imageFile = File(image.path));
  }

  // --- PAYLAŞMA İŞLEMİ (SUPABASE) ---
  Future<void> _sharePost() async {
    final content = _textController.text.trim();
    if (content.isEmpty && _imageFile == null) return;

    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      String? imageUrl;

      // 1. Fotoğraf Varsa Yükle
      if (_imageFile != null) {
        final fileExt = _imageFile!.path.split('.').last;
        final fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        await Supabase.instance.client.storage
            .from('uploads')
            .uploadBinary(
          fileName,
          await _imageFile!.readAsBytes(),
          fileOptions: const FileOptions(upsert: true),
        );

        imageUrl =
            Supabase.instance.client.storage.from('uploads').getPublicUrl(fileName);
      }

      // 2. Veritabanına Kaydet (Görünürlük bilgisi dahil)
      await Supabase.instance.client.from('posts').insert({
        'user_id': userId,
        'content': content,
        'image_url': imageUrl,
        'visibility': _visibility, // GÖRÜNÜRLÜK KAYDI
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Gönderildi! 🚀"),
            backgroundColor: Color(0xFF6C63FF),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Hata: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050505),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 15, top: 10, bottom: 10),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sharePost,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: _isLoading
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : Text(
                "Paylaş",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // YAZI ALANI
            Expanded(
              child: TextField(
                controller: _textController,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 18),
                maxLines: null,
                decoration: InputDecoration(
                  hintText: "Neler düşünüyorsun?",
                  hintStyle:
                  GoogleFonts.poppins(color: Colors.white38, fontSize: 18),
                  border: InputBorder.none,
                ),
              ),
            ),

            // SEÇİLEN FOTOĞRAF ÖNİZLEMESİ
            if (_imageFile != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.file(
                      _imageFile!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 5,
                    top: 5,
                    child: GestureDetector(
                      onTap: () => setState(() => _imageFile = null),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                ],
              ),
          ],
        ),
      ),
      // ALT ARAÇ ÇUBUĞU
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white10)),
          color: Color(0xFF050505),
        ),
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // SOL: MEDYA SEÇENEKLERİ
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      FontAwesomeIcons.image,
                      color: Color(0xFF6C63FF),
                    ),
                    onPressed: _pickImage,
                  ),
                  const SizedBox(width: 15),
                  const Icon(FontAwesomeIcons.camera, color: Colors.white38),
                ],
              ),

              // SAĞ: GÖRÜNÜRLÜK SEÇENEĞİ (ToggleButtons)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ToggleButtons(
                  isSelected: [
                    _visibility == 'public',
                    _visibility == 'friends'
                  ],
                  onPressed: (int index) {
                    setState(() {
                      _visibility = index == 0 ? 'public' : 'friends';
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  selectedColor: Colors.white,
                  fillColor: const Color(0xFF6C63FF),
                  color: Colors.white54,
                  borderColor: Colors.transparent,
                  selectedBorderColor: Colors.transparent,
                  children: _visibilityOptions.entries
                      .map(
                        (entry) => Padding(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        entry.value,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
