import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'resume_category.dart';

/// Contract for Canva-style modular resume templates.
///
/// Each unique resume design will be an independent file implementing this interface.
/// This guarantees:
/// 1. Zero code clutter: Each design's styling, curves, gauges, or timelines live in its own file.
/// 2. Pre-filled sample data: Starts with a 100% complete, beautiful dummy resume out of the box.
/// 3. Design-specific custom controls (e.g. gauge sliders, QR code generators, wave ribbons).
/// 4. Synchronized PDF generation using `pw.Widget`.
abstract class ResumeTemplateDefinition {
  /// Unique machine identifier, e.g. 'mathew_yellow_arc', 'farrukh_dark_schematic'
  String get id;

  /// Display name, e.g. 'Mathew Parker'
  String get name;

  /// Subtitle or role tagline
  String get tagline;

  /// The category this design belongs to: [ResumeCategory.professional],
  /// [ResumeCategory.designed], or [ResumeCategory.modern].
  ResumeCategory get category;

  /// Whether this template requires a PRO / Premium plan.
  bool get isPremium;

  /// Default accent color for this specific design.
  Color get defaultAccentColor;

  /// Pre-filled complete dummy document so the user never starts with a blank screen.
  Map<String, dynamic> get defaultSampleDocument;

  /// Renders the Flutter UI preview (Canva-style live interactive or canvas view).
  Widget buildPreview({
    required BuildContext context,
    required Map<String, dynamic> document,
    Color? customAccentColor,
    bool isInteractive = false,
  });

  /// Generates the vector PDF equivalent using package:pdf.
  pw.Widget buildPdf({
    required pw.Context context,
    required Map<String, dynamic> document,
    PdfColor? customAccentColor,
  });
}
