// lib/features/tools/services/image_tools_service.dart
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';

class ConvertedImageResult {
  final Uint8List bytes;
  final String format;
  final int width;
  final int height;
  final int originalSize;
  final int newSize;

  ConvertedImageResult({
    required this.bytes,
    required this.format,
    required this.width,
    required this.height,
    required this.originalSize,
    required this.newSize,
  });

  double get savingsPercent {
    if (originalSize <= 0) return 0;
    final diff = originalSize - newSize;
    return (diff / originalSize * 100).clamp(-999.0, 100.0);
  }
}

class ImageToolsService {
  /// 1. IMAGE CONVERTER
  /// Converts an image to target format (PNG, JPG, WEBP, BMP, GIF, SVG).
  static Future<ConvertedImageResult> convertImage(
    Uint8List inputBytes, {
    required String targetFormat, // 'png', 'jpg', 'webp', 'bmp', 'gif', 'svg'
    int quality = 90,
  }) async {
    Uint8List effectiveBytes = inputBytes;
    if (_isSvg(inputBytes)) {
      effectiveBytes = await _renderSvgToPng(inputBytes);
    }

    final decoded = img.decodeImage(effectiveBytes);
    if (decoded == null) throw Exception('Unable to decode image file');

    Uint8List output;
    final fmt = targetFormat.toLowerCase();

    switch (fmt) {
      case 'jpg':
      case 'jpeg':
        output = Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
        break;
      case 'png':
        output = Uint8List.fromList(img.encodePng(decoded));
        break;
      case 'webp':
        output = Uint8List.fromList(
          img.encodeWebP(decoded, lossless: false, quality: quality),
        );
        break;
      case 'bmp':
        output = Uint8List.fromList(img.encodeBmp(decoded));
        break;
      case 'gif':
        output = Uint8List.fromList(img.encodeGif(decoded));
        break;
      case 'svg':
        final pngData = Uint8List.fromList(img.encodePng(decoded));
        final b64 = base64Encode(pngData);
        final svgXml = '<?xml version="1.0" encoding="UTF-8"?>\n'
            '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
            'width="${decoded.width}" height="${decoded.height}" viewBox="0 0 ${decoded.width} ${decoded.height}">\n'
            '  <image width="${decoded.width}" height="${decoded.height}" xlink:href="data:image/png;base64,$b64"/>\n'
            '</svg>';
        output = Uint8List.fromList(utf8.encode(svgXml));
        break;
      default:
        throw ArgumentError.value(
          targetFormat,
          'targetFormat',
          'Choose PNG, JPG, WEBP, BMP, GIF, or SVG.',
        );
    }

    return ConvertedImageResult(
      bytes: output,
      format: fmt,
      width: decoded.width,
      height: decoded.height,
      originalSize: inputBytes.lengthInBytes,
      newSize: output.lengthInBytes,
    );
  }

  static bool _isSvg(Uint8List bytes) {
    if (bytes.length < 5) return false;
    final header = String.fromCharCodes(bytes.take(200)).toLowerCase();
    return header.contains('<svg') || header.contains('<?xml');
  }

  static Future<Uint8List> _renderSvgToPng(Uint8List svgBytes) async {
    final svgString = utf8.decode(svgBytes, allowMalformed: true);
    final pictureInfo = await vg.loadPicture(SvgStringLoader(svgString), null);
    final width = pictureInfo.size.width.toInt().clamp(1, 4096);
    final height = pictureInfo.size.height.toInt().clamp(1, 4096);
    final image = await pictureInfo.picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    pictureInfo.picture.dispose();
    image.dispose();
    if (byteData == null) throw Exception('Unable to rasterize SVG image');
    return byteData.buffer.asUint8List();
  }

