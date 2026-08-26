/// Shared plan/output/canonical geometry preparation used by canvas, mask,
/// and icon painters. Ticker-free — this layer only holds a frozen plan and
/// preallocated buffers, never drives animation itself.
///
/// The private [MorphRender] object keeps a [MorphPlan], output buffers, and
/// canonical [CubicPath] list in one place so all paint targets (MorphPainter,
/// MorphCanvasPainter, and the future MorphMaskPainter) share the same
/// allocation strategy.
library;

import 'dart:typed_data';

import 'dart:ui';

import 'package:morphicons_core/morphicons_core.dart';

/// Immutable, pre-allocated render state for a from → to icon pair.
///
/// Created synchronously (no async, no ticker). All methods that write
/// interpolated output are side-effect-free from the caller's perspective:
/// they write into the preallocated [out] buffers and return a reference to
/// them, so there is zero per-frame heap allocation after construction.
final class MorphRender {
  /// The correspondence+alignment plan between [from] and [to].
  final MorphPlan plan;

  /// Preallocated interpolation output buffers (one [Float64List] per
  /// subpath, each of length `2 * plan.n`).
  final List<Float64List> out;

  /// Canonical target cubics; used for pixel-exact snap at t = 1.
  final List<CubicPath> canonicalPaths;

  /// Closed-flag list derived from the plan; passed to [serialize].
  final List<bool> closed;

  const MorphRender._({
    required this.plan,
    required this.out,
    required this.canonicalPaths,
    required this.closed,
  });

  /// Builds a [MorphRender] for the given [from] / [to] `d` strings.
  ///
  /// Uses [planBetween] (cached for object icons) and [allocOutputs].
  factory MorphRender.forPair(String from, String to) {
    final plan = planBetween(from, to);
    final out = allocOutputs(plan);
    final canonicalPaths = iconToCubics(to);
    final closed = plan.items.map((it) => it.closed).toList();
    return MorphRender._(
      plan: plan,
      out: out,
      canonicalPaths: canonicalPaths,
      closed: closed,
    );
  }

  /// Runs [interpPolar] for [progress] into [out] and returns [out].
  ///
  /// The returned list is the same object as [out]; the caller must not
  /// hold a reference across re-entrant calls on the same [MorphRender].
  List<Float64List> interpolate(double progress) {
    interpPolar(plan, progress, out);
    return out;
  }

  /// Serializes the current [out] buffers to a polyline `d` string.
  ///
  /// Suitable for [MorphTween.transform] and in-flight interruption
  /// re-planning. Caller is responsible for calling [interpolate] first.
  String serializeOut() => serialize(out, closed);
}

/// Builds the stroked path for a render snapshot.
Path morphPath(
  MorphRender render,
  double progress, {
  required bool canonicalSnap,
}) {
  if (canonicalSnap) return _cubicsToPath(render.canonicalPaths);
  render.interpolate(progress);
  final path = Path();
  for (var k = 0; k < render.out.length; k++) {
    final points = render.out[k];
    final count = points.length ~/ 2;
    if (count == 0) continue;
    path.moveTo(points[0], points[1]);
    for (var i = 1; i < count; i++) {
      path.lineTo(points[i * 2], points[i * 2 + 1]);
    }
    if (render.closed[k]) path.close();
  }
  return path;
}

Path _cubicsToPath(List<CubicPath> paths) {
  final path = Path();
  for (final cubic in paths) {
    final points = cubic.pts;
    if (points.length < 2) continue;
    path.moveTo(points[0], points[1]);
    for (var i = 2; i < points.length; i += 6) {
      path.cubicTo(
        points[i],
        points[i + 1],
        points[i + 2],
        points[i + 3],
        points[i + 4],
        points[i + 5],
      );
    }
    if (cubic.closed) path.close();
  }
  return path;
}
