import 'package:flutter/material.dart';
import 'package:morphicons_flutter/morphicons_flutter.dart';

/// Real Flutter `IconData` morph example.
///
/// Same widget, same solver — `MorphIcon(icon: Icons.home)` animates to any
/// other `IconData` or stroked `String d`. This file is the repo counterpart
/// to the live website IconData section (`website/index.html#icondata`).
///
/// Run with: `flutter run -d chrome --target example/icon_data_example.dart`
void main() => runApp(const IconDataExampleApp());

class IconDataExampleApp extends StatefulWidget {
  const IconDataExampleApp({super.key});

  @override
  State<IconDataExampleApp> createState() => _IconDataExampleAppState();
}

class _IconDataExampleAppState extends State<IconDataExampleApp> {
  bool _first = true;
  bool _useMaterial = true;

  // Curated pairs — Material Icons glyphs go through the same Procrustes +
  // polar solver as stroke icons (see lib/src/icon_data_resolver.dart).
  static const _homeFavorite = (Icons.home, Icons.favorite);
  static const _searchStar = (Icons.search, Icons.star);

  (IconData, IconData) get _materialPair =>
      _first ? _homeFavorite : _searchStar;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('MorphIcon — IconData live')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Uncontrolled IconData morph ──────────────────────────
              // Same widget as SVG: swap `icon`, spring animates.
              MorphIcon(
                icon: _useMaterial
                    ? (_first ? _materialPair.$1 : _materialPair.$2)
                    : (_first
                        ? MaterialIconPaths.home
                        : MaterialIconPaths.favorite),
                spring: SpringPreset.snappy,
                size: 96,
                // Filled glyphs are rendered with PaintingStyle.fill,
                // strokeWidth is ignored — see morph_painter.dart:filled.
                semanticLabel: _first ? 'Home' : 'Favorite',
              ),
              const SizedBox(height: 12),
              Text(
                _useMaterial
                    ? 'MorphIcon(icon: Icons.${_first ? "home" : "favorite"})'
                    : 'MorphIcon(icon: "M12 21.35...") // heart d',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              const SizedBox(height: 20),

              // ── Controls ─────────────────────────────────────────────
              FilledButton(
                onPressed: () => setState(() => _first = !_first),
                child: Text(_first ? 'Morph to ${_materialPair.$2}' : 'Morph back'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => setState(() => _useMaterial = !_useMaterial),
                child: Text(
                  _useMaterial
                      ? 'Switch to String d (Lucide heart)'
                      : 'Switch to IconData (Material)',
                ),
              ),
              const SizedBox(height: 24),

              // ── Controlled (scrub) + Mixed ───────────────────────────
              const Text('Controlled + mixed (IconData ↔ String):',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 8),
              const _MixedDemo(),
              const SizedBox(height: 24),
              const _ImperativeDemo(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Controlled slider driving a filled morph.
class _MixedDemo extends StatefulWidget {
  const _MixedDemo();
  @override
  State<_MixedDemo> createState() => _MixedDemoState();
}

class _MixedDemoState extends State<_MixedDemo> {
  double _t = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MorphIcon.controlled(
          from: Icons.home,
          icon: Icons.settings,
          progress: _t,
          size: 64,
          semanticLabel: 'Home → Settings at ${(_t * 100).round()}%',
        ),
        Slider(
          value: _t,
          onChanged: (v) => setState(() => _t = v),
        ),
        Text('progress: ${_t.toStringAsFixed(2)}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
      ],
    );
  }
}

/// Imperative via GlobalKey.
class _ImperativeDemo extends StatefulWidget {
  const _ImperativeDemo();
  @override
  State<_ImperativeDemo> createState() => _ImperativeDemoState();
}

class _ImperativeDemoState extends State<_ImperativeDemo> {
  final _key = GlobalKey<MorphIconState>();
  bool _toStar = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MorphIcon(
          key: _key,
          icon: Icons.star,
          size: 48,
        ),
        const SizedBox(width: 12),
        FilledButton.tonal(
          onPressed: () {
            _toStar = !_toStar;
            _key.currentState?.morphTo(_toStar ? Icons.favorite : Icons.star);
          },
          child: const Text('morphTo via key'),
        ),
      ],
    );
  }
}
