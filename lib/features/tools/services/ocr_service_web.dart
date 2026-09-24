// lib/features/tools/services/ocr_service_web.dart
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<String> performImageOcr(Uint8List imageBytes, {String? fileName}) async {
  if (imageBytes.isEmpty) throw ArgumentError('The selected image is empty.');
  if (imageBytes.lengthInBytes > 25 * 1024 * 1024) {
    throw ArgumentError('Choose an image smaller than 25 MB.');
  }

  final b64 = base64Encode(imageBytes);
  final extension = fileName?.split('.').last.toLowerCase();
  final mimeType = switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    _ => 'image/png',
  };
  final dataUri = 'data:$mimeType;base64,$b64';

  final completer = Completer<String>();
  late StreamSubscription sub;

  sub = html.window.on['campussetu_ocr_response'].listen((html.Event e) {
    unawaited(sub.cancel());
    if (e is html.CustomEvent) {
      final text = e.detail?.toString() ?? '';
      if (text.startsWith('ERROR:')) {
        completer.completeError(StateError('OCR failed. Check the image and try again.'));
      } else if (text.isEmpty) {
        completer.completeError(StateError('No readable text was found in the selected image.'));
      } else {
        completer.complete(text.trim());
      }
    } else {
      completer.completeError(StateError('OCR returned an invalid response.'));
    }
  });

  html.window.dispatchEvent(html.CustomEvent('campussetu_ocr_request', detail: dataUri));
  return completer.future.timeout(
    const Duration(seconds: 45),
    onTimeout: () {
      unawaited(sub.cancel());
      throw TimeoutException('OCR request timed out. Try a smaller image.');
    },
  );
}
