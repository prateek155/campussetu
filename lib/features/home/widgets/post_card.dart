// lib/features/home/widgets/post_card.dart
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/neu_card.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/models/post_model.dart';

class PostCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onReport;

  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: NeuCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Sponsored label ─────────────────────────
            if (post.isSponsored)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.campaign_outlined, size: 13, color: AppColors.warning),
                    const SizedBox(width: 4),
                    Text('Sponsored', style: AppTypography.interBadge(color: AppColors.warning)),
                  ],
                ),
              ),

            // ── Author row ──────────────────────────────
            Row(
              children: [
                UserAvatar(
                  name: post.author.name,
                  imageUrl: post.author.photoUrl,
                  size: 42,
                  isVerified: post.author.isVerified,
                  isPremium: post.author.isPremium,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.author.name, style: AppTypography.interButton(color: AppColors.ink, size: 14)),
                      Text(
                        post.author.college ?? post.author.email,
                        style: AppTypography.interCaption(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  timeago.format(post.createdAt, locale: 'en_short'),
                  style: AppTypography.monoTimestamp(),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _showPostOptions(context),
                  child: Icon(Icons.more_vert_rounded, size: 20, color: AppColors.inkSoft),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Content ─────────────────────────────────
            Text(
              post.content,
              style: AppTypography.interBody(color: AppColors.ink, size: 14, height: 1.6),
            ),

            // ── Image ───────────────────────────────────
            if (post.imageUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  post.imageUrl!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            ],

            const SizedBox(height: 14),

            // ── Action bar ──────────────────────────────
            if (!post.isSponsored)
              Row(
                children: [
                  _ActionBtn(
                    icon: post.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    label: post.likesCount > 0 ? '${post.likesCount}' : 'Like',
                    color: post.isLiked ? AppColors.error : AppColors.inkSoft,
                    onTap: onLike,
                  ),
                  const SizedBox(width: 6),
                  _ActionBtn(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: post.commentsCount > 0 ? '${post.commentsCount}' : 'Comment',
                    onTap: onComment,
                  ),
                  const Spacer(),
                  _ActionBtn(
                    icon: Icons.share_outlined,
                    label: 'Share',
                    onTap: onShare,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showPostOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppColors.neuRaisedShadows,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.shadowDark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            _OptionTile(
              icon: Icons.flag_outlined,
              label: 'Report Post',
              color: AppColors.error,
              onTap: () {
                Navigator.pop(context);
                onReport();
              },
            ),
            _OptionTile(
              icon: Icons.block_outlined,
              label: 'Not interested',
              onTap: () => Navigator.pop(context),
            ),
            _OptionTile(
              icon: Icons.share_outlined,
              label: 'Share',
              onTap: () {
                Navigator.pop(context);
                onShare();
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  _ActionBtn({
    required this.icon,
    required this.label,
    Color? color,
    required this.onTap,
  }) : color = color ?? AppColors.inkSoft;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(width: 6),
            Text(label, style: AppTypography.interBody(color: color, size: 13).copyWith(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  _OptionTile({
    required this.icon,
    required this.label,
    Color? color,
    required this.onTap,
  }) : color = color ?? AppColors.ink;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: AppTypography.interBody(color: color)),
      onTap: onTap,
    );
  }
}
