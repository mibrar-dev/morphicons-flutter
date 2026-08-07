import 'package:flutter/material.dart';
import 'package:morphicons_core/morphicons_core.dart';

/// Static lucide-style icon rendered from its `d` data via morphicons_core.
///
/// Small CustomPaint helper for the icon grid: the 24×24 icon space is
/// scaled to the widget size and stroked with round caps/joins.
class StaticIcon extends StatelessWidget {
  final String d;
  final double size;
  final double strokeWidth;
  final Color? color;

  const StaticIcon({
    super.key,
    required this.d,
    this.size = 24,
    this.strokeWidth = 2,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _StaticIconPainter(
        paths: iconToCubics(d),
        strokeWidth: strokeWidth,
        color: color ?? DefaultTextStyle.of(context).style.color,
      ),
    );
  }
}

class _StaticIconPainter extends CustomPainter {
  final List<CubicPath> paths;
  final double strokeWidth;
  final Color? color;

  _StaticIconPainter({
    required this.paths,
    required this.strokeWidth,
    this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth / scale
      ..color = color ?? const Color(0xFF000000);

    canvas.save();
    canvas.scale(scale);
    final path = Path();
    for (final cubic in paths) {
      final pts = cubic.pts;
      if (pts.length < 2) continue;
      path.moveTo(pts[0], pts[1]);
      for (var i = 2; i < pts.length; i += 6) {
        path.cubicTo(
          pts[i], pts[i + 1],
          pts[i + 2], pts[i + 3],
          pts[i + 4], pts[i + 5],
        );
      }
      if (cubic.closed) path.close();
    }
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StaticIconPainter oldDelegate) =>
      paths != oldDelegate.paths ||
      strokeWidth != oldDelegate.strokeWidth ||
      color != oldDelegate.color;
}
