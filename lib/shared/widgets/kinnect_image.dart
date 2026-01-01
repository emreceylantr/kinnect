import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class KinnectImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final bool isCircle;
  final Color? backgroundColor;

  /// Eğer true ise shimmer efekti gösterilir. False ise basit bir CircularProgressIndicator.
  final bool useShimmer;

  const KinnectImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.isCircle = false,
    this.backgroundColor,
    this.useShimmer = true,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildErrorPlaceholder();
    }

    final imageWidget = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: (width != null && width!.isFinite)
          ? (width! * 2).toInt()
          : null, // Optimizasyon
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) => _buildErrorPlaceholder(),
      fadeInDuration: const Duration(milliseconds: 300),
    );

    if (isCircle) {
      return ClipOval(child: imageWidget);
    }

    if (borderRadius > 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildPlaceholder() {
    if (!useShimmer) {
      return Container(
        width: width,
        height: height,
        color: backgroundColor ?? Colors.grey[900],
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Shimmer.fromColors(
      baseColor: Colors.grey[900]!,
      highlightColor: Colors.grey[800]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.black,
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isCircle ? null : BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey[900],
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Colors.white24,
        size: (width != null && width! < 50) ? 16 : 24,
      ),
    );
  }
}
