import 'dart:io';

import 'package:flutter/material.dart';

class AlarmWallpaperImage extends StatelessWidget {
  const AlarmWallpaperImage({super.key, required this.path, this.fit = BoxFit.cover});
  final String path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => Image.file(
      File(path),
      fit: fit,
      cacheWidth: 1440,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
}
