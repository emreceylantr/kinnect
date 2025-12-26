// Kinnect - Yeni gönderi oluşturma

import 'dart:io';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'photo_tag_screen.dart'; // 🆕 Fotoğrafa kişi etiketleme
import 'music_picker_screen.dart'; // 🌵 Spotify müzik ekle

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final String _currentUserId = Supabase.instance.client.auth.currentUser!.id;

  File? _imageFile;
  List<File> _imageFiles = [];
  int _currentImageIndex = 0;
  bool _isLoading = false;
  String _visibility = 'public';
  String? _avatarUrl;
  String _currentHint = "";

  // 🆕 Fotoğrafa etiketlenen kişiler
  List<Map<String, dynamic>> _photoTags = [];

  // 🎧 Müzik bilgileri
  Map<String, dynamic>? _selectedMusic;

  // 📍 Konum bilgisi
  String? _location;
  bool _isGettingLocation = false;

  // --- ANİMASYON STATE'LERİ ---
  bool _isShareButtonPressed = false;
  double _hintOpacity = 0.0;

  late AnimationController _auroraController;

  // 🔥 ORTALANACAK KISA SÖZLER
  final Set<String> _centeredHints = {
    "Neler düşünüyorsun?",
    "Bugün nasılsın?",
    "Aklında ne var?",
    "Nasıl hissediyorsun?",
    "Günün nasıl geçti?",
    "Ne paylaşsam acaba…",
    "Kendime bir not bırakıyorum.",
    "Dur bak şimdi bir şey paylaşacağım…",
    "Takipçilerine bir mesajın var mı?",
    "İlham verici bir şeyler yaz...",
    "Paylaşmak istediğin bir şey mi var?",
  };

  // 🔥 TÜM LİSTE
  final List<String> _hintList = [
    "Neler düşünüyorsun?",
    "Bugün nasılsın?",
    "Aklında ne var?",
    "Nasıl hissediyorsun?",
    "Günün nasıl geçti?",
    "Ne paylaşsam acaba…",
    "Kendime bir not bırakıyorum.",
    "Dur bak şimdi bir şey paylaşacağım…",
    "Takipçilerine bir mesajın var mı?",
    "İlham verici bir şeyler yaz...",
    "Paylaşmak istediğin bir şey mi var?",
    "Bir şey yazacaktım… unuttum. Neyse yazıyorum.",
    "Düşündüğüm bazı şeyleri paylaşmam gerekiyor sanki.",
    "Buraya düşüncelerimden bir parça bırakıyorum.",
    "Bugün biraz fazla iyi görünüyorum, paylaşayım dedim 👀",
    "Şimdi öyle bir şey paylaşacağım ki… biri üstüne alınacak.",
    "Post seçmek bu kadar zorsa, kod yazmayı düşünemiyorum bile… kahve getiriyorum.",
    "Developerlarımız kadar yorulmadım ama post seçerken bile enerji tükendi, kahve şart."
  ];

  @override
  void initState() {
    super.initState();
    _fetchMyAvatar();
    _setRandomHint();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _hintOpacity = 1.0;
        });
      }
    });

    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  void _setRandomHint() {
    setState(() {
      _currentHint = _hintList[Random().nextInt(_hintList.length)];
    });
  }

  Future<void> _fetchMyAvatar() async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('avatar_url')
          .eq('id', _currentUserId)
          .single();
      if (mounted) {
        setState(() {
          _avatarUrl = data['avatar_url'];
        });
      }
    } catch (_) {}
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();

    if (source == ImageSource.gallery) {
      final List<XFile> images = await picker.pickMultiImage(imageQuality: 70);
      if (images.isNotEmpty && mounted) {
        final files = images.map((img) => File(img.path)).toList();

        // İlk fotoğraf için etiketleme ekranına git
        if (_imageFiles.isEmpty && files.isNotEmpty) {
          final tags = await Navigator.push<List<Map<String, dynamic>>>(
            context,
            MaterialPageRoute(
              builder: (_) => PhotoTagScreen(imageFile: files.first),
            ),
          );
          if (mounted) {
            setState(() {
              _imageFiles = [..._imageFiles, ...files].take(10).toList();
              _photoTags = tags ?? [];
            });
          }
        } else {
          setState(() {
            _imageFiles = [..._imageFiles, ...files].take(10).toList();
          });
        }
      }
    } else {
      final XFile? image =
      await picker.pickImage(source: source, imageQuality: 70);
      if (image != null && mounted) {
        final file = File(image.path);

        if (_imageFiles.isEmpty) {
          final tags = await Navigator.push<List<Map<String, dynamic>>>(
            context,
            MaterialPageRoute(
              builder: (_) => PhotoTagScreen(imageFile: file),
            ),
          );
          if (mounted) {
            setState(() {
              _imageFiles.add(file);
              _photoTags = tags ?? [];
            });
          }
        } else if (_imageFiles.length < 10) {
          setState(() => _imageFiles.add(file));
        }
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imageFiles.removeAt(index);
      if (_currentImageIndex >= _imageFiles.length && _imageFiles.isNotEmpty) {
        _currentImageIndex = _imageFiles.length - 1;
      }
    });
  }

  Future<void> _sharePost() async {
    if (_isLoading) return;
    final content = _textController.text.trim();
    if (content.isEmpty && _imageFiles.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      List<String> imageUrls = [];

      for (int i = 0; i < _imageFiles.length; i++) {
        final file = _imageFiles[i];
        final fileExt = file.path.split('.').last;
        final fileName =
            '$_currentUserId/${DateTime.now().millisecondsSinceEpoch}_$i.$fileExt';

        await Supabase.instance.client.storage.from('uploads').uploadBinary(
          fileName,
          await file.readAsBytes(),
          fileOptions: const FileOptions(upsert: true),
        );

        final url = Supabase.instance.client.storage
            .from('uploads')
            .getPublicUrl(fileName);
        imageUrls.add(url);
      }

      final postResponse = await Supabase.instance.client
          .from('posts')
          .insert({
        'user_id': _currentUserId,
        'content': content,
        'image_url': imageUrls.isNotEmpty ? imageUrls.first : null,
        'image_urls': imageUrls.isNotEmpty ? imageUrls : null,
        'visibility': _visibility,
        // 🎧 Müzik bilgileri
        if (_selectedMusic != null) ...{
          'spotify_track_id': _selectedMusic!['id'],
          'spotify_track_name': _selectedMusic!['name'],
          'spotify_artist_name': _selectedMusic!['artist'],
          'spotify_preview_url': _selectedMusic!['preview_url'],
          'spotify_album_image': _selectedMusic!['album_image'],
        },
        // 📍 Konum
        'location': _location,
      })
          .select('id')
          .single();

      final postId = postResponse['id'];

      // 🆕 Etiketleri kaydet
      if (_photoTags.isNotEmpty && imageUrls.isNotEmpty) {
        for (final tag in _photoTags) {
          try {
            await Supabase.instance.client.from('post_tags').insert({
              'post_id': postId,
              'tagged_user_id': tag['user']['id'],
              'x_position': tag['x'],
              'y_position': tag['y'],
            });

            // Etiketlenen kişiye bildirim gönder
            await Supabase.instance.client.from('notifications').insert({
              'user_id': tag['user']['id'],
              'actor_id': _currentUserId,
              'type': 'tag',
              'post_id': postId,
              'is_read': false,
            });

            // 🔔 PUSH BİLDİRİM GÖNDER
            try {
              final myProfile = await Supabase.instance.client
                  .from('profiles')
                  .select('username')
                  .eq('id', _currentUserId)
                  .single();
              final username = myProfile['username'] ?? 'Birisi';

              await Supabase.instance.client.functions
                  .invoke('send-push-notification', body: {
                'target_user_id': tag['user']['id'],
                'title': '📸 Fotoğrafta Etiketlendin!',
                'body': '$username seni bir fotoğrafta etiketledi',
                'type': 'tag',
                'target_id': postId,
              });
            } catch (_) {}
          } catch (_) {}
        }
      }

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
              content: Text("Hata: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 📍 KONUM ALMA FONKSİYONU
  Future<void> _getLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // 1. Servis açık mı?
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Konum servisi kapalı.';
      }

      // 2. İzin kontrolü
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Konum izni reddedildi.';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Konum izni kalıcı olarak reddedildi, ayarlardan açmalısın.';
      }

      // 3. Konumu al
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      // 4. Adrese çevir
      List<Placemark> placemarks =
      await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        // Örn: "Kadıköy, İstanbul" veya "Beşiktaş"
        String loc = "";
        if (place.subAdministrativeArea != null) {
          loc = place.subAdministrativeArea!;
        } else if (place.locality != null) {
          loc = place.locality!;
        }

        if (place.administrativeArea != null &&
            place.administrativeArea != loc) {
          if (loc.isNotEmpty) loc += ", ";
          loc += place.administrativeArea!;
        }

        setState(() => _location = loc);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Hata: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  // 📍 KONUM SEÇİCİ
  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Konum Ekle",
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // Seçenek 1: Mevcut Konum
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.2),
                    shape: BoxShape.circle),
                child:
                const Icon(Icons.my_location, color: Colors.orangeAccent),
              ),
              title: Text("Şu anki konumu bul",
                  style: GoogleFonts.poppins(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _getLocation();
              },
            ),

            // Seçenek 2: Elle Gir
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.2),
                    shape: BoxShape.circle),
                child: const Icon(Icons.edit_location_alt,
                    color: Color(0xFF6C63FF)),
              ),
              title: Text("Elle konum gir",
                  style: GoogleFonts.poppins(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _showManualLocationDialog();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ✍️ ELLE KONUM GİRİŞİ
  void _showManualLocationDialog() {
    final TextEditingController locController =
    TextEditingController(text: _location);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title:
        Text("Konum Yaz", style: GoogleFonts.poppins(color: Colors.white)),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: locController,
                style: GoogleFonts.poppins(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Örn: Kadıköy, İstanbul",
                  hintStyle: GoogleFonts.poppins(color: Colors.white38),
                  enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF6C63FF))),
                ),
                autofocus: true,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.search, color: Color(0xFF6C63FF)),
              onPressed: () async {
                if (locController.text.trim().isEmpty) return;
                try {
                  List<Location> locations =
                  await locationFromAddress(locController.text);
                  if (locations.isNotEmpty) {
                    List<Placemark> placemarks = await placemarkFromCoordinates(
                        locations.first.latitude, locations.first.longitude);
                    if (placemarks.isNotEmpty) {
                      final p = placemarks.first;
                      String newLoc = "";
                      if (p.locality != null) newLoc += p.locality!;
                      if (p.administrativeArea != null) {
                        if (newLoc.isNotEmpty) newLoc += ", ";
                        newLoc += p.administrativeArea!;
                      }
                      locController.text = newLoc;
                    }
                  }
                } catch (e) {
                  debugPrint("Konum bulma hatası: $e");
                }
              },
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("İptal",
                style: GoogleFonts.poppins(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              setState(() => _location = locController.text.trim());
              Navigator.pop(ctx);
            },
            child: Text("Tamam",
                style: GoogleFonts.poppins(
                    color: const Color(0xFF6C63FF),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _auroraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 DÜZELTME: Yazı boyutu 16'ya çekildi (Daha dengeli)
    final TextStyle commonTextStyle =
    GoogleFonts.poppins(color: Colors.white, fontSize: 16, height: 1.5);

    final TextStyle hintTextStyle =
    commonTextStyle.copyWith(color: Colors.white54);

    // 🔥 HİZALAMA MATEMATİĞİ:
    // Avatar (Radius 22) => Height 44px
    // Yazı (Font 16 * 1.5) => Height 24px
    // Fark = 20px. Ortalamak için üstten 10px boşluk gerekir.
    final double topPadding =
    _centeredHints.contains(_currentHint) ? 10.0 : 0.0;

    final bool showAurora = _textController.text.isEmpty && _imageFile == null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. AURORA
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: showAurora ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 2000),
              curve: Curves.easeInOut,
              child: AnimatedBuilder(
                animation: _auroraController,
                builder: (context, child) {
                  final double t = _auroraController.value;
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1.0 + t * 0.5, -1.0),
                        end: Alignment(1.0 - t * 0.5, 1.0),
                        colors: [
                          Color.lerp(Colors.black, const Color(0xFF004D40), t)!,
                          Color.lerp(const Color(0xFF1A237E),
                              const Color(0xFF311B92), t)!,
                          Color.lerp(Colors.black, const Color(0xFF4A148C), t)!,
                        ],
                        stops: [0.0 + t * 0.2, 0.5, 1.0 - t * 0.2],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 2. İÇERİK
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 70), // Üst bar boşluğu

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 🔥 DÜZELTME: Avatarın üzerindeki fazlalık padding kaldırıldı
                            CircleAvatar(
                              radius: 22, // Standart boyut
                              backgroundColor: const Color(0xFF1F1F1F),
                              backgroundImage: _avatarUrl != null
                                  ? NetworkImage(_avatarUrl!)
                                  : null,
                              child: _avatarUrl == null
                                  ? const Icon(Icons.person,
                                  color: Colors.white54)
                                  : null,
                            ),
                            const SizedBox(width: 15),

                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(top: topPadding),
                                child: Stack(
                                  alignment: Alignment.topLeft,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.zero,
                                      child: AnimatedOpacity(
                                        opacity: _textController.text.isEmpty
                                            ? _hintOpacity
                                            : 0.0,
                                        duration:
                                        const Duration(milliseconds: 800),
                                        curve: Curves.easeOut,
                                        child: Text(
                                          _currentHint,
                                          style: hintTextStyle,
                                          maxLines: null,
                                        ),
                                      ),
                                    ),
                                    TextField(
                                      controller: _textController,
                                      style: commonTextStyle,
                                      maxLines: null,
                                      cursorColor: const Color(0xFF6C63FF),
                                      onChanged: (val) => setState(() {}),
                                      decoration: const InputDecoration(
                                        hintText: null,
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_imageFiles.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 25, left: 60),
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 250,
                                  child: PageView.builder(
                                    itemCount: _imageFiles.length,
                                    onPageChanged: (i) =>
                                        setState(() => _currentImageIndex = i),
                                    itemBuilder: (context, index) {
                                      return Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                            BorderRadius.circular(20),
                                            child: Image.file(
                                              _imageFiles[index],
                                              height: 250,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          Positioned(
                                            top: 10,
                                            right: 10,
                                            child: GestureDetector(
                                              onTap: () => _removeImage(index),
                                              child: Container(
                                                padding:
                                                const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withOpacity(0.6),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                      color: Colors.white24,
                                                      width: 1),
                                                ),
                                                child: const Icon(Icons.close,
                                                    color: Colors.white,
                                                    size: 18),
                                              ),
                                            ),
                                          ),
                                          if (_imageFiles.length > 1)
                                            Positioned(
                                              top: 10,
                                              left: 10,
                                              child: Container(
                                                padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withOpacity(0.6),
                                                  borderRadius:
                                                  BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  '${index + 1}/${_imageFiles.length}',
                                                  style: GoogleFonts.poppins(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                      FontWeight.w600),
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                if (_imageFiles.length > 1)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.center,
                                      children: List.generate(
                                        _imageFiles.length,
                                            (i) => Container(
                                          width: 6,
                                          height: 6,
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 2),
                                          decoration: BoxDecoration(
                                            color: i == _currentImageIndex
                                                ? const Color(0xFF6C63FF)
                                                : Colors.white.withOpacity(0.3),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        // 🎧 Seçilen Müzik Gösterimi
                        if (_selectedMusic != null)
                          Padding(
                            padding: const EdgeInsets.only(
                                top: 15, left: 60, right: 20),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFC3C44)
                                    .withOpacity(0.15), // Apple Music Red
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                  const Color(0xFFFC3C44).withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Album art
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: _selectedMusic!['album_image'] !=
                                        null
                                        ? Image.network(
                                      _selectedMusic!['album_image'],
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                    )
                                        : Container(
                                      width: 44,
                                      height: 44,
                                      color: Colors.grey[800],
                                      child: const Icon(Icons.music_note,
                                          color: Colors.white54),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Track info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedMusic!['name'] ?? 'Şarkı',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          _selectedMusic!['artist'] ??
                                              'Sanatçı',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Kaldır butonu
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _selectedMusic = null),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close,
                                          color: Colors.white54, size: 16),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. ÜST BAR (FLOATING)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // KAPAT BUTONU
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.1)),
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ),

                    // GİZLİLİK SEÇİMİ
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              _buildVisibilityOption('public', 'Herkes'),
                              const SizedBox(width: 4),
                              _buildVisibilityOption('friends', 'Arkadaşlar'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. ALT BAR (PAYLAŞ VE MEDYA)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 30, left: 16, right: 16),
              height: 70,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(35),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    // 🔥 DEĞİŞİKLİK 1: Padding azaltıldı (24 -> 16).
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E).withOpacity(0.7),
                      borderRadius: BorderRadius.circular(35),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.image_outlined,
                              color: Colors.greenAccent, size: 28),
                          tooltip: 'Galeri',
                          padding: EdgeInsets.zero, // Sıkıştırıldı
                          constraints: const BoxConstraints(),
                        ),
                        // 🔥 DEĞİŞİKLİK 2: Boşluklar arttırıldı (6 -> 12)
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined,
                              color: Colors.blueAccent, size: 28),
                          tooltip: 'Kamera',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 12),
                        // 🎧 Müzik Butonu - GÜNCELLENDİ (Outlined Double Note)
                        IconButton(
                          onPressed: () async {
                            final music =
                            await Navigator.push<Map<String, dynamic>>(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const MusicPickerScreen()),
                            );
                            if (music != null) {
                              setState(() => _selectedMusic = music);
                            }
                          },
                          icon: const Icon(
                            // 🔥 Tam olarak "Çift başlı, içi boş nota" budur
                            Icons.audiotrack_outlined,
                            color: Color(0xFF6C63FF),
                            size: 28,
                          ),
                          tooltip: 'Müzik Ekle',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 12),
                        // 📍 Konum Butonu - GÜNCELLENDİ (Outlined Pin)
                        IconButton(
                          onPressed: _showLocationPicker,
                          icon: _isGettingLocation
                              ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.orangeAccent,
                                  strokeWidth: 2))
                              : const Icon(
                            Icons.location_on_outlined, // İçi boş pin
                            color: Colors.orangeAccent,
                            size: 28,
                          ),
                          tooltip: 'Konum Ekle',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),

                        // 🔥 ÖNEMLİ DEĞİŞİKLİK: Spacer()
                        // Bu widget, ikonlarla buton arasındaki tüm boşluğu doldurur.
                        // Böylece ikonlar sola, buton sağa yaslanır.
                        const Spacer(),

                        GestureDetector(
                          onTapDown: (_) =>
                              setState(() => _isShareButtonPressed = true),
                          onTapUp: (_) {
                            setState(() => _isShareButtonPressed = false);
                            if (!_isLoading) _sharePost();
                          },
                          onTapCancel: () =>
                              setState(() => _isShareButtonPressed = false),
                          child: AnimatedScale(
                            scale: _isShareButtonPressed ? 0.95 : 1.0,
                            duration: const Duration(milliseconds: 100),
                            curve: Curves.easeInOut,
                            child: Container(
                              height: 42,
                              padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF6C63FF),
                                    Color(0xFF448AFF),
                                    Color(0xFF69F0AE)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(21),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6C63FF)
                                        .withOpacity(0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2))
                                    : Text("Paylaş",
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Colors.white)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityOption(String value, String label) {
    final isSelected = _visibility == value;
    return GestureDetector(
      onTap: () => setState(() => _visibility = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C63FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.white : Colors.grey[400],
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}