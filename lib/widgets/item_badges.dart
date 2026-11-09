import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// "LOST" / "FOUND" pill that stays readable in both light and dark mode.
class TypeBadge extends StatelessWidget {
  final String type;
  const TypeBadge({super.key, required this.type});

  /// (foreground, background) for a listing type in the current brightness.
  static (Color, Color) colorsFor(BuildContext context, String type) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (type == 'FOUND') {
      return (
        dark ? AppColors.found : const Color(0xFF1B7F37),
        dark ? AppColors.foundBg : const Color(0xFFE2F6E7),
      );
    }
    return (
      dark ? AppColors.lost : const Color(0xFFD70015),
      dark ? AppColors.lostBg : const Color(0xFFFFE5E3),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = colorsFor(context, type);
    return _Pill(label: type, foreground: fg, background: bg);
  }
}

/// Shown on listings the owner has marked as resolved.
class ResolvedBadge extends StatelessWidget {
  const ResolvedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Pill(
      label: 'RESOLVED',
      foreground: scheme.onSurfaceVariant,
      background: scheme.surfaceContainerHighest,
      icon: Icons.check_circle_outline_rounded,
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color foreground;
  final Color background;
  final IconData? icon;

  const _Pill({
    required this.label,
    required this.foreground,
    required this.background,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(30)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: foreground),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: TextStyle(color: foreground, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .3),
        ),
      ]),
    );
  }
}
