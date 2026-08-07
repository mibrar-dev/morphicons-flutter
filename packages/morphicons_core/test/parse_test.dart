import 'package:morphicons_core/morphicons_core.dart';
import 'package:test/test.dart';

void main() {
  group('parsePath', () {
    test('empty string returns empty list', () {
      expect(parsePath(''), isEmpty);
    });

    test('simple moveto is filtered (no segments, matches upstream)', () {
      // Upstream drops subpaths with zero segments.
      final subs = parsePath('M 10 20');
      expect(subs, isEmpty);
    });

    test('relative moveto', () {
      final subs = parsePath('M 10 20 L 12 22 m 5 5 l 1 1');
      expect(subs.length, equals(2));
      expect(subs[1].x0, equals(17));
      expect(subs[1].y0, equals(27));
    });

    test('moveto with implicit lineto', () {
      final subs = parsePath('M 10 20 30 40 50 60');
      expect(subs.length, equals(1));
      expect(subs[0].segs.length, equals(2));
      final seg1 = subs[0].segs[0] as RawSegLine;
      expect(seg1.x, equals(30));
      expect(seg1.y, equals(40));
      final seg2 = subs[0].segs[1] as RawSegLine;
      expect(seg2.x, equals(50));
      expect(seg2.y, equals(60));
    });

    test('line commands', () {
      final subs = parsePath('M 0 0 L 10 20 L 30 40');
      expect(subs[0].segs.length, equals(2));
    });

    test('relative line commands', () {
      final subs = parsePath('M 0 0 l 10 20 l 10 0');
      expect(subs[0].segs.length, equals(2));
      final seg1 = subs[0].segs[0] as RawSegLine;
      expect(seg1.x, equals(10));
      expect(seg1.y, equals(20));
      final seg2 = subs[0].segs[1] as RawSegLine;
      expect(seg2.x, equals(20));
      expect(seg2.y, equals(20));
    });

    test('horizontal line H', () {
      final subs = parsePath('M 0 0 H 10 H 20');
      expect(subs[0].segs.length, equals(2));
      final seg1 = subs[0].segs[0] as RawSegLine;
      expect(seg1.x, equals(10));
      expect(seg1.y, equals(0));
    });

    test('vertical line V', () {
      final subs = parsePath('M 0 0 V 10 V 20');
      expect(subs[0].segs.length, equals(2));
      final seg1 = subs[0].segs[0] as RawSegLine;
      expect(seg1.x, equals(0));
      expect(seg1.y, equals(10));
    });

    test('cubic bezier C', () {
      final subs = parsePath('M 0 0 C 10 10 20 10 30 0');
      expect(subs[0].segs.length, equals(1));
      final seg = subs[0].segs[0] as RawSegCubic;
      expect(seg.x1, equals(10));
      expect(seg.y1, equals(10));
      expect(seg.x2, equals(20));
      expect(seg.y2, equals(10));
      expect(seg.x, equals(30));
      expect(seg.y, equals(0));
    });

    test('smooth cubic S with reflection', () {
      // After C, S should reflect the control point
      final subs = parsePath('M 0 0 C 10 10 20 10 30 0 S 40 -10 50 0');
      expect(subs[0].segs.length, equals(2));
      final segS = subs[0].segs[1] as RawSegCubic;
      // Reflected from (20, 10) around (30, 0) = (40, -10)
      expect(segS.x1, closeTo(40, 1e-10));
      expect(segS.y1, closeTo(-10, 1e-10));
    });

    test('smooth cubic S without previous C', () {
      final subs = parsePath('M 0 0 S 10 10 20 0');
      expect(subs[0].segs.length, equals(1));
      final seg = subs[0].segs[0] as RawSegCubic;
      // No reflection: control point = current point
      expect(seg.x1, equals(0));
      expect(seg.y1, equals(0));
    });

    test('quadratic bezier Q', () {
      final subs = parsePath('M 0 0 Q 15 20 30 0');
      expect(subs[0].segs.length, equals(1));
      final seg = subs[0].segs[0] as RawSegQuad;
      expect(seg.x1, equals(15));
      expect(seg.y1, equals(20));
      expect(seg.x, equals(30));
      expect(seg.y, equals(0));
    });

    test('smooth quadratic T with reflection', () {
      final subs = parsePath('M 0 0 Q 15 20 30 0 T 60 0');
      expect(subs[0].segs.length, equals(2));
      final segT = subs[0].segs[1] as RawSegQuad;
      // Reflected from (15, 20) around (30, 0) = (45, -20)
      expect(segT.x1, closeTo(45, 1e-10));
      expect(segT.y1, closeTo(-20, 1e-10));
    });

    test('arc command A', () {
      final subs = parsePath('M 0 0 A 10 10 0 0 1 20 0');
      expect(subs[0].segs.length, equals(1));
      final seg = subs[0].segs[0] as RawSegArc;
      expect(seg.rx, equals(10));
      expect(seg.ry, equals(10));
      expect(seg.rotDeg, equals(0));
      expect(seg.large, equals(0));
      expect(seg.sweep, equals(1));
      expect(seg.x, equals(20));
      expect(seg.y, equals(0));
    });

    test('arc flags without separators (packed)', () {
      // "011" should parse as large=0, sweep=1, then the 1 is part of next number
      final subs = parsePath('M 0 0 a 10 10 0 0110 0');
      expect(subs[0].segs.length, equals(1));
      final seg = subs[0].segs[0] as RawSegArc;
      expect(seg.large, equals(0));
      expect(seg.sweep, equals(1));
      // "10" is the x coordinate (relative, so absolute = 0 + 10 = 10)
      expect(seg.x, equals(10));
    });

    test('arc flags packed "0110"', () {
      // "0110" -> large=0, sweep=1, x="10"
      final subs = parsePath('M 0 0 a 5 5 0 0110 0');
      expect(subs[0].segs.length, equals(1));
      final seg = subs[0].segs[0] as RawSegArc;
      expect(seg.large, equals(0));
      expect(seg.sweep, equals(1));
      expect(seg.x, equals(10));
    });

    test('close path Z', () {
      final subs = parsePath('M 0 0 L 10 0 L 10 10 Z');
      expect(subs[0].closed, isTrue);
    });

    test('close path z (lowercase)', () {
      final subs = parsePath('M 0 0 L 10 0 L 10 10 z');
      expect(subs[0].closed, isTrue);
    });

    test('multiple subpaths', () {
      final subs = parsePath('M 0 0 L 10 0 Z M 20 20 L 30 20 Z');
      expect(subs.length, equals(2));
      expect(subs[0].closed, isTrue);
      expect(subs[1].closed, isTrue);
    });

    test('implicit command repetition', () {
      // After M, coordinate pairs without command should be treated as L
      final subs = parsePath('M 0 0 10 10 20 20');
      expect(subs[0].segs.length, equals(2));
    });

    test('scientific notation in numbers', () {
      final subs = parsePath('M 1e2 2E-1 L 3.5e+1 4E2');
      expect(subs[0].x0, equals(100));
      expect(subs[0].y0, closeTo(0.2, 1e-10));
      final seg = subs[0].segs[0] as RawSegLine;
      expect(seg.x, equals(35));
      expect(seg.y, equals(400));
    });

    test('comma as separator', () {
      final subs = parsePath('M 0,0 L 10,20');
      expect(subs[0].x0, equals(0));
      expect(subs[0].y0, equals(0));
      final seg = subs[0].segs[0] as RawSegLine;
      expect(seg.x, equals(10));
      expect(seg.y, equals(20));
    });

    test('mixed separators', () {
      final subs = parsePath('M 0, 0 L  10 ,20');
      expect(subs[0].segs.length, equals(1));
    });

    test('error: path must start with M', () {
      expect(() => parsePath('L 10 20'), throwsFormatException);
    });

    test('error: expected number', () {
      expect(() => parsePath('M x y'), throwsFormatException);
    });

    test('error: stray data after Z', () {
      expect(() => parsePath('M 0 0 Z 10 10'), throwsFormatException);
    });

    // Real Lucide-style paths (~40 icons)
    test('lucide menu icon', () {
      final d = 'M4 6h16M4 12h16M4 18h16';
      expect(() => parsePath(d), returnsNormally);
      final subs = parsePath(d);
      expect(subs.length, equals(3));
    });

    test('lucide x icon', () {
      final d = 'M18 6 6 18M6 6l12 12';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide chevron-right icon', () {
      final d = 'm9 18 6-6-6-6';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide arrow-right icon', () {
      final d = 'M5 12h14M12 5l7 7-7 7';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide home icon', () {
      final d = 'm3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide user icon', () {
      final d = 'M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide settings icon', () {
      final d = 'M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide search icon', () {
      final d = 'M21 21l-6-6m2-5a7 7 0 1 1-14 0 7 7 0 0 1 14 0z';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide heart icon', () {
      final d = 'M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide star icon', () {
      final d = 'M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide bell icon', () {
      final d = 'M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9M10.3 21a1.94 1.94 0 0 0 3.4 0';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide mail icon', () {
      final d = 'M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide send icon', () {
      final d = 'm22 2-7 20-4-9-9-4Z';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide edit icon', () {
      final d = 'M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide trash icon', () {
      final d = 'M3 6h18M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide plus icon', () {
      final d = 'M12 5v14M5 12h14';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide minus icon', () {
      final d = 'M5 12h14';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide check icon', () {
      final d = 'M20 6 9 17l-5-5';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide circle icon', () {
      // Real lucide circle `d`: moveto subpath has no segments and is
      // filtered; the two arcs form one closed subpath.
      const d = 'M12 12m-10 0a10 10 0 1 0 20 0a10 10 0 1 0 -20 0';
      final subs = parsePath(d);
      expect(subs.length, equals(1));
      expect(subs[0].segs.length, equals(2));
    });

    test('lucide square icon', () {
      final d = 'M3 3h18v18H3z';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide play icon', () {
      final d = 'm5 3 14 9-14 9V3z';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide pause icon', () {
      final d = 'M6 4h4v16H6zM14 4h4v16h-4z';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide skip-forward icon', () {
      final d = 'm5 4 10 8-10 8V4zM19 5v14';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide volume icon', () {
      final d = 'M11 5 6 9H2v6h4l5 4V5zM19.07 4.93a10 10 0 0 1 0 14.14M15.54 8.46a5 5 0 0 1 0 7.07';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide download icon', () {
      final d = 'M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide upload icon', () {
      final d = 'M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M17 8 12 3 7 8M12 3v12';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide camera icon', () {
      final d = 'M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2zM12 17a4 4 0 1 0 0-8 4 4 0 0 0 0 8z';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide image icon', () {
      final d = 'M19 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2zM8.5 10a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3zM21 15l-5-5L5 21';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide folder icon', () {
      final d = 'M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide file icon', () {
      final d = 'M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide calendar icon', () {
      final d = 'M8 2v4M16 2v4M3 10h18M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide clock icon', () {
      final d = 'M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10zM12 6v6l4 2';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide map-pin icon', () {
      final d = 'M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0zM12 13a3 3 0 1 0 0-6 3 3 0 0 0 0 6z';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide link icon', () {
      final d = 'M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide external-link icon', () {
      final d = 'M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6M15 3h6v6M10 14 21 3';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide lock icon', () {
      final d = 'M19 11H5a2 2 0 0 0-2 2v7a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7a2 2 0 0 0-2-2zM7 11V7a5 5 0 0 1 10 0v4';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide unlock icon', () {
      final d = 'M19 11H5a2 2 0 0 0-2 2v7a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7a2 2 0 0 0-2-2zM8 11V7a4 4 0 0 1 8 0';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide eye icon', () {
      final d = 'M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8zM12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide eye-off icon', () {
      final d = 'M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24M1 1l22 22';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide filter icon', () {
      final d = 'M22 3H2l8 9.46V19l4 2v-8.54L22 3z';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide grid icon', () {
      final d = 'M3 3h7v7H3zM14 3h7v7h-7zM14 14h7v7h-7zM3 14h7v7H3z';
      expect(() => parsePath(d), returnsNormally);
    });

    test('lucide list icon', () {
      final d = 'M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01';
      expect(() => parsePath(d), returnsNormally);
    });

    // Additional edge case tests
    test('negative numbers', () {
      final subs = parsePath('M -10 -20 L -5 -10');
      expect(subs[0].x0, equals(-10));
      expect(subs[0].y0, equals(-20));
    });

    test('positive sign in numbers', () {
      final subs = parsePath('M +10 +20 L +5 +10');
      expect(subs[0].x0, equals(10));
      expect(subs[0].y0, equals(20));
    });

    test('arc with rotation', () {
      final subs = parsePath('M 0 0 A 10 5 45 0 1 20 0');
      final seg = subs[0].segs[0] as RawSegArc;
      expect(seg.rotDeg, equals(45));
    });

    test('arc large-arc flag', () {
      final subs = parsePath('M 0 0 A 10 10 0 1 0 20 0');
      final seg = subs[0].segs[0] as RawSegArc;
      expect(seg.large, equals(1));
    });

    test('Z resets current point to start', () {
      final subs = parsePath('M 10 20 L 30 40 Z L 50 60');
      // After Z, current point should be back at (10, 20)
      // So the L should be relative to (10, 20) if it was relative
      // But L is absolute, so it goes to (50, 60)
      expect(subs.length, equals(2)); // Z creates a new subpath on next draw
    });

    test('multiple arcs', () {
      final d = 'M 0 0 A 10 10 0 0 1 20 0 A 10 10 0 0 1 40 0';
      expect(() => parsePath(d), returnsNormally);
      final subs = parsePath(d);
      expect(subs[0].segs.length, equals(2));
    });
  });
}
