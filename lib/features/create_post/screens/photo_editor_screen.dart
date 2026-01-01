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
import '../../../core/theme/app_colors.dart';
import '../models/photo_editor_models.dart';
import '../widgets/drawing_painter.dart';
import '../widgets/photo_editor_tabs.dart';

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
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(8),
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
    return CropTab(
      onCrop: _cropImage,
      onRotate: _cropImage, // Döndürme için de cropper kullanılıyor
      onAddText: _showAddTextDialog,
    );
  }

  // Ayarlar sekmesi
  Widget _buildAdjustTab() {
    return AdjustTab(
      brightness: _brightness,
      contrast: _contrast,
      saturation: _saturation,
      onBrightnessChanged: (v) => setState(() => _brightness = v),
      onContrastChanged: (v) => setState(() => _contrast = v),
      onSaturationChanged: (v) => setState(() => _saturation = v),
    );
  }

  // Filtreler sekmesi
  Widget _buildFilterTab() {
    return FilterTab(
      filters: _filters,
      selectedFilterIndex: _selectedFilterIndex,
      currentImage: _currentImage,
      onFilterSelected: (index) => setState(() => _selectedFilterIndex = index),
    );
  }

  // Çizim sekmesi
  Widget _buildDrawTab() {
    return DrawTab(
      drawingColor: _drawingColor,
      brushSize: _brushSize,
      onColorChanged: (color) => setState(() => _drawingColor = color),
      onBrushSizeChanged: (v) => setState(() => _brushSize = v),
      onUndo: () {
        if (_drawingPoints.isNotEmpty) {
          setState(() {
            int lastNull = _drawingPoints.lastIndexOf(null);
            if (lastNull > 0) {
              _drawingPoints = _drawingPoints.sublist(0, lastNull);
            } else {
              _drawingPoints.clear();
            }
          });
        }
      },
      onClear: () => setState(() => _drawingPoints.clear()),
    );
  }
}
