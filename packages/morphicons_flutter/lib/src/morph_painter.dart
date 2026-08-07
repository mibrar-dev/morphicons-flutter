/// MorphPainter: CustomPainter that renders a morph plan at progress t.
///
/// Takes a plan + progress t, builds a dart:ui.Path from the interpolated
/// polyline points (stroke style: PaintingStyle.stroke, StrokeCap.round,
/// StrokeJoin.round, given strokeWidth/color), and snaps to the exact
/// canonical target icon paths when settled (t >= 1 / spring settled) so a
/// resting icon is pixel-identical to a static one.
///
/// Only touches dart:ui here — never in morphicons_core.
library;

import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:morphicons_core/morphicons_core.dart';

/// CustomPainter for rendering a morph plan at progress t.
///
/// When [t] >= 1, paints the exact canonical shape from [canonicalPaths]
/// instead of the interpolated polyline for pixel-perfect rest state.
class MorphPainter extends CustomPainter {
  /// The morph plan to render. Null when at rest (use canonicalPaths).
  final MorphPlan? plan;

  /// Interpolated output buffers (preallocated, zero allocation per frame).
  final List<Float64List>? out;

  /// Progress through the morph (0..1). Values > 1 are extrapolation (overshoot).
  final double t;

  /// Canonical cubic paths for the target icon (for exact t=1 rendering).
  /// When provided and t >= 1, this is painted instead of the polyline.
  final List<CubicPath>? canonicalPaths;

  /// Stroke width for the path.
  final double strokeWidth;

  /// Stroke color for the path.
  final Color color;

  /// Icon coordinate-space extent (icons are drawn in this box and scaled
  /// to the paint size). Defaults to the canonical 24×24 grid.
  final double viewBox;

  MorphPainter({
    required this.plan,
    required this.out,
    required this.t,
    this.canonicalPaths,
    this.strokeWidth = 2,
    this.color = const Color(0xFF000000),
    this.viewBox = 24,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..color = color;

    // Icon geometry lives in the viewBox square; scale to the paint size.
    canvas.save();
    canvas.scale(size.width / viewBox, size.height / viewBox);
    try {
      // When t >= 1 and we have canonical paths, render them exactly.
      // This ensures pixel-perfect matching with a static icon at rest.
      if (t >= 1 && canonicalPaths != null) {
        final path = _cubicsToPath(canonicalPaths!);
        canvas.drawPath(path, paint);
        return;
      }

      // Otherwise, render the interpolated polyline.
      if (plan == null || out == null) return;

      // Interpolate to the current t.
      interpPolar(plan!, t, out!);

      // Build the path from interpolated polyline points.
      final closed = plan!.items.map((it) => it.closed).toList();
      final path = _polylineToPath(out!, closed);
      canvas.drawPath(path, paint);
    } finally {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant MorphPainter oldDelegate) {
    return t != oldDelegate.t ||
        plan != oldDelegate.plan ||
        color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth ||
        canonicalPaths != oldDelegate.canonicalPaths;
  }
}

/// Converts a list of CubicPath to a single dart:Path.
Path _cubicsToPath(List<CubicPath> paths) {
  final path = Path();
  for (final cubic in paths) {
    final pts = cubic.pts;
    if (pts.length < 2) continue;

    path.moveTo(pts[0], pts[1]);

    // Each cubic segment has 6 values: c1x, c1y, c2x, c2y, x, y
    for (var i = 2; i < pts.length; i += 6) {
      path.cubicTo(
        pts[i], pts[i + 1], // first control point
        pts[i + 2], pts[i + 3], // second control point
        pts[i + 4], pts[i + 5], // end point
      );
    }

    if (cubic.closed) path.close();
  }
  return path;
}

/// Converts interpolated polyline points to a dart:Path.
Path _polylineToPath(List<Float64List> subs, List<bool> closed) {
  final path = Path();
  for (var k = 0; k < subs.length; k++) {
    final pts = subs[k];
    final n = pts.length ~/ 2;
    if (n < 1) continue;

    path.moveTo(pts[0], pts[1]);
    for (var i = 1; i < n; i++) {
      path.lineTo(pts[2 * i], pts[2 * i + 1]);
    }

    if (closed[k]) path.close();
  }
  return path;
}
