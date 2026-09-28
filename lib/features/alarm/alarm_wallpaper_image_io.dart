import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart' hide LinearGradient, Image; // hide to avoid ambiguous imports
import 'package:video_player/video_player.dart';

// ── Path encoding helpers ─────────────────────────────────────────────────────
bool _isBuiltIn(String path) => path.startsWith('__builtin__:');
bool _isAssetImg(String path) => path.startsWith('__asset_img__:');
bool _isAssetRive(String path) => path.startsWith('__asset_rive__:');
bool _isAssetVideo(String path) => path.startsWith('__asset_video__:');
bool _isRemoteImg(String path) => path.startsWith('__remote_img__:') || (path.startsWith('http') && !path.endsWith('.riv') && !path.endsWith('.mp4'));
bool _isRemoteRive(String path) => path.startsWith('__remote_rive__:') || (path.startsWith('http') && path.endsWith('.riv'));
bool _isRemoteVideo(String path) => path.startsWith('__remote_video__:') || (path.startsWith('http') && path.endsWith('.mp4'));

String _stripPrefix(String path) {
  if (path.contains(':') && (path.startsWith('__') || path.startsWith('http'))) {
    if (path.startsWith('http')) return path;
    return path.substring(path.indexOf(':') + 1);
  }
  return path;
}
String _builtInId(String path) => path.replaceFirst('__builtin__:', '');

// Built-in gradients catalog
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

/// Get primary gradient colors for any wallpaper path (for alarm card background)
List<Color> getWallpaperColors(String path) {
  if (_isBuiltIn(path)) {
    return builtInGradients[_builtInId(path)] ?? const [Color(0xFF232526), Color(0xFF414345)];
  }
  if (path.contains('sunset') || path.contains('college')) {
    return const [Color(0xFFE52D27), Color(0xFFB31217)];
  }
  if (path.contains('ocean') || path.contains('gym')) {
    return const [Color(0xFF0A58CA), Color(0xFF0D6EFD)];
  }
  if (path.isEmpty) {
    return const [Color(0xFF2B303A), Color(0xFF1F242E)];
  }
  return const [Color(0xFF2E3440), Color(0xFF232731)];
}

/// Main wallpaper widget — auto-detects path type and renders accordingly.
class AlarmWallpaperImage extends StatelessWidget {
  const AlarmWallpaperImage({super.key, required this.path, this.fit = BoxFit.cover});
  final String path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    // 1️⃣ Built-in gradient
    if (_isBuiltIn(path)) {
      final colors = builtInGradients[_builtInId(path)] ??
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

    // 3️⃣ Asset Rive animated wallpaper
    if (_isAssetRive(path)) {
      return _RiveAssetWallpaper(assetPath: _stripPrefix(path));
    }

    // 4️⃣ Asset Video wallpaper (looping, muted)
    if (_isAssetVideo(path)) {
      return _VideoAssetWallpaper(assetPath: _stripPrefix(path));
    }

    // 5️⃣ Remote Network Image (uploaded by admin via API)
    if (_isRemoteImg(path)) {
      final url = _stripPrefix(path);
      return CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        placeholder: (_, __) => const _FallbackBg(),
        errorWidget: (_, __, ___) => const _FallbackBg(),
      );
    }

    // 6️⃣ Remote Network Rive
    if (_isRemoteRive(path)) {
      return _RiveNetworkWallpaper(url: _stripPrefix(path));
    }

    // 7️⃣ Remote Network Video
    if (_isRemoteVideo(path)) {
      return _VideoNetworkWallpaper(url: _stripPrefix(path));
    }

    // 8️⃣ Custom user-picked local file
    if (path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: fit,
          cacheWidth: 1440,
          errorBuilder: (_, __, ___) => const _FallbackBg(),
        );
      }
    }

    return const _FallbackBg();
  }
}

// ── Rive asset wallpaper ──────────────────────────────────────────────────────
class _RiveAssetWallpaper extends StatelessWidget {
  const _RiveAssetWallpaper({required this.assetPath});
  final String assetPath;

  @override
  Widget build(BuildContext context) => RiveAnimation.asset(
    assetPath,
    fit: BoxFit.cover,
  );
}

// ── Rive network wallpaper ────────────────────────────────────────────────────
class _RiveNetworkWallpaper extends StatelessWidget {
  const _RiveNetworkWallpaper({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) => RiveAnimation.network(
    url,
    fit: BoxFit.cover,
  );
}

// ── Video asset wallpaper (looping, muted) ────────────────────────────────────
class _VideoAssetWallpaper extends StatefulWidget {
  const _VideoAssetWallpaper({required this.assetPath});
  final String assetPath;

  @override
  State<_VideoAssetWallpaper> createState() => _VideoAssetWallpaperState();
}

class _VideoAssetWallpaperState extends State<_VideoAssetWallpaper> {
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
          ..setVolume(0)
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

// ── Video network wallpaper (looping, muted) ──────────────────────────────────
class _VideoNetworkWallpaper extends StatefulWidget {
  const _VideoNetworkWallpaper({required this.url});
  final String url;

  @override
  State<_VideoNetworkWallpaper> createState() => _VideoNetworkWallpaperState();
}

class _VideoNetworkWallpaperState extends State<_VideoNetworkWallpaper> {
  late VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        _controller
          ..setLooping(true)
          ..setVolume(0)
          ..play();
        setState(() => _ready = true);
      }).catchError((_) {});
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
