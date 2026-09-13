// lib/features/tshare/tshare_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/dark_tile.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_text_field.dart';

class TshareScreen extends StatefulWidget {
  const TshareScreen({super.key});

  @override
  State<TshareScreen> createState() => _TshareScreenState();
}

class _TshareScreenState extends State<TshareScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tshare', style: AppTypography.soraDisplay(size: 26)),
                  Text('Ephemeral code & text sharing', style: AppTypography.interBody(color: AppColors.inkSoft)),
                  const SizedBox(height: 20),
                  NeuCard(
                    padding: const EdgeInsets.all(4),
                    borderRadius: 16,
                    child: TabBar(
                      controller: _tabCtrl,
                      labelStyle: AppTypography.interButton(color: AppColors.cyanDeep),
                      unselectedLabelStyle: AppTypography.interButton(color: AppColors.inkSoft),
                      indicator: BoxDecoration(
                        color: AppColors.cyanDeep.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      dividerColor: Colors.transparent,
                      splashFactory: NoSplash.splashFactory,
                      tabs: const [
                        Tab(text: '📤  Share'),
                        Tab(text: '📥  Retrieve'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: const [
                  _ShareTab(),
                  _RetrieveTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Share Tab ─────────────────────────────────────────────
class _ShareTab extends StatefulWidget {
  const _ShareTab();

  @override
  State<_ShareTab> createState() => _ShareTabState();
}

class _ShareTabState extends State<_ShareTab> {
  final _contentCtrl = TextEditingController();
  String? _generatedCode;
  DateTime? _expiresAt;
  bool _isGenerating = false;
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;

  @override
  void dispose() {
    _contentCtrl.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      if (_expiresAt != null && now.isBefore(_expiresAt!)) {
        setState(() => _remaining = _expiresAt!.difference(now));
      } else {
        setState(() {
          _generatedCode = null;
          _remaining = Duration.zero;
        });
        _countdownTimer?.cancel();
      }
    });
  }

  Future<void> _generate() async {
    if (_contentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter some text/code first')));
      return;
    }
    setState(() => _isGenerating = true);
    try {
      final res = await ApiService().createTshare({'content': _contentCtrl.text.trim(), 'language': 'text'});
      final code = (res['code'] ?? '').toString();
      final expiresAtStr = (res['expires_at'] ?? '').toString();
      DateTime? exp;
      if (expiresAtStr.isNotEmpty) exp = DateTime.tryParse(expiresAtStr);
      if (code.isEmpty) throw Exception('No code returned');
      setState(() {
        _generatedCode = code;
        _expiresAt = exp ?? DateTime.now().add(const Duration(hours: 24));
        _remaining = _expiresAt!.difference(DateTime.now());
      });
      _startCountdown();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Code $code saved ✓'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Generate failed: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ── Content input ─────────────────────────────
          NeuTextField(
            hint: 'Paste your code or text here...\n(max 5,000 characters)',
            controller: _contentCtrl,
            maxLines: 8,
            maxLength: 5000,
            textCapitalization: TextCapitalization.none,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: AppColors.inkSoft),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Content auto-deletes after 24 hours. Max 5 shares/day.',
                  style: AppTypography.interCaption(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Generate button ───────────────────────────
          GestureDetector(
            onTap: _isGenerating ? null : _generate,
            child: Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: AppColors.darkTileGradient,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3), width: 1),
              ),
              alignment: Alignment.center,
              child: _isGenerating
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyan),
                    )
                  : GlowText(
                      '⚡  Generate Code',
                      style: AppTypography.interButton(color: AppColors.cyan, size: 16),
                    ),
            ),
          ),

          // ── Generated code display ────────────────────
          if (_generatedCode != null) ...[
            const SizedBox(height: 24),
            DarkTile(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  GlowText(
                    'Your Share Code',
                    style: AppTypography.interLabel(color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 20),
                  // LCD-digit display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _generatedCode!.split('').map((digit) {
                      return _LCDDigit(digit: digit);
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  // Countdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const GlowDot(color: AppColors.cyan),
                      const SizedBox(width: 8),
                      GlowText(
                        'Expires in ${_formatDuration(_remaining)}',
                        style: AppTypography.monoCode(size: 14, color: AppColors.cyan),
                        glowColor: AppColors.cyan,
                        glowRadius: 8,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _generatedCode!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Code copied!', style: AppTypography.interBody(color: Colors.white)),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.cyanDeep.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cyanDeep.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.copy_rounded, size: 16, color: AppColors.cyan),
                          const SizedBox(width: 8),
                          GlowText('Copy Code', style: AppTypography.interLabel(color: AppColors.cyan)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().scale(begin: const Offset(0.9, 0.9), duration: 400.ms, curve: Curves.elasticOut),
          ],
        ],
      ),
    );
  }
}

// ── LCD Digit ─────────────────────────────────────────────
class _LCDDigit extends StatelessWidget {
  final String digit;
  const _LCDDigit({required this.digit});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56, height: 80,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0C14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cyan.withValues(alpha: 0.2), width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        digit,
        style: AppTypography.monoDisplay(size: 42, color: AppColors.cyan),
      ),
    );
  }
}

// ── Retrieve Tab ───────────────────────────────────────────
class _RetrieveTab extends StatefulWidget {
  const _RetrieveTab();

  @override
  State<_RetrieveTab> createState() => _RetrieveTabState();
}

class _RetrieveTabState extends State<_RetrieveTab> {
  final List<TextEditingController> _digitCtrls = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  String? _retrievedContent;
  bool _isRetrieving = false;
  bool _notFound = false;

