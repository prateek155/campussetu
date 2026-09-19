import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/models/user_model.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/dark_tile.dart';
import '../../../core/widgets/user_avatar.dart';

class CampusIdCard extends StatelessWidget {
  final UserModel user;
  final bool isOwn;
  const CampusIdCard({super.key, required this.user, this.isOwn = false});

  String get _place {
    final parts = <String>[];
    if ((user.city ?? '').isNotEmpty) parts.add(user.city!);
    if ((user.state ?? '').isNotEmpty) parts.add(user.state!);
    final loc = parts.join(', ');
    if (loc.isNotEmpty && (user.college ?? '').isNotEmpty) return '$loc • ${user.college}';
    if (loc.isNotEmpty) return loc;
    return user.college ?? 'CampusSetu Student';
  }

  void _copy(BuildContext context) {
    final id = user.campusId ?? '';
    if (id.isEmpty) return;
    Clipboard.setData(ClipboardData(text: id));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Campus ID copied ✓'), backgroundColor: AppColors.success));
  }

  void _share() {
    final id = user.campusId ?? '';
    if (id.isEmpty) return;
    Share.share('My CampusSetu ID: $id (${user.name}). Send me points on CampusSetu!', subject: 'My Campus ID');
  }

  @override
  Widget build(BuildContext context) {
    return DarkTile(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          UserAvatar(name: user.name, imageUrl: user.photoUrl, size: 52, isVerified: user.isVerified),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(user.name, style: AppTypography.interButton(color: Colors.white, size: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (user.isVerified) const Icon(Icons.verified_rounded, color: AppColors.cyan, size: 16),
            ]),
            const SizedBox(height: 2),
            Text(_place, style: AppTypography.interCaption(color: AppColors.inkSoft), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.emoji_events_rounded, size: 14, color: AppColors.warning),
                const SizedBox(width: 5),
                Text('${user.points} points', style: AppTypography.interButton(color: AppColors.warning, size: 13)),
              ]),
            ),
          ])),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3))),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('CAMPUS ID', style: AppTypography.interBadge(color: AppColors.inkSoft)),
              const SizedBox(height: 2),
              Text(user.campusId ?? '…', style: AppTypography.monoCode(size: 19, weight: FontWeight.w800, color: AppColors.cyan)),
            ])),
            IconButton(onPressed: () => _copy(context), icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 19), tooltip: 'Copy'),
            IconButton(onPressed: _share, icon: const Icon(Icons.share_outlined, color: Colors.white70, size: 19), tooltip: 'Share'),
          ]),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => context.push(AppRoutes.pointsTransfer, extra: isOwn ? null : {'toCampusId': user.campusId, 'toName': user.name}),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(gradient: AppColors.cyanGradient, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.send_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(isOwn ? 'Send Points to a Student' : 'Send Points to ${user.name.split(' ').first}', style: AppTypography.interButton(color: Colors.white, size: 13)),
            ]),
          ),
        ),
      ]),
    );
  }
}
