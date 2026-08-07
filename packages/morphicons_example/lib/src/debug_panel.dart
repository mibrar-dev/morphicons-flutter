import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:morphicons_core/morphicons_core.dart';

/// θ/σ/residual readout for the plan between [from] and [to] — the same
/// numeric self-check upstream's playground exposes.
class PlanDebugPanel extends StatelessWidget {
  final String from;
  final String to;

  const PlanDebugPanel({super.key, required this.from, required this.to});

  static String _fmt(double v) => v.toStringAsFixed(4);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final plan = buildPlan(sampledOf(from), sampledOf(to));

    // Under the global hybrid all items share one (θ, σ); surface the first
    // item's values as the global pair.
    final theta = plan.items.first.theta;
    final sigma = math.exp(plan.items.first.lnSigma);
    var resSum = 0.0;
    for (final it in plan.items) {
      resSum += it.res * it.res;
    }
    final resRms = math.sqrt(resSum / plan.items.length);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bug_report_outlined,
                    size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text('Plan debug', style: textTheme.titleSmall),
                const Spacer(),
                Text(
                  '${plan.items.length} subpath(s) · N=${plan.n}',
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _row(textTheme, 'θ (global theta)', '${_fmt(theta)} rad'),
            _row(textTheme, 'σ (scale)', _fmt(sigma)),
            _row(textTheme, 'residual (RMS)', _fmt(resRms)),
            const SizedBox(height: 8),
            ...plan.items.indexed.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'item ${entry.$1}: θ ${_fmt(entry.$2.theta)} · '
                  'σ ${_fmt(math.exp(entry.$2.lnSigma))} · '
                  'res ${_fmt(entry.$2.res)}'
                  '${entry.$2.block != null ? ' · block' : ''}',
                  style: textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _row(TextTheme textTheme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: textTheme.bodyMedium)),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
