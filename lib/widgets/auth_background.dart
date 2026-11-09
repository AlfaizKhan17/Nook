import 'dart:math' as math;
import 'dart:ui' show PointMode;
import 'package:flutter/material.dart';

/// Deep-navy "aurora" backdrop for the sign-in and register screens.
///
/// Drawn entirely in code (gradient, soft drifting glows, a faint dot grid and
/// concentric rings), so it needs no image assets and stays sharp on every
/// screen size. The glows drift slowly; the animation is switched off when the
/// device asks to reduce motion.
class AuthBackground extends StatefulWidget {
  final Widget child;
  const AuthBackground({super.key, required this.child});

  @override
  State<AuthBackground> createState() => _AuthBackgroundState();
}

class _AuthBackgroundState extends State<AuthBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 22));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Static layers are cached; only the glows repaint each frame.
        const RepaintBoundary(child: CustomPaint(painter: _BackdropPainter())),
        RepaintBoundary(child: CustomPaint(painter: _GlowPainter(_controller))),
        widget.child,
      ],
    );
  }
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Base gradient: near-black navy into a rich blue.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF050B1F), Color(0xFF0A1F5C), Color(0xFF0B3C9E)],
          stops: [0, .55, 1],
        ).createShader(rect),
    );

    // Concentric rings, top-right and bottom-left.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x12FFFFFF);
    final topRight = Offset(size.width * .90, size.height * .08);
    for (var r = 90.0; r < size.longestSide * .9; r += 74) {
      canvas.drawCircle(topRight, r, ring);
    }
    final fainter = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x0AFFFFFF);
    final bottomLeft = Offset(size.width * .02, size.height * .98);
    for (var r = 70.0; r < size.longestSide * .6; r += 74) {
      canvas.drawCircle(bottomLeft, r, fainter);
    }

    // Faint dot grid.
    const gap = 28.0;
    final dots = <Offset>[
      for (var y = gap / 2; y < size.height; y += gap)
        for (var x = gap / 2; x < size.width; x += gap) Offset(x, y),
    ];
    canvas.drawPoints(
      PointMode.points,
      dots,
      Paint()
        ..color = const Color(0x14FFFFFF)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Gentle darkening toward the bottom for depth.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0x59000000)],
          stops: [.45, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GlowPainter extends CustomPainter {
  final Animation<double> animation;
  _GlowPainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value * 2 * math.pi;

    void glow(Offset center, double radius, Color color) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ).createShader(rect),
      );
    }

    final base = size.shortestSide;
    glow(
      Offset(size.width * (.14 + .06 * math.sin(t)), size.height * (.12 + .04 * math.cos(t))),
      base * .95,
      const Color(0x990A84FF),
    );
    glow(
      Offset(size.width * (.96 + .05 * math.cos(t + 1)), size.height * (.46 + .05 * math.sin(t + 2))),
      base * .80,
      const Color(0x735E5CE6),
    );
    glow(
      Offset(size.width * (.30 + .08 * math.sin(t + 3)), size.height * (.99 + .02 * math.cos(t))),
      base * .95,
      const Color(0x4064D2FF),
    );
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) => oldDelegate.animation != animation;
}
