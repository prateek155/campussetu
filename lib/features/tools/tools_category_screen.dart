// lib/features/tools/tools_category_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/theme/app_typography.dart';

enum ToolCategory { pdf, image }

class ToolDefinition {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final ToolCategory category;

  const ToolDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.category,
  });
}

class ToolsData {
  static const List<ToolDefinition> pdfTools = [
    ToolDefinition(
      id: 'pdf_to_word',
      name: 'PDF to Word',
      description: 'Extract text & convert PDF into editable Word (.docx)',
      icon: Icons.description_rounded,
      iconBgColor: Color(0xFF1E3A8A),
      iconColor: Color(0xFF60A5FA),
      category: ToolCategory.pdf,
    ),
    ToolDefinition(
      id: 'pdf_watermark',
      name: 'Watermark Remover',
      description: 'Cleanly erase watermarks, stamps & headers from pages',
      icon: Icons.layers_clear_rounded,
      iconBgColor: Color(0xFF7F1D1D),
      iconColor: Color(0xFFF87171),
      category: ToolCategory.pdf,
    ),
    ToolDefinition(
      id: 'word_to_pdf',
      name: 'Word to PDF',
      description: 'Convert Word document contents or text into PDF',
      icon: Icons.picture_as_pdf_rounded,
      iconBgColor: Color(0xFF7C2D12),
      iconColor: Color(0xFFFB923C),
      category: ToolCategory.pdf,
    ),
    ToolDefinition(
      id: 'compress_pdf',
      name: 'Compress PDF',
      description: 'Reduce PDF file size while maintaining high quality',
      icon: Icons.compress_rounded,
      iconBgColor: Color(0xFF581C87),
      iconColor: Color(0xFFC084FC),
      category: ToolCategory.pdf,
    ),
    ToolDefinition(
      id: 'image_to_pdf',
      name: 'Image to PDF',
      description: 'Combine single or multiple images into a multi-page PDF',
      icon: Icons.photo_library_rounded,
      iconBgColor: Color(0xFF134E4A),
      iconColor: Color(0xFF2DD4BF),
      category: ToolCategory.pdf,
    ),
    ToolDefinition(
      id: 'delete_pages',
      name: 'Delete PDF Pages',
      description: 'Select & permanently delete specific pages from PDF',
      icon: Icons.delete_sweep_rounded,
      iconBgColor: Color(0xFF831843),
      iconColor: Color(0xFFF472B6),
      category: ToolCategory.pdf,
    ),
    ToolDefinition(
      id: 'organize_pdf',
      name: 'Organize PDF',
      description: 'Drag & drop pages to rearrange page order sequence',
      icon: Icons.swap_vert_rounded,
      iconBgColor: Color(0xFF312E81),
      iconColor: Color(0xFF818CF8),
      category: ToolCategory.pdf,
    ),
    ToolDefinition(
      id: 'ppt_to_pdf',
      name: 'PPT to PDF',
      description: 'Convert PowerPoint slides (.ppt) into presentation PDF',
      icon: Icons.slideshow_rounded,
      iconBgColor: Color(0xFF831843),
      iconColor: Color(0xFFF472B6),
      category: ToolCategory.pdf,
    ),
    ToolDefinition(
      id: 'pptx_to_pdf',
      name: 'PPTX to PDF',
      description: 'Convert modern PowerPoint (.pptx) into presentation PDF',
      icon: Icons.present_to_all_rounded,
      iconBgColor: Color(0xFFB45309),
      iconColor: Color(0xFFFBBF24),
      category: ToolCategory.pdf,
    ),
    ToolDefinition(
      id: 'csv_to_excel_pdf',
      name: 'CSV to Excel & PDF',
      description: 'Convert CSV tables into Excel (.xlsx) and styled PDF',
      icon: Icons.table_chart_rounded,
      iconBgColor: Color(0xFF065F46),
      iconColor: Color(0xFF34D399),
      category: ToolCategory.pdf,
    ),
    ToolDefinition(
      id: 'txt_to_word_pdf',
      name: 'TXT to Word & PDF',
      description: 'Convert plain text files into Word (.docx) and PDF',
      icon: Icons.text_snippet_rounded,
      iconBgColor: Color(0xFF1E3A8A),
      iconColor: Color(0xFF60A5FA),
      category: ToolCategory.pdf,
    ),
    ToolDefinition(
      id: 'pdf_to_pptx',
      name: 'PDF to PPT / PPTX',
      description: 'Convert PDF pages into editable PowerPoint presentation',
      icon: Icons.co_present_rounded,
      iconBgColor: Color(0xFF7C2D12),
      iconColor: Color(0xFFFB923C),
      category: ToolCategory.pdf,
    ),
  ];

