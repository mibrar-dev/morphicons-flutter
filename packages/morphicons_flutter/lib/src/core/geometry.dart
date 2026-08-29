/// Geometry types for cubic Bézier paths — pure Dart, no Flutter/dart:ui.
library;

import 'dart:typed_data';

/// A 2D point — plain doubles, no dependency on dart:ui.Offset.
typedef Point2D = (double, double);

/// Normalized subpath: a chain of cubic Béziers packed as a flat list
/// [x0, y0, c1x, c1y, c2x, c2y, x1, y1, c1x', c1y', ...].
///
/// Each cubic segment uses 6 values (2 control points + endpoint).
/// Consecutive segments share an endpoint: the endpoint of segment i
/// is the start point of segment i+1.
///
/// Total length: 2·(3m + 1) where m = number of segments.
class CubicPath {
  /// Packed control points: [x0, y0, c1x, c1y, c2x, c2y, x1, y1, ...].
  final Float64List pts;

  /// Whether this subpath is closed (Z command in SVG).
  final bool closed;

  CubicPath(this.pts, {required this.closed});

  /// Number of cubic segments in this path.
  int segCount() => (pts.length ~/ 2 - 1) ~/ 3;
}

/// Subpath sampled at N points by arc length + its topology.
/// This is the currency between resample and plan phases.
class Sampled {
  /// Packed points: [x0, y0, x1, y1, ...].
  final Float64List pts;

  /// Whether this subpath is closed.
  final bool closed;

  Sampled(this.pts, {required this.closed});

  /// Number of sample points.
  int pointCount() => pts.length ~/ 2;
}
