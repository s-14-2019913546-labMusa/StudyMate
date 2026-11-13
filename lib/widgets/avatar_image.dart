import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

/// Image for a user's avatar from the `photoUrl` field.
///
/// * `http(s)` URL → cached network image (works for friends too).
/// * Local file path → only if the file exists on this phone (another
///   user's local path from an old app version would otherwise throw).
/// * Anything else / empty → null, so the caller shows its fallback icon.
ImageProvider? avatarImageProvider(String? photoUrl) {
  if (photoUrl == null || photoUrl.isEmpty) return null;
  if (photoUrl.startsWith('http')) return CachedNetworkImageProvider(photoUrl);
  try {
    final f = File(photoUrl);
    if (f.existsSync()) return FileImage(f);
  } catch (_) {}
  return null;
}
