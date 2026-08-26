/// MorphPainter: CustomPainter that renders a morph plan at progress t.
///
/// Takes a plan + progress t, builds a dart:ui.Path from the interpolated
/// polyline points (stroke style: PaintingStyle.stroke, StrokeCap.round,
/// StrokeJoin.round, given strokeWidth/color), and snaps to the exact
/// canonical target icon paths when [canonicalSnap] is true so a resting
/// icon is pixel-identical to a static one.
///
/// Only touches dart:ui here — never in morphicons_core.
library;

import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:morphicons_core/morphicons_core.dart';

/// CustomPainter for rendering a morph plan at progress t.
///
/// When [canonicalSnap] is true, paints the exact canonical shape from
/// [canonicalPaths] instead of the interpolated polyline. Callers are
/// responsible for deciding when to snap:
///
/// * **Uncontrolled settled**: pass `canonicalSnap: true` after the spring
///   has fully settled at its target.
/// * **Controlled t == 1**: pass `canonicalSnap: true` for pixel-perfect
///   rendering at exactly t = 1.
/// * **Controlled t > 1 (overshoot)**: pass `canonicalSnap: false` so the
///   extrapolated frame remains visible.
/// * **In-flight**: pass `canonicalSnap: false`.
class MorphPainter extends CustomPainter {
  /// The morph plan to render. Null when using canonical snap only.
  final MorphPlan? plan;

  /// Interpolated output buffers (preallocated, zero allocation per frame).
  final List<Float64List>? out;

  /// Progress through the morph (0..1 typical; < 0 or > 1 extrapolates).
  final double t;

  /// Canonical cubic paths for the target icon (for exact t = 1 rendering).
  final List<CubicPath>? canonicalPaths;

  /// When true, paints [canonicalPaths] exactly instead of the polyline.
  ///
  /// Pass true for a fully-settled uncontrolled icon or controlled t == 1.
  /// Pass false for in-flight springs and controlled t > 1 (overshoot).
  final bool canonicalSnap;

  /// Stroke width for the path.
  final double strokeWidth;

  /// Stroke color for the path.
  final Color color;

  /// Icon coordinate-space extent (icons are drawn in this box and scaled
  /// to the paint size). Defaults to the canonical 24×24 grid.
  final double viewBox;

  const MorphPainter({
    required this.plan,
    required this.out,
    required this.t,
    this.canonicalPaths,
    this.canonicalSnap = false,
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
      // Canonical snap: render exact target cubics when explicitly requested.
      if (canonicalSnap && canonicalPaths != null) {
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
        canonicalSnap != oldDelegate.canonicalSnap ||
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