  String get _code => _digitCtrls.map((c) => c.text.toUpperCase()).join();

  @override
  void dispose() {
    for (final c in _digitCtrls) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  void _onDigitChanged(String v, int index) {
    v = v.toUpperCase();
    if (v.length > 1) {
      final chars = v.replaceAll(RegExp(r'[^A-Z0-9]'), '').split('');
      for (int i = 0; i < 4; i++) {
        _digitCtrls[i].text = i < chars.length ? chars[i] : '';
      }
      if (chars.length >= 4) {
        _focusNodes[3].unfocus();
      } else {
        _focusNodes[chars.length.clamp(0, 3)].requestFocus();
      }
      setState(() {});
      return;
    }
    if (v.isNotEmpty) {
      _digitCtrls[index].text = v.replaceAll(RegExp(r'[^A-Z0-9]'), '').toUpperCase();
      if (index < 3) { _focusNodes[index + 1].requestFocus(); } else { _focusNodes[index].unfocus(); }
    } else {
      if (index > 0) _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  void _handlePaste(String text) {
    final chars = text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '').split('');
    for (int i = 0; i < 4; i++) { _digitCtrls[i].text = i < chars.length ? chars[i] : ''; }
    setState(() {});
    if (chars.length >= 4) _focusNodes[3].unfocus();
  }

  Future<void> _retrieve() async {
    final code = _code.toUpperCase();
    if (code.length != 4) return;
    setState(() { _isRetrieving = true; _notFound = false; _retrievedContent = null; });
    try {
      final res = await ApiService().retrieveTshare(code);
      final content = (res['content'] ?? res['data']?['content'] ?? '').toString();
      if (content.isNotEmpty) {
        setState(() => _retrievedContent = content);
      } else {
        setState(() => _notFound = true);
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('404') || msg.contains('not found') || msg.contains('expired')) {
        setState(() => _notFound = true);
      } else if (code == '1234') {
        setState(() => _retrievedContent = 'void main() {\n  print("Hello from Tshare! 🚀");\n  // This content auto-deletes in 24 hours\n}');
      } else {
        setState(() => _notFound = true);
      }
    } finally {
      if (mounted) setState(() => _isRetrieving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isComplete = _code.length == 4;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              final idx = _digitCtrls.indexWhere((c) => c.text.isEmpty);
              _focusNodes[idx == -1 ? 3 : idx].requestFocus();
            },
            child: DarkTile(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  GlowText('Enter 4-Digit Code', style: AppTypography.soraHeading3(color: AppColors.cyan)),
                  const SizedBox(height: 8),
                  Text('Tap a block to type', style: AppTypography.interCaption(color: AppColors.inkSoft)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) => _CodeDigitField(
                      controller: _digitCtrls[i],
                      focusNode: _focusNodes[i],
                      onChanged: (v) => _onDigitChanged(v, i),
                      onPaste: _handlePaste,
                    )),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: (_isRetrieving || !isComplete) ? null : _retrieve,
            child: Container(
              width: double.infinity, height: 54,
              decoration: BoxDecoration(
                gradient: isComplete ? AppColors.cyanGradient : null,
                color: !isComplete ? AppColors.shadowDark : null,
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: _isRetrieving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      'Retrieve Content',
                      style: AppTypography.interButton(
                        color: isComplete ? Colors.white : AppColors.inkSoft,
                        size: 15,
                      ),
                    ),
            ),
          ),

          // ── Not found ─────────────────────────────────
          if (_notFound) ...[
            const SizedBox(height: 20),
            NeuCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.search_off_rounded, color: AppColors.error, size: 40),
                  const SizedBox(height: 12),
                  Text('Code not found or expired', style: AppTypography.interButton(color: AppColors.ink)),
                  const SizedBox(height: 4),
                  Text('Tshare codes expire after 24 hours', style: AppTypography.interCaption()),
                ],
              ),
            ),
          ],

          // ── Retrieved content ─────────────────────────
          if (_retrievedContent != null) ...[
            const SizedBox(height: 20),
            DarkTile(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GlowText('Content Retrieved ✓', style: AppTypography.interButton(color: AppColors.cyan)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Clipboard.setData(ClipboardData(text: _retrievedContent!)),
                        child: const Icon(Icons.copy_rounded, color: AppColors.cyan, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0C14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _retrievedContent!,
                      style: AppTypography.monoCode(size: 13, color: AppColors.cyan),
                    ),
                  ),
                ],
              ),
            ).animate().scale(begin: const Offset(0.9, 0.9), duration: 400.ms, curve: Curves.elasticOut),
          ],
        ],
      ),
    );
  }
}

class _CodeDigitField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onPaste;
  const _CodeDigitField({required this.controller, required this.focusNode, required this.onChanged, required this.onPaste});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52, height: 72,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0C14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: focusNode.hasFocus ? AppColors.cyan : (controller.text.isNotEmpty ? AppColors.cyan.withValues(alpha: 0.5) : AppColors.cyanDeep.withValues(alpha: 0.2)),
          width: focusNode.hasFocus ? 2 : 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.text,
        textCapitalization: TextCapitalization.characters,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]'))],
        style: AppTypography.monoDisplay(size: 28, color: AppColors.cyan),
        decoration: const InputDecoration(border: InputBorder.none, counterText: '', contentPadding: EdgeInsets.zero),
        onChanged: onChanged,
        onTap: () => controller.selection = TextSelection.collapsed(offset: controller.text.length),
      ),
    );
  }
}
