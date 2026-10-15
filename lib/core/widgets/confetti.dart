import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One-shot confetti burst. Mount it to play it.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key});

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _Piece {
  _Piece({
    required this.vx,
    required this.vy,
    required this.size,
    required this.rot,
    required this.vr,
    required this.color,
    required this.round,
  });

  final double vx, vy, size, rot, vr;
  final Color color;
  final bool round;
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..forward();
  late final List<_Piece> _pieces;

  @override
  void initState() {
    super.initState();
    final r = math.Random();
    const colors = [
      Color(0xFF178A55),
      Color(0xFF52B788),
      Color(0xFFF5B83D),
      Color(0xFF7C5CFC),
      Color(0xFFE8693F),
      Color(0xFF3B9AE1),
      Color(0xFFE05A9A),
    ];
    _pieces = List.generate(80, (i) {
      return _Piece(
        vx: (r.nextDouble() - 0.5) * 1.5,
        vy: 0.1 + r.nextDouble() * 0.5,
        size: 6 + r.nextDouble() * 7,
        rot: r.nextDouble() * math.pi,
        vr: (r.nextDouble() - 0.5) * 12,
        color: colors[r.nextInt(colors.length)],
        round: r.nextBool(),
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_pieces, _c.value),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final fade = t < 0.75 ? 1.0 : 1.0 - (t - 0.75) / 0.25;
    for (final p in pieces) {
      final x = (0.5 + p.vx * t) * size.width;
      final y = (-0.05 + p.vy * t * 1.4 + 1.1 * t * t) * size.height;
      final paint = Paint()..color = p.color.withValues(alpha: fade.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rot + p.vr * t);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
