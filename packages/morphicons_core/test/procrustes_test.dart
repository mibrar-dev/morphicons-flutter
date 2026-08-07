/// Parity tests for the Procrustes alignment + global hybrid pass against
/// the golden fixtures dumped from the upstream JS implementation.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:morphicons_core/morphicons_core.dart';
import 'package:test/test.dart';

const double tol = 1e-9;

/// Residuals of near-congruent clouds are catastrophic-cancellation noise
/// (sqrt of a ~ulp difference), whose sign/last digits depend on the
/// engine's libm. Two such values are "equal" when both sit at the
/// machine-zero level; anything non-trivial must match within [tol].
void expectResidualParity(double actual, double expected) {
  if (expected.abs() < 1e-6) {
    expect(actual.abs(), lessThan(1e-6));
  } else {
    expect(actual, closeTo(expected, tol));
  }
}

double asDouble(Object? v) => (v! as num).toDouble();

List<double> asDoubleList(Object? v) =>
    (v! as List).map((e) => (e as num).toDouble()).toList();

Float64List asPts(Object? v) => Float64List.fromList(asDoubleList(v));

/// Builds the PlanItems the way buildPlan does pre-hybrid: a/aC from the
/// source cloud, bO/bT from the oriented target, both centered on their own
/// centroids.
List<PlanItem> buildItems(List<dynamic> subpaths, int n) {
  final items = <PlanItem>[];
  for (final sp in subpaths) {
    final s = sp as Map<String, dynamic>;
    final a = asPts(s['from']);
    final b = asPts(s['to']);
    final ca = centroid(a);
    final cb = centroid(b);
    final aC = Float64List(2 * n);
    for (var i = 0; i < 2 * n; i += 2) {
      aC[i] = a[i] - ca.$1;
      aC[i + 1] = a[i + 1] - ca.$2;
    }
    items.add(PlanItem(
      a: a,
      aC: aC,
      bT: Float64List(2 * n),
      bO: Float64List.fromList(b),
      ca: ca,
      cb: cb,
      theta: 0,
      lnSigma: 0,
      res: 0,
      closed: s['closed'] as bool,
    ));
  }
  return items;
}