  static const List<ToolDefinition> imageTools = [
    ToolDefinition(
      id: 'image_convert',
      name: 'Image Converter',
      description: 'Convert between PNG, JPG, WEBP, BMP, GIF, and SVG formats',
      icon: Icons.transform_rounded,
      iconBgColor: Color(0xFF1E3A8A),
      iconColor: Color(0xFF60A5FA),
      category: ToolCategory.image,
    ),
    ToolDefinition(
      id: 'compress_image',
      name: 'Compress Image',
      description: 'Shrink image file size with live quality & dimension tuning',
      icon: Icons.photo_size_select_small_rounded,
      iconBgColor: Color(0xFF7C2D12),
      iconColor: Color(0xFFFB923C),
      category: ToolCategory.image,
    ),
    ToolDefinition(
      id: 'image_watermark',
      name: 'Watermark Remover',
      description: 'Smartly erase stamps, logos, and watermark text from photos',
      icon: Icons.auto_fix_high_rounded,
      iconBgColor: Color(0xFF831843),
      iconColor: Color(0xFFF472B6),
      category: ToolCategory.image,
    ),
    ToolDefinition(
      id: 'qr_generator',
      name: 'QR Generator',
      description: 'Create QR codes from text, URLs, or embed photos',
      icon: Icons.qr_code_2_rounded,
      iconBgColor: Color(0xFF312E81),
      iconColor: Color(0xFF818CF8),
      category: ToolCategory.image,
    ),
    ToolDefinition(
      id: 'barcode_generator',
      name: 'Barcode Generator',
      description: 'Generate standard Code 128 barcodes from text or IDs',
      icon: Icons.view_column_rounded,
      iconBgColor: Color(0xFF134E4A),
      iconColor: Color(0xFF2DD4BF),
      category: ToolCategory.image,
    ),
    ToolDefinition(
      id: 'image_ocr_to_pdf_word',
      name: 'Image to PDF & Word (OCR)',
      description: 'Extract text from photos/scans and export to PDF or Word',
      icon: Icons.document_scanner_rounded,
      iconBgColor: Color(0xFF4C1D95),
      iconColor: Color(0xFFA78BFA),
      category: ToolCategory.image,
    ),
  ];

  static ToolDefinition? findById(String id) {
    for (final t in pdfTools) {
      if (t.id == id) return t;
    }
    for (final t in imageTools) {
      if (t.id == id) return t;
    }
    return null;
  }
}

class ToolsCategoryScreen extends ConsumerStatefulWidget {
  final ToolCategory category;
  const ToolsCategoryScreen({super.key, required this.category});

  @override
  ConsumerState<ToolsCategoryScreen> createState() => _ToolsCategoryScreenState();
}

class _ToolsCategoryScreenState extends ConsumerState<ToolsCategoryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark ||
        Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF0F111A) : const Color(0xFFF6F8FA);
    final cardBg = isDark ? const Color(0xFF1A1D2B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF282D42) : Colors.black.withValues(alpha: 0.08);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D24);
    final textMuted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    final isPdf = widget.category == ToolCategory.pdf;
    final title = isPdf ? 'PDF Tools' : 'Image Tools';
    final allTools = isPdf ? ToolsData.pdfTools : ToolsData.imageTools;

    final filtered = allTools.where((t) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return t.name.toLowerCase().contains(q) || t.description.toLowerCase().contains(q);
    }).toList();

    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;
    final isTablet = width > 600 && width <= 900;
    final crossAxisCount = isDesktop ? 3 : (isTablet ? 3 : 2);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: bgColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          title,
          style: AppTypography.soraHeading2().copyWith(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 950),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                // ── Early Access / Free Banner ──────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF181E30) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF253358) : const Color(0xFFBFDBFE),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Color(0xFF38BDF8), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'All tools are open with a 100% Free & Unlimited plan.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E3A8A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Helpful reuse tip card (Matching Screenshot 1) ─
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF16253D) : const Color(0xFFE0EDFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF263C63) : const Color(0xFFBCD8F8),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isPdf ? Icons.picture_as_pdf_outlined : Icons.photo_library_outlined,
                          color: const Color(0xFF38BDF8),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPdf ? 'Working on a PDF file?' : 'Working on an Image file?',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Everything runs locally in memory — fast, private, and offline. Files are never stored anywhere.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Search Tools Bar (Matching Screenshot 1) ────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: TextStyle(color: textColor, fontSize: 14),
                    decoration: InputDecoration(
                      icon: Icon(Icons.search_rounded, color: textMuted, size: 20),
                      hintText: 'Search tools',
                      hintStyle: TextStyle(color: textMuted, fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── 2-Column Grid (Matching Screenshot 1) ───────
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    mainAxisExtent: 140,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final tool = filtered[i];
                    return InkWell(
                      onTap: () => context.push('/tools/workspace?toolId=${tool.id}'),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cardBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isDark ? tool.iconBgColor : tool.iconBgColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                tool.icon,
                                color: isDark ? tool.iconColor : tool.iconBgColor,
                                size: 20,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              tool.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tool.description,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.25,
                                color: textMuted,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
