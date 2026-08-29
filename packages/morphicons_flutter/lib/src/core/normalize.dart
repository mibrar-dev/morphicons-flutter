/// Normalization: any SVG primitive → cubic Bézier segments.
///
/// Line → collinear controls at ⅓ and ⅔. Quadratic → exact degree elevation.
/// Arc → center parametrization (SVG spec F.6), slices ≤ 90°, α = 4/3·tan(Δθ/4).
/// circle/ellipse/rect/polyline/polygon → lines and quarter ellipses.
library;

import 'dart:math';
import 'dart:typed_data';

import 'geometry.dart';
import 'svg_path_parser.dart';

/// Control-point offset for a quarter circle: (4/3)·tan(π/8) ≈ 0.5523.
const kappa = 4 / 3 * pi / 8; // Will compute as tan(π/8) = tan(22.5°)
// Actually: 4/3 * tan(π/8) = 4/3 * tan(22.5°) ≈ 0.5522847498...

// Computed at runtime for precision
double _kappa() => 4 / 3 * tan(pi / 8);

const _tau = 2 * pi;

/// Attributes of an icon node (values as Lucide exports them: string or number).
typedef IconNodeAttrs = Map<String, dynamic>;

/// Lucide-style icon data: a [tag, attrs] list.
typedef IconNode = List<(String, IconNodeAttrs)>;

/// Input accepted by the core: an IconNode or a raw `d` attribute.
typedef IconInput = Object; // String or IconNode

/// Operations of a cubic accumulator.
class _Builder {
  final List<double> pts;
  double cx;
  double cy;

  _Builder(double x0, double y0)
      : pts = [x0, y0],
        cx = x0,
        cy = y0;

  void cubic(double x1, double y1, double x2, double y2, double x, double y) {
    pts.addAll([x1, y1, x2, y2, x, y]);
    cx = x;
    cy = y;
  }

  void line(double x, double y) {
    if ((x - cx).abs() < 1e-12 && (y - cy).abs() < 1e-12) return; // degenerate
    cubic(
      cx + (x - cx) / 3,
      cy + (y - cy) / 3,
      cx + 2 * (x - cx) / 3,
      cy + 2 * (y - cy) / 3,
      x,
      y,
    );
  }

  void quad(double x1, double y1, double x, double y) {
    cubic(
      cx + 2 / 3 * (x1 - cx),
      cy + 2 / 3 * (y1 - cy),
      x + 2 / 3 * (x1 - x),
      y + 2 / 3 * (y1 - y),
      x,
      y,
    );
  }

  /// Elliptical arc → cubics. Endpoint → center per SVG spec, appendix F.6.
  void arc(double rx0, double ry0, double rotDeg, int large, int sweep, double x, double y) {
    final x1 = cx;
    final y1 = cy;
    if ((x - x1).abs() < 1e-12 && (y - y1).abs() < 1e-12) return; // F.6.2
    var rx = rx0.abs();
    var ry = ry0.abs();
    if (rx < 1e-12 || ry < 1e-12) {
      line(x, y); // F.6.6: zero radius → line
      return;
    }
    final phi = rotDeg * pi / 180;
    final cosP = cos(phi);
    final sinP = sin(phi);
    final hx = (x1 - x) / 2;
    final hy = (y1 - y) / 2;
    final x1p = cosP * hx + sinP * hy;
    final y1p = -sinP * hx + cosP * hy;
    // F.6.6: scale up insufficient radii
    final lam = x1p * x1p / (rx * rx) + y1p * y1p / (ry * ry);
    if (lam > 1) {
      final s = sqrt(lam);
      rx *= s;
      ry *= s;
    }
    // F.6.5: center
    final rx2 = rx * rx;
    final ry2 = ry * ry;
    final xp2 = x1p * x1p;
    final yp2 = y1p * y1p;
    var rad = (rx2 * ry2 - rx2 * yp2 - ry2 * xp2) / (rx2 * yp2 + ry2 * xp2);
    if (rad < 0) rad = 0;
    final co = (large == sweep ? -1 : 1) * sqrt(rad);
    final cxp = co * rx * y1p / ry;
    final cyp = -co * ry * x1p / rx;
    final ccx = cosP * cxp - sinP * cyp + (x1 + x) / 2;
    final ccy = sinP * cxp + cosP * cyp + (y1 + y) / 2;
    final th1 = atan2((y1p - cyp) / ry, (x1p - cxp) / rx);
    var dth = atan2((-y1p - cyp) / ry, (-x1p - cxp) / rx) - th1;
    if (sweep == 0 && dth > 0) {
      dth -= _tau;
    } else if (sweep == 1 && dth < 0) {
      dth += _tau;
    }
    // Slice into arcs ≤ 90°, each slice to a cubic with α = 4/3·tan(δ/4)
    final slices = max(1, (dth.abs() / (pi / 2) - 1e-9).ceil());
    final delta = dth / slices;
    final alpha = 4 / 3 * tan(delta / 4);
    double ex(double t) => ccx + rx * cos(t) * cosP - ry * sin(t) * sinP;
    double ey(double t) => ccy + rx * cos(t) * sinP + ry * sin(t) * cosP;
    double dx(double t) => -rx * sin(t) * cosP - ry * cos(t) * sinP;
    double dy(double t) => -rx * sin(t) * sinP + ry * cos(t) * cosP;
    var t0 = th1;
    var p0x = x1;
    var p0y = y1;
    for (var s = 1; s <= slices; s++) {
      final t1 = th1 + delta * s;
      final p1x = s == slices ? x : ex(t1); // exact final endpoint, no fp drift
      final p1y = s == slices ? y : ey(t1);
      cubic(
        p0x + alpha * dx(t0),
        p0y + alpha * dy(t0),
        p1x - alpha * dx(t1),
        p1y - alpha * dy(t1),
        p1x,
        p1y,
      );
      t0 = t1;
      p0x = p1x;
      p0y = p1y;
    }
  }

