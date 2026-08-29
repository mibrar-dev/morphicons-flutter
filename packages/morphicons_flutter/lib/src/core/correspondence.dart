/// Subpath correspondence — pure Dart, no Flutter/dart:ui.
///
/// Point-level correspondence (both traversal directions, N circular offsets
/// for closed loops, minimal-rotation tie-break) via [alignPair], and
/// subpath-level pairing between two icons (centroid + length cost; exact
/// permutation ≤ 8 subpaths, surjective duplication when counts differ).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'geometry.dart';
import 'procrustes.dart';

/// Weight of |ΔL| in the subpath pairing cost.
const double lenWeight = 0.35;

/// λ of the minimal-rotation tie-break: score = res + λ·|θ|/π.
/// It exists because shapes symmetric under inversion (lines) tie in
/// residual for both traversal orientations yet produce different rotations.
const double lambda = 0.05;

/// Bounds for exhaustive matching; above them it falls back to greedy with
/// repair. 8! = 40 320 permutations / 1e5 assignments — both sub-ms.
const int permMax = 8;
const double surjMax = 1e5;

/// Perimeter of a packed polyline [x0, y0, x1, y1, ...].
double polyLen(Float64List p) {
  final n = p.length ~/ 2;
  var l = 0.0;
  for (var i = 1; i < n; i++) {
    final dx = p[2 * i] - p[2 * i - 2];
    final dy = p[2 * i + 1] - p[2 * i - 1];
    l += math.sqrt(dx * dx + dy * dy);
  }
  return l;
}

/// Point order reversed: out[i] = p[n − 1 − i].
Float64List reversePts(Float64List p) {
  final n = p.length ~/ 2;
  final out = Float64List(2 * n);
  for (var i = 0; i < n; i++) {
    out[2 * i] = p[2 * (n - 1 - i)];
    out[2 * i + 1] = p[2 * (n - 1 - i) + 1];
  }
  return out;
}

/// Circular re-indexing of a loop: out[i] = p[(i+off) mod n]. Same point
/// set, different cut point — the circular degree of freedom of closed paths.
Float64List rotatePts(Float64List p, int off) {
  final n = p.length ~/ 2;
  final out = Float64List(2 * n);
  for (var i = 0; i < n; i++) {
    final j = (i + off) % n;
    out[2 * i] = p[2 * j];
    out[2 * i + 1] = p[2 * j + 1];
  }
  return out;
}

/// Result of [alignPair]: the similarity plus both clouds re-indexed to the
/// chosen correspondence.
class Alignment extends Similarity {
  final Point2D ca;
  final Point2D cb;

  /// A with the chosen correspondence (re-indexed only if A is the closed
  /// loop).
  final Float64List a;

  /// B with the chosen correspondence (orientation and circular offset).
  final Float64List b;

  const Alignment({
    required super.theta,
    required super.sigma,
    required super.res,
    required this.ca,
    required this.cb,
    required this.a,
    required this.b,
  });
}

/// Best index-to-index correspondence between a and b: tries both traversal
/// directions and, if there is a closed loop, its N circular offsets,
/// scoring with score = res + λ·|θ|/π. The freedom is applied to ONE cloud
/// — the closed one (b if both are); varying both at once would be
/// redundant.
Alignment alignPair(
  Float64List aPts,
  Float64List bPts, {
  bool aClosed = false,
  bool bClosed = false,
}) {
  final ca = centroid(aPts);
  final cb = centroid(bPts);
  final varyA = aClosed && !bClosed;
  final base = varyA ? aPts : bPts;
  final offs = aClosed || bClosed ? base.length ~/ 2 : 1;
  var bestScore = double.infinity;
  var best = base;
  var sim = const Similarity(theta: 0, sigma: 1, res: 0);
  for (var dir = 0; dir < 2; dir++) {
    final walk = dir == 1 ? reversePts(base) : base;
    for (var off = 0; off < offs; off++) {
      final cand = off != 0 ? rotatePts(walk, off) : walk;
      final s = varyA
          ? procrustes(cand, bPts, ca, cb)
          : procrustes(aPts, cand, ca, cb);
      final score = s.res + (lambda * s.theta.abs()) / math.pi;
      if (score < bestScore) {
        bestScore = score;
        best = cand;
        sim = s;
      }
    }
  }
  return varyA
      ? Alignment(
          theta: sim.theta,
          sigma: sim.sigma,
          res: sim.res,
          ca: ca,
          cb: cb,
          a: best,
          b: bPts,
        )
      : Alignment(
          theta: sim.theta,
          sigma: sim.sigma,
          res: sim.res,
          ca: ca,
          cb: cb,
          a: aPts,
          b: best,
        );
}

/// Cost matrix dist(centroids) + lenWeight·|ΔL| between all pairs.
List<List<double>> costMatrix(List<Float64List> a, List<Float64List> b) {
  final cbs = b.map(centroid).toList();
  final lbs = b.map(polyLen).toList();
  return a.map((ai) {
    final ca = centroid(ai);
    final la = polyLen(ai);
    return List<double>.generate(b.length, (j) {
      final dx = ca.$1 - cbs[j].$1;
      final dy = ca.$2 - cbs[j].$2;
      return math.sqrt(dx * dx + dy * dy) + lenWeight * (la - lbs[j]).abs();
    });
  }).toList();
}

