import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<Directory> _alarmAssetDirectory() async {
  final root = await getApplicationSupportDirectory();
  return Directory('${root.path}${Platform.pathSeparator}campussetu_alarm_assets');
}

Future<String?> persistAlarmAsset({
  required int alarmId,
  required String kind,
  required String originalName,
  required String? sourcePath,
  required Uint8List? bytes,
  required Stream<List<int>>? dataStream,
}) async {
  try {
    final root = await _alarmAssetDirectory();
    final targetDirectory = Directory('${root.path}${Platform.pathSeparator}$alarmId');
    await targetDirectory.create(recursive: true);

    final extension = originalName.contains('.')
        ? originalName.split('.').last.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')
        : '';
    final safeExtension = extension.isEmpty ? (kind == 'sound' ? 'audio' : 'image') : extension;
    final fileName = '${kind}_${DateTime.now().microsecondsSinceEpoch}.$safeExtension';
    final target = File('${targetDirectory.path}${Platform.pathSeparator}$fileName');
    final source = sourcePath;
    if (source != null && source.isNotEmpty && await File(source).exists()) {
      await File(source).copy(target.path);
    } else if (dataStream != null) {
      await dataStream.pipe(target.openWrite());
    } else if (bytes != null && bytes.isNotEmpty) {
      await target.writeAsBytes(bytes, flush: true);
    } else {
      return null;
    }
    return target.path;
  } catch (_) {
    return null;
  }
}

Future<void> deleteAlarmAsset(String? path) async {
  if (path == null || path.isEmpty) return;
  try {
    final root = await _alarmAssetDirectory();
    final normalizedRoot = '${root.absolute.path}${Platform.pathSeparator}';
    final target = File(path).absolute;
    if (!target.path.startsWith(normalizedRoot)) return;
    if (await target.exists()) await target.delete();
  } catch (_) {
    // Cleanup is best-effort; it must not prevent alarm updates.
  }
}