  /// 2. COMPRESS IMAGE
  /// Resizes and recompresses image bytes with quality control.
  static Future<ConvertedImageResult> compressImage(
    Uint8List inputBytes, {
    int quality = 70, // 1 to 100
    int? maxDimension, // e.g. 1920, 1280, 800
  }) async {
    final decoded = img.decodeImage(inputBytes);
    if (decoded == null) throw Exception('Unable to decode image file');

    img.Image working = decoded;
    if (maxDimension != null &&
        (working.width > maxDimension || working.height > maxDimension)) {
      if (working.width >= working.height) {
        working = img.copyResize(working, width: maxDimension);
      } else {
        working = img.copyResize(working, height: maxDimension);
      }
    }

    final compressed =
        Uint8List.fromList(img.encodeJpg(working, quality: quality));

    return ConvertedImageResult(
      bytes: compressed,
      format: 'jpg',
      width: working.width,
      height: working.height,
      originalSize: inputBytes.lengthInBytes,
      newSize: compressed.lengthInBytes,
    );
  }

  /// Removes a connected, near-uniform background using only local image
  /// processing. Best results are expected when the subject is separated from
  /// a plain/solid background; no image is uploaded or stored remotely.
  static Future<Uint8List> removeBackground(
    Uint8List inputBytes, {
    required int tolerance,
  }) {
    return compute(_removeBackgroundTask, <String, Object>{
      'bytes': inputBytes,
      'tolerance': tolerance,
    });
  }

  /// 3. IMAGE WATERMARK REMOVER
  /// Cleanses/inpaints the marked bounding box area using surrounding color smoothing.
  static Future<Uint8List> removeWatermark(
    Uint8List inputBytes, {
    required Rect relativeArea, // 0.0 to 1.0 relative coordinates
  }) async {
    final decoded = img.decodeImage(inputBytes);
    if (decoded == null) throw Exception('Unable to decode image');

    final xStart =
        (relativeArea.left * decoded.width).toInt().clamp(0, decoded.width - 1);
    final yStart = (relativeArea.top * decoded.height)
        .toInt()
        .clamp(0, decoded.height - 1);
    final w = (relativeArea.width * decoded.width)
        .toInt()
        .clamp(1, decoded.width - xStart);
    final h = (relativeArea.height * decoded.height)
        .toInt()
        .clamp(1, decoded.height - yStart);

    // Sample border colors around the watermark region to blend seamlessly
    int rSum = 0, gSum = 0, bSum = 0, sampleCount = 0;

    // Top & bottom perimeter
    for (int px = xStart; px < xStart + w; px++) {
      final yTop = (yStart - 2).clamp(0, decoded.height - 1);
      final yBot = (yStart + h + 1).clamp(0, decoded.height - 1);
      final p1 = decoded.getPixel(px, yTop);
      final p2 = decoded.getPixel(px, yBot);
      rSum += p1.r.toInt() + p2.r.toInt();
      gSum += p1.g.toInt() + p2.g.toInt();
      bSum += p1.b.toInt() + p2.b.toInt();
      sampleCount += 2;
    }

    // Left & right perimeter
    for (int py = yStart; py < yStart + h; py++) {
      final xLeft = (xStart - 2).clamp(0, decoded.width - 1);
      final xRight = (xStart + w + 1).clamp(0, decoded.width - 1);
      final p1 = decoded.getPixel(xLeft, py);
      final p2 = decoded.getPixel(xRight, py);
      rSum += p1.r.toInt() + p2.r.toInt();
      gSum += p1.g.toInt() + p2.g.toInt();
      bSum += p1.b.toInt() + p2.b.toInt();
      sampleCount += 2;
    }

    final avgR = sampleCount > 0 ? (rSum / sampleCount).round() : 255;
    final avgG = sampleCount > 0 ? (gSum / sampleCount).round() : 255;
    final avgB = sampleCount > 0 ? (bSum / sampleCount).round() : 255;
    final blendColor = img.ColorRgb8(avgR, avgG, avgB);

    // Fill the watermark area with the interpolated surrounding color
    img.fillRect(
      decoded,
      x1: xStart,
      y1: yStart,
      x2: xStart + w,
      y2: yStart + h,
      color: blendColor,
    );

    // Apply mild Gaussian blur on the boundary region to blend smoothly
    img.gaussianBlur(decoded, radius: 2);

    return Uint8List.fromList(img.encodePng(decoded));
  }

