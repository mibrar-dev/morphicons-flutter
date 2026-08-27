import 'dart:io';

import 'package:morphicons_tabler/morphicons_tabler.dart';

/// Icon data is plain `d` strings — usable anywhere, with or without Flutter.
/// Run with: dart run example/main.dart
void main() {
  // By constant:
  stdout.writeln('heart: ${MorphIconsTabler.heart}');
  stdout.writeln('x:    ${MorphIconsTabler.x}');

  // By name:
  for (final name in ['arrow-right', 'check', 'plus', 'heart', 'star']) {
    stdout.writeln('$name: ${tablerIcons[name]}');
  }

  stdout.writeln('total icons: ${tablerIcons.length}');
}
