import 'package:flutter/material.dart';
import 'package:morphicons_lucide/morphicons_lucide.dart';

import 'static_icon.dart';

/// Number of icons shown in the picker grid.
const int kGridIconCount = 60;

/// Scrollable grid of the first [kGridIconCount] lucide icons. Tapping an
/// icon pops the Navigator with its name so the caller can use it as the
/// morph target.
class IconGridScreen extends StatelessWidget {
  final String? selectedName;

  const IconGridScreen({super.key, this.selectedName});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = lucideIcons.entries.take(kGridIconCount).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Pick morph target')),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 96,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.85,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final selected = entry.key == selectedName;
          return Material(
            color: selected
                ? scheme.primaryContainer
                : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).pop(entry.key),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  StaticIcon(
                    d: entry.value,
                    size: 32,
                    strokeWidth: 2,
                    color: selected ? scheme.onPrimaryContainer : null,
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      entry.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: selected
                                ? scheme.onPrimaryContainer
                                : scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
