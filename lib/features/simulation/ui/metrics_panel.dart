import 'package:flutter/material.dart';

import 'package:ccn_visualization/core/models/metrics.dart';

class MetricsPanel extends StatelessWidget {
  const MetricsPanel({super.key, required this.metrics, required this.step});

  final LiveMetrics metrics;
  final int step;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _MetricTile(label: 'Step', value: '$step'),
        _MetricTile(label: 'Batch spikes', value: '${metrics.batchSpikes}'),
        _MetricTile(label: 'Total spikes', value: '${metrics.totalSpikes}'),
        _MetricTile(
          label: 'Active neurons',
          value: '${metrics.activeNeuronCount}',
        ),
        _MetricTile(
          label: 'Avg weight',
          value: metrics.averageWeight.toStringAsFixed(3),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}
