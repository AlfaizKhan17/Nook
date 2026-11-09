import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool light;
  const AppLogo({super.key, this.size = 70, this.light = false});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final foreground = light ? Colors.white : Theme.of(context).colorScheme.onSurface;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: size, height: size, decoration: BoxDecoration(color: accent.withValues(alpha: .14), shape: BoxShape.circle, border: Border.all(color: accent.withValues(alpha: .45))),
        child: Icon(Icons.spa_rounded, size: size * .52, color: accent)),
      const SizedBox(height: 10),
      Text('nook.', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: foreground, fontSize: size * .40, fontWeight: FontWeight.w800, letterSpacing: -1.2)),
      const SizedBox(height: 4),
      Text('A little place for your campus life.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: foreground.withValues(alpha: .75), fontSize: 10.5)),
    ]);
  }
}
