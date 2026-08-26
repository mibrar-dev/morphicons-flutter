import 'package:flutter/material.dart';
import 'package:morphicons_flutter/morphicons_flutter.dart';
import 'package:morphicons_lucide/morphicons_lucide.dart';

import 'debug_panel.dart';
import 'icon_grid_screen.dart';

const Map<String, SpringPreset> _springPresets = {
  'smooth': SpringPreset.smooth,
  'snappy': SpringPreset.snappy,
  'bouncy': SpringPreset.bouncy,
};

/// Playground home: morph stage + spring picker + t-scrubber + debug readout.
class PlaygroundHome extends StatefulWidget {
  const PlaygroundHome({super.key});

  @override
  State<PlaygroundHome> createState() => _PlaygroundHomeState();
}

class _PlaygroundHomeState extends State<PlaygroundHome> {
  String _fromName = 'menu';
  String _toName = 'x';
  String _displayed = 'menu';
  String _presetName = 'snappy';
  bool _scrubMode = false;
  double _t = 0;

  String get _fromD => lucideIcons[_fromName]!;
  String get _toD => lucideIcons[_toName]!;

  void _resetStageToFrom() {
    _displayed = _fromName;
    _t = 0;
  }

  Future<void> _openGrid() async {
    final picked = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => IconGridScreen(selectedName: _toName),
      ),
    );
    if (picked == null || picked == _toName) return;
    setState(() {
      _toName = picked;
      _resetStageToFrom();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final strokeColor = scheme.onSurface;

    final stage = _scrubMode
        ? MorphIcon.controlled(
            from: _fromD,
            icon: _toD,
            progress: _t,
            size: 160,
            strokeWidth: 2,
            color: strokeColor,
            semanticLabel: '$_fromName to $_toName at ${(_t * 100).round()}%',
          )
        : MorphIcon(
            icon: lucideIcons[_displayed]!,
            spring: _springPresets[_presetName]!,
            size: 160,
            strokeWidth: 2,
            color: strokeColor,
            semanticLabel: _displayed,
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Morphicons Playground')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: stage,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Spring'),
                  icon: Icon(Icons.animation),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Scrub'),
                  icon: Icon(Icons.tune),
                ),
              ],
              selected: {_scrubMode},
              onSelectionChanged: (selection) =>
                  setState(() => _scrubMode = selection.first),
            ),
          ),
          const SizedBox(height: 16),
          if (_scrubMode) ...[
            Row(
              children: [
                Text('t', style: textTheme.titleMedium),
                Expanded(
                  child: Slider(
                    value: _t,
                    onChanged: (value) => setState(() => _t = value),
                    label: _t.toStringAsFixed(2),
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    _t.toStringAsFixed(2),
                    textAlign: TextAlign.right,
                    style: textTheme.bodyMedium
                        ?.copyWith(fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _presetName,
                    decoration: const InputDecoration(labelText: 'Spring'),
                    items: _springPresets.keys
                        .map((name) => DropdownMenuItem(
                              value: name,
                              child: Text(name),
                            ))
                        .toList(),
                    onChanged: (name) =>
                        setState(() => _presetName = name ?? _presetName),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _displayed = _displayed == _toName
                          ? _fromName
                          : _toName;
                    });
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Morph'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('from-$_fromName'),
                  initialValue: _fromName,
                  decoration: const InputDecoration(labelText: 'From'),
                  items: lucideIcons.keys
                      .map((name) => DropdownMenuItem(
                            value: name,
                            child: Text(name),
                          ))
                      .toList(),
                  onChanged: (name) {
                    if (name == null || name == _fromName) return;
                    setState(() {
                      _fromName = name;
                      _resetStageToFrom();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('to-$_toName'),
                  initialValue: _toName,
                  decoration: const InputDecoration(labelText: 'To'),
                  items: lucideIcons.keys
                      .map((name) => DropdownMenuItem(
                            value: name,
                            child: Text(name),
                          ))
                      .toList(),
                  onChanged: (name) {
                    if (name == null || name == _toName) return;
                    setState(() {
                      _toName = name;
                      _resetStageToFrom();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _openGrid,
              icon: const Icon(Icons.grid_view),
              label: const Text('Pick target from icon grid'),
            ),
          ),
          const SizedBox(height: 16),
          PlanDebugPanel(from: _fromD, to: _toD),
        ],
      ),
    );
  }
}
