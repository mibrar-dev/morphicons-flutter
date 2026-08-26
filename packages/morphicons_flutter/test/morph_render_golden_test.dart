import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:morphicons_flutter/morphicons_flutter.dart';

const _menu = 'M4 6L20 6M4 12L20 12M4 18L20 18';
const _x = 'M18 6L6 18M6 6L18 18';

void main() {
  test('fixed-size canvas raster smoke test has a non-empty picture', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    MorphCanvasPainter.controlled(from: _menu, to: _x, progress: 1.25)
        .paint(canvas, const Size.square(64));
    final picture = recorder.endRecording();
    expect(picture.approximateBytesUsed, greaterThan(0));
    picture.dispose();
  });
}
