import 'dart:io';

import 'package:morphicons_heroicons/morphicons_heroicons.dart';

/// Icon data is plain `d` strings — usable anywhere, with or without Flutter.
/// Run with: dart run example/main.dart
void main() {
  // Outline 24×24 stroke — primary (like Lucide, no fitIcon needed)
  stdout.writeln('outline bars3: ${MorphIconsHeroicons.bars3}');
  stdout.writeln('outline xMark: ${MorphIconsHeroicons.xMark}');
  stdout.writeln('outline heart: ${MorphIconsHeroicons.heart}');

  // Solid 20×20 fitted to 24×24 — fill
  stdout.writeln('solid heart: ${MorphIconsHeroiconsSolid.heart}');
  stdout.writeln('solid24 heart: ${MorphIconsHeroiconsSolid24.heart}');

  // By name:
  for (final name in ['arrow-right', 'check', 'plus', 'heart', 'star']) {
    // heroicons uses star already? check outline star
    stdout.writeln('$name (outline): ${heroiconsIcons[name]}');
    stdout.writeln('$name (solid): ${heroiconsSolidIcons[name]}');
  }

  stdout.writeln('outline count: ${heroiconsIcons.length}');
  stdout.writeln('solid20 count: ${heroiconsSolidIcons.length}');
  stdout.writeln('solid24 count: ${heroiconsSolid24Icons.length}');
  stdout.writeln('solid16 count: ${heroiconsSolid16Icons.length}');
  stdout.writeln('total fitted solid20 bars-3 path: ${heroiconsSolidIcons['bars-3']}');
}
