/// The morph plan: pairing + alignment frozen into a reusable, serializable
/// structure — pure Dart, no Flutter/dart:ui.
///
/// buildPlan resamples nothing: it takes already-sampled subpaths, pairs
/// them (correspondence.dart), aligns each pair and runs the global hybrid
/// pass (procrustes.dart). The plan is cacheable; [planBetween] caches by
/// identity (Expando ≈ WeakMap) exactly like upstream — string inputs are
/// re-derived every call, only object icons with stable identity are
/// retained.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'correspondence.dart';
import 'geometry.dart';
import 'normalize.dart';
import 'procrustes.dart';
import 'resample.dart';

/// Frozen correspondence + alignment between two sampled icons.
class MorphPlan {
  final List<PlanItem> items;

  /// Sample count per subpath (all subpaths share N).
  final int n;

  const MorphPlan({required this.items, required this.n});
}

/// Builds the morph plan between two lists of sampled subpaths. The plan is
/// cacheable and serializable; it accepts any list — including intermediate
/// shapes (interruptions).
MorphPlan buildPlan(List<Sampled> srcSubs, List<Sampled> dstSubs) {
  final pairs = pairSubpaths(srcSubs, dstSubs);
  final n = srcSubs[0].pts.length ~/ 2;
  final items = <PlanItem>[];
  for (final (si, di) in pairs) {
    final al = alignPair(
      srcSubs[si].pts,
      dstSubs[di].pts,
      aClosed: srcSubs[si].closed,
      bClosed: dstSubs[di].closed,
    );
    final a = al.a;
    final aC = Float64List(2 * n);
    final bT = Float64List(2 * n);
    final bO = Float64List(2 * n);
    final cos = math.cos(-al.theta);
    final sin = math.sin(-al.theta);
    for (var i = 0; i < n; i++) {
      aC[2 * i] = a[2 * i] - al.ca.$1;
      aC[2 * i + 1] = a[2 * i + 1] - al.ca.$2;
      final bx = al.b[2 * i] - al.cb.$1;
      final by = al.b[2 * i + 1] - al.cb.$2;
      bT[2 * i] = (bx * cos - by * sin) / al.sigma;
      bT[2 * i + 1] = (bx * sin + by * cos) / al.sigma;
      bO[2 * i] = al.b[2 * i];
      bO[2 * i + 1] = al.b[2 * i + 1];
    }
    items.add(PlanItem(
      a: a,
      aC: aC,
      bT: bT,
      bO: bO,
      ca: al.ca,
      cb: al.cb,
      theta: al.theta,
      lnSigma: math.log(al.sigma),
      res: al.res,
      closed: srcSubs[si].closed && dstSubs[di].closed,
    ));
  }
  if (items.length > 1) applyGlobal(items, n);
  return MorphPlan(items: items, n: n);
}

// ---------------------------------------------------------------------------
// Caches by identity (Expando ≈ upstream's WeakMap). Only object icons are
// cacheable; strings are re-derived — plan() is sub-ms, retaining isn't
// worth it.

final Expando<List<Sampled>> _samples = Expando();
final Expando<Expando<MorphPlan>> _plans = Expando();

/// Sampled subpaths of an icon, cached by identity for object icons.
List<Sampled> sampledOf(IconInput icon, [int n = 64]) {
  if (icon is String) return resampleIcon(icon, n);
  var s = _samples[icon];
  if (s == null) {
    s = resampleIcon(icon, n);
    _samples[icon] = s;
  }
  return s;
}

/// Rest→target plan, cached when both endpoints have stable identity.
/// Plans from intermediate shapes (interruptions passed as strings) are
/// never cached.
MorphPlan planBetween(IconInput src, IconInput dst) {
  if (src is String || dst is String) {
    return buildPlan(sampledOf(src), sampledOf(dst));
  }
  var inner = _plans[src];
  if (inner == null) {
    inner = Expando();
    _plans[src] = inner;
  }
  var p = inner[dst];
  if (p == null) {
    p = buildPlan(sampledOf(src), sampledOf(dst));
    inner[dst] = p;
  }
  return p;
}
