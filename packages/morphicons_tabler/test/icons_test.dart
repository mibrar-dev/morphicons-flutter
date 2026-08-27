import 'package:morphicons_core/morphicons_core.dart';
import 'package:morphicons_tabler/morphicons_tabler.dart';
import 'package:test/test.dart';

void main() {
  test('every generated tabler icon parses without throwing', () {
    expect(tablerIcons.length, greaterThan(4000));
    var parsed = 0;
    for (final entry in tablerIcons.entries) {
      try {
        final subs = parsePath(entry.value);
        expect(subs, isNotEmpty, reason: '${entry.key} produced no subpaths');
        parsed++;
      } catch (e) {
        fail('icon "${entry.key}" failed to parse: $e');
      }
    }
    expect(parsed, tablerIcons.length);
  });

  test('spot-check geometry of known icons', () {
    // x: two diagonals (18,6)-(6,18) and (6,6)-(18,18) — same as lucide x.
    final x = parsePath(MorphIconsTabler.x);
    expect(x.length, 2);
    expect(x[0].x0, 18);
    expect(x[0].y0, 6);
    expect(x[1].x0, 6);
    expect(x[1].y0, 6);

    // menu-2: three horizontal lines at y = 6, 12, 18.
    final menu2 = parsePath(MorphIconsTabler.menu2);
    expect(menu2.length, 3);

    // check: single polyline "M5 12l5 5l10 -10" → one subpath.
    final check = parsePath(MorphIconsTabler.check);
    expect(check.length, 1);
    expect(check[0].segs.length, 2);

    // home: Tabler home has 3 subpaths (roof, wall, inner door).
    final home = parsePath(MorphIconsTabler.home);
    expect(home.length, 3);

    // circle via arc notation is two arcs back to start, no explicit Z.
    // Parser marks closed only on Z, so we check one subpath with two arcs.
    final circle = parsePath(MorphIconsTabler.circle);
    expect(circle.length, 1);
    expect(circle[0].segs.length, 2);
  });

  test('brand-kbin (g wrapper) and binoculars (rect) parse', () {
    // brand-kbin was a <g> wrapper in raw SVG — must have been flattened.
    final brandKbin = parsePath(MorphIconsTabler.brandKbin);
    expect(brandKbin.length, 2);

    // binoculars contains a <rect> at the bridge.
    final binoculars = parsePath(MorphIconsTabler.binoculars);
    expect(binoculars.length, greaterThan(5));
  });

  test('tablerIcons map mirrors class constants', () {
    expect(tablerIcons['x'], MorphIconsTabler.x);
    expect(tablerIcons['heart'], MorphIconsTabler.heart);
    expect(tablerIcons['star'], MorphIconsTabler.star);
  });
}
