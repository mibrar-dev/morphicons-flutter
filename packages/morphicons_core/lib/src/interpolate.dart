/// Polar interpolation + in-flight serialization — pure Dart, no
/// Flutter/dart:ui.
///
/// The similarity is interpolated in its natural space (linear angle,
/// log-linear scale, lerped centroid) and applied to the residual blend in
/// the aligned frame:
///   P(t) = c(t) + σᵗ·R(t·θ)·[(1−t)·aC + t·bT]
/// Under the global hybrid the centroid does not lerp — it rides the shared
/// similarity around the global centroid (block transport, see plan.dart):
///   c(t) = ca + t·drift + (σᵗ·R(t·θ) − I)·off
/// so congruent icons stay rigid mid-flight, not only at the endpoints.
/// Exact at t=0 and t=1; with spring overshoot (t>1) it extrapolates
/// naturally. Raw lerp (linear mode) is kept for comparison.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'plan.dart';

/// Preallocated output buffers for a plan (zero allocation per frame).
List<Float64List> allocOutputs(MorphPlan plan) {
  return plan.items.map((_) => Float64List(2 * plan.n)).toList();
}

void interpPolar(MorphPlan plan, double t, List<Float64List> out) {
  for (var k = 0; k < plan.items.length; k++) {
    final it = plan.items[k];
    final o = out[k];
    final n = plan.n;
    final s = math.exp(it.lnSigma * t);
    final ang = it.theta * t;
    final cos = math.cos(ang) * s;
    final sin = math.sin(ang) * s;
    double cx;
    double cy;
    final block = it.block;
    if (block != null) {
      final ox = block.off.$1;
      final oy = block.off.$2;
      final dx = block.drift.$1;
      final dy = block.drift.$2;
      cx = it.ca.$1 + dx * t + (ox * cos - oy * sin - ox);
      cy = it.ca.$2 + dy * t + (ox * sin + oy * cos - oy);
    } else {
      cx = it.ca.$1 + (it.cb.$1 - it.ca.$1) * t;
      cy = it.ca.$2 + (it.cb.$2 - it.ca.$2) * t;
    }
    for (var i = 0; i < n; i++) {
      final px = it.aC[2 * i] + (it.bT[2 * i] - it.aC[2 * i]) * t;
      final py = it.aC[2 * i + 1] + (it.bT[2 * i + 1] - it.aC[2 * i + 1]) * t;
      o[2 * i] = cx + px * cos - py * sin;
      o[2 * i + 1] = cy + px * sin + py * cos;
    }
  }
}

/// Raw coordinate lerp (same correspondence, no decomposition).
void interpLinear(MorphPlan plan, double t, List<Float64List> out) {
  for (var k = 0; k < plan.items.length; k++) {
    final it = plan.items[k];
    final o = out[k];
    final n = plan.n;
    for (var i = 0; i < n; i++) {
      o[2 * i] = it.a[2 * i] + (it.bO[2 * i] - it.a[2 * i]) * t;
      o[2 * i + 1] = it.a[2 * i + 1] + (it.bO[2 * i + 1] - it.a[2 * i + 1]) * t;
    }
  }
}

// In flight each subpath is emitted as a polyline `M x y L x y …` with 2
// decimals — invisible at 24px. Mirrors upstream's
// `String(Math.round(v * 100) / 100)`, including JS number-to-string
// semantics (integral doubles print without a decimal point).
String _fmt(double v) {
  final q = (v * 100).round() / 100;
  if (q == q.truncateToDouble()) return q.toInt().toString();
  return q.toString();
}

/// Sampled subpaths → polyline `d` attribute. `closed?[k]` appends Z to
/// subpath k (closed loops in flight); without flags everything is open.
String serialize(List<Float64List> subs, [List<bool>? closed]) {
  final sb = StringBuffer();
  for (var k = 0; k < subs.length; k++) {
    final o = subs[k];
    final n = o.length ~/ 2;
    sb.write('M${_fmt(o[0])} ${_fmt(o[1])}');
    for (var i = 1; i < n; i++) {
      sb.write('L${_fmt(o[2 * i])} ${_fmt(o[2 * i + 1])}');
    }
    if (closed != null && closed[k]) sb.write('Z');
  }
  return sb.toString();
}