/// p === q: minimum-cost permutation. Exhaustive with pruning up to
/// [permMax]; greedy (pairs sorted by cost) above it — with that many
/// subpaths the exact optimum stops mattering visually.
List<int> bestPermutation(List<List<double>> c) {
  final n = c.length;
  if (n > permMax) {
    final pairs = <List<num>>[];
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        pairs.add([c[i][j], i, j]);
      }
    }
    // Upstream relies on a stable sort by cost (insertion order breaks
    // ties): pairs were pushed i-major, j-minor.
    pairs.sort((x, y) {
      final d = (x[0] as double).compareTo(y[0] as double);
      if (d != 0) return d;
      final di = (x[1] as int).compareTo(y[1] as int);
      if (di != 0) return di;
      return (x[2] as int).compareTo(y[2] as int);
    });
    final out = List<int>.filled(n, -1);
    final used = List<bool>.filled(n, false);
    for (final p in pairs) {
      final i = p[1] as int;
      final j = p[2] as int;
      if (out[i] < 0 && !used[j]) {
        out[i] = j;
        used[j] = true;
      }
    }
    return out;
  }
  final idx = List<int>.generate(n, (i) => i);
  var best = List<int>.of(idx);
  var bc = double.infinity;
  void perm(List<int> arr, int k, double acc) {
    if (acc >= bc) return;
    if (k == n) {
      bc = acc;
      best = List<int>.of(arr);
      return;
    }
    for (var i = k; i < n; i++) {
      final t = arr[k];
      arr[k] = arr[i];
      arr[i] = t;
      perm(arr, k + 1, acc + c[k][arr[k]]);
      final u = arr[k];
      arr[k] = arr[i];
      arr[i] = u;
    }
  }
  perm(idx, 0, 0);
  return best;
}

/// p ≠ q: surjective assignment from the large side to the small one,
/// minimum cost. Enumeration with pruning when S^B is small; greedy +
/// coverage repair otherwise. Surjectivity guarantees no subpath appears or
/// vanishes out of nowhere — leftovers duplicate the nearest subpath.
///
/// Rows of [c] are the large side (B), columns the small side (S); the
/// result maps each row to its assigned column.
List<int> bestSurjection(List<List<double>> c) {
  final big = c.length;
  final small = c[0].length;
  if (math.pow(small, big) > surjMax) {
    final f = c.map((row) {
      var m = 0;
      for (var j = 1; j < row.length; j++) {
        if (row[j] < row[m]) m = j;
      }
      return m;
    }).toList();
    final mult = List<int>.filled(small, 0);
    for (final s in f) {
      mult[s]++;
    }
    for (var s = 0; s < small; s++) {
      if (mult[s] > 0) continue;
      var bi = -1;
      var bc = double.infinity;
      for (var i = 0; i < big; i++) {
        if (mult[f[i]] < 2) continue; // only donors with multiplicity
        final extra = c[i][s] - c[i][f[i]];
        if (extra < bc) {
          bc = extra;
          bi = i;
        }
      }
      mult[f[bi]]--;
      f[bi] = s;
      mult[s]++;
    }
    return f;
  }
  List<int>? best;
  var bc = double.infinity;
  final f = List<int>.filled(big, 0);
  final mult = List<int>.filled(small, 0);
  void rec(int i, double acc, int covered) {
    if (acc >= bc || small - covered > big - i) return;
    if (i == big) {
      bc = acc;
      best = List<int>.of(f);
      return;
    }
    for (var s = 0; s < small; s++) {
      f[i] = s;
      mult[s]++;
      rec(i + 1, acc + c[i][s], covered + (mult[s] == 1 ? 1 : 0));
      mult[s]--;
    }
  }
  rec(0, 0, 0);
  if (best == null) {
    throw StateError('morphicons: no valid surjection (B < S)');
  }
  return best!;
}

/// Pairs every source subpath with a destination subpath (index pairs
/// (srcIndex, dstIndex)). When counts differ, the larger side maps onto the
/// smaller surjectively — surplus subpaths DUPLICATE the nearest one.
List<(int, int)> pairSubpaths(List<Sampled> srcSubs, List<Sampled> dstSubs) {
  final p = srcSubs.length;
  final q = dstSubs.length;
  if (p == 0 || q == 0) {
    throw ArgumentError('morphicons: icon has no subpaths');
  }
  final a = srcSubs.map((s) => s.pts).toList();
  final b = dstSubs.map((s) => s.pts).toList();
  final pairs = <(int, int)>[];
  if (p == q) {
    final perm = bestPermutation(costMatrix(a, b));
    for (var i = 0; i < p; i++) {
      pairs.add((i, perm[i]));
    }
  } else if (p < q) {
    final f = bestSurjection(costMatrix(b, a));
    for (var j = 0; j < q; j++) {
      pairs.add((f[j], j));
    }
  } else {
    final f = bestSurjection(costMatrix(a, b));
    for (var i = 0; i < p; i++) {
      pairs.add((i, f[i]));
    }
  }
  return pairs;
}
