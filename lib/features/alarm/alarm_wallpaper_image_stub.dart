import 'package:flutter/material.dart';

final builtInGradients = <String, List<Color>>{
  'aurora':   const [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
  'sunset':   const [Color(0xFFFF512F), Color(0xFFDD2476)],
  'ocean':    const [Color(0xFF1A2980), Color(0xFF26D0CE)],
  'forest':   const [Color(0xFF134E5E), Color(0xFF71B280)],
  'midnight': const [Color(0xFF232526), Color(0xFF414345)],
  'lavender': const [Color(0xFF8360C3), Color(0xFF2EBF91)],
  'fire':     const [Color(0xFFf12711), Color(0xFFf5af19)],
  'cosmos':   const [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
  'mint':     const [Color(0xFF00B4DB), Color(0xFF0083B0)],
  'cherry':   const [Color(0xFFEB3349), Color(0xFFF45C43)],
  'ink':      const [Color(0xFF000000), Color(0xFF434343)],
  'rose':     const [Color(0xFFB76E79), Color(0xFFFFD1D1)],
};

List<Color> getWallpaperColors(String path) {
  if (path.contains('sunset')) return const [Color(0xFFE52D27), Color(0xFFB31217)];
  if (path.contains('ocean')) return const [Color(0xFF0A58CA), Color(0xFF0D6EFD)];
  return const [Color(0xFF232526), Color(0xFF414345)];
}

class AlarmWallpaperImage extends StatelessWidget {
  const AlarmWallpaperImage({super.key, required this.path, this.fit = BoxFit.cover});
  final String path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
