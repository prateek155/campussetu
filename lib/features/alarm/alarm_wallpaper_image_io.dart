import 'dart:io';

import 'package:flutter/material.dart';
import 'package:rive/rive.dart' hide LinearGradient, Image; // hide to avoid ambiguous imports
import 'package:video_player/video_player.dart';

// ── Path encoding helpers ─────────────────────────────────────────────────────
bool _isBuiltIn(String path) => path.startsWith('__builtin__:');
bool _isAssetImg(String path) => path.startsWith('__asset_img__:');
bool _isAssetRive(String path) => path.startsWith('__asset_rive__:');
bool _isAssetVideo(String path) => path.startsWith('__asset_video__:');

String _stripPrefix(String path) => path.substring(path.indexOf(':') + 1);
String _builtInId(String path) => path.replaceFirst('__builtin__:', '');

// Must stay in sync with _gradientWallpapers in alarm_screen.dart
final _builtInGradients = <String, List<Color>>{
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

/// Main wallpaper widget — auto-detects path type and renders accordingly.
class AlarmWallpaperImage extends StatelessWidget {
  const AlarmWallpaperImage({super.key, required this.path, this.fit = BoxFit.cover});
  final String path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    // 1️⃣ Built-in gradient
    if (_isBuiltIn(path)) {
      final colors = _builtInGradients[_builtInId(path)] ??
          const [Color(0xFF232526), Color(0xFF414345)];
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
    }

    // 2️⃣ Asset image (JPG/PNG bundled in APK)
    if (_isAssetImg(path)) {
      return Image.asset(
        _stripPrefix(path),
        fit: fit,
        errorBuilder: (_, __, ___) => const _FallbackBg(),
      );
    }

    // 3️⃣ Rive animated wallpaper
    if (_isAssetRive(path)) {
      return _RiveWallpaper(assetPath: _stripPrefix(path));
    }

    // 4️⃣ Video wallpaper (looping, muted)
    if (_isAssetVideo(path)) {
      return _VideoWallpaper(assetPath: _stripPrefix(path));
    }

    // 5️⃣ Custom user-picked file
    return Image.file(
      File(path),
      fit: fit,
      cacheWidth: 1440,
      errorBuilder: (_, __, ___) => const _FallbackBg(),
    );
  }
}

// ── Rive animated wallpaper ───────────────────────────────────────────────────
class _RiveWallpaper extends StatelessWidget {
  const _RiveWallpaper({required this.assetPath});
  final String assetPath;

  @override
  Widget build(BuildContext context) => RiveAnimation.asset(
    assetPath,
    fit: BoxFit.cover,
    // animations play automatically by default in Rive
  );
}

// ── Video wallpaper (looping, muted) ─────────────────────────────────────────
class _VideoWallpaper extends StatefulWidget {
  const _VideoWallpaper({required this.assetPath});
  final String assetPath;

  @override
  State<_VideoWallpaper> createState() => _VideoWallpaperState();
}

class _VideoWallpaperState extends State<_VideoWallpaper> {
  late VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.assetPath)
      ..initialize().then((_) {
        if (!mounted) return;
        _controller
          ..setLooping(true)
          ..setVolume(0) // always muted — alarm sound is separate
          ..play();
        setState(() => _ready = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const _FallbackBg();
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _controller.value.size.width,
        height: _controller.value.size.height,
        child: VideoPlayer(_controller),
      ),
    );
  }
}

// ── Fallback background ───────────────────────────────────────────────────────
class _FallbackBg extends StatelessWidget {
  const _FallbackBg();
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF232526), Color(0xFF414345)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  );
}
