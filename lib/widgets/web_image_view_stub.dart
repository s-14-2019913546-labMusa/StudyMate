import 'package:flutter/material.dart';

Widget buildPlatformImageView({
  required String imageUrl,
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  VoidCallback? onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          width: width ?? 200,
          height: height ?? 160,
          color: Colors.grey.withValues(alpha: 0.1),
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stack) => Container(
        width: width ?? 200,
        height: height ?? 160,
        color: Colors.grey.withValues(alpha: 0.15),
        child: const Center(
          child: Icon(Icons.broken_image_rounded, size: 36, color: Colors.grey),
        ),
      ),
    ),
  );
}
