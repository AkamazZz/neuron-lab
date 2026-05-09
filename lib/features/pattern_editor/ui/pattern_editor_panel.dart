import 'package:flutter/material.dart';

import '../../../core/scope/simulation_scope.dart';
import '../controller/pattern_editor_controller.dart';
import 'neuron_grid_editor.dart';
import 'pattern_preview.dart';
import 'pattern_save_controls.dart';

class PatternEditorPanel extends StatefulWidget {
  const PatternEditorPanel({super.key});

  @override
  State<PatternEditorPanel> createState() => _PatternEditorPanelState();
}

class _PatternEditorPanelState extends State<PatternEditorPanel> {
  late final PatternEditorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PatternEditorController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final simulationController = SimulationScope.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.state;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pattern editor',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            NeuronGridEditor(
              activeCells: state.activeCells,
              onToggle: _controller.toggleCell,
            ),
            const SizedBox(height: 12),
            Text('Strength ${state.strength.toStringAsFixed(2)}'),
            Slider(
              value: state.strength,
              min: 0.2,
              max: 2,
              divisions: 18,
              onChanged: _controller.setStrength,
            ),
            Text('Noise ${(state.noise * 100).toStringAsFixed(0)}%'),
            Slider(
              value: state.noise,
              min: 0,
              max: 0.5,
              divisions: 20,
              onChanged: _controller.setNoise,
            ),
            PatternSaveControls(
              activeName: state.activeName,
              onNameChanged: _controller.setActiveName,
              onSave: _controller.saveActivePattern,
            ),
            const SizedBox(height: 8),
            PatternPreview(state: state),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed:
                  state.activeCells.isEmpty && state.savedPatterns.isEmpty
                  ? null
                  : () => simulationController.loadPreset(
                      state.toExperimentDefinition(),
                    ),
              icon: const Icon(Icons.science),
              label: const Text('Use custom pattern'),
            ),
          ],
        );
      },
    );
  }
}
