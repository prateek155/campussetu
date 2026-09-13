// lib/core/widgets/neu_text_field.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Inset-style text field — visually "pressed in" to read as interactive.
/// Uses the neu-inset shadow pattern from the design spec.
class NeuTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int maxLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final FocusNode? focusNode;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final bool autofocus;
  final TextCapitalization textCapitalization;

  const NeuTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.maxLength,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  State<NeuTextField> createState() => _NeuTextFieldState();
}

class _NeuTextFieldState extends State<NeuTextField> {
  bool _hasFocus = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(() {
      setState(() => _hasFocus = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: AppTypography.interLabel()),
          const SizedBox(height: 8),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(18),
            boxShadow: _hasFocus
                ? [
                    ...AppColors.neuInsetShadows,
                    BoxShadow(
                      color: AppColors.cyanDeep.withValues(alpha: 0.15),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : AppColors.neuInsetShadows,
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            validator: widget.validator,
            keyboardType: widget.keyboardType,
            obscureText: widget.obscureText,
            maxLines: widget.maxLines,
            maxLength: widget.maxLength,
            onChanged: widget.onChanged,
            onTap: widget.onTap,
            readOnly: widget.readOnly,
            autofocus: widget.autofocus,
            textCapitalization: widget.textCapitalization,
            textInputAction: widget.textInputAction,
            onFieldSubmitted: widget.onFieldSubmitted,
            style: AppTypography.interBody(color: AppColors.ink),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: AppTypography.interBody(color: AppColors.inkMuted),
              prefixIcon: widget.prefixIcon,
              suffixIcon: widget.suffixIcon,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              counterText: '',
            ),
          ),
        ),
      ],
    );
  }
}

/// Inset container for any non-text pressed content (search bars, dropdowns)
class NeuInset extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;

  const NeuInset({
    super.key,
    required this.child,
    this.borderRadius = 18,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: AppColors.neuInsetShadows,
      ),
      child: child,
    );
  }
}
