import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../co../../../core/theme/app_colors.dart';

class ImagePreviewGallery extends StatefulWidget {
  final List<File> images;
  final Function(int) onRemove;

  const ImagePreviewGallery({
    super.key,
    required this.images,
    required this.onRemove,
  });

  @override
  State<ImagePreviewGallery> createState() => _ImagePreviewGalleryState();
}

class _ImagePreviewGalleryState extends State<ImagePreviewGallery> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 25, left: 60),
      child: Column(
        children: [
          SizedBox(
            height: 250,
            child: PageView.builder(
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.file(
                        widget.images[index],
                        height: 250,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: () {
                          widget.onRemove(index);
                          if (_currentIndex >= widget.images.length - 1 &&
                              _currentIndex > 0) {
                            setState(() {
                              _currentIndex = widget.images.length - 2;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.bgBlack.withOpacity(0.6),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                    if (widget.images.length > 1)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.bgBlack.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${index + 1}/${widget.images.length}',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          if (widget.images.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.images.length,
                  (i) => Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i == _currentIndex
                          ? AppColors.primary
                          : Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
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