  /// 4. QR CODE GENERATION (PNG BYTES)
  /// Converts string data (text, URL, or data URI) into high-resolution PNG bytes.
  static Future<Uint8List> generateQrPng(
    String data, {
    double size = 400,
    Color foregroundColor = Colors.black,
    Color backgroundColor = Colors.white,
  }) async {
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: true,
      dataModuleStyle: QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: foregroundColor,
      ),
      eyeStyle: QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: foregroundColor,
      ),
    );

    final pic = painter.toPicture(size);
    final image = await pic.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// IMAGE TO QR CODE
  /// Resizes image to compact thumb and encodes it as Base64 Data-URI QR.
  static Future<String> prepareImageForQr(Uint8List imageBytes) async {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) throw Exception('Invalid image data');

    // Scale down to compact thumbnail suitable for standard QR payload limits (<= 1.5KB)
    final thumb = img.copyResize(decoded, width: 48, height: 48);
    final jpgBytes = img.encodeJpg(thumb, quality: 30);
    final base64Str = base64Encode(jpgBytes);
    return 'data:image/jpeg;base64,$base64Str';
  }

  /// 5. BARCODE GENERATION (PNG BYTES)
  /// Converts alphanumeric text to standard Code 128 Barcode PNG bytes.
  static Future<Uint8List> generateBarcodePng(
    String data, {
    double width = 500,
    double height = 180,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    final barcode = Barcode.code128();
    final painter = _BarcodeCanvasPainter(
      barcode: barcode,
      data: data,
      color: Colors.black,
      drawText: true,
    );
    painter.paint(canvas, Size(width, height));

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}

Uint8List _removeBackgroundTask(Map<String, Object> args) {
  final inputBytes = args['bytes'] as Uint8List;
  final tolerance = (args['tolerance'] as int).clamp(8, 110).toInt();
  final decoded = img.decodeImage(inputBytes);
  if (decoded == null) throw ArgumentError('Unable to decode this image.');

  final width = decoded.width;
  final height = decoded.height;
  final pixelCount = width * height;
  if (pixelCount > 6000000) {
    throw ArgumentError(
        'For this offline tool, choose an image up to 6 megapixels.');
  }

  // Estimate a dominant edge color from a small border sample. The connected
  // flood fill below prevents similarly colored areas inside the subject from
  // being removed unless they touch the image edge.
  final buckets = <int, List<int>>{};
  final scratchPixel = decoded.getPixel(0, 0);
  void addSample(int x, int y) {
    final pixel = decoded.getPixel(x, y, scratchPixel);
    final r = pixel.r.toInt();
    final g = pixel.g.toInt();
    final b = pixel.b.toInt();
    final key = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
    final bucket = buckets.putIfAbsent(key, () => <int>[0, 0, 0, 0]);
    bucket[0] += r;
    bucket[1] += g;
    bucket[2] += b;
    bucket[3] += 1;
  }

  final step = (math.min(width, height) ~/ 160).clamp(1, 1000000).toInt();
  for (var x = 0; x < width; x += step) {
    addSample(x, 0);
    if (height > 1) addSample(x, height - 1);
  }
  for (var y = step; y < height - 1; y += step) {
    addSample(0, y);
    if (width > 1) addSample(width - 1, y);
  }
  final dominant = buckets.values.reduce((a, b) => a[3] >= b[3] ? a : b);
  final bgR = dominant[0] ~/ dominant[3];
  final bgG = dominant[1] ~/ dominant[3];
  final bgB = dominant[2] ~/ dominant[3];
  final hardLimit = tolerance * tolerance * 3;
  final softLimit = (tolerance + 36) * (tolerance + 36) * 3;
  final hardDistance = math.sqrt(hardLimit);
  final softDistance = math.sqrt(softLimit);

  final visited = Uint8List(pixelCount);
  final queue = Int32List(pixelCount);
  var head = 0;
  var tail = 0;

  bool isBackground(int x, int y) {
    final pixel = decoded.getPixel(x, y, scratchPixel);
    final dr = pixel.r.toInt() - bgR;
    final dg = pixel.g.toInt() - bgG;
    final db = pixel.b.toInt() - bgB;
    return dr * dr + dg * dg + db * db <= softLimit;
  }

  void enqueue(int x, int y) {
    final index = y * width + x;
    if (visited[index] != 0 || !isBackground(x, y)) return;
    visited[index] = 1;
    queue[tail++] = index;
  }

  for (var x = 0; x < width; x += 1) {
    enqueue(x, 0);
    if (height > 1) enqueue(x, height - 1);
  }
  for (var y = 1; y < height - 1; y += 1) {
    enqueue(0, y);
    if (width > 1) enqueue(width - 1, y);
  }

  while (head < tail) {
    final index = queue[head++];
    final x = index % width;
    final y = index ~/ width;
    if (x > 0) enqueue(x - 1, y);
    if (x + 1 < width) enqueue(x + 1, y);
    if (y > 0) enqueue(x, y - 1);
    if (y + 1 < height) enqueue(x, y + 1);
  }

  final output = img.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; y += 1) {
    for (var x = 0; x < width; x += 1) {
      final index = y * width + x;
      final pixel = decoded.getPixel(x, y, scratchPixel);
      var alpha = pixel.a.toInt();
      if (visited[index] != 0) {
        final dr = pixel.r.toInt() - bgR;
        final dg = pixel.g.toInt() - bgG;
        final db = pixel.b.toInt() - bgB;
        final distance = math.sqrt(dr * dr + dg * dg + db * db);
        final coverage = distance <= hardDistance
            ? 0.0
            : ((distance - hardDistance) / (softDistance - hardDistance))
                .clamp(0.0, 1.0);
        alpha = (alpha * coverage).round();
      }
      output.setPixelRgba(
        x,
        y,
        pixel.r.toInt(),
        pixel.g.toInt(),
        pixel.b.toInt(),
        alpha,
      );
    }
  }
  return Uint8List.fromList(img.encodePng(output));
}

