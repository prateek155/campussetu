// lib/features/tools/services/image_tools_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
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
  /// Converts an image to target format (PNG, JPG, BMP, GIF, SVG).
  static Future<ConvertedImageResult> convertImage(
    Uint8List inputBytes, {
    required String targetFormat, // 'png', 'jpg', 'bmp', 'gif', 'svg'
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
        output = Uint8List.fromList(img.encodePng(decoded));
        break;
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
    if (maxDimension != null && (working.width > maxDimension || working.height > maxDimension)) {
      if (working.width >= working.height) {
        working = img.copyResize(working, width: maxDimension);
      } else {
        working = img.copyResize(working, height: maxDimension);
      }
    }

    final compressed = Uint8List.fromList(img.encodeJpg(working, quality: quality));

    return ConvertedImageResult(
      bytes: compressed,
      format: 'jpg',
      width: working.width,
      height: working.height,
      originalSize: inputBytes.lengthInBytes,
      newSize: compressed.lengthInBytes,
    );
  }

  /// 3. IMAGE WATERMARK REMOVER
  /// Cleanses/inpaints the marked bounding box area using surrounding color smoothing.
  static Future<Uint8List> removeWatermark(
    Uint8List inputBytes, {
    required Rect relativeArea, // 0.0 to 1.0 relative coordinates
  }) async {
    final decoded = img.decodeImage(inputBytes);
    if (decoded == null) throw Exception('Unable to decode image');

    final xStart = (relativeArea.left * decoded.width).toInt().clamp(0, decoded.width - 1);
    final yStart = (relativeArea.top * decoded.height).toInt().clamp(0, decoded.height - 1);
    final w = (relativeArea.width * decoded.width).toInt().clamp(1, decoded.width - xStart);
    final h = (relativeArea.height * decoded.height).toInt().clamp(1, decoded.height - yStart);

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
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.white);

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
        text: TextSpan(text: 'Invalid barcode data: "$data"', style: const TextStyle(color: Colors.red, fontSize: 12)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      tp.paint(canvas, const Offset(20.0, 20.0));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
