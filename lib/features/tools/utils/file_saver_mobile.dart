// lib/features/tools/utils/file_saver_mobile.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveAndDownloadFile(Uint8List bytes, String fileName) async {
  try {
    Directory? dir;
    if (Platform.isAndroid) {
      dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    
    // Attempt to open or share
    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done) {
      await Share.shareXFiles([XFile(file.path)], text: 'Download $fileName');
    }
  } catch (_) {
    // Fallback using share_plus
    await Share.shareXFiles([
      XFile.fromData(bytes, name: fileName, mimeType: 'application/octet-stream')
    ], text: fileName);
  }
}