  CubicPath? finish(bool closed) {
    if (closed) line(pts[0], pts[1]); // explicit closing segment if needed
    if (pts.length < 8) return null; // no real segments
    return CubicPath(Float64List.fromList(pts), closed: closed);
  }
}

CubicPath? _lowerSubpath(RawSubpath raw) {
  final builder = _Builder(raw.x0, raw.y0);
  for (final s in raw.segs) {
    switch (s) {
      case RawSegLine(:final x, :final y):
        builder.line(x, y);
      case RawSegCubic(:final x1, :final y1, :final x2, :final y2, :final x, :final y):
        builder.cubic(x1, y1, x2, y2, x, y);
      case RawSegQuad(:final x1, :final y1, :final x, :final y):
        builder.quad(x1, y1, x, y);
      case RawSegArc(:final rx, :final ry, :final rotDeg, :final large, :final sweep, :final x, :final y):
        builder.arc(rx, ry, rotDeg, large, sweep, x, y);
    }
  }
  return builder.finish(raw.closed);
}

double _attrNum(IconNodeAttrs attrs, String key, [double fallback = 0]) {
  final v = attrs[key];
  if (v == null) return fallback;
  final x = v is double ? v : double.tryParse(v.toString());
  return x?.isFinite == true ? x! : fallback;
}

List<double> _parsePoints(dynamic v) {
  final s = v?.toString().trim() ?? '';
  if (s.isEmpty) return [];
  final nums = s.split(RegExp(r'[\s,]+')).map(double.parse).toList();
  if (nums.any((x) => !x.isFinite)) {
    throw FormatException('morphicons: invalid points: "$s"');
  }
  return nums;
}

CubicPath? _polyPath(List<double> nums, bool closed) {
  if (nums.length < 4) return null;
  final builder = _Builder(nums[0], nums[1]);
  for (var i = 2; i + 1 < nums.length; i += 2) {
    builder.line(nums[i], nums[i + 1]);
  }
  return builder.finish(closed);
}

CubicPath? _ellipsePath(double cx, double cy, double rx, double ry) {
  if (rx < 1e-12 || ry < 1e-12) return null;
  final kx = _kappa() * rx;
  final ky = _kappa() * ry;
  final e = cx + rx; // east
  final w = cx - rx; // west
  final s = cy + ry; // south
  final n = cy - ry; // north
  final builder = _Builder(e, cy);
  builder.cubic(e, cy + ky, cx + kx, s, cx, s);
  builder.cubic(cx - kx, s, w, cy + ky, w, cy);
  builder.cubic(w, cy - ky, cx - kx, n, cx, n);
  builder.cubic(cx + kx, n, e, cy - ky, e, cy);
  return builder.finish(true);
}

CubicPath? _rectPath(IconNodeAttrs attrs) {
  final x = _attrNum(attrs, 'x');
  final y = _attrNum(attrs, 'y');
  final w = _attrNum(attrs, 'width');
  final h = _attrNum(attrs, 'height');
  if (w < 1e-12 || h < 1e-12) return null;
  // SVG rules: rx/ry copy each other when only one is given; clamp to half the side.
  var rx = _attrNum(attrs, 'rx', double.nan);
  var ry = _attrNum(attrs, 'ry', double.nan);
  if (rx.isNaN) rx = ry.isNaN ? 0 : ry;
  if (ry.isNaN) ry = rx;
  rx = rx.clamp(0, w / 2);
  ry = ry.clamp(0, h / 2);
  if (rx < 1e-12 || ry < 1e-12) {
    return _polyPath([x, y, x + w, y, x + w, y + h, x, y + h], true);
  }
  // Coordinates of the straight↔arc joints of each rounded corner.
  final xa = x + rx;
  final xb = x + w - rx;
  final xr = x + w;
  final ya = y + ry;
  final yb = y + h - ry;
  final yd = y + h;
  final kx = _kappa() * rx;
  final ky = _kappa() * ry;
  final builder = _Builder(xa, y);
  builder.line(xb, y);
  builder.cubic(xb + kx, y, xr, ya - ky, xr, ya);
  builder.line(xr, yb);
  builder.cubic(xr, yb + ky, xb + kx, yd, xb, yd);
  builder.line(xa, yd);
  builder.cubic(xa - kx, yd, x, yb + ky, x, yb);
  builder.line(x, ya);
  builder.cubic(x, ya - ky, xa - kx, y, xa, y);
  return builder.finish(true);
}

