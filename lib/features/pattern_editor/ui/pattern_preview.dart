import 'package:flutter/material.dart';

import 'package:ccn_visualization/features/pattern_editor/controller/pattern_editor_state.dart';

class PatternPreview extends StatelessWidget {
  const PatternPreview({super.key, required this.state});

  final PatternEditorState state;

  @override
  Widget build(BuildContext context) {
    final preview = state.experimentPreview;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Experiment preview', style: textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          'Source: current grid ${preview.patternLabel} '
          '(${preview.activeCount} active: ${preview.neuronIdsLabel}).',
        ),
        Text(
          'Train: ${preview.patternId} with ${preview.dropoutLabel} '
          'input dropout, learning enabled.',
        ),
        Text('Probe: ${preview.patternId} without dropout, learning disabled.'),
        Text(
          'Rust receives: strength ${preview.strength.toStringAsFixed(2)} '
          'as activation current; dropout as schedule noise_probability.',
        ),
      ],
    );
  }
}
