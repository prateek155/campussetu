// lib/features/tools/services/ocr_service_mobile.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/painting.dart' show decodeImageFromList;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'ocr_service.dart';

Future<OcrDocumentResult> performImageOcr(Uint8List imageBytes, {String? fileName}) async {
  if (imageBytes.isEmpty) throw ArgumentError('The selected image is empty.');
  if (imageBytes.lengthInBytes > 25 * 1024 * 1024) {
    throw ArgumentError('Choose an image smaller than 25 MB.');
  }

  // Windows Desktop support using native Windows.Media.Ocr
  if (Platform.isWindows) {
    return _performWindowsOcr(imageBytes, fileName: fileName);
  }

  // Mobile platforms (Android / iOS) using Google ML Kit
  return _performMobileMlKitOcr(imageBytes, fileName: fileName);
}

Future<OcrDocumentResult> _performWindowsOcr(Uint8List imageBytes, {String? fileName}) async {
  final tempDir = await getTemporaryDirectory();
  final ext = switch (fileName?.split('.').last.toLowerCase()) {
    'jpg' || 'jpeg' => 'jpg',
    'png' => 'png',
    'webp' => 'webp',
    _ => 'png',
  };
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  final tempFile = File('${tempDir.path}${Platform.pathSeparator}campussetu_ocr_$timestamp.$ext');
  final psFile = File('${tempDir.path}${Platform.pathSeparator}campussetu_ocr_runner_$timestamp.ps1');

  try {
    await tempFile.writeAsBytes(imageBytes, flush: true);

    const psScript = r'''
param($imgPath)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
Function Await($WinRtTask, $ResultType) {
    $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
    $netTask = $asTask.Invoke($null, @($WinRtTask))
    $netTask.Wait(-1) | Out-Null
    $netTask.Result
}
[Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
[Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType = WindowsRuntime] | Out-Null
$engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
if ($engine -eq $null) { $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage([Windows.Globalization.Language]::new('en-US')) }

$file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($imgPath)) ([Windows.Storage.StorageFile])
$stream = Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
$decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
$bitmap = Await ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
$ocrResult = Await ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])

$linesOut = @()
foreach ($line in $ocrResult.Lines) {
    $minX = 999999; $minY = 999999; $maxX = 0; $maxY = 0;
    foreach ($w in $line.Words) {
        if ($w.BoundingRect.X -lt $minX) { $minX = $w.BoundingRect.X }
        if ($w.BoundingRect.Y -lt $minY) { $minY = $w.BoundingRect.Y }
        $right = $w.BoundingRect.X + $w.BoundingRect.Width
        $bottom = $w.BoundingRect.Y + $w.BoundingRect.Height
        if ($right -gt $maxX) { $maxX = $right }
        if ($bottom -gt $maxY) { $maxY = $bottom }
    }
    $linesOut += [PSCustomObject]@{
        text = $line.Text
        x = [double]$minX
        y = [double]$minY
        width = [double]($maxX - $minX)
        height = [double]($maxY - $minY)
    }
}

$jsonObj = [PSCustomObject]@{
    imageWidth = [double]$bitmap.PixelWidth
    imageHeight = [double]$bitmap.PixelHeight
    lines = $linesOut
}
$jsonObj | ConvertTo-Json -Depth 5 -Compress
''';

    await psFile.writeAsString(psScript);

    final processResult = await Process.run(
      'powershell',
      ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', psFile.path, tempFile.path],
    );

    if (processResult.exitCode != 0) {
      throw StateError('Windows OCR engine failed: ${processResult.stderr}');
    }

    final rawOutput = processResult.stdout.toString().trim();
    if (rawOutput.isEmpty) {
      throw StateError('No readable text was found in the selected image.');
    }

    final Map<String, dynamic> data = jsonDecode(rawOutput);
    final double imgW = (data['imageWidth'] as num?)?.toDouble() ?? 800.0;
    final double imgH = (data['imageHeight'] as num?)?.toDouble() ?? 600.0;
    final rawLinesList = data['lines'] as List<dynamic>? ?? [];

    return _processExtractedLines(rawLinesList, imgW, imgH);
  } finally {
    if (await tempFile.exists()) {
      try {
        await tempFile.delete();
      } catch (_) {}
    }
    if (await psFile.exists()) {
      try {
        await psFile.delete();
      } catch (_) {}
    }
  }
}

Future<OcrDocumentResult> _performMobileMlKitOcr(Uint8List imageBytes, {String? fileName}) async {
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

    double imgW = 800.0;
    double imgH = 600.0;
    try {
      final decoded = await decodeImageFromList(imageBytes);
      imgW = decoded.width.toDouble();
      imgH = decoded.height.toDouble();
    } catch (_) {}

    final rawLines = <Map<String, dynamic>>[];
    for (final block in result.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isEmpty) continue;
        rawLines.add({
          'text': text,
          'x': line.boundingBox.left,
          'y': line.boundingBox.top,
          'width': line.boundingBox.width,
          'height': line.boundingBox.height,
        });
      }
    }

    if (rawLines.isEmpty) {
      throw StateError('No readable text was found in the selected image.');
    }

    return _processExtractedLines(rawLines, imgW, imgH);
  } finally {
    try {
      await recognizer.close();
    } finally {
      if (await imageFile.exists()) await imageFile.delete();
    }
  }
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

  // Sort lines top-to-bottom (with slight line grouping tolerance of ~8 pixels)
  items.sort((a, b) {
    final double yA = a['y'];
    final double yB = b['y'];
    if ((yA - yB).abs() <= 8.0) {
      return (a['x'] as double).compareTo(b['x'] as double);
    }
    return yA.compareTo(yB);
  });

  // Calculate median line height to distinguish headings from body text
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

    // Calculate left indent in twips
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
