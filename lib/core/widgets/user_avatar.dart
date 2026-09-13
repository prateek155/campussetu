// lib/core/widgets/user_avatar.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// User avatar with neumorphic border and optional verified/premium badge
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double size;
  final bool showNeuBorder;
  final bool isVerified;
  final bool isPremium;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 48,
    this.showNeuBorder = false,
    this.isVerified = false,
    this.isPremium = false,
    this.onTap,
  });

  String get _initials {
    if (name == null || name!.isEmpty) return '?';
    final parts = name!.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }

  Color get _avatarColor {
    if (name == null) return AppColors.cyanDeep;
    final colors = [
      const Color(0xFF3FD8F5),
      const Color(0xFF7C3AED),
      const Color(0xFF059669),
      const Color(0xFFDC2626),
      const Color(0xFFD97706),
      const Color(0xFF2563EB),
    ];
    final index = (name!.codeUnitAt(0)) % colors.length;
    return colors[index];
  }

  @override
  Widget build(BuildContext context) {
    Widget avatar = CircleAvatar(
      radius: size / 2,
      backgroundColor: _avatarColor.withValues(alpha: 0.2),
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _buildInitials(),
                placeholder: (_, __) => _buildInitials(),
              ),
            )
          : _buildInitials(),
    );

    if (showNeuBorder) {
      avatar = Container(
        width: size + 8,
        height: size + 8,
        decoration: BoxDecoration(
          color: AppColors.bg,
          shape: BoxShape.circle,
          boxShadow: AppColors.neuSmallShadows,
        ),
        child: Center(child: avatar),
      );
    }

    if (isVerified || isPremium) {
      avatar = Stack(
        children: [
          avatar,
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: size * 0.32,
              height: size * 0.32,
              decoration: BoxDecoration(
                color: isPremium ? AppColors.gold : AppColors.cyanDeep,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.bg, width: 2),
              ),
              child: Icon(
                isPremium ? Icons.workspace_premium : Icons.verified,
                color: Colors.white,
                size: size * 0.18,
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatar);
    }
    return avatar;
  }

  Widget _buildInitials() {
    return Text(
      _initials,
      style: AppTypography.interButton(
        color: _avatarColor,
        size: size * 0.35,
      ),
    );
  }
}
