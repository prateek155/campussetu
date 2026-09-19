import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/neu_card.dart';
import '../../core/widgets/neu_text_field.dart';
import '../../core/widgets/user_avatar.dart';

class TransferPointsScreen extends ConsumerStatefulWidget {
  final String? toCampusId;
  final String? toName;
  const TransferPointsScreen({super.key, this.toCampusId, this.toName});
  @override
  ConsumerState<TransferPointsScreen> createState() => _TransferPointsScreenState();
}

class _TransferPointsScreenState extends ConsumerState<TransferPointsScreen> {
  late final _idCtrl = TextEditingController(text: widget.toCampusId ?? '');
  final _amountCtrl = TextEditingController();
  Map<String, dynamic>? _receiver;
  bool _lookingUp = false;
  bool _sending = false;
  String? _lookupError;

  @override
  void initState() {
    super.initState();
    if (widget.toCampusId != null && widget.toCampusId!.isNotEmpty) _lookup();
  }

  @override
  void dispose() { _idCtrl.dispose(); _amountCtrl.dispose(); super.dispose(); }

  Future<void> _ensureToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      if (token != null) ApiService().setToken(token);
    }
  }

  Future<void> _lookup() async {
    final id = _idCtrl.text.trim().toUpperCase();
    if (id.isEmpty) {
      setState(() { _lookupError = 'Campus ID daalo (e.g. CS-AB12CD)'; _receiver = null; });
      return;
    }
    setState(() { _lookingUp = true; _lookupError = null; _receiver = null; });
    try {
      await _ensureToken();
      final r = await ApiService().getUserByCampusId(id);
      setState(() => _receiver = r);
    } catch (_) {
      setState(() => _lookupError = 'Student nahi mila. ID check karo.');
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  Future<void> _send() async {
    final amount = int.tryParse(_amountCtrl.text.trim());
    if (_receiver == null) { _err('Pehle student verify karo'); return; }
    if (amount == null || amount <= 0) { _err('Valid points daalo'); return; }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Send $amount points?', style: AppTypography.soraHeading3()),
        content: Text('${_receiver!['name']} (${_receiver!['campus_id']}) ko $amount points transfer honge. Ye undo nahi hoga.', style: AppTypography.interBody()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyanDeep), onPressed: () => Navigator.pop(ctx, true), child: const Text('Send', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (ok != true || _sending) return;
    final preBal = ref.read(currentUserProvider).value?.points;
    setState(() => _sending = true);
    try {
      await _ensureToken();
      final res = await ApiService().transferPoints(toCampusId: (_receiver!['campus_id'] ?? '').toString(), amount: amount);
      final meJson = await ApiService().getMe();
      final meData = meJson.containsKey('data') ? meJson['data'] : meJson;
      final serverBal = int.tryParse('${(meData as Map)['points'] ?? ''}');
      ref.invalidate(currentUserProvider);
      ref.invalidate(profileProvider(null));
      if (!mounted) return;
      // Verify transfer: new balance should be less than old balance
      if (serverBal != null && preBal != null && serverBal >= preBal) {
        _err('Transfer verify nahi hua (balance unchanged). Please retry.');
        return;
      }
      final showBal = serverBal ?? res['new_balance'];
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✓ $amount points sent to ${res['to']} • Balance: $showBal'), backgroundColor: AppColors.success));
      context.pop();
    } catch (e) {
      var msg = e.toString();
      if (msg.contains('Insufficient')) {
        final i = msg.indexOf('Balance');
        _err(i > 0 ? 'Insufficient points. ${msg.substring(i, i + 20)}' : 'Insufficient points balance');
      } else {
        _err('Failed: ${msg.length > 120 ? msg.substring(0, 120) : msg}');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _err(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: AppColors.error));

  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(currentUserProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(backgroundColor: AppColors.bg, elevation: 0, leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: AppColors.ink), onPressed: () => context.pop()), title: Text('Send Points', style: AppTypography.soraHeading3())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          meAsync.when(
            data: (u) => NeuCard(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.stars_rounded, color: AppColors.warning, size: 26),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Your balance', style: AppTypography.interCaption()),
                  Text('${u.points} points', style: AppTypography.soraHeading2(color: AppColors.warning)),
                ]),
              ]),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          Text('Student ka Campus ID', style: AppTypography.interButton(size: 13)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: NeuTextField(hint: 'e.g. CS-AB12CD', controller: _idCtrl, textCapitalization: TextCapitalization.characters, onFieldSubmitted: (_) => _lookup())),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _lookingUp ? null : _lookup,
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15), decoration: BoxDecoration(gradient: AppColors.cyanGradient, borderRadius: BorderRadius.circular(14)), child: _lookingUp ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('Verify', style: AppTypography.interButton(color: Colors.white))),
            ),
          ]),
          if (_lookupError != null) ...[const SizedBox(height: 8), Text(_lookupError!, style: AppTypography.interBody(color: AppColors.error, size: 13))],
          if (_receiver != null) ...[
            const SizedBox(height: 12),
            NeuCard(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                UserAvatar(name: (_receiver!['name'] ?? '?').toString(), imageUrl: _receiver!['photo_url']?.toString(), size: 46),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Text((_receiver!['name'] ?? '').toString(), style: AppTypography.interButton(size: 15)), const SizedBox(width: 6), const Icon(Icons.verified_rounded, color: AppColors.success, size: 15)]),
                  Text('${(_receiver!['college'] ?? '').toString()} • ${(_receiver!['city'] ?? '').toString()}', style: AppTypography.interCaption(), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text((_receiver!['campus_id'] ?? '').toString(), style: AppTypography.monoCode(size: 13, color: AppColors.cyanDeep, weight: FontWeight.w700)),
                ])),
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
              ]),
            ),
            const SizedBox(height: 16),
            Text('Kitne points bhejne hai?', style: AppTypography.interButton(size: 13)),
            const SizedBox(height: 8),
            NeuTextField(hint: 'e.g. 50', controller: _amountCtrl, keyboardType: TextInputType.number),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [10, 25, 50, 100].map((v) => GestureDetector(onTap: () => setState(() => _amountCtrl.text = '$v'), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Text('+$v', style: AppTypography.interButton(color: AppColors.warning, size: 12))))).toList()),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: _sending ? null : _send,
              child: Container(width: double.infinity, height: 54, decoration: BoxDecoration(gradient: AppColors.cyanGradient, borderRadius: BorderRadius.circular(16)), alignment: Alignment.center, child: _sending ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('Send Points', style: AppTypography.interButton(color: Colors.white))),
            ),
          ],
          const SizedBox(height: 16),
          NeuCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Points kaise kamaye?', style: AppTypography.interButton(size: 13)),
              const SizedBox(height: 6),
              Text('• New account: 25 bonus\n• Post likes: har 100 likes = 20 pts\n• Points task complete: helper ko reward\n• Admin reward', style: AppTypography.interBody(size: 12, color: AppColors.inkSoft, height: 1.7)),
            ]),
          ),
        ]),
      ),
    );
  }
}
