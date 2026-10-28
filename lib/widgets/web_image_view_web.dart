// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

final Set<String> _registeredViews = {};

Widget buildPlatformImageView({
  required String imageUrl,
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  VoidCallback? onTap,
}) {
  final viewType = 'chat-img-${imageUrl.hashCode.abs()}';

  if (!_registeredViews.contains(viewType)) {
    _registeredViews.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final img = html.ImageElement();
      img.src = imageUrl;
      img.style.width = '100%';
      img.style.height = '100%';
      img.style.objectFit = 'cover';
      img.style.borderRadius = '8px';
      img.style.cursor = 'pointer';
      img.onClick.listen((_) {
        if (onTap != null) onTap();
      });
      return img;
    });
  }

  return SizedBox(
    width: width ?? 220,
    height: height ?? 180,
    child: Stack(
      children: [
        HtmlElementView(viewType: viewType),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
            ),
          ),
        ),
      ],
    ),
  );
}
