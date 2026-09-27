import 'package:flutter/material.dart';

class AlarmWallpaperImage extends StatelessWidget {
  const AlarmWallpaperImage({super.key, required this.path, this.fit = BoxFit.cover});
  final String path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
