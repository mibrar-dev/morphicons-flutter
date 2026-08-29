/// Arc-length resampling with anchored corners.
///
/// The length of a cubic has no closed form: |B′(t)| is integrated with
/// 8-point Gauss-Legendre. Corners (tangent discontinuity above an angular
/// threshold) are anchored as exact sample points; the remaining points are
/// distributed by arc length between corners — integer apportionment by
/// largest remainder, minimum 1 interval per run, summing exactly to N−1
/// (N if closed).
library;

import 'dart:math';
import 'dart:typed_data';

import 'geometry.dart';
import 'normalize.dart';

/// Default angular threshold for a segment joint to count as a corner.
const cornerThreshold = pi / 8; // 22.5°

// Gauss-Legendre, 8 points on [−1, 1] — symmetric nodes: only half is stored.
const _gx = [
  0.18343464249564978,
  0.525532409916329,
  0.7966664774136267,
  0.9602898564975363,
];
const _gw = [
  0.362683783378362,
  0.31370664587788727,
  0.22238103445337448,
  0.10122853629037626,
];

// |B′(t)| of segment k. B′(t) = 3(1−t)²(P₁−P₀) + 6(1−t)t(P₂−P₁) + 3t²(P₃−P₂).
double _speed(Float64List p, int k, double t) {
  final i = 6 * k;
  final u = 1 - t;
  final c0 = 3 * u * u;
  final c1 = 6 * u * t;
  final c2 = 3 * t * t;
  final dx =
      c0 * (p[i + 2] - p[i]) + c1 * (p[i + 4] - p[i + 2]) + c2 * (p[i + 6] - p[i + 4]);
  final dy =
      c0 * (p[i + 3] - p[i + 1]) + c1 * (p[i + 5] - p[i + 3]) + c2 * (p[i + 7] - p[i + 5]);
  return sqrt(dx * dx + dy * dy);
}

// ∫₀^t1 |B′| of segment k via Gauss-Legendre.
double _segLen(Float64List p, int k, [double t1 = 1]) {
  final half = t1 / 2;
  var s = 0.0;
  for (var j = 0; j < 4; j++) {
    s += _gw[j] * (_speed(p, k, half + half * _gx[j]) + _speed(p, k, half - half * _gx[j]));
  }
  return s * half;
}

// Bernstein evaluation of segment k at t → (out[o], out[o+1]).
void _point(Float64List p, int k, double t, Float64List out, int o) {
  final i = 6 * k;
  final u = 1 - t;
  final b0 = u * u * u;
  final b1 = 3 * u * u * t;
  final b2 = 3 * u * t * t;
  final b3 = t * t * t;
  out[o] = b0 * p[i] + b1 * p[i + 2] + b2 * p[i + 4] + b3 * p[i + 6];
  out[o + 1] = b0 * p[i + 1] + b1 * p[i + 3] + b2 * p[i + 5] + b3 * p[i + 7];
}

// Tangent at an endpoint of segment k. atEnd: outgoing at P₃ (P₃−P₂);
// otherwise incoming at P₀ (P₁−P₀). Falls back to the next control point
// when degenerate.
(double, double)? _tangent(Float64List p, int k, bool atEnd) {
  final i = 6 * k;
  final b = atEnd ? i + 6 : i; // base point (endpoint)
  final s = atEnd ? -1 : 1;
  for (final j in atEnd ? const [4, 2, 0] : const [2, 4, 6]) {
    final dx = s * (p[i + j] - p[b]);
    final dy = s * (p[i + j + 1] - p[b + 1]);
    if (dx * dx + dy * dy > 1e-18) return (dx, dy);
  }
  return null;
}

/// Segment boundaries (index of the segment starting at the corner) whose
/// tangent discontinuity exceeds the threshold. For closed paths this
/// includes the closing joint (boundary = first active segment).
List<int> detectCorners(CubicPath path, [double threshold = cornerThreshold]) {
  final p = path.pts;
  final m = (p.length ~/ 2 - 1) ~/ 3;
  final active = <int>[];
  for (var k = 0; k < m; k++) {
    if (_segLen(p, k) > 1e-9) active.add(k);
  }
  if (active.isEmpty) return [];
  final corners = <int>{};
  void test(int a, int b) {
    final u = _tangent(p, a, true);
    final v = _tangent(p, b, false);
    if (u == null || v == null) return;
    final ang = atan2(u.$1 * v.$2 - u.$2 * v.$1, u.$1 * v.$1 + u.$2 * v.$2).abs();
    if (ang > threshold) corners.add(b);
  }

  for (var j = 0; j + 1 < active.length; j++) {
    test(active[j], active[j + 1]);
  }
  if (path.closed && active.length > 1) test(active[active.length - 1], active[0]);
  final out = corners.toList()..sort();
  return out;
}

/// Total arc length of the subpath (per-segment Gauss-Legendre).
double arcLength(CubicPath path) {
  final m = (path.pts.length ~/ 2 - 1) ~/ 3;
  var l = 0.0;
  for (var k = 0; k < m; k++) {
    l += _segLen(path.pts, k);
  }
  return l;
}

// Arc-length inversion: t such that ∫₀^t |B′| = s. Safeguarded Newton with
// a bisection bracket; |B′| is the exact derivative of the objective.
double _invert(Float64List p, int k, double s, double ls) {
  if (s <= 0) return 0;
  if (s >= ls) return 1;
  var lo = 0.0;
  var hi = 1.0;
  var t = s / ls;
  for (var it = 0; it < 12; it++) {
    final f = _segLen(p, k, t) - s;
    if (f.abs() < 1e-10 * ls + 1e-14) break;
    if (f > 0) {
      hi = t;
    } else {
      lo = t;
    }
    final sp = _speed(p, k, t);
    var nt = sp > 1e-12 ? t - f / sp : (lo + hi) / 2;
    if (!(nt > lo && nt < hi)) nt = (lo + hi) / 2;
    t = nt;
  }
  return t;
}

