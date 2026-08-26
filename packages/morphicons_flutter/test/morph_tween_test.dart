import 'package:flutter_test/flutter_test.dart';
import 'package:morphicons_flutter/morphicons_flutter.dart';

const _menu = 'M4 6L20 6M4 12L20 12M4 18L20 18';
const _x = 'M18 6L6 18M6 6L18 18';

void main() {
  test('returns exact canonical endpoints', () {
    final tween = MorphTween(from: _menu, to: _x);

    expect(tween.transform(0), _menu);
    expect(tween.transform(1), _x);
    expect(tween.lerp(0), tween.transform(0));
    expect(tween.lerp(1), tween.transform(1));
  });

  test('progress above one remains extrapolated', () {
    final tween = MorphTween(from: _menu, to: _x);

    final atOne = tween.transform(1);
    final overshoot = tween.transform(1.25);

    expect(atOne, isNotEmpty);
    expect(overshoot, isNotEmpty);
    expect(overshoot, isNot(atOne));
    expect(overshoot, isNot(contains('NaN')));
    expect(overshoot, isNot(contains('Infinity')));
  });

  test('rejects non-finite progress', () {
    final tween = MorphTween(from: _menu, to: _x);

    expect(() => tween.transform(double.nan), throwsArgumentError);
    expect(() => tween.transform(double.infinity), throwsArgumentError);
    expect(() => tween.transform(double.negativeInfinity), throwsArgumentError);
  });
}
