// lib/features/admin/admin_wallpapers_screen.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/services/api_service.dart';
import 'widgets/admin_toast.dart';

class AdminWallpapersScreen extends StatefulWidget {
  const AdminWallpapersScreen({super.key});

  @override
  State<AdminWallpapersScreen> createState() => _AdminWallpapersScreenState();
}

class _AdminWallpapersScreenState extends State<AdminWallpapersScreen> {
  static const _bg     = Color(0xFF080C14);
  static const _card   = Color(0xFF0D121E);
  static const _border = Color(0xFF1E283D);
  static const _cyan   = Color(0xFF38BDF8);
  static const _green  = Color(0xFF10B981);
  static const _red    = Color(0xFFEF4444);
  static const _amber  = Color(0xFFF59E0B);
  static const _inkSoft= Color(0xFF94A3B8);

  Map<String, dynamic> _wallpapers = {};
  bool _loading = true;
  String? _error;
  String _filter = 'all'; // all, image, animated, video

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService().getAlarmWallpapers();
      if (mounted) {
        setState(() {
          _wallpapers = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _deleteWallpaper(String id, String label) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _border)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: _red, size: 22),
            SizedBox(width: 8),
            Text('Delete Wallpaper', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text('Permanently delete "$label"? Students will no longer see this wallpaper.', style: const TextStyle(color: _inkSoft, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: _inkSoft))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await ApiService().deleteAlarmWallpaper(id);
      if (mounted) {
        AdminToast.success(context, 'Wallpaper deleted successfully');
        _load();
      }
    } catch (e) {
      if (mounted) AdminToast.error(context, 'Failed to delete: $e');
    }
  }

