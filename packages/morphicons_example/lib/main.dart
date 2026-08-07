import 'package:flutter/material.dart';

void main() => runApp(const MorphiconsPlayground());

/// Placeholder shell — filled in during Phase 13.
class MorphiconsPlayground extends StatelessWidget {
  const MorphiconsPlayground({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Morphicons Playground',
      home: Scaffold(body: Center(child: Text('Morphicons'))),
    );
  }
}
