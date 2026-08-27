import 'package:morphicons_core/morphicons_core.dart';
import 'package:morphicons_heroicons/morphicons_heroicons.dart';
import 'package:test/test.dart';

void main() {
  test('every generated heroicons outline icon parses without throwing', () {
    expect(heroiconsIcons.length, greaterThan(300));
    var parsed = 0;
    for (final entry in heroiconsIcons.entries) {
      try {
        final subs = parsePath(entry.value);
        expect(subs, isNotEmpty, reason: '${entry.key} produced no subpaths');
        parsed++;
      } catch (e) {
        fail('heroicons outline icon "${entry.key}" failed to parse: $e');
      }
    }
    expect(parsed, heroiconsIcons.length);
  });

  test('every generated heroicons solid 20 fitted icon parses', () {
    expect(heroiconsSolidIcons.length, greaterThan(300));
    var parsed = 0;
    for (final entry in heroiconsSolidIcons.entries) {
      try {
        final subs = parsePath(entry.value);
        expect(subs, isNotEmpty, reason: 'solid ${entry.key} produced no subpaths');
        parsed++;
      } catch (e) {
        fail('heroicons solid icon "${entry.key}" failed to parse: $e');
      }
    }
    expect(parsed, heroiconsSolidIcons.length);
  });

  test('every generated heroicons solid 24 icon parses', () {
    expect(heroiconsSolid24Icons.length, greaterThan(300));
    for (final entry in heroiconsSolid24Icons.entries) {
      final subs = parsePath(entry.value);
      expect(subs, isNotEmpty, reason: 'solid24 ${entry.key} produced no subpaths');
    }
  });

  test('every generated heroicons solid 16 fitted icon parses', () {
    expect(heroiconsSolid16Icons.length, greaterThan(300));
    for (final entry in heroiconsSolid16Icons.entries) {
      final subs = parsePath(entry.value);
      expect(subs, isNotEmpty, reason: 'solid16 ${entry.key} produced no subpaths');
    }
  });

  test('spot-check geometry of known heroicons', () {
    // Outline x-mark: two diagonals on 24 grid (6,6)-(18,18) and (6,18)-(18,6).
    // Heroicons outline x-mark is "M6 18 18 6M6 6l12 12" with M0 0 anchor.
    final xMark = parsePath(MorphIconsHeroicons.xMark);
    expect(xMark.length, 2);
    // First subpath starts at 6,18 after M0 0 anchor drop.
    expect(xMark[0].x0, 6);
    expect(xMark[0].y0, 18);
    expect(xMark[1].x0, 6);
    expect(xMark[1].y0, 6);

    // bars-3 outline: three horizontal lines at y=6.75,12,17.25 on 24 grid.
    final bars3 = parsePath(MorphIconsHeroicons.bars3);
    expect(bars3.length, 3);

    // check outline: single check path
    final check = parsePath(MorphIconsHeroicons.check);
    expect(check.length, 1);

    // solid heart (20→24 fitted) should be a single closed evenodd shape.
    final heartSolid = parsePath(MorphIconsHeroiconsSolid.heart);
    expect(heartSolid.length, 1);
    expect(heartSolid[0].closed, isTrue);

    // solid heart 24 should also be one closed shape.
    final heartSolid24 = parsePath(MorphIconsHeroiconsSolid24.heart);
    expect(heartSolid24.length, 1);

    // Outline heart is a stroked open path — single subpath.
    final heartOutline = parsePath(MorphIconsHeroicons.heart);
    expect(heartOutline.length, 1);

    // heroiconsIcons map mirrors class constants.
    expect(heroiconsIcons['x-mark'], MorphIconsHeroicons.xMark);
    expect(heroiconsIcons['bars-3'], MorphIconsHeroicons.bars3);
    expect(heroiconsSolidIcons['heart'], MorphIconsHeroiconsSolid.heart);
    expect(heroiconsSolid24Icons['heart'], MorphIconsHeroiconsSolid24.heart);
  });

  test('viewBox fitting for solid 20 is applied (coordinates scaled ×1.2)', () {
    // Solid academic-cap raw 20-grid has first move ~9.664 1.319; fitted to 24 should be ~11.5968 1.5828.
    // Check that solid fitted x0 is ~1.2× the 20-grid value and >10 (since 9.6*1.2=11.5).
    final fitted = parsePath(MorphIconsHeroiconsSolid.academicCap);
    expect(fitted, isNotEmpty);
    expect(fitted[0].x0, closeTo(11.5968, 0.01));
    expect(fitted[0].y0, closeTo(1.5828, 0.01));

    // Outline academic-cap stays on 24 grid, first x ~4.26 (not scaled).
    final outline = parsePath(MorphIconsHeroicons.academicCap);
    expect(outline[0].x0, closeTo(4.26, 0.01));
  });

  test('heroiconsAllIcons combined map', () {
    expect(heroiconsAllIcons.length, greaterThan(300));
    // Should contain keys from both.
    expect(heroiconsAllIcons.containsKey('bars-3'), isTrue);
    expect(heroiconsAllIcons.containsKey('heart'), isTrue);
  });
}
