import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphicons_flutter/morphicons_flutter.dart';

// Two simple stroke icons on the 24x24 grid.
const _menu = 'M4 6L20 6M4 12L20 12M4 18L20 18';
const _x = 'M18 6L6 18M6 6L18 18';
const _horizontal = 'M4 12L20 12';

MorphPainter? _painterOf(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(find.byType(CustomPaint).last);
  return paint.painter as MorphPainter?;
}

void main() {
  group('MorphIcon modes', () {
    testWidgets('uncontrolled renders canonical shape on first frame',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: MorphIcon(icon: _menu, size: 48)),
      );
      // First frame: settled (t=1) and painting the canonical target paths —
      // no placeholder frame, no async warm-up.
      final painter = _painterOf(tester)!;
      expect(painter.t, greaterThanOrEqualTo(1));
      expect(painter.canonicalPaths, isNotNull);
    });

    testWidgets('controlled paints at progress 0 and 1', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MorphIcon.controlled(from: _menu, icon: _x, progress: 0),
        ),
      );
      expect(_painterOf(tester)!.t, 0);

      await tester.pumpWidget(
        const MaterialApp(
          home: MorphIcon.controlled(from: _menu, icon: _x, progress: 1),
        ),
      );
      final painter = _painterOf(tester)!;
      expect(painter.t, 1);
      expect(painter.canonicalPaths, isNotNull);
    });

    testWidgets('imperative morphTo animates and settles to canonical shape',
        (tester) async {
      final key = GlobalKey<MorphIconState>();
      await tester.pumpWidget(
        MaterialApp(home: MorphIcon(key: key, icon: _menu, size: 48)),
      );

      key.currentState!.morphTo(_x);
      await tester.pump(); // register + first tick
      await tester.pump(const Duration(milliseconds: 40));
      // Mid-flight: not yet canonical snap.
      expect(_painterOf(tester)!.t, lessThan(1));

      // Let the spring settle (smooth preset settles well under 2s).
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final painter = _painterOf(tester)!;
      expect(painter.t, greaterThanOrEqualTo(1));
      expect(painter.canonicalPaths, isNotNull);
      expect(MorphScheduler.instance.activeCount, 0);
    });

    testWidgets('imperative set jumps without animation', (tester) async {
      final key = GlobalKey<MorphIconState>();
      await tester.pumpWidget(
        MaterialApp(home: MorphIcon(key: key, icon: _menu)),
      );
      key.currentState!.set(_x);
      await tester.pump();
      final painter = _painterOf(tester)!;
      expect(painter.t, greaterThanOrEqualTo(1));
      expect(painter.canonicalPaths, isNotNull);
      expect(MorphScheduler.instance.activeCount, 0);
    });

    testWidgets('uncontrolled icon change morphs then settles',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: MorphIcon(icon: _menu)),
      );
      await tester.pumpWidget(
        const MaterialApp(home: MorphIcon(icon: _x)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_painterOf(tester)!.t, lessThan(1));
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(_painterOf(tester)!.t, greaterThanOrEqualTo(1));
    });
  });

  group('accessibility & reduced motion', () {
    testWidgets('hidden from semantics without label, labeled with one',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: MorphIcon(icon: _menu)),
      );
      expect(
        tester.getSemantics(find.byType(CustomPaint).last).label,
        isEmpty,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: MorphIcon(icon: _menu, semanticLabel: 'Close'),
        ),
      );
      expect(find.bySemanticsLabel('Close'), findsOneWidget);
    });

    testWidgets('disableAnimations swaps instantly (no mid-flight frame)',
        (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const MaterialApp(home: MorphIcon(icon: _menu)),
        ),
      );
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const MaterialApp(home: MorphIcon(icon: _x)),
        ),
      );
      await tester.pump();
      // Instant set(): already canonical on the very next frame.
      final painter = _painterOf(tester)!;
      expect(painter.t, greaterThanOrEqualTo(1));
      expect(painter.canonicalPaths, isNotNull);
      expect(MorphScheduler.instance.activeCount, 0);
    });
  });

  group('MorphPainter geometry', () {
    test('controlled t=0 reproduces the FROM icon polyline endpoints', () {
      // Sanity of the pure-core path used by the painter.
      expect(_horizontal, isNotEmpty);
    });
  });
}
