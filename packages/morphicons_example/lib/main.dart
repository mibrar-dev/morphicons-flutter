import 'package:flutter/material.dart';

import 'src/playground_home.dart';

void main() => runApp(const MorphiconsPlayground());

/// Morphicons playground: morph stage, spring picker, t-scrubber, icon grid
/// and θ/σ/residual debug readout. Material 3, follows system light/dark.
class MorphiconsPlayground extends StatelessWidget {
  const MorphiconsPlayground({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Morphicons Playground',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3E63DD)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3E63DD),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const PlaygroundHome(),
    );
  }
}
