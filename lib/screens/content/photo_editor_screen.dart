// Kinnect - Fotoğraf Düzenleme Ekranı
// Kırpma, Döndürme, Filtreler, Renk Ayarları, Çizim ve Metin

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import '../../theme/app_colors.dart';

class PhotoEditorScreen extends StatefulWidget {
  final File imageFile;

  const PhotoEditorScreen({super.key, required this.imageFile});

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late File _currentImage;

  // Renk ayarları
  double _brightness = 0.0;
  double _contrast = 1.0;
  double _saturation = 1.0;

  // Seçili filtre
  int _selectedFilterIndex = 0;

  // Çizim
  List<DrawingPoint?> _drawingPoints = [];
  Color _drawingColor = Colors.white;
  double _brushSize = 5.0;

  // Metin
  List<TextOverlay> _textOverlays = [];

  // Global key for screenshot
  final GlobalKey _repaintKey = GlobalKey();

  bool _isProcessing = false;

  // Filtre listesi
  final List<FilterPreset> _filters = [
    FilterPreset('Normal', null),
    FilterPreset(
        'Clarendon',
        ColorFilter.matrix([
          1.2,
          0,
          0,
          0,
          10,
          0,
          1.2,
          0,
          0,
          10,
          0,
          0,
          1.2,
          0,
          10,
          0,
          0,
          0,
          1,
          0,
        ])),
    FilterPreset(
        'Moon',
        ColorFilter.matrix([
          0.33,
          0.33,
          0.33,
          0,
          0,
          0.33,
          0.33,
          0.33,
          0,
          0,
          0.33,
          0.33,
          0.33,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ])),
    FilterPreset(
        'Lark',
        ColorFilter.matrix([
          1.2,
          0,
          0,
          0,
          20,
          0,
          1.1,
          0,
          0,
          10,
          0,
          0,
          0.9,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ])),
    FilterPreset(
        'Juno',
        ColorFilter.matrix([
          1.3,
          0,
          0,
          0,
          0,
          0,
          1.1,
          0,
          0,
          0,
          0,
          0,
          0.8,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ])),
    FilterPreset(
        'Reyes',
        ColorFilter.matrix([
          1.1,
          0,
          0,
          0,
          30,
          0,
          1.0,
          0,
          0,
          20,
          0,
          0,
          0.9,
          0,
          10,
          0,
          0,
          0,
          1,
          0,
        ])),
    FilterPreset(
        'Slumber',
        ColorFilter.matrix([
          0.9,
          0,
          0.1,
          0,
          0,
          0,
          0.9,
          0.1,
          0,
          0,
          0.1,
          0.1,
          0.8,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ])),
    FilterPreset(
        'Crema',
        ColorFilter.matrix([
          1.1,
          0.1,
          0,
          0,
          20,
          0.1,
          1.0,
          0.1,
          0,
          15,
          0,
          0.1,
          0.9,
          0,
          10,
          0,
          0,
          0,
          1,
          0,
        ])),
    FilterPreset(
        'Aden',
        ColorFilter.matrix([
          0.9,
          0.1,
          0,
          0,
          20,
          0.1,
          0.9,
          0.1,
          0,
          15,
          0,
          0.1,
          0.85,
          0,
          30,
          0,
          0,
          0,
          1,
          0,
        ])),
    FilterPreset(
        'Perpetua',
        ColorFilter.matrix([
          1.0,
          0,
          0.1,
          0,
          10,
          0,
          1.0,
          0.1,
          0,
          10,
          0.1,
          0.1,
          1.1,
          0,
          20,
          0,
          0,
          0,
          1,
          0,
        ])),
    FilterPreset(
        'Valencia',
        ColorFilter.matrix([
          1.2,
          0.1,
          0,
          0,
          10,
          0.1,
          1.0,
          0,
          0,
          0,
          0,
          0,
          0.8,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ])),
    FilterPreset(
        'X-Pro II',
        ColorFilter.matrix([
          1.3,
          0,
          0,
          0,
          -20,
          0,
          1.2,
          0,
          0,
          -10,
          0,
          0,
          1.0,
          0,
          30,
          0,
          0,
          0,
          1,
          0,
        ])),
    FilterPreset(
        'Willow',
        ColorFilter.matrix([
          0.4,
          0.3,
          0.3,
          0,
          0,
          0.3,
          0.4,
          0.3,
          0,
          0,
          0.3,
          0.3,
          0.5,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ])),
    FilterPreset(
        'Lo-Fi',
        ColorFilter.matrix([
          1.5,
          0,
          0,
          0,
          -30,
          0,
          1.5,
          0,
          0,
          -30,
          0,
          0,
          1.5,
          0,
          -30,
          0,
          0,
          0,
          1,
          0,
        ])),
    FilterPreset(
        'Inkwell',
        ColorFilter.matrix([
          0.21,
          0.72,
          0.07,
          0,
          0,
          0.21,
          0.72,
          0.07,
          0,
          0,
          0.21,
          0.72,
          0.07,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ])),
  ];

