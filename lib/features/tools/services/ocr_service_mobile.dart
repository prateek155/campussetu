// lib/features/tools/services/ocr_service_mobile.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

Future<String> performImageOcr(Uint8List imageBytes, {String? fileName}) async {
  if (imageBytes.isEmpty) throw ArgumentError('The selected image is empty.');
  if (imageBytes.lengthInBytes > 25 * 1024 * 1024) {
    throw ArgumentError('Choose an image smaller than 25 MB.');
  }

  final tempDirectory = await getTemporaryDirectory();
  final extension = switch (fileName?.split('.').last.toLowerCase()) {
    'jpg' => 'jpg',
    'jpeg' => 'jpeg',
    'png' => 'png',
    'webp' => 'webp',
    _ => 'img',
  };
  final imageFile = File(
    '${tempDirectory.path}${Platform.pathSeparator}'
    'campussetu_ocr_${DateTime.now().microsecondsSinceEpoch}.$extension',
  );
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  try {
    await imageFile.writeAsBytes(imageBytes, flush: true);
    final result = await recognizer.processImage(
      InputImage.fromFilePath(imageFile.path),
    );
    final text = result.text.trim();
    if (text.isEmpty) {
      throw StateError('No readable text was found in the selected image.');
    }
    return text;
  } finally {
    try {
      await recognizer.close();
    } finally {
      if (await imageFile.exists()) await imageFile.delete();
    }
  }
}