  Future<void> _showAddWallpaperDialog() async {
    final labelCtrl = TextEditingController();
    String type = 'image';
    String? selectedFilePath;
    String? selectedFileName;
    bool uploading = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: _border)),
          title: const Row(
            children: [
              Icon(Icons.wallpaper_rounded, color: _cyan, size: 22),
              SizedBox(width: 10),
              Text('Add Remote Wallpaper', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Label / Title', style: TextStyle(color: _inkSoft, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: labelCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. Cyberpunk Neon',
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    filled: true,
                    fillColor: _bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Category / Type', style: TextStyle(color: _inkSoft, fontSize: 12)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
                  child: DropdownButton<String>(
                    value: type,
                    isExpanded: true,
                    dropdownColor: _card,
                    underline: const SizedBox.shrink(),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: 'image', child: Text('🖼️ Static Image (JPG, PNG, WebP)')),
                      DropdownMenuItem(value: 'animated', child: Text('✨ Rive Animation (.riv)')),
                      DropdownMenuItem(value: 'video', child: Text('🎬 Video Wallpaper (.mp4)')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDlgState(() => type = v);
                    },
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Wallpaper File', style: TextStyle(color: _inkSoft, fontSize: 12)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final res = await FilePicker.platform.pickFiles(
                      type: FileType.any,
                      allowMultiple: false,
                    );
                    if (res != null && res.files.isNotEmpty) {
                      setDlgState(() {
                        selectedFilePath = res.files.single.path;
                        selectedFileName = res.files.single.name;
                      });
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selectedFilePath != null ? _cyan : _border, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Icon(selectedFilePath != null ? Icons.check_circle_rounded : Icons.file_upload_outlined, color: selectedFilePath != null ? _cyan : _inkSoft),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedFileName ?? 'Tap to select file from device',
                            style: TextStyle(color: selectedFilePath != null ? Colors.white : _inkSoft, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: uploading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: _inkSoft)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _cyan,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: uploading
                  ? null
                  : () async {
                      final label = labelCtrl.text.trim();
                      if (label.isEmpty) {
                        AdminToast.error(context, 'Enter a wallpaper label');
                        return;
                      }
                      if (selectedFilePath == null) {
                        AdminToast.error(context, 'Please select a file to upload');
                        return;
                      }
                      setDlgState(() => uploading = true);
                      try {
                        await ApiService().uploadAlarmWallpaper(
                          label: label,
                          type: type,
                          filePath: selectedFilePath!,
                        );
                        if (mounted && ctx.mounted) {
                          Navigator.pop(ctx);
                          AdminToast.success(context, 'Wallpaper uploaded successfully!');
                          _load();
                        }
                      } catch (e) {
                        setDlgState(() => uploading = false);
                        if (mounted) AdminToast.error(context, 'Upload failed: $e');
                      }
                    },
              child: uploading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Text('Upload', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = (_wallpapers['images'] as List?) ?? [];
    final animated = (_wallpapers['animated'] as List?) ?? [];
    final videos = (_wallpapers['videos'] as List?) ?? [];
    final totalCount = images.length + animated.length + videos.length;

    List<dynamic> activeList;
    if (_filter == 'image') {
      activeList = images;
    } else if (_filter == 'animated') {
      activeList = animated;
    } else if (_filter == 'video') {
      activeList = videos;
    } else {
      activeList = [...images, ...animated, ...videos];
    }

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: const BoxDecoration(
                color: _card,
                border: Border(bottom: BorderSide(color: _border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: _cyan.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.wallpaper_rounded, color: _cyan, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Wallpaper Management', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                            Text('Manage student alarm wallpapers, rive animations and video clips', style: TextStyle(color: _inkSoft, fontSize: 11)),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _cyan,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Upload', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        onPressed: _showAddWallpaperDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Metrics Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _StatBadge(label: 'Total', value: '$totalCount', color: Colors.white),
                        const SizedBox(width: 8),
                        _StatBadge(label: 'Images', value: '${images.length}', color: _cyan),
                        const SizedBox(width: 8),
                        _StatBadge(label: 'Animated (Rive)', value: '${animated.length}', color: _amber),
                        const SizedBox(width: 8),
                        _StatBadge(label: 'Videos', value: '${videos.length}', color: _green),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(label: 'All Wallpapers', value: 'all', selected: _filter == 'all', onSelect: (v) => setState(() => _filter = v)),
                        const SizedBox(width: 6),
                        _FilterChip(label: 'Images', value: 'image', selected: _filter == 'image', onSelect: (v) => setState(() => _filter = v)),
                        const SizedBox(width: 6),
                        _FilterChip(label: 'Animated (.riv)', value: 'animated', selected: _filter == 'animated', onSelect: (v) => setState(() => _filter = v)),
                        const SizedBox(width: 6),
                        _FilterChip(label: 'Videos (.mp4)', value: 'video', selected: _filter == 'video', onSelect: (v) => setState(() => _filter = v)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Wallpapers Grid / List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _cyan))
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Error: $_error', style: const TextStyle(color: _red)),
                              const SizedBox(height: 10),
                              ElevatedButton(onPressed: _load, child: const Text('Retry')),
                            ],
                          ),
                        )
                      : activeList.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.wallpaper_outlined, color: _inkSoft.withValues(alpha: 0.5), size: 48),
                                  const SizedBox(height: 12),
                                  const Text('No wallpapers uploaded in this category', style: TextStyle(color: _inkSoft, fontSize: 14)),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: activeList.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (ctx, i) {
                                final w = Map<String, dynamic>.from(activeList[i] as Map);
                                final id = (w['id'] ?? '').toString();
                                final label = (w['label'] ?? 'Wallpaper').toString();
                                final type = (w['type'] ?? 'image').toString();
                                final url = (w['url'] ?? '').toString();
                                final typeBadge = switch (type) {
                                  'animated' => '✨ Animated (Rive)',
                                  'video' => '🎬 Video (.mp4)',
                                  _ => '🖼️ Static Image',
                                };

                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _card,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: _border),
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: SizedBox(
                                          width: 60,
                                          height: 60,
                                          child: type == 'image'
                                              ? Image.network(
                                                  url,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => Container(
                                                    color: _bg,
                                                    child: const Icon(Icons.broken_image_rounded, color: _inkSoft),
                                                  ),
                                                )
                                              : Container(
                                                  color: _bg,
                                                  child: Icon(
                                                    type == 'video' ? Icons.play_arrow_rounded : Icons.auto_awesome,
                                                    color: _cyan,
                                                    size: 28,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                                            const SizedBox(height: 4),
                                            Text(typeBadge, style: const TextStyle(color: _inkSoft, fontSize: 12)),
                                            const SizedBox(height: 2),
                                            Text(url, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Delete Wallpaper',
                                        icon: const Icon(Icons.delete_outline_rounded, color: _red, size: 20),
                                        onPressed: () => _deleteWallpaper(id, label),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11)),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final void Function(String) onSelect;
  const _FilterChip({required this.label, required this.value, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF38BDF8);
    const border = Color(0xFF1E283D);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onSelect(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? cyan.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? cyan : border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? cyan : const Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
