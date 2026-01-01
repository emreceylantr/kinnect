import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../models/photo_editor_models.dart';

class CropTab extends StatelessWidget {
  final VoidCallback onCrop;
  final VoidCallback onRotate;
  final VoidCallback onAddText;

  const CropTab({
    super.key,
    required this.onCrop,
    required this.onRotate,
    required this.onAddText,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolButton(icon: Icons.crop, label: 'Kırp', onTap: onCrop),
          _ToolButton(
              icon: Icons.rotate_90_degrees_ccw,
              label: 'Döndür',
              onTap: onRotate),
          _ToolButton(
              icon: Icons.text_fields, label: 'Metin', onTap: onAddText),
        ],
      ),
    );
  }
}

class AdjustTab extends StatelessWidget {
  final double brightness;
  final double contrast;
  final double saturation;
  final Function(double) onBrightnessChanged;
  final Function(double) onContrastChanged;
  final Function(double) onSaturationChanged;

  const AdjustTab({
    super.key,
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.onBrightnessChanged,
    required this.onContrastChanged,
    required this.onSaturationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _AdjustSlider(
              label: 'Parlaklık',
              value: brightness,
              min: -0.5,
              max: 0.5,
              onChanged: onBrightnessChanged),
          _AdjustSlider(
              label: 'Kontrast',
              value: contrast,
              min: 0.5,
              max: 1.5,
              onChanged: onContrastChanged),
          _AdjustSlider(
              label: 'Doygunluk',
              value: saturation,
              min: 0.0,
              max: 2.0,
              onChanged: onSaturationChanged),
        ],
      ),
    );
  }
}

class FilterTab extends StatelessWidget {
  final List<FilterPreset> filters;
  final int selectedFilterIndex;
  final File currentImage;
  final Function(int) onFilterSelected;

  const FilterTab({
    super.key,
    required this.filters,
    required this.selectedFilterIndex,
    required this.currentImage,
    required this.onFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: filters.length,
      itemBuilder: (context, index) {
        final isSelected = selectedFilterIndex == index;
        return GestureDetector(
          onTap: () => onFilterSelected(index),
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
                    colorFilter: filters[index].filter ??
                        const ColorFilter.matrix([
                          1,
                          0,
                          0,
                          0,
                          0,
                          0,
                          1,
                          0,
                          0,
                          0,
                          0,
                          0,
                          1,
                          0,
                          0,
                          0,
                          0,
                          0,
                          1,
                          0,
                        ]),
                    child: Image.file(
                      currentImage,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  filters[index].name,
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
}

class DrawTab extends StatelessWidget {
  final Color drawingColor;
  final double brushSize;
  final Function(Color) onColorChanged;
  final Function(double) onBrushSizeChanged;
  final VoidCallback onUndo;
  final VoidCallback onClear;

  const DrawTab({
    super.key,
    required this.drawingColor,
    required this.brushSize,
    required this.onColorChanged,
    required this.onBrushSizeChanged,
    required this.onUndo,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: colors
                .map((color) => GestureDetector(
                      onTap: () => onColorChanged(color),
                      child: Container(
                        width: 28,
                        height: 28,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: drawingColor == color
                                ? AppColors.primary
                                : Colors.white24,
                            width: drawingColor == color ? 3 : 1,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.brush, color: Colors.white54, size: 16),
              Expanded(
                child: Slider(
                  value: brushSize,
                  min: 2,
                  max: 20,
                  activeColor: AppColors.primary,
                  onChanged: onBrushSizeChanged,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.undo, color: Colors.white70),
                onPressed: onUndo,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white70),
                onPressed: onClear,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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

class _AdjustSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final Function(double) onChanged;

  const _AdjustSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
}
