import 'package:flutter/material.dart';

import 'package:ccn_visualization/core/models/experiment_definition.dart';
import 'package:ccn_visualization/features/experiments/presets/preset_catalog.dart';

class PresetPicker extends StatelessWidget {
  const PresetPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final ExperimentDefinition selected;
  final ValueChanged<ExperimentDefinition> onSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: [
        for (final preset in PresetCatalog.all())
          ButtonSegment(
            value: preset.id,
            label: Text(preset.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      selected: {selected.id},
      onSelectionChanged: (value) {
        final id = value.first;
        onSelected(PresetCatalog.all().firstWhere((preset) => preset.id == id));
      },
    );
  }
}
