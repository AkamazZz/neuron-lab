import 'package:flutter/material.dart';

import '../../../core/models/experiment_definition.dart';

class ExperimentSummary extends StatelessWidget {
  const ExperimentSummary({super.key, required this.experiment});

  final ExperimentDefinition experiment;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(experiment.label, style: textTheme.titleMedium),
        const SizedBox(height: 6),

        Text(experiment.description),
        const SizedBox(height: 12),
        Text('Seed ${experiment.seed}'),
        Text('${experiment.network.neuronCount} neurons'),
        Text('${experiment.phases.length} phases'),
      ],
    );
  }
}
