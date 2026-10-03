// lib/features/tools/services/ocr_service_web.dart
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'ocr_service.dart';

Future<OcrDocumentResult> performImageOcr(Uint8List imageBytes, {String? fileName}) async {
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

  final completer = Completer<OcrDocumentResult>();
  late StreamSubscription sub;

  sub = html.window.on['campussetu_ocr_response'].listen((html.Event e) {
    unawaited(sub.cancel());
    if (e is html.CustomEvent) {
      final raw = e.detail?.toString() ?? '';
      if (raw.startsWith('ERROR:')) {
        completer.completeError(StateError('OCR failed: ${raw.replaceFirst('ERROR:', '').trim()}'));
      } else if (raw.isEmpty) {
        completer.completeError(StateError('No readable text was found in the selected image.'));
      } else {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            final double imgW = (decoded['imageWidth'] as num?)?.toDouble() ?? 1000.0;
            final double imgH = (decoded['imageHeight'] as num?)?.toDouble() ?? 1000.0;
            final rawLines = decoded['lines'] as List<dynamic>? ?? [];
            if (rawLines.isNotEmpty) {
              final result = _processExtractedLines(rawLines, imgW, imgH);
              completer.complete(result);
              return;
            }
          }
          completer.complete(OcrDocumentResult.fromText(raw));
        } catch (_) {
          completer.complete(OcrDocumentResult.fromText(raw));
        }
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

OcrDocumentResult _processExtractedLines(
  List<dynamic> rawLines,
  double imageWidth,
  double imageHeight,
) {
  final List<Map<String, dynamic>> items = [];
  for (final l in rawLines) {
    final text = (l['text'] ?? '').toString().trim();
    if (text.isEmpty) continue;
    final x = (l['x'] as num?)?.toDouble() ?? 0.0;
    final y = (l['y'] as num?)?.toDouble() ?? 0.0;
    final width = (l['width'] as num?)?.toDouble() ?? 0.0;
    final height = (l['height'] as num?)?.toDouble() ?? 16.0;

    items.add({
      'text': text,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    });
  }

  if (items.isEmpty) {
    throw StateError('No readable text was found in the selected image.');
  }

  items.sort((a, b) {
    final double yA = a['y'];
    final double yB = b['y'];
    if ((yA - yB).abs() <= 8.0) {
      return (a['x'] as double).compareTo(b['x'] as double);
    }
    return yA.compareTo(yB);
  });

  final heights = items.map((e) => e['height'] as double).toList()..sort();
  final medianHeight = heights.isNotEmpty ? heights[heights.length ~/ 2] : 16.0;

  final ocrLines = <OcrLine>[];
  final fullTextBuffer = StringBuffer();

  for (final item in items) {
    final text = item['text'] as String;
    final x = item['x'] as double;
    final y = item['y'] as double;
    final width = item['width'] as double;
    final height = item['height'] as double;

    final alignment = OcrService.detectAlignment(
      x: x,
      width: width,
      imageWidth: imageWidth,
    );

    final isHeading = height >= (medianHeight * 1.35) || (alignment == OcrLineAlignment.center && height >= (medianHeight * 1.15));
    final fontSize = height >= (medianHeight * 1.5)
        ? 16.0
        : (isHeading ? 13.5 : 11.0);

    int indentTwips = 0;
    if (alignment == OcrLineAlignment.left && x > (imageWidth * 0.12)) {
      final ratio = ((x - (imageWidth * 0.08)) / imageWidth).clamp(0.0, 0.45);
      indentTwips = (ratio * 9000).round();
    }

    ocrLines.add(OcrLine(
      text: text,
      x: x,
      y: y,
      width: width,
      height: height,
      alignment: alignment,
      isHeading: isHeading,
      fontSize: fontSize,
      indentTwips: indentTwips,
    ));

    fullTextBuffer.writeln(text);
  }

  return OcrDocumentResult(
    fullText: fullTextBuffer.toString().trim(),
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    lines: ocrLines,
  );
}
