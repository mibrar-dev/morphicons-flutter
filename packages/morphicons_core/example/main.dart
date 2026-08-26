import 'dart:io';

import 'package:morphicons_core/morphicons_core.dart';

/// Pure-Dart usage — no Flutter needed. Run with:
///   dart run example/main.dart
void main() {
  const menu = 'M4 6L20 6M4 12L20 12M4 18L20 18';
  const x = 'M18 6L6 18M6 6L18 18';

  // Build a morph plan between two icons.
  final plan = planBetween(menu, x);
  final out = allocOutputs(plan);

  // Interpolate at t = 0.5 in polar/similarity space.
  interpPolar(plan, 0.5, out);
  stdout.writeln('mid-flight polyline: ${serialize(out).substring(0, 40)}…');

  // The solver's decision for this pair:
  final item = plan.items.first;
  stdout.writeln('theta: ${item.theta} rad');
  stdout.writeln('block hybrid applied: ${item.block != null}');

  // Spring to completion with the `snappy` preset.
  final spring = Spring()..applyPreset(SpringPreset.snappy)..start();
  var frames = 0;
  while (!spring.step(1 / 60)) {
    frames++;
  }
  stdout.writeln('settled after ${frames / 60.0}s');
}
