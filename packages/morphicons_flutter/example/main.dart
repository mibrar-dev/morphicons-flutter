import 'package:flutter/material.dart';
import 'package:morphicons_flutter/morphicons_flutter.dart';

/// Minimal runnable example. In a real app, add `morphicons_lucide` for icon
/// data — here we use two raw `d` strings so the example is self-contained.
void main() => runApp(const ExampleApp());

const _menu = 'M4 6L20 6M4 12L20 12M4 18L20 18';
const _x = 'M18 6L6 18M6 6L18 18';

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  final _iconKey = GlobalKey<MorphIconState>();
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Uncontrolled mode: change `icon`, the morph animates.
              // The key also exposes the imperative API (morphTo / set).
              MorphIcon(
                key: _iconKey,
                icon: _open ? _x : _menu,
                spring: SpringPreset.snappy,
                size: 96,
                semanticLabel: _open ? 'Close' : 'Menu',
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  setState(() => _open = !_open);
                  // Equivalent imperative call:
                  // _iconKey.currentState?.morphTo(_open ? _x : _menu);
                },
                child: Text(_open ? 'Show menu' : 'Show close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
