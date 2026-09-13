// lib/core/widgets/neu_dropdown.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class NeuDropdown<T> extends StatelessWidget {
  final String? label;
  final String hint;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  const NeuDropdown({
    super.key,
    this.label,
    required this.hint,
    this.value,
    required this.items,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: AppTypography.interLabel()),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppColors.neuInsetShadows,
          ),
          child: DropdownButtonFormField<T>(
            initialValue: value,
            items: items,
            onChanged: onChanged,
            hint: Text(hint, style: AppTypography.interBody(color: AppColors.inkMuted)),
            style: AppTypography.interBody(color: AppColors.ink),
            dropdownColor: AppColors.bg,
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.inkSoft),
          ),
        ),
      ],
    );
  }
}
