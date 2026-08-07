import 'package:morphicons_core/morphicons_core.dart';
import 'package:test/test.dart';
import 'dart:math';
import 'dart:typed_data';

void main() {
  group('iconToCubics', () {
    group('path element (d string)', () {
      test('simple line becomes cubic with collinear controls', () {
        final paths = iconToCubics('M 0 0 L 10 0');
        expect(paths.length, equals(1));
        final pts = paths[0].pts;
        // Line (0,0) → (10,0) becomes cubic with controls at ⅓ and ⅔
        // Start: (0, 0)
        expect(pts[0], equals(0));
        expect(pts[1], equals(0));
        // Control 1: (0 + 10/3, 0) = (3.333..., 0)
        expect(pts[2], closeTo(10 / 3, 1e-10));
        expect(pts[3], equals(0));
        // Control 2: (0 + 20/3, 0) = (6.666..., 0)
        expect(pts[4], closeTo(20 / 3, 1e-10));
        expect(pts[5], equals(0));
        // End: (10, 0)
        expect(pts[6], equals(10));
        expect(pts[7], equals(0));
      });

      test('quadratic becomes elevated cubic', () {
        final paths = iconToCubics('M 0 0 Q 10 20 20 0');
        expect(paths.length, equals(1));
        final pts = paths[0].pts;
        // Q (10, 20) → C with controls at 2/3 toward Q control point
        // Start: (0, 0)
        expect(pts[0], equals(0));
        expect(pts[1], equals(0));
        // Control 1: (0 + 2/3*(10-0), 0 + 2/3*(20-0)) = (20/3, 40/3)
        expect(pts[2], closeTo(20 / 3, 1e-10));
        expect(pts[3], closeTo(40 / 3, 1e-10));
        // Control 2: (20 + 2/3*(10-20), 0 + 2/3*(20-0)) = (40/3, 40/3)
        expect(pts[4], closeTo(40 / 3, 1e-10));
        expect(pts[5], closeTo(40 / 3, 1e-10));
        // End: (20, 0)
        expect(pts[6], equals(20));
        expect(pts[7], equals(0));
      });

      test('cubic passes through unchanged', () {
        final paths = iconToCubics('M 0 0 C 10 10 20 10 30 0');
        expect(paths.length, equals(1));
        final pts = paths[0].pts;
        expect(pts[0], equals(0));
        expect(pts[1], equals(0));
        expect(pts[2], equals(10));
        expect(pts[3], equals(10));
        expect(pts[4], equals(20));
        expect(pts[5], equals(10));
        expect(pts[6], equals(30));
        expect(pts[7], equals(0));
      });

      test('arc converts to cubic(s)', () {
        final paths = iconToCubics('M 0 0 A 10 10 0 0 1 20 0');
        expect(paths.length, equals(1));
        expect(paths[0].segCount(), greaterThanOrEqualTo(1));
      });

      test('arc with large-arc flag', () {
        final paths = iconToCubics('M 0 0 A 10 10 0 1 1 20 0');
        expect(paths.length, equals(1));
        // Large arc should produce more segments
        expect(paths[0].segCount(), greaterThanOrEqualTo(1));
      });

      test('arc with rotation', () {
        final paths = iconToCubics('M 0 0 A 10 5 45 0 1 20 0');
        expect(paths.length, equals(1));
      });

      test('degenerate arc (zero radius) becomes line', () {
        final paths = iconToCubics('M 0 0 A 0 0 0 0 1 10 0');
        expect(paths.length, equals(1));
        // Should be a single line segment
        expect(paths[0].segCount(), equals(1));
      });

      test('closed path has closing segment', () {
        final paths = iconToCubics('M 0 0 L 10 0 L 10 10 Z');
        expect(paths.length, equals(1));
        expect(paths[0].closed, isTrue);
        // Should have 3 segments: (0,0)→(10,0), (10,0)→(10,10), (10,10)→(0,0)
        expect(paths[0].segCount(), equals(3));
      });

      test('multiple subpaths', () {
        final paths = iconToCubics('M 0 0 L 10 0 Z M 20 20 L 30 20 Z');
        expect(paths.length, equals(2));
      });
    });

    group('line element', () {
      test('line element becomes cubic', () {
        final paths = iconToCubics([
          ('line', {'x1': 0, 'y1': 0, 'x2': 10, 'y2': 20}),
        ]);
        expect(paths.length, equals(1));
        expect(paths[0].segCount(), equals(1));
        expect(paths[0].closed, isFalse);
      });
    });

    group('circle element', () {
      test('circle becomes 4 cubic segments', () {
        final paths = iconToCubics([
          ('circle', {'cx': 50, 'cy': 50, 'r': 10}),
        ]);
        expect(paths.length, equals(1));
        expect(paths[0].segCount(), equals(4));
        expect(paths[0].closed, isTrue);
      });

      test('circle control points with kappa', () {
        final paths = iconToCubics([
          ('circle', {'cx': 0, 'cy': 0, 'r': 10}),
        ]);
        final pts = paths[0].pts;
        // Circle centered at (0,0) with r=10 starts at east point (10, 0)
        expect(pts[0], equals(10));
        expect(pts[1], equals(0));
        // First cubic goes to (0, 10) (south)
        // Control 1 y should be kappa * r = 0.552... * 10 ≈ 5.52
        final k = 4 / 3 * tan(pi / 8);
        expect(pts[3], closeTo(k * 10, 0.01));
      });
    });

    group('ellipse element', () {
      test('ellipse becomes 4 cubic segments', () {
        final paths = iconToCubics([
          ('ellipse', {'cx': 50, 'cy': 50, 'rx': 20, 'ry': 10}),
        ]);
        expect(paths.length, equals(1));
        expect(paths[0].segCount(), equals(4));
        expect(paths[0].closed, isTrue);
      });
    });

    group('rect element', () {
      test('sharp rect becomes 4 line segments', () {
        final paths = iconToCubics([
          ('rect', {'x': 0, 'y': 0, 'width': 10, 'height': 20}),
        ]);
        expect(paths.length, equals(1));
        expect(paths[0].segCount(), equals(4));
        expect(paths[0].closed, isTrue);
      });

      test('rounded rect has corner arcs', () {
        final paths = iconToCubics([
          ('rect', {'x': 0, 'y': 0, 'width': 100, 'height': 100, 'rx': 10, 'ry': 10}),
        ]);
        expect(paths.length, equals(1));
        // Rounded rect: 4 lines + 4 quarter arcs = 8 segments
        expect(paths[0].segCount(), equals(8));
      });

      test('rx only copies to ry', () {
        final paths = iconToCubics([
          ('rect', {'x': 0, 'y': 0, 'width': 100, 'height': 100, 'rx': 10}),
        ]);
        // Should have rounded corners
        expect(paths[0].segCount(), equals(8));
      });

      test('ry only copies to rx', () {
        final paths = iconToCubics([
          ('rect', {'x': 0, 'y': 0, 'width': 100, 'height': 100, 'ry': 10}),
        ]);
        expect(paths[0].segCount(), equals(8));
      });

      test('rx clamped to half width', () {
        final paths = iconToCubics([
          ('rect', {'x': 0, 'y': 0, 'width': 10, 'height': 20, 'rx': 100}),
        ]);
        // rx clamps to 5 (half width); horizontal edges degenerate and are
        // dropped by the builder — verified against upstream JS (4 segments).
        expect(paths[0].segCount(), equals(4));
      });
    });

    group('polyline element', () {
      test('polyline becomes line segments', () {
        final paths = iconToCubics([
          ('polyline', {'points': '0,0 10,10 20,0'}),
        ]);
        expect(paths.length, equals(1));
        expect(paths[0].segCount(), equals(2));
        expect(paths[0].closed, isFalse);
      });
    });

    group('polygon element', () {
      test('polygon becomes closed line segments', () {
        final paths = iconToCubics([
          ('polygon', {'points': '0,0 10,0 10,10 0,10'}),
        ]);
        expect(paths.length, equals(1));
        expect(paths[0].segCount(), equals(4));
        expect(paths[0].closed, isTrue);
      });
    });

    group('IconNode with multiple elements', () {
      test('multiple path elements', () {
        final paths = iconToCubics([
          ('path', {'d': 'M 0 0 L 10 0'}),
          ('path', {'d': 'M 20 20 L 30 20'}),
        ]);
        expect(paths.length, equals(2));
      });

      test('mixed elements', () {
        final paths = iconToCubics([
          ('circle', {'cx': 50, 'cy': 50, 'r': 10}),
          ('line', {'x1': 0, 'y1': 0, 'x2': 10, 'y2': 10}),
        ]);
        expect(paths.length, equals(2));
      });
    });

    group('error handling', () {
      test('unsupported tag throws', () {
        expect(
          () => iconToCubics([('g', <String, Object?>{})]),
          throwsFormatException,
        );
      });
    });
  });

  group('fitIcon', () {
    test('32x32 → 24x24 scales and centers', () {
      // A point at (16, 16) in 32x32 should go to (12, 12) in 24x24
      final result = fitIcon('M 16 16 L 16 16.1', 32, 24);
      // Parse the result to check coordinates
      final paths = iconToCubics(result);
      // Scale factor = 24/32 = 0.75
      // Center offset: (24 - 32*0.75)/2 = (24 - 24)/2 = 0
      // So (16, 16) → (16*0.75, 16*0.75) = (12, 12)
      expect(paths[0].pts[0], closeTo(12, 0.01));
      expect(paths[0].pts[1], closeTo(12, 0.01));
    });

    test('20x20 → 24x24 scales and centers', () {
      // A point at (10, 10) in 20x20 should go to (12, 12) in 24x24
      final result = fitIcon('M 10 10 L 10 10.1', 20, 24);
      final paths = iconToCubics(result);
      // Scale factor = 24/20 = 1.2
      // Center offset: (24 - 20*1.2)/2 = (24 - 24)/2 = 0
      // So (10, 10) → (10*1.2, 10*1.2) = (12, 12)
      expect(paths[0].pts[0], closeTo(12, 0.01));
      expect(paths[0].pts[1], closeTo(12, 0.01));
    });

    test('non-square viewBox centers', () {
      // 20x40 → 24x24: scale = 24/40 = 0.6
      // Horizontal offset: (24 - 20*0.6)/2 = (24 - 12)/2 = 6
      final result = fitIcon('M 0 0 L 0 0.1', '0 0 20 40', 24);
      final paths = iconToCubics(result);
      // (0, 0) → (0*0.6 + 6, 0*0.6) = (6, 0)
      expect(paths[0].pts[0], closeTo(6, 0.01));
      expect(paths[0].pts[1], closeTo(0, 0.01));
    });

    test('string viewBox', () {
      final result = fitIcon('M 0 0 L 1 1', '0 0 24 24', 24);
      expect(() => iconToCubics(result), returnsNormally);
    });

    test('list viewBox', () {
      final result = fitIcon('M 0 0 L 1 1', [0, 0, 24, 24], 24);
      expect(() => iconToCubics(result), returnsNormally);
    });

    test('IconNode input', () {
      final result = fitIcon([
        ('circle', {'cx': 12, 'cy': 12, 'r': 10}),
      ], 24, 24);
      expect(() => iconToCubics(result), returnsNormally);
    });

    test('preserves subpath count', () {
      final result = fitIcon('M 0 0 L 10 0 Z M 20 20 L 30 20 Z', 24, 24);
      final paths = iconToCubics(result);
      expect(paths.length, equals(2));
    });
  });

  group('segCount', () {
    test('empty path has 0 segments', () {
      // Need at least 8 values for one segment (2 pts start + 6 for cubic)
      expect(CubicPath(Float64List.fromList([0, 0]), closed: false).segCount(), equals(0));
    });

    test('single segment', () {
      expect(
        CubicPath(Float64List.fromList([0, 0, 1, 1, 2, 2, 3, 3]), closed: false).segCount(),
        equals(1),
      );
    });

    test('two segments', () {
      // 2 values for start + 6 for first segment + 6 for second = 14 values
      expect(
        CubicPath(
          Float64List.fromList([0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6]),
          closed: false,
        ).segCount(),
        equals(2),
      );
    });
  });

  group('arc flag edge cases', () {
    test('arc flags packed "0110"', () {
      // This was a specific edge case in the TypeScript
      final paths = iconToCubics('M 0 0 a 5 5 0 0110 0');
      expect(paths.length, equals(1));
    });

    test('arc flags packed "1110"', () {
      final paths = iconToCubics('M 0 0 a 5 5 0 1110 0');
      expect(paths.length, equals(1));
    });

    test('arc flags with spaces', () {
      final paths = iconToCubics('M 0 0 a 5 5 0 1 1 10 0');
      expect(paths.length, equals(1));
    });
  });

  group('real icon paths (normalized)', () {
    test('lucide menu icon normalizes', () {
      final d = 'M4 6h16M4 12h16M4 18h16';
      expect(() => iconToCubics(d), returnsNormally);
      final paths = iconToCubics(d);
      expect(paths.length, equals(3));
    });

    test('lucide x icon normalizes', () {
      final d = 'M18 6 6 18M6 6l12 12';
      expect(() => iconToCubics(d), returnsNormally);
    });

    test('lucide home icon normalizes', () {
      final d = 'm3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z';
      expect(() => iconToCubics(d), returnsNormally);
    });

    test('lucide search icon with arc normalizes', () {
      final d = 'M21 21l-6-6m2-5a7 7 0 1 1-14 0 7 7 0 0 1 14 0z';
      expect(() => iconToCubics(d), returnsNormally);
    });

    test('lucide user icon normalizes', () {
      final d = 'M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z';
      expect(() => iconToCubics(d), returnsNormally);
    });

    test('lucide settings icon normalizes', () {
      final d = 'M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z';
      expect(() => iconToCubics(d), returnsNormally);
    });

    test('lucide heart icon normalizes', () {
      final d = 'M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z';
      expect(() => iconToCubics(d), returnsNormally);
    });

    test('lucide play icon normalizes', () {
      final d = 'm5 3 14 9-14 9V3z';
      expect(() => iconToCubics(d), returnsNormally);
    });
  });
}
