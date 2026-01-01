import 'package:flutter/material.dart';

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
