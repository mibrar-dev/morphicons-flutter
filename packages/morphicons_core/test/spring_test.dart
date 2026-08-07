import 'dart:math';

import 'package:morphicons_core/src/spring.dart';
import 'package:test/test.dart';

void main() {
  group('presets', () {
    test('k/c values match upstream exactly', () {
      expect(SpringPreset.smooth.k, 170);
      expect(SpringPreset.smooth.c, 26);
      expect(SpringPreset.snappy.k, 420);
      expect(SpringPreset.snappy.c, 30);
      expect(SpringPreset.bouncy.k, 300);
      expect(SpringPreset.bouncy.c, 14);
    });

    test('damping ratios match upstream comments', () {
      double zeta(SpringPreset p) => p.c / (2 * sqrt(p.k));
      expect(zeta(SpringPreset.smooth), closeTo(1.00, 0.005));
      expect(zeta(SpringPreset.snappy), closeTo(0.73, 0.005));
      expect(zeta(SpringPreset.bouncy), closeTo(0.40, 0.005));
    });
  });

  group('settle condition |1-x| < 0.001 AND |v| < 0.02', () {
    test('inside both thresholds settles', () {
      expect(springSettled(1.0, 0.0), isTrue);
      expect(springSettled(1.0005, 0.019), isTrue);
      expect(springSettled(0.9995, -0.019), isTrue);
    });

    test('outside either threshold does not settle', () {
      expect(springSettled(0.998, 0.0), isFalse); // |1-x| = 0.002
      expect(springSettled(1.002, 0.0), isFalse);
      expect(springSettled(1.0, 0.03), isFalse); // |v| too large
      expect(springSettled(0.9995, 0.02), isFalse); // |v| at boundary (strict <)
      expect(springSettled(0.999, 0.0), isFalse); // |1-x| at boundary (strict <)
    });

    test('step() returns the settle condition', () {
      final s = Spring();
      s.x = 1;
      s.v = 0;
      expect(s.step(1 / 60), isTrue);
      s.x = 0.5;
      s.v = 0;
      expect(s.step(1 / 60), isFalse);
    });
  });

  group('integration', () {
    test('smooth preset converges to x ~ 1', () {
      final s = Spring()
        ..x = 0
        ..applyPreset(SpringPreset.smooth)
        ..start();
      var settled = false;
      for (var frame = 0; frame < 600; frame++) {
        settled = s.step(1 / 60);
        if (settled) break;
      }
      expect(settled, isTrue);
      expect(s.x, closeTo(1.0, 0.001));
      expect(s.v.abs(), lessThan(0.02));
    });

    test('semi-implicit Euler matches a hand-computed substep', () {
      // One substep at h = 1/240 from x=0, v=0 with k=170, c=26.
      const h = 1 / 240;
      final st = stepSpring(SpringState(0, 0), k: 170, c: 26);
      final a = 170 * (1 - 0.0) - 26 * 0.0;
      final v = a * h;
      expect(st.v, v);
      expect(st.x, v * h);
    });

    test('bouncy preset overshoots (zeta < 1)', () {
      final s = Spring()
        ..applyPreset(SpringPreset.bouncy)
        ..start();
      var maxX = 0.0;
      for (var frame = 0; frame < 600; frame++) {
        if (s.step(1 / 60)) break;
        if (s.x > maxX) maxX = s.x;
      }
      expect(maxX, greaterThan(1.0));
    });
  });

  group('velocity clamp', () {
    test('start() clamps velocity to +/-14', () {
      final s = Spring();
      s.v = 20;
      s.start();
      expect(s.v, 14);
      s.v = -20;
      s.start();
      expect(s.v, -14);
      s.v = 5;
      s.start();
      expect(s.v, 5);
      s.v = -5;
      s.start();
      expect(s.v, -5);
    });
  });

  group('interruption re-plan', () {
    test('re-planning mid-flight preserves velocity, no position jump', () {
      final s = Spring()..applyPreset(SpringPreset.smooth);
      s.start();
      // Advance partway (10 frames at 60fps): 0 < x < 1, v > 0.
      for (var i = 0; i < 10; i++) {
        s.step(1 / 60);
      }
      final xMid = s.x;
      final vMid = s.v;
      expect(xMid, greaterThan(0));
      expect(xMid, lessThan(1));

      // Rendered shape before interruption: blend(from, to, xMid).
      const from = 0.0;
      const to = 10.0;
      final renderedBefore = from + (to - from) * xMid;

      // Re-plan: the current sampled shape becomes the new `from`, and the
      // spring restarts at x = 0 with preserved velocity.
      s.start();
      expect(s.x, 0.0); // new plan starts at the re-sampled shape
      expect(s.v, vMid); // velocity preserved
      final newFrom = renderedBefore;
      final renderedAfter = newFrom + (to - newFrom) * s.x;
      expect(renderedAfter, renderedBefore); // no visual jump
    });

    test('rapid re-trigger continues with carried velocity', () {
      final s = Spring()..applyPreset(SpringPreset.snappy);
      s.start();
      for (var i = 0; i < 5; i++) {
        s.step(1 / 60);
      }
      final vBefore = s.v;
      s.start(); // interrupt mid-flight
      expect(s.v, vBefore);
      s.step(1 / 60);
      // Motion continues forward from the carried velocity, not from rest.
      expect(s.x, greaterThan(vBefore * (1 / 60) * 0.5));
    });
  });
}
