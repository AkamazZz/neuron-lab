import 'package:flutter/material.dart';

import 'package:ccn_visualization/core/scope/simulation_scope.dart';
import 'package:ccn_visualization/features/experiments/ui/experiment_summary.dart';
import 'package:ccn_visualization/features/experiments/ui/preset_picker.dart';
import 'package:ccn_visualization/features/pattern_editor/ui/pattern_editor_panel.dart';
import 'package:ccn_visualization/features/simulation/ui/run_controls.dart';

class LabSidebar extends StatelessWidget {
  const LabSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = SimulationScope.of(context);
    final state = controller.state;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'CCN Visualization',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        PresetPicker(
          selected: state.selectedExperiment,
          onSelected: controller.loadPreset,
        ),
        const SizedBox(height: 16),
        ExperimentSummary(experiment: state.selectedExperiment),
        const SizedBox(height: 16),
        RunControls(
          runState: state.runState,
          onRun: () => controller.run(),
          onPause: controller.pause,
          onStep: () => controller.stepOnce(),
          onReset: () => controller.reset(),
          onRerun: () => controller.rerunSameSeed(),
          stepsPerTick: state.stepsPerTick,
          onSpeedChanged: controller.setStepsPerTick,
        ),
        const SizedBox(height: 20),
        const PatternEditorPanel(),
        const SizedBox(height: 12),
        SwitchListTile(
          key: const ValueKey('narration-mode-switch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Narration'),
          value: state.narrationEnabled,
          onChanged: controller.setNarrationEnabled,
        ),
      ],
    );
  }
}