  @override
  void initState() {
    super.initState();
    _currentImage = widget.imageFile;
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Kırpma işlemi
  Future<void> _cropImage() async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: _currentImage.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Kırp',
          toolbarColor: AppColors.bgBlack,
          toolbarWidgetColor: Colors.white,
          backgroundColor: AppColors.bgBlack,
          activeControlsWidgetColor: AppColors.primary,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
        IOSUiSettings(
          title: 'Kırp',
          doneButtonTitle: 'Tamam',
          cancelButtonTitle: 'İptal',
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        _currentImage = File(croppedFile.path);
      });
    }
  }

  // Renk ayarları matrisi
  ColorFilter _getAdjustmentFilter() {
    // Brightness + Contrast + Saturation combined matrix
    final double b = _brightness;
    final double c = _contrast;
    final double s = _saturation;

    // Saturation matrix coefficients
    final double sr = (1 - s) * 0.3086;
    final double sg = (1 - s) * 0.6094;
    final double sb = (1 - s) * 0.0820;

    return ColorFilter.matrix([
      c * (sr + s),
      c * sg,
      c * sb,
      0,
      b * 255,
      c * sr,
      c * (sg + s),
      c * sb,
      0,
      b * 255,
      c * sr,
      c * sg,
      c * (sb + s),
      0,
      b * 255,
      0,
      0,
      0,
      1,
      0,
    ]);
  }

  // Kaydet ve çık
  Future<void> _saveAndExit() async {
    setState(() => _isProcessing = true);

    try {
      // RepaintBoundary'den görüntü yakala
      RenderRepaintBoundary boundary = _repaintKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Geçici dosyaya kaydet
      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);

      if (mounted) {
        Navigator.pop(context, file);
      }
    } catch (e) {
      debugPrint('Kaydetme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // Metin ekleme dialogu
  void _showAddTextDialog() {
    final controller = TextEditingController();
    Color selectedColor = Colors.white;
    double fontSize = 24;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: Text('Metin Ekle',
              style: GoogleFonts.poppins(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                style: GoogleFonts.poppins(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Metni yaz...',
                  hintStyle: GoogleFonts.poppins(color: Colors.white38),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primary)),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              // Renk seçimi
              Wrap(
                spacing: 8,
                children: [
                  Colors.white,
                  Colors.black,
                  Colors.red,
                  Colors.orange,
                  Colors.yellow,
                  Colors.green,
                  Colors.blue,
                  Colors.purple,
                ]
                    .map((color) => GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedColor = color),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedColor == color
                                    ? AppColors.primary
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              // Boyut slider
              Row(
                children: [
                  Text('Boyut:',
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: fontSize,
                      min: 12,
                      max: 64,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setDialogState(() => fontSize = v),
                    ),
                  ),
                  Text('${fontSize.toInt()}',
                      style: GoogleFonts.poppins(
                          color: Colors.white70, fontSize: 12)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('İptal',
                  style: GoogleFonts.poppins(color: Colors.white38)),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    _textOverlays.add(TextOverlay(
                      text: controller.text.trim(),
                      color: selectedColor,
                      fontSize: fontSize,
                      position: const Offset(50, 50),
                    ));
                  });
                }
                Navigator.pop(ctx);
              },
              child: Text('Ekle',
                  style: GoogleFonts.poppins(
                      color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      appBar: AppBar(
        backgroundColor: AppColors.bgBlack,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Düzenle',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          _isProcessing
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  ),
                )
              : TextButton(
                  onPressed: _saveAndExit,
                  child: Text('Tamam',
                      style: GoogleFonts.poppins(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold)),
                ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.white54,
          labelStyle:
              GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.crop, size: 20), text: 'Kırp'),
            Tab(icon: Icon(Icons.tune, size: 20), text: 'Ayarlar'),
            Tab(icon: Icon(Icons.filter_vintage, size: 20), text: 'Filtreler'),
            Tab(icon: Icon(Icons.brush, size: 20), text: 'Çizim'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Fotoğraf önizleme
          Expanded(
            child: Center(
              child: RepaintBoundary(
                key: _repaintKey,
                child: GestureDetector(
                  onPanStart: _tabController.index == 3
                      ? (details) {
                          setState(() {
                            _drawingPoints.add(DrawingPoint(
                              offset: details.localPosition,
                              paint: Paint()
                                ..color = _drawingColor
                                ..strokeWidth = _brushSize
                                ..strokeCap = StrokeCap.round
                                ..isAntiAlias = true,
                            ));
                          });
                        }
                      : null,
                  onPanUpdate: _tabController.index == 3
                      ? (details) {
                          setState(() {
                            _drawingPoints.add(DrawingPoint(
                              offset: details.localPosition,
                              paint: Paint()
                                ..color = _drawingColor
                                ..strokeWidth = _brushSize
                                ..strokeCap = StrokeCap.round
                                ..isAntiAlias = true,
                            ));
                          });
                        }
                      : null,
                  onPanEnd: _tabController.index == 3
                      ? (details) {
                          setState(() {
                            _drawingPoints.add(null); // Separator
                          });
                        }
                      : null,
                  child: Stack(
                    children: [
                      // Temel fotoğraf + filtreler + ayarlar
                      ColorFiltered(
                        colorFilter: _getAdjustmentFilter(),
                        child: _filters[_selectedFilterIndex].filter != null
                            ? ColorFiltered(
                                colorFilter:
                                    _filters[_selectedFilterIndex].filter!,
                                child: Image.file(_currentImage,
                                    fit: BoxFit.contain),
                              )
                            : Image.file(_currentImage, fit: BoxFit.contain),
                      ),
                      // Çizim katmanı
                      if (_drawingPoints.isNotEmpty)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: DrawingPainter(_drawingPoints),
                          ),
                        ),
                      // Metin katmanları
                      ..._textOverlays.asMap().entries.map((entry) {
                        final index = entry.key;
                        final overlay = entry.value;
                        return Positioned(
                          left: overlay.position.dx,
                          top: overlay.position.dy,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                _textOverlays[index] = overlay.copyWith(
                                  position: Offset(
                                    overlay.position.dx + details.delta.dx,
                                    overlay.position.dy + details.delta.dy,
                                  ),
                                );
                              });
                            },
                            onLongPress: () {
                              setState(() {
                                _textOverlays.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black38,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                overlay.text,
                                style: GoogleFonts.poppins(
                                  color: overlay.color,
                                  fontSize: overlay.fontSize,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Alt kontrol paneli
          Container(
            height: 140,
            color: AppColors.bgCard,
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // TAB 1: Kırp
                _buildCropTab(),
                // TAB 2: Ayarlar
                _buildAdjustTab(),
                // TAB 3: Filtreler
                _buildFilterTab(),
                // TAB 4: Çizim
                _buildDrawTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Kırpma sekmesi
  Widget _buildCropTab() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildToolButton(Icons.crop, 'Kırp', _cropImage),
          _buildToolButton(Icons.rotate_90_degrees_ccw, 'Döndür', () {
            // Döndürme için cropper'ı aç
            _cropImage();
          }),
          _buildToolButton(Icons.text_fields, 'Metin', _showAddTextDialog),
        ],
      ),
    );
  }

  // Ayarlar sekmesi
  Widget _buildAdjustTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildSlider('Parlaklık', _brightness, -0.5, 0.5,
              (v) => setState(() => _brightness = v)),
          _buildSlider('Kontrast', _contrast, 0.5, 1.5,
              (v) => setState(() => _contrast = v)),
          _buildSlider('Doygunluk', _saturation, 0.0, 2.0,
              (v) => setState(() => _saturation = v)),
        ],
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max,
      Function(double) onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              activeColor: AppColors.primary,
              inactiveColor: Colors.white24,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // Filtreler sekmesi
  Widget _buildFilterTab() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _filters.length,
      itemBuilder: (context, index) {
        final isSelected = _selectedFilterIndex == index;
        return GestureDetector(
          onTap: () => setState(() => _selectedFilterIndex = index),
          child: Container(
            width: 70,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ColorFiltered(
                    colorFilter: _filters[index].filter ??
                        const ColorFilter.mode(
                            Colors.transparent, BlendMode.dst),
                    child: Image.file(
                      _currentImage,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _filters[index].name,
                  style: GoogleFonts.poppins(
                    color: isSelected ? AppColors.primary : Colors.white54,
                    fontSize: 9,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Çizim sekmesi
  Widget _buildDrawTab() {
    final colors = [
      Colors.white,
      Colors.black,
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.green,
      Colors.blue,
      Colors.purple,
      Colors.pink,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Renk seçimi
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: colors
                .map((color) => GestureDetector(
                      onTap: () => setState(() => _drawingColor = color),
                      child: Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _drawingColor == color
                                ? AppColors.primary
                                : Colors.white24,
                            width: _drawingColor == color ? 3 : 1,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          // Fırça boyutu + Geri al
          Row(
            children: [
              const Icon(Icons.brush, color: Colors.white54, size: 16),
              Expanded(
                child: Slider(
                  value: _brushSize,
                  min: 2,
                  max: 20,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _brushSize = v),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.undo, color: Colors.white70),
                onPressed: () {
                  if (_drawingPoints.isNotEmpty) {
                    setState(() {
                      // Son çizgiyi sil
                      int lastNull = _drawingPoints.lastIndexOf(null);
                      if (lastNull > 0) {
                        _drawingPoints = _drawingPoints.sublist(0, lastNull);
                      } else {
                        _drawingPoints.clear();
                      }
                    });
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white70),
                onPressed: () => setState(() => _drawingPoints.clear()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

// Veri modelleri
class FilterPreset {
  final String name;
  final ColorFilter? filter;

  FilterPreset(this.name, this.filter);
}

class DrawingPoint {
  final Offset offset;
  final Paint paint;

  DrawingPoint({required this.offset, required this.paint});
}

class TextOverlay {
  final String text;
  final Color color;
  final double fontSize;
  final Offset position;

  TextOverlay({
    required this.text,
    required this.color,
    required this.fontSize,
    required this.position,
  });

  TextOverlay copyWith({
    String? text,
    Color? color,
    double? fontSize,
    Offset? position,
  }) {
    return TextOverlay(
      text: text ?? this.text,
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
      position: position ?? this.position,
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPoint?> points;

  DrawingPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(
          points[i]!.offset,
          points[i + 1]!.offset,
          points[i]!.paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}
