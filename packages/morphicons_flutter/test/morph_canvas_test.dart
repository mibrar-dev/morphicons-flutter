import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphicons_flutter/morphicons_flutter.dart';

const _menu = 'M4 6L20 6M4 12L20 12M4 18L20 18';
const _x = 'M18 6L6 18M6 6L18 18';

void main() {
  test('controlled painter accepts endpoints and overshoot', () {
    for (final progress in [0.0, 1.0, 1.25]) {
      final painter = MorphCanvasPainter.controlled(
        from: _menu,
        to: _x,
        progress: progress,
        color: Colors.red,
        strokeWidth: 3,
        viewBox: 24,
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size.square(64));
      recorder.endRecording().dispose();
    }
  });

  test('shouldRepaint compares all paint inputs', () {
    MorphCanvasPainter painter(double progress) =>
        MorphCanvasPainter.controlled(from: _menu, to: _x, progress: progress);
    final same = painter(0);
    expect(same.shouldRepaint(painter(0)), isFalse);
    expect(same.shouldRepaint(painter(1)), isTrue);
    expect(
      same.shouldRepaint(
        MorphCanvasPainter.controlled(
          from: _menu,
          to: _x,
          progress: 0,
          color: Colors.blue,
        ),
      ),
      isTrue,
    );
  });

  testWidgets('controlled canvas is ticker-free and accessible',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MorphCanvas.controlled(
          from: _menu,
          icon: _x,
          progress: 1.25,
          semanticLabel: 'Close',
        ),
      ),
    );
    expect(MorphScheduler.instance.activeCount, 0);
    expect(find.bySemanticsLabel('Close'), findsOneWidget);
    final customPaint =
        tester.widget<CustomPaint>(find.byType(CustomPaint).last);
    expect(customPaint.painter, isA<MorphCanvasPainter>());
  });

  testWidgets('uncontrolled canvas unregisters on dispose', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MorphCanvas(icon: _menu)));
    await tester.pumpWidget(const MaterialApp(home: MorphCanvas(icon: _x)));
    expect(MorphScheduler.instance.activeCount, 1);
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    expect(MorphScheduler.instance.activeCount, 0);
  });
}