/// Icon (IconNode or `d` string) → list of cubic subpaths.
List<CubicPath> iconToCubics(IconInput input) {
  final out = <CubicPath>[];
  void push(CubicPath? p) {
    if (p != null) out.add(p);
  }

  if (input is String) {
    for (final s in parsePath(input)) {
      push(_lowerSubpath(s));
    }
    return out;
  }

  if (input is IconNode) {
    for (final entry in input) {
      final tag = entry.$1;
      final attrs = entry.$2;
      switch (tag) {
        case 'path':
          for (final s in parsePath(attrs['d']?.toString() ?? '')) {
            push(_lowerSubpath(s));
          }
          break;
        case 'line': {
          final builder = _Builder(_attrNum(attrs, 'x1'), _attrNum(attrs, 'y1'));
          builder.line(_attrNum(attrs, 'x2'), _attrNum(attrs, 'y2'));
          push(builder.finish(false));
          break;
        }
        case 'circle': {
          final r = _attrNum(attrs, 'r');
          push(_ellipsePath(_attrNum(attrs, 'cx'), _attrNum(attrs, 'cy'), r, r));
          break;
        }
        case 'ellipse':
          push(_ellipsePath(
            _attrNum(attrs, 'cx'),
            _attrNum(attrs, 'cy'),
            _attrNum(attrs, 'rx'),
            _attrNum(attrs, 'ry'),
          ));
          break;
        case 'rect':
          push(_rectPath(attrs));
          break;
        case 'polyline':
          push(_polyPath(_parsePoints(attrs['points']), false));
          break;
        case 'polygon':
          push(_polyPath(_parsePoints(attrs['points']), true));
          break;
        default:
          throw FormatException('morphicons: unsupported tag <$tag>');
      }
    }
  }

  return out;
}

/// A source viewBox: `24`, `"0 0 20 20"` or `[minX, minY, w, h]`.
typedef ViewBox = Object; // num, String, or List<num>

List<double> _parseViewBox(ViewBox vb) {
  List<num> v;
  if (vb is num) {
    v = [0, 0, vb, vb];
  } else if (vb is String) {
    v = vb.trim().split(RegExp(r'[\s,]+')).map(num.parse).toList();
  } else if (vb is List<num>) {
    v = vb;
  } else {
    throw FormatException('morphicons: invalid viewBox "$vb"');
  }
  if (v.length != 4 || !(v[2] > 0) || !(v[3] > 0) || !v[0].isFinite || !v[1].isFinite) {
    throw FormatException('morphicons: invalid viewBox "$vb"');
  }
  return v.map((e) => e.toDouble()).toList();
}

/// Serializes cubic paths to SVG `d` attribute string.
String _cubicsToPathD(List<CubicPath> paths) {
  final sb = StringBuffer();
  for (final path in paths) {
    final pts = path.pts;
    if (pts.length < 2) continue;
    sb.write('M ${pts[0]} ${pts[1]}');
    for (var i = 2; i < pts.length; i += 6) {
      sb.write(' C ${pts[i]} ${pts[i + 1]} ${pts[i + 2]} ${pts[i + 3]} ${pts[i + 4]} ${pts[i + 5]}');
    }
    if (path.closed) sb.write(' Z');
  }
  return sb.toString();
}

/// Re-grids an icon drawn on `viewBox` onto the shared `grid` (24 by default),
/// centered and preserving aspect ratio — the SVG `xMidYMid meet` rule.
///
/// Both endpoints of a morph must live on the same coordinate space. Lucide and
/// Tabler already draw on 24×24; packs on 20 (Heroicons solid) or 32 (Carbon)
/// do not, and mixing them unfitted makes Procrustes read the scale/offset gap
/// as rotation. Apply once at module scope (not per render) and pass the
/// resulting `d` anywhere an icon is accepted.
String fitIcon(IconInput input, ViewBox viewBox, [int grid = 24]) {
  final vb = _parseViewBox(viewBox);
  final minX = vb[0];
  final minY = vb[1];
  final w = vb[2];
  final h = vb[3];
  final s = min(grid / w, grid / h);
  final tx = (grid - w * s) / 2 - minX * s;
  final ty = (grid - h * s) / 2 - minY * s;
  final paths = iconToCubics(input);
  for (final path in paths) {
    final pts = path.pts;
    for (var i = 0; i < pts.length; i += 2) {
      pts[i] = pts[i] * s + tx;
      pts[i + 1] = pts[i + 1] * s + ty;
    }
  }
  return _cubicsToPathD(paths);
}
