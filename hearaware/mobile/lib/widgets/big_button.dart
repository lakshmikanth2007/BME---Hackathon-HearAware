import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = true,
    this.color,
    this.semanticsLabel,
    this.height = 72,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool filled;
  final Color? color;
  final String? semanticsLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.accent;
    final fg = filled ? (c == AppColors.accent ? AppColors.onAccent : Colors.black) : c;
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 30, color: fg), const SizedBox(width: 12)],
        Flexible(
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: fg, letterSpacing: 0.5)),
        ),
      ],
    );
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: filled
            ? FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: c,
                  disabledBackgroundColor: AppColors.surfaceHi,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: onPressed,
                child: child)
            : OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: c, width: 3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: onPressed,
                child: child),
      ),
    );
  }
}
