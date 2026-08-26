import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphicons_flutter/morphicons_flutter.dart';

const _menu = 'M4 6L20 6M4 12L20 12M4 18L20 18';
const _x = 'M18 6L6 18M6 6L18 18';

void main() {
  test('morphTo and morph aliases produce equivalent pairs', () {
    final pair = _menu.morphTo(_x);
    final samePair = _menu.morph(_x);

    expect(pair.from, _menu);
    expect(pair.to, _x);
    expect(samePair.from, pair.from);
    expect(samePair.to, pair.to);
    expect(pair.tween(), isA<MorphTween>());
  });

  test('pair icon creates the controlled widget factory', () {
    final icon = _menu.morphTo(_x).icon(progress: 0.5);

    expect(icon, isA<MorphIcon>());
    expect(icon.from, _menu);
    expect(icon.icon, _x);
    expect(icon.progress, 0.5);
  });

  test('pair canvas creates the controlled canvas factory', () {
    final canvas = _menu.morphTo(_x).canvas(progress: 0.75);

    expect(canvas, isA<MorphCanvas>());
    expect(canvas.from, _menu);
    expect(canvas.icon, _x);
    expect(canvas.progress, 0.75);
  });

  test('pair mask creates the controlled mask factory', () {
    final mask =
        _menu.morphTo(_x).mask(progress: 0.25, child: const SizedBox.shrink());

    expect(mask, isA<MorphMask>());
    expect(mask.from, _menu);
    expect(mask.icon, _x);
    expect(mask.progress, 0.25);
  });

  test('string extensions produce equivalent controlled widgets', () {
    final pair = _menu.morphTo(_x);

    final canvas = _menu.morphCanvasTo(_x, progress: 0.75);
    expect(canvas.from, pair.from);
    expect(canvas.icon, pair.to);
    expect(canvas.progress, 0.75);

    final mask = _menu.morphMaskTo(
      _x,
      progress: 0.25,
      child: const SizedBox.shrink(),
    );
    expect(mask.from, pair.from);
    expect(mask.icon, pair.to);
    expect(mask.progress, 0.25);
  });
}
