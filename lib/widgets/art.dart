import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Original header artwork: dusk sky, soft sun, temple-tower silhouettes and
/// a faint lotus pattern. Drawn in code - no image assets needed.
class TempleHeaderPainter extends CustomPainter {
  const TempleHeaderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
        rect, Paint()..shader = RB.headerGradient.createShader(rect));

    // Sun glow
    final sunC = Offset(size.width * 0.80, size.height * 0.62);
    canvas.drawCircle(
      sunC,
      size.width * 0.32,
      Paint()
        ..shader = RadialGradient(colors: [
          RB.gold.withValues(alpha: 0.35),
          RB.gold.withValues(alpha: 0.0),
        ]).createShader(
            Rect.fromCircle(center: sunC, radius: size.width * 0.32)),
    );

    // Lotus pattern
    final lotus = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var y = 20.0; y < size.height; y += 46) {
      for (var x = (y ~/ 46).isEven ? 10.0 : 33.0; x < size.width; x += 46) {
        _petal(canvas, Offset(x, y), 9, lotus);
      }
    }

    // Temple towers (back row, then front row)
    final base = size.height * 0.98;
    final back = Paint()..color = RB.night.withValues(alpha: 0.35);
    final front = Paint()..color = RB.night.withValues(alpha: 0.55);
    final w = size.width;
    _tower(canvas, Offset(w * 0.62, base), w * 0.09, size.height * 0.36, back);
    _tower(canvas, Offset(w * 0.94, base), w * 0.09, size.height * 0.36, back);
    _tower(canvas, Offset(w * 0.70, base), w * 0.11, size.height * 0.46, front);
    _tower(canvas, Offset(w * 0.86, base), w * 0.11, size.height * 0.46, front);
    _tower(canvas, Offset(w * 0.78, base), w * 0.14, size.height * 0.62, front);
    canvas.drawRect(
      Rect.fromLTRB(w * 0.52, base - 6, w, size.height),
      front,
    );
  }

  void _petal(Canvas c, Offset o, double r, Paint p) {
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      c.drawOval(
        Rect.fromCenter(
          center: o + Offset(math.cos(a) * r * 0.6, math.sin(a) * r * 0.6),
          width: r * (i.isEven ? 1.3 : 0.6),
          height: r * (i.isEven ? 0.6 : 1.3),
        ),
        p,
      );
    }
  }

  /// Stacked tiers narrowing to a lotus-bud spire.
  void _tower(Canvas c, Offset base, double width, double height, Paint p) {
    const tiers = 5;
    final path = Path();
    final tierH = height * 0.72 / tiers;
    var y = base.dy;
    for (var i = 0; i < tiers; i++) {
      final wBottom = width * (1 - i * 0.16);
      final wTop = width * (1 - (i + 1) * 0.16) * 1.08;
      path.addPolygon([
        Offset(base.dx - wBottom / 2, y),
        Offset(base.dx + wBottom / 2, y),
        Offset(base.dx + wTop / 2, y - tierH),
        Offset(base.dx - wTop / 2, y - tierH),
      ], true);
      y -= tierH;
    }
    final spireW = width * 0.22;
    path.moveTo(base.dx - spireW / 2, y);
    path.quadraticBezierTo(
        base.dx - spireW / 2, y - height * 0.2, base.dx, base.dy - height);
    path.quadraticBezierTo(
        base.dx + spireW / 2, y - height * 0.2, base.dx + spireW / 2, y);
    path.close();
    c.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Romdoul (Cambodia's national flower) mark - three soft petals.
class RomdoulLogo extends StatelessWidget {
  const RomdoulLogo({super.key, this.size = 36});
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _LogoPainter());
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = RB.cream);
    final petal = Paint()
      ..shader = const LinearGradient(colors: [RB.gold, RB.goldDeep])
          .createShader(Offset.zero & size);
    for (var i = 0; i < 3; i++) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(i * 2 * math.pi / 3 - math.pi / 2);
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(r * 0.36, 0), width: r * 0.78, height: r * 0.52),
        petal,
      );
      canvas.restore();
    }
    canvas.drawCircle(c, r * 0.16, Paint()..color = RB.teal);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
