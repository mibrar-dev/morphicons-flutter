/// Parity tests for polar interpolation + serialization + plan builder/cache
/// against the golden fixtures dumped from the upstream JS implementation.
library;

import 'dart:convert';
import 'dart:io';

import 'package:morphicons_core/morphicons_core.dart';
import 'package:test/test.dart';

/// Fixture strings are quantized to 2 decimals upstream (fmt = round to
/// 0.01), so point values may sit ±0.005 off the exact double — 6e-3 leaves
/// margin for that plus cross-engine libm noise.
const double frameEps = 6e-3;

final RegExp _num = RegExp(r'-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?');

/// Extracts all coordinate numbers from a polyline `d` string.
List<double> parsePolyline(String d) =>
    _num.allMatches(d).map((m) => double.parse(m.group(0)!)).toList();

/// Max absolute coordinate difference between two polyline `d` strings.
double polylineMaxDiff(String actual, String expected) {
  final a = parsePolyline(actual);
  final e = parsePolyline(expected);
  expect(a.length, e.length,
      reason: 'point count mismatch:\n  actual: $actual\n  expected: $expected');
  var m = 0.0;
  for (var i = 0; i < a.length; i++) {
    final d = (a[i] - e[i]).abs();
    if (d > m) m = d;
  }
  return m;
}

void main() {
  final fixtures = jsonDecode(
    File('../../reference/fixtures.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final pairs = fixtures['pairs'] as Map<String, dynamic>;

  group('frame parity: serialize(interpPolar(plan, t))', () {
    for (final entry in pairs.entries) {
      final name = entry.key;
      final pair = entry.value as Map<String, dynamic>;
      final d = pair['d'] as Map<String, dynamic>;
      final fromD = d['from'] as String;
      final toD = d['to'] as String;
      final frames = pair['frames'] as Map<String, dynamic>;

      test(name, () {
        final plan = buildPlan(resampleIcon(fromD), resampleIcon(toD));
        expect(plan.n, (pair['n'] as num).toInt());
        final out = allocOutputs(plan);
        var maxDiff = 0.0;
        for (final tKey in frames.keys) {
          final t = double.parse(tKey);
          interpPolar(plan, t, out);
          final expected = (frames[tKey] as List).cast<String>();
          expect(out.length, expected.length,
              reason: 'subpath count mismatch at t=$t');
          for (var k = 0; k < expected.length; k++) {
            final actual = serialize([out[k]]);
            final diff = polylineMaxDiff(actual, expected[k]);
            if (diff > maxDiff) maxDiff = diff;
            expect(diff, lessThan(frameEps),
                reason: '$name t=$t subpath $k:\n'
                    '  actual:   $actual\n'
                    '  expected: ${expected[k]}');
          }
        }
        // ignore: avoid_print
        print('$name: max frame-parity error = $maxDiff');
      });
    }
  });

  group('endpoint exactness', () {
    for (final entry in pairs.entries) {
      final name = entry.key;
      final pair = entry.value as Map<String, dynamic>;
      final d = pair['d'] as Map<String, dynamic>;

      test(name, () {
        final plan = buildPlan(
          resampleIcon(d['from'] as String),
          resampleIcon(d['to'] as String),
        );
        final out = allocOutputs(plan);

        // t = 0 reproduces the FROM icon's resampled points (item.a is the
        // FROM cloud with the chosen correspondence — same points, possibly
        // circularly re-cut for closed loops).
        interpPolar(plan, 0, out);
        for (var k = 0; k < plan.items.length; k++) {
          final a = plan.items[k].a;
          for (var i = 0; i < out[k].length; i++) {
            expect((out[k][i] - a[i]).abs(), lessThan(1e-9),
                reason: 't=0 k=$k coord $i');
          }
        }

        // t = 1 reproduces the TO icon's resampled points (item.bO).
        interpPolar(plan, 1, out);
        for (var k = 0; k < plan.items.length; k++) {
          final b = plan.items[k].bO;
          for (var i = 0; i < out[k].length; i++) {
            expect((out[k][i] - b[i]).abs(), lessThan(1e-9),
                reason: 't=1 k=$k coord $i');
          }
        }
      });
    }
  });

  group('plan cache (identity semantics, Expando ≈ WeakMap)', () {
    IconNode icon(List<String> ds) =>
        [for (final d in ds) ('path', <String, dynamic>{'d': d})];

    // Two 2-subpath icons.
    final plusD = ['M5 12h14', 'M12 5v14'];
    final minusD = ['M5 12h14', 'M7 12h10'];

    test('same identity → identical cached plan; samples cached too', () {
      final a = icon(plusD);
      final b = icon(minusD);
      final p1 = planBetween(a, b);
      final p2 = planBetween(a, b);
      expect(identical(p1, p2), isTrue);
      expect(identical(sampledOf(a), sampledOf(a)), isTrue);
    });

    test('different identity rebuilds (equal contents, new object)', () {
      final a = icon(plusD);
      final b = icon(minusD);
      final p1 = planBetween(a, b);
      final a2 = icon(plusD);
      final p2 = planBetween(a2, b);
      expect(identical(p1, p2), isFalse);
      // But the rebuild is numerically the same plan.
      expect(p2.items.length, p1.items.length);
      expect(p2.n, p1.n);
    });

    test('string inputs are never cached (re-derived every call)', () {
      final a = icon(plusD);
      final p1 = planBetween(a, minusD.join(''));
      final p2 = planBetween(a, minusD.join(''));
      expect(identical(p1, p2), isFalse);
    });
  });

  test('plan build timing: two 2-subpath icons well under 5ms', () {
    IconNode icon(List<String> ds) =>
        [for (final d in ds) ('path', <String, dynamic>{'d': d})];
    final a = icon(['M5 12h14', 'M12 5v14']);
    final b = icon(['M5 12h14', 'M7 12h10']);
    // Warmup so JIT/parser first-run costs don't skew the measurement.
    planBetween(icon(['M5 12h14', 'M12 5v14']), icon(['M5 12h14']));
    final sw = Stopwatch()..start();
    planBetween(a, b);
    sw.stop();
    // ignore: avoid_print
    print('plan build time: ${sw.elapsedMicroseconds} µs');
    expect(sw.elapsedMilliseconds, lessThan(5));
  });
}
