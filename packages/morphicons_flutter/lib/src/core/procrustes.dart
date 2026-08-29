/// 2D closed-form Procrustes alignment — pure Dart, no Flutter/dart:ui.
///
/// Closed-form similarity (θ, σ) via atan2 (no SVD), plus the global hybrid
/// pass: if the whole icon is congruent under ONE similarity, every subpath
/// shares it (coherent block rotation).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'geometry.dart';

/// Global residual below which the whole icon counts as congruent and the
/// plan shares (θ, σ) across all items (hybrid variant of Procrustes).
const double globalEps = 5e-3;

/// Arithmetic mean of a packed point cloud [x0, y0, x1, y1, ...].
Point2D centroid(Float64List p) {
  final n = p.length ~/ 2;
  var cx = 0.0;
  var cy = 0.0;
  for (var i = 0; i < n; i++) {
    cx += p[2 * i];
    cy += p[2 * i + 1];
  }
  return (cx / n, cy / n);
}

/// Optimal similarity (θ, σ) — the result of the Procrustes fit.
class Similarity {
  final double theta;
  final double sigma;

  /// RMS residual normalized by b's energy (0 → same shape).
  final double res;

  const Similarity({
    required this.theta,
    required this.sigma,
    required this.res,
  });
}

/// Optimal similarity (θ, σ) minimizing Σ|σ·R(θ)·(a−c_A) − (b−c_B)|².
/// θ* = atan2(S_xy − S_yx, S_xx + S_yy); σ* by zero derivative.
/// res = RMS residual normalized by b's energy (0 → same shape).
Similarity procrustes(
  Float64List a,
  Float64List b,
  Point2D ca,
  Point2D cb,
) {
  final n = a.length ~/ 2;
  var sxx = 0.0;
  var sxy = 0.0;
  var syx = 0.0;
  var syy = 0.0;
  var na = 0.0;
  var nb = 0.0;
  for (var i = 0; i < n; i++) {
    final ax = a[2 * i] - ca.$1;
    final ay = a[2 * i + 1] - ca.$2;
    final bx = b[2 * i] - cb.$1;
    final by = b[2 * i + 1] - cb.$2;
    sxx += ax * bx;
    syy += ay * by;
    sxy += ax * by;
    syx += ay * bx;
    na += ax * ax + ay * ay;
    nb += bx * bx + by * by;
  }
  final theta = math.atan2(sxy - syx, sxx + syy);
  final num =
      math.cos(theta) * (sxx + syy) + math.sin(theta) * (sxy - syx);
  var sigma = na > 1e-12 ? num / na : 1.0;
  if (!(sigma > 1e-6)) sigma = 1e-6;
  final res2 = math.max(0.0, sigma * sigma * na - 2 * sigma * num + nb);
  final res = nb > 1e-12 ? math.sqrt(res2 / nb) : 0.0;
  return Similarity(theta: theta, sigma: sigma, res: res);
}

/// Block transport (set by the global hybrid): mid-flight the centroid rides
/// the shared similarity around the global centroid instead of lerping —
/// off = c_A − g_A; drift closes c(1) = c_B exactly.
class Block {
  final Point2D off;
  final Point2D drift;

  const Block({required this.off, required this.drift});
}

/// One matched subpath pair with its alignment bookkeeping.
class PlanItem {
  /// Points of A with the chosen correspondence (if A is a closed loop it
  /// may come circularly re-indexed: same points, different cut).
  final Float64List a;

  /// A centered on its centroid.
  final Float64List aC;

  /// B brought into A's frame: R(−θ)·(b − c_B)/σ.
  final Float64List bT;

  /// B oriented, raw (for linear mode and for exact t=1).
  final Float64List bO;

  final Point2D ca;
  final Point2D cb;
  double theta;
  double lnSigma;
  double res;

  /// true if both endpoints are closed loops: the subpath flies with Z.
  final bool closed;

  /// Block transport (set by the global hybrid, else null).
  Block? block;

  PlanItem({
    required this.a,
    required this.aC,
    required this.bT,
    required this.bO,
    required this.ca,
    required this.cb,
    required this.theta,
    required this.lnSigma,
    required this.res,
    required this.closed,
    this.block,
  });
}

/// Global hybrid: Procrustes over the concatenated clouds with the already
/// chosen correspondence. If the global residual ≈ 0 the whole icon is
/// congruent and every item shares (θ, σ): coherent block rotation (keeps a
/// symmetric subpath from picking the opposite spin).
///
/// Returns true when the hybrid was applied.
bool applyGlobal(List<PlanItem> items, int n) {
  final t = items.length * n;
  final ga = Float64List(2 * t);
  final gb = Float64List(2 * t);
  for (var k = 0; k < items.length; k++) {
    ga.setRange(2 * n * k, 2 * n * (k + 1), items[k].a);
    gb.setRange(2 * n * k, 2 * n * (k + 1), items[k].bO);
  }
  final gca = centroid(ga);
  final g = procrustes(ga, gb, gca, centroid(gb));
  if (g.res >= globalEps) return false;
  final cos = math.cos(-g.theta);
  final sin = math.sin(-g.theta);
  final rc = math.cos(g.theta);
  final rs = math.sin(g.theta);
  for (final it in items) {
    var e2 = 0.0;
    var nb = 0.0;
    for (var i = 0; i < n; i++) {
      final bx = it.bO[2 * i] - it.cb.$1;
      final by = it.bO[2 * i + 1] - it.cb.$2;
      it.bT[2 * i] = (bx * cos - by * sin) / g.sigma;
      it.bT[2 * i + 1] = (bx * sin + by * cos) / g.sigma;
      final ex = g.sigma * (rc * it.aC[2 * i] - rs * it.aC[2 * i + 1]) - bx;
      final ey = g.sigma * (rs * it.aC[2 * i] + rc * it.aC[2 * i + 1]) - by;
      e2 += ex * ex + ey * ey;
      nb += bx * bx + by * by;
    }
    it.theta = g.theta;
    it.lnSigma = math.log(g.sigma);
    it.res = nb > 1e-12 ? math.sqrt(e2 / nb) : 0;
    // Block transport: every part spins with the shared θ, but lerping the
    // centroids would send off-center parts along the chord — inside the
    // arc — and the block would deform mid-flight (an arrow's head sags
    // toward its shaft). The centroid rides the shared similarity around
    // the global centroid instead; drift absorbs the (tiny) global residual
    // so t = 1 stays exact. Same ops as the interpolator on purpose: the
    // rotation delta cancels bit-exactly at both endpoints.
    final s1 = math.exp(it.lnSigma);
    final c1 = math.cos(it.theta) * s1;
    final n1 = math.sin(it.theta) * s1;
    final ox = it.ca.$1 - gca.$1;
    final oy = it.ca.$2 - gca.$2;
    final rx = ox * c1 - oy * n1 - ox;
    final ry = ox * n1 + oy * c1 - oy;
    it.block = Block(
      off: (ox, oy),
      drift: (it.cb.$1 - it.ca.$1 - rx, it.cb.$2 - it.ca.$2 - ry),
    );
  }
  return true;
}