void main() {
  final fixtures = jsonDecode(
    File('../../reference/fixtures.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final pairs = fixtures['pairs'] as Map<String, dynamic>;

  group('per-subpath procrustes parity', () {
    for (final entry in pairs.entries) {
      final name = entry.key;
      final pair = entry.value as Map<String, dynamic>;
      final subpaths = pair['subpaths'] as List;

      test(name, () {
        for (final sp in subpaths) {
          final s = sp as Map<String, dynamic>;
          final from = asPts(s['from']);
          final to = asPts(s['to']);

          // Fixture ca/cb must agree with the centroids of the fixture
          // clouds (they are the same values upstream fed to procrustes).
          final caC = centroid(from);
          final cbC = centroid(to);
          final fx = asDoubleList(s['ca']);
          final fy = asDoubleList(s['cb']);
          expect(caC.$1, closeTo(fx[0], 1e-12));
          expect(caC.$2, closeTo(fx[1], 1e-12));
          expect(cbC.$1, closeTo(fy[0], 1e-12));
          expect(cbC.$2, closeTo(fy[1], 1e-12));

          final sim = procrustes(from, to, caC, cbC);
          expect(sim.theta, closeTo(asDouble(s['theta']), tol));
          expect(sim.sigma, closeTo(asDouble(s['sigma']), tol));
          expectResidualParity(sim.res, asDouble(s['residual']));
        }
      });
    }
  });

  group('global hybrid parity', () {
    for (final entry in pairs.entries) {
      final name = entry.key;
      final pair = entry.value as Map<String, dynamic>;
      final subpaths = pair['subpaths'] as List;
      final global = pair['global'] as Map<String, dynamic>;

      test(name, () {
        final n = asDoubleList(subpaths.first['from']).length ~/ 2;
        final ga = Float64List(2 * n * subpaths.length);
        final gb = Float64List(2 * n * subpaths.length);
        for (var k = 0; k < subpaths.length; k++) {
          ga.setRange(2 * n * k, 2 * n * (k + 1), asPts(subpaths[k]['from']));
          gb.setRange(2 * n * k, 2 * n * (k + 1), asPts(subpaths[k]['to']));
        }
        final g = procrustes(ga, gb, centroid(ga), centroid(gb));
        expect(g.theta, closeTo(asDouble(global['theta']), tol));
        expect(g.sigma, closeTo(asDouble(global['sigma']), tol));
        expect(g.res, closeTo(asDouble(global['residual']), tol));
        expect(g.res < globalEps, global['blockHybridApplied']);
      });
    }
  });

  group('applyGlobal block transport parity', () {
    for (final entry in pairs.entries) {
      final name = entry.key;
      final pair = entry.value as Map<String, dynamic>;
      final global = pair['global'] as Map<String, dynamic>;
      if (global['blockHybridApplied'] != true) continue;
      final subpaths = pair['subpaths'] as List;

      test(name, () {
        final n = asDoubleList(subpaths.first['from']).length ~/ 2;
        final items = <PlanItem>[];
        for (final sp in subpaths) {
          final s = sp as Map<String, dynamic>;
          final a = asPts(s['from']);
          final b = asPts(s['to']);
          final ca = centroid(a);
          final cb = centroid(b);
          final aC = Float64List(2 * n);
          for (var i = 0; i < 2 * n; i += 2) {
            aC[i] = a[i] - ca.$1;
            aC[i + 1] = a[i + 1] - ca.$2;
          }
          items.add(PlanItem(
            a: a,
            aC: aC,
            bT: Float64List(2 * n),
            bO: Float64List.fromList(b),
            ca: ca,
            cb: cb,
            theta: 0,
            lnSigma: 0,
            res: 0,
            closed: s['closed'] as bool,
          ));
        }

        expect(applyGlobal(items, n), isTrue);
        for (var k = 0; k < items.length; k++) {
          final s = subpaths[k] as Map<String, dynamic>;
          final it = items[k];
          expect(it.theta, closeTo(asDouble(s['theta']), tol));
          expect(math.exp(it.lnSigma), closeTo(asDouble(s['sigma']), tol));
          expectResidualParity(it.res, asDouble(s['residual']));
          final block = s['block'] as Map<String, dynamic>;
          final off = asDoubleList(block['off']);
          final drift = asDoubleList(block['drift']);
          expect(it.block, isNotNull);
          expect(it.block!.off.$1, closeTo(off[0], tol));
          expect(it.block!.off.$2, closeTo(off[1], tol));
          expect(it.block!.drift.$1, closeTo(drift[0], tol));
          expect(it.block!.drift.$2, closeTo(drift[1], tol));
        }
      });
    }
  });

  test('HARD GATE: arrow-right<->arrow-down is a pure pi/2 rotation', () {
    final pair = pairs['arrow-right<->arrow-down'] as Map<String, dynamic>;
    final global = pair['global'] as Map<String, dynamic>;
    expect(asDouble(global['theta']), closeTo(math.pi / 2, tol));
    expect(asDouble(global['residual']), lessThan(tol));
    expect(global['blockHybridApplied'], isTrue);

    // Recompute from the fixture clouds to prove the port reproduces it.
    final subpaths = pair['subpaths'] as List;
    final n = asDoubleList(subpaths.first['from']).length ~/ 2;
    final ga = Float64List(2 * n * subpaths.length);
    final gb = Float64List(2 * n * subpaths.length);
    for (var k = 0; k < subpaths.length; k++) {
      ga.setRange(2 * n * k, 2 * n * (k + 1), asPts(subpaths[k]['from']));
      gb.setRange(2 * n * k, 2 * n * (k + 1), asPts(subpaths[k]['to']));
    }
    final g = procrustes(ga, gb, centroid(ga), centroid(gb));
    expect(g.theta, closeTo(math.pi / 2, tol));
    expect(g.res, lessThan(tol));
  });

  group('alignPair parity on fixture subpaths', () {
    for (final entry in pairs.entries) {
      final name = entry.key;
      final pair = entry.value as Map<String, dynamic>;
      final subpaths = pair['subpaths'] as List;

      test(name, () {
        for (final sp in subpaths) {
          final s = sp as Map<String, dynamic>;
          final from = asPts(s['from']);
          final to = asPts(s['to']);
          final closed = s['closed'] as bool;
          final al = alignPair(from, to, aClosed: closed, bClosed: closed);
          final fxTheta = asDouble(s['theta']);
          final fxRes = asDouble(s['residual']);
          if (fxRes < 1e-6) {
            // Nearly-congruent subpath: the correspondence search must land
            // on the stored rotation with a near-zero residual.
            expect(al.res, lessThan(1e-6));
            expect(al.theta, closeTo(fxTheta, tol));
          } else {
            // Non-congruent subpath (check<->x): alignPair cannot beat the
            // score of the correspondence the plan already chose.
            final id = procrustes(from, to, centroid(from), centroid(to));
            final idScore = id.res + (lambda * id.theta.abs()) / math.pi;
            final alScore = al.res + (lambda * al.theta.abs()) / math.pi;
            expect(alScore, lessThanOrEqualTo(idScore + tol));
          }
        }
      });
    }
  });

  group('subpath matching', () {
    Float64List square(double cx, double cy, {double r = 1}) {
      return Float64List.fromList([
        cx - r, cy - r,
        cx + r, cy - r,
        cx + r, cy + r,
        cx - r, cy + r,
      ]);
    }

    test('equal counts pair by proximity', () {
      final a = [
        Sampled(square(0, 0), closed: true),
        Sampled(square(10, 10), closed: true),
      ];
      final b = [
        Sampled(square(10.2, 10.1), closed: true),
        Sampled(square(0.1, 0), closed: true),
      ];
      expect(pairSubpaths(a, b), [(0, 1), (1, 0)]);
    });

    test('surplus subpaths duplicate the nearest (p > q)', () {
      final a = [
        Sampled(square(0, 0), closed: true),
        Sampled(square(0.3, 0.2), closed: true),
        Sampled(square(50, 50), closed: true),
      ];
      final b = [Sampled(square(0, 0), closed: true)];
      expect(pairSubpaths(a, b), [(0, 0), (1, 0), (2, 0)]);
    });

    test('surplus subpaths duplicate the nearest (p < q)', () {
      final a = [Sampled(square(0, 0), closed: true)];
      final b = [
        Sampled(square(0.1, 0), closed: true),
        Sampled(square(0, 0.2), closed: true),
      ];
      expect(pairSubpaths(a, b), [(0, 0), (0, 1)]);
    });
  });

  test('alignPair recovers the circular offset of a closed loop', () {
    final a = Float64List.fromList([
      0, 0,
      4, 0,
      4, 1,
      1, 1,
      1, 3,
      0, 3,
    ]);
    final b = rotatePts(a, 2);
    final al = alignPair(a, b, aClosed: true, bClosed: true);
    expect(al.res, lessThan(1e-12));
    expect(al.theta.abs(), lessThan(1e-12));
  });
}
