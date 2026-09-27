import 'dart:async';
import 'dart:typed_data';

Future<String?> persistAlarmAsset({
  required int alarmId,
  required String kind,
  required String originalName,
  required String? sourcePath,
  required Uint8List? bytes,
  required Stream<List<int>>? dataStream,
}) async => null;

Future<void> deleteAlarmAsset(String? path) async {}
