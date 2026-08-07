import 'package:morphicons_core/morphicons_core.dart';
import 'package:morphicons_lucide/morphicons_lucide.dart';
import 'package:test/test.dart';

void main() {
  test('every generated lucide icon parses without throwing', () {
    expect(lucideIcons.length, greaterThan(1500));
    var parsed = 0;
    for (final entry in lucideIcons.entries) {
      try {
        final subs = parsePath(entry.value);
        expect(subs, isNotEmpty, reason: '${entry.key} produced no subpaths');
        parsed++;
      } catch (e) {
        fail('icon "${entry.key}" failed to parse: $e');
      }
    }
    expect(parsed, lucideIcons.length);
  });

  test('spot-check geometry of known icons', () {
    // x: two diagonals (18,6)-(6,18) and (6,6)-(18,18).
    final x = parsePath(MorphIconsLucide.x);
    expect(x.length, 2);
    expect(x[0].x0, 18);
    expect(x[0].y0, 6);
    expect(x[1].x0, 6);
    expect(x[1].y0, 6);

    // menu: three horizontal lines at y = 12, 6, 18.
    final menu = parsePath(MorphIconsLucide.menu);
    expect(menu.length, 3);
  });
}