/// Samples a cubic subpath at N points equidistant by arc length, anchoring
/// corners and endpoints as exact samples. Returns Float64List(2N). Closed
/// paths distribute N intervals around the loop (without duplicating the
/// first point); the circular start-point freedom is resolved by the plan's
/// circular correspondence.
Float64List resamplePath(CubicPath path,
    [int n = 64, double threshold = cornerThreshold]) {
  final p = path.pts;
  final m = (p.length ~/ 2 - 1) ~/ 3;
  final out = Float64List(2 * n);
  Float64List fill() {
    for (var i = 0; i < n; i++) {
      out[2 * i] = p[0];
      out[2 * i + 1] = p[1];
    }
    return out;
  }

  if (m < 1) return fill();
  final lens = List<double>.filled(m, 0);
  var l = 0.0;
  for (var k = 0; k < m; k++) {
    lens[k] = _segLen(p, k);
    l += lens[k];
  }
  if (l < 1e-12) return fill();

  // Anchors: segment boundaries. For open paths, endpoints + corners. For
  // closed paths, ONLY corners: sampling must be intrinsic to the shape and
  // not to the arbitrary M point — two congruent loops with different start
  // points produce the same sample set (modulo index rotation, which the
  // plan's circular correspondence resolves). With no corners (a circle)
  // the path start is the only possible reference.
  final cs = detectCorners(path, threshold);
  final anchors = path.closed
      ? (cs.isNotEmpty ? cs : [0])
      : ({0, ...cs, m}.toList()..sort());
  // Runs between anchors; for closed paths the last wraps to anchors[0] + m.
  final runs = <(int, int)>[];
  if (path.closed) {
    for (var j = 0; j < anchors.length; j++) {
      final a = anchors[j];
      final b = j + 1 < anchors.length ? anchors[j + 1] : anchors[0] + m;
      runs.add((a, b));
    }
  } else {
    for (var j = 0; j + 1 < anchors.length; j++) {
      runs.add((anchors[j], anchors[j + 1]));
    }
  }
  final rl = runs.map((r) {
    var s = 0.0;
    for (var k = r.$1; k < r.$2; k++) {
      s += lens[k % m];
    }
    return s;
  }).toList();
  final intervals = path.closed ? n : n - 1;
  if (runs.length > intervals) {
    throw StateError('morphicons: N=$n too small (${runs.length} runs)');
  }

  // Largest-remainder apportionment: proportional to length, min 1, exact sum.
  final total = rl.fold(0.0, (a, b) => a + b);
  final denom = total == 0 ? 1.0 : total;
  final ideal = rl.map((x) => (intervals * x) / denom).toList();
  final counts = ideal.map((q) => max(1, q.floor())).toList();
  var r = intervals - counts.fold(0, (a, b) => a + b);
  if (r > 0) {
    // Quantized fraction: the quadrature's fp noise (~1e-15) must not decide
    // the tie-break — runs congruent under rotation must apportion the same
    // in both icons or Procrustes loses the exact congruence.
    final order = [
      for (var idx = 0; idx < ideal.length; idx++)
        (((ideal[idx] - ideal[idx].floor()) * 1e9).round(), idx)
    ]..sort((a, b) {
        final c = b.$1.compareTo(a.$1);
        return c != 0 ? c : a.$2.compareTo(b.$2);
      });
    for (var j = 0; j < r; j++) {
      counts[order[j % counts.length].$2]++;
    }
  }
  while (r < 0) {
    var bi = 0;
    for (var idx = 1; idx < counts.length; idx++) {
      if (counts[idx] > counts[bi]) bi = idx;
    }
    if (counts[bi] <= 1) break;
    counts[bi]--;
    r++;
  }

  // Sampling: exact anchor at the start of each run + interiors by inversion.
  var w = 0;
  for (var ri = 0; ri < runs.length; ri++) {
    final k0 = runs[ri].$1;
    final k1 = runs[ri].$2;
    final cnt = counts[ri];
    final lr = rl[ri];
    final vi = 6 * (k0 % m);
    out[2 * w] = p[vi];
    out[2 * w + 1] = p[vi + 1];
    w++;
    var seg = k0;
    var acc = 0.0;
    for (var j = 1; j < cnt; j++) {
      final target = (lr * j) / cnt;
      while (seg < k1 - 1 && acc + lens[seg % m] < target) {
        acc += lens[seg % m];
        seg++;
      }
      final k = seg % m;
      final ls = lens[k];
      final t = ls > 1e-12 ? _invert(p, k, target - acc, ls) : 0.0;
      _point(p, k, t, out, 2 * w);
      w++;
    }
  }
  if (!path.closed) {
    final vi = 6 * m;
    out[2 * w] = p[vi];
    out[2 * w + 1] = p[vi + 1];
  }
  return out;
}

/// Full input pipeline: icon → cubics → sampled subpaths with their
/// topology (the plan needs to know which subpaths are closed loops).
List<Sampled> resampleIcon(IconInput input, [int n = 64]) {
  return iconToCubics(input)
      .map((path) => Sampled(resamplePath(path, n), closed: path.closed))
      .toList();
}
