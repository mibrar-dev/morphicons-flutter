import 'dart:io';

import 'package:morphicons_lucide/morphicons_lucide.dart';

/// Icon data is plain `d` strings — usable anywhere, with or without Flutter.
/// Run with: dart run example/main.dart
void main() {
  // By constant:
  stdout.writeln('menu: ${MorphIconsLucide.menu}');
  stdout.writeln('x:    ${MorphIconsLucide.x}');

  // By name:
  for (final name in ['arrow-right', 'check', 'plus', 'heart', 'star']) {
    stdout.writeln('$name: ${lucideIcons[name]}');
  }

  stdout.writeln('total icons: ${lucideIcons.length}');
}
