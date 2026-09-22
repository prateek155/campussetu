// lib/features/tools/tools_hub_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/neu_card.dart';
import 'widgets/pdf_tool_dialogs.dart';
import 'widgets/image_tool_dialogs.dart';

class ToolsHubScreen extends StatefulWidget {
  const ToolsHubScreen({super.key});

  @override
  State<ToolsHubScreen> createState() => _ToolsHubScreenState();
}

class _ToolsHubScreenState extends State<ToolsHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;
    final isTablet = width > 600 && width <= 900;
    final crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.bg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: AppColors.ink,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tools Hub', style: AppTypography.soraHeading2()),
            Text('100% Client-Side Converters & Utilities', style: AppTypography.interCaption(color: AppColors.inkSoft)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.shadowDark.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.cyanDeep,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cyanDeep.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.inkSoft,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(
                  icon: Icon(Icons.picture_as_pdf_rounded, size: 18),
                  text: 'PDF Tools (7)',
                ),
                Tab(
                  icon: Icon(Icons.photo_library_rounded, size: 18),
                  text: 'Image Tools (5)',
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              children: [
                // Privacy badge
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: AppColors.success, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Zero Database Storage: Files are processed 100% locally in your browser/device and are never uploaded or saved to any server.',
                            style: AppTypography.interCaption(color: AppColors.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Tool Grid Views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // ── PDF Tools Grid ──────────────────────────
                      _buildToolsGrid(
                        context,
                        crossAxisCount: crossAxisCount,
                        tools: [
                          _ToolItem(
                            title: 'PDF to Word',
                            description: 'Extract text & format into an editable Word document (.docx).',
                            icon: Icons.description_rounded,
                            iconColor: const Color(0xFF2B579A),
                            badge: 'MOST POPULAR',
                            onTap: () => PdfToolDialogs.showPdfToWordDialog(context),
                          ),
                          _ToolItem(
                            title: 'Watermark Remover',
                            description: 'Cleanly erase or whiteout watermarks, stamps & headers from PDF pages.',
                            icon: Icons.layers_clear_rounded,
                            iconColor: Colors.redAccent,
                            badge: 'SMART',
                            onTap: () => PdfToolDialogs.showPdfWatermarkDialog(context),
                          ),
                          _ToolItem(
                            title: 'Word to PDF',
                            description: 'Convert Word document contents or editable text into a clean PDF.',
                            icon: Icons.picture_as_pdf_rounded,
                            iconColor: Colors.deepOrange,
                            onTap: () => PdfToolDialogs.showWordToPdfDialog(context),
                          ),
                          _ToolItem(
                            title: 'Compress PDF',
                            description: 'Shrink PDF file size for easier sharing and uploading.',
                            icon: Icons.compress_rounded,
                            iconColor: Colors.purple,
                            badge: 'FAST',
                            onTap: () => PdfToolDialogs.showCompressPdfDialog(context),
                          ),
                          _ToolItem(
                            title: 'Image to PDF',
                            description: 'Combine single or multiple images (JPG, PNG) into a single PDF.',
                            icon: Icons.photo_library_rounded,
                            iconColor: Colors.teal,
                            onTap: () => PdfToolDialogs.showImageToPdfDialog(context),
                          ),
                          _ToolItem(
                            title: 'Delete Specific Pages',
                            description: 'Pick and permanently remove unwanted pages, then download updated PDF.',
                            icon: Icons.delete_sweep_rounded,
                            iconColor: Colors.red,
                            onTap: () => PdfToolDialogs.showDeletePagesDialog(context),
                          ),
                          _ToolItem(
                            title: 'Organize / Reorder PDF',
                            description: 'Drag & drop pages into any sequence and download reorganized PDF.',
                            icon: Icons.swap_vert_rounded,
                            iconColor: Colors.indigo,
                            onTap: () => PdfToolDialogs.showOrganizePdfDialog(context),
                          ),
                        ],
                      ),

                      // ── Image Tools Grid ────────────────────────
                      _buildToolsGrid(
                        context,
                        crossAxisCount: crossAxisCount,
                        tools: [
                          _ToolItem(
                            title: 'Image Converter',
                            description: 'Convert between PNG, JPG, JPEG, WEBP, BMP, and GIF formats.',
                            icon: Icons.transform_rounded,
                            iconColor: Colors.blueAccent,
                            badge: 'UNIVERSAL',
                            onTap: () => ImageToolDialogs.showImageConverterDialog(context),
                          ),
                          _ToolItem(
                            title: 'Compress Image',
                            description: 'Reduce image file size with live quality slider & dimension control.',
                            icon: Icons.photo_size_select_small_rounded,
                            iconColor: Colors.orange,
                            onTap: () => ImageToolDialogs.showCompressImageDialog(context),
                          ),
                          _ToolItem(
                            title: 'Watermark Remover',
                            description: 'Seamlessly blend and remove watermarks or logos from pictures.',
                            icon: Icons.auto_fix_high_rounded,
                            iconColor: Colors.pinkAccent,
                            onTap: () => ImageToolDialogs.showWatermarkRemoverDialog(context),
                          ),
                          _ToolItem(
                            title: 'QR Code Generator',
                            description: 'Create QR codes from text, URLs, or embed photos for instant scanning.',
                            icon: Icons.qr_code_2_rounded,
                            iconColor: const Color(0xFF6C63FF),
                            badge: '2-IN-1',
                            onTap: () => ImageToolDialogs.showQrGeneratorDialog(context),
                          ),
                          _ToolItem(
                            title: 'Barcode Generator',
                            description: 'Generate standard Code 128 barcodes from text, IDs, or roll numbers.',
                            icon: Icons.view_column_rounded,
                            iconColor: Colors.deepPurple,
                            onTap: () => ImageToolDialogs.showBarcodeGeneratorDialog(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolsGrid(
    BuildContext context, {
    required int crossAxisCount,
    required List<_ToolItem> tools,
  }) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 145,
      ),
      itemCount: tools.length,
      itemBuilder: (ctx, i) {
        final item = tools[i];
        return NeuCard(
          onTap: item.onTap,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: item.iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.icon, color: item.iconColor, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.title,
                      style: AppTypography.soraHeading3(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.iconColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.badge!,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: item.iconColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Text(
                  item.description,
                  style: AppTypography.interCaption(color: AppColors.inkSoft),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Launch Tool',
                    style: AppTypography.interLabel(color: AppColors.cyanDeep),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.cyanDeep),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ToolItem {
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final String? badge;
  final VoidCallback onTap;

  _ToolItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    this.badge,
    required this.onTap,
  });
}
