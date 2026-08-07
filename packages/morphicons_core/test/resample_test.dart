/// Parity tests for the arc-length resampler + corner detection against the
/// golden fixtures dumped from the upstream JS implementation.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:morphicons_core/morphicons_core.dart';
import 'package:test/test.dart';

List<double> asDoubleList(Object? v) =>
    (v! as List).map((e) => (e as num).toDouble()).toList();

/// All points of a sampled icon as a flat [x0, y0, x1, y1, ...] list.
List<double> pool(List<Sampled> sampled) {
  final out = <double>[];
  for (final s in sampled) {
    out.addAll(s.pts);
  }
  return out;
}

/// Smallest distance from [x, y] to any point in the flat list [pts].
double minDist(double x, double y, List<double> pts) {
  var best = double.infinity;
  for (var i = 0; i < pts.length; i += 2) {
    final dx = pts[i] - x;
    final dy = pts[i + 1] - y;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d < best) best = d;
  }
  return best;
}

void main() {
  test('fixture parity: resampled points match the golden samples', () {
    final fixtures = jsonDecode(
      File('../../reference/fixtures.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final pairs = fixtures['pairs'] as Map<String, dynamic>;
    expect(pairs, isNotEmpty);

    var maxErr = 0.0;
    for (final entry in pairs.entries) {
      final pair = entry.value as Map<String, dynamic>;
      final d = pair['d'] as Map<String, dynamic>;
      final fromD = d['from'] as String;
      final toD = d['to'] as String;
      final fixSubs = (pair['subpaths'] as List).cast<Map<String, dynamic>>();

      final resFrom = resampleIcon(fromD);
      final resTo = resampleIcon(toD);

      // Correspondence may duplicate subpaths of the thinner icon, so the
      // fixture count equals the side with more subpaths.
      expect(
        math.max(resFrom.length, resTo.length),
        fixSubs.length,
        reason: '${entry.key}: subpath count',
      );
      for (final s in resFrom) {
        expect(s.pts.length, 2 * 64, reason: '${entry.key}: N=64 default');
      }
      for (final s in resTo) {
        expect(s.pts.length, 2 * 64, reason: '${entry.key}: N=64 default');
      }

      // Order-insensitive point matching: the fixture arrays are AFTER
      // correspondence (possibly reversed/rotated), so compare the point
      // clouds of both icons against the pooled fixture clouds.
      final resampled = [...pool(resFrom), ...pool(resTo)];
      final fixturePts = <double>[];
      for (final sp in fixSubs) {
        fixturePts.addAll(asDoubleList(sp['from']));
        fixturePts.addAll(asDoubleList(sp['to']));
      }
      for (var i = 0; i < fixturePts.length; i += 2) {
        final e = minDist(fixturePts[i], fixturePts[i + 1], resampled);
        maxErr = math.max(maxErr, e);
        expect(e, lessThan(1e-6),
            reason: '${entry.key}: fixture point $i not reproduced');
      }
      for (var i = 0; i < resampled.length; i += 2) {
        final e = minDist(resampled[i], resampled[i + 1], fixturePts);
        maxErr = math.max(maxErr, e);
        expect(e, lessThan(1e-6),
            reason: '${entry.key}: resampled point $i not in fixture');
      }
    }
    // ignore: avoid_print
    print('resample parity: max error over all pairs = $maxErr');
  });

  test('sharp corner is anchored as an exact sample', () {
    final paths = iconToCubics('M0 0L10 0L10 10');
    expect(paths, hasLength(1));
    final path = paths.single;
    expect(detectCorners(path), [1]);

    final samples = resamplePath(path);
    var found = false;
    for (var i = 0; i < samples.length; i += 2) {
      if ((samples[i] - 10).abs() < 1e-12 && (samples[i + 1]).abs() < 1e-12) {
        found = true;
        break;
      }
    }
    expect(found, isTrue, reason: 'corner (10, 0) must be an exact sample');
  });

  test('N defaults to 64', () {
    final sampled = resampleIcon('M0 0L1 1');
    expect(sampled, hasLength(1));
    expect(sampled.single.pts, isA<Float64List>());
    expect(sampled.single.pts.length, 2 * 64);
    expect(sampled.single.pointCount(), 64);
  });

  test('arc length of a straight unit line is 1', () {
    final paths = iconToCubics('M0 0L1 0');
    expect(paths, hasLength(1));
    expect(arcLength(paths.single), closeTo(1, 1e-12));
  });
}