class _BarcodeCanvasPainter extends CustomPainter {
  final Barcode barcode;
  final String data;
  final Color color;
  final bool drawText;

  _BarcodeCanvasPainter({
    required this.barcode,
    required this.data,
    required this.color,
    required this.drawText,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fill white background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.white);

    const padding = 20.0;
    final textHeight = drawText ? 24.0 : 0.0;
    final barcodeHeight = size.height - (padding * 2) - textHeight;
    final barcodeWidth = size.width - (padding * 2);

    try {
      final operations = barcode.make(
        data,
        width: barcodeWidth,
        height: barcodeHeight,
        drawText: false,
      );

      final barPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      for (final op in operations) {
        if (op is BarcodeBar) {
          canvas.drawRect(
            Rect.fromLTWH(
              padding + op.left,
              padding + op.top,
              op.width,
              op.height,
            ),
            barPaint,
          );
        }
      }

      if (drawText) {
        final textSpan = TextSpan(
          text: data,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        );
        final tp = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout(maxWidth: size.width);

        final x = (size.width - tp.width) / 2;
        final y = padding + barcodeHeight + 8;
        tp.paint(canvas, Offset(x, y));
      }
    } catch (_) {
      // Draw error message on canvas
      final tp = TextPainter(
        text: TextSpan(
            text: 'Invalid barcode data: "$data"',
            style: const TextStyle(color: Colors.red, fontSize: 12)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      tp.paint(canvas, const Offset(20.0, 20.0));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
