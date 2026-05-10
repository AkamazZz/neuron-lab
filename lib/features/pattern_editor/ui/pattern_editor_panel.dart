import 'package:flutter/material.dart';

import 'package:ccn_visualization/core/scope/simulation_scope.dart';
import 'package:ccn_visualization/features/pattern_editor/controller/pattern_editor_controller.dart';
import 'package:ccn_visualization/features/pattern_editor/controller/pattern_editor_state.dart';
import 'package:ccn_visualization/features/pattern_editor/ui/neuron_grid_editor.dart';
import 'package:ccn_visualization/features/pattern_editor/ui/pattern_preview.dart';
import 'package:ccn_visualization/features/pattern_editor/ui/pattern_save_controls.dart';

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
            Text('Input dropout ${(state.noise * 100).toStringAsFixed(0)}%'),
            Text(
              'Suppresses selected pattern inputs during training.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
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
            _SavedPatternList(
              summaries: state.savedPatternSummaries,
              onLoad: _controller.loadSavedPattern,
            ),
            const SizedBox(height: 8),
            PatternPreview(state: state),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: state.activeCells.isEmpty
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

class _SavedPatternList extends StatelessWidget {
  const _SavedPatternList({required this.summaries, required this.onLoad});

  final List<SavedPatternSummary> summaries;
  final ValueChanged<String> onLoad;

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) {
      return Text(
        'No saved pattern slots yet.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Saved slots', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        for (final summary in summaries) ...[
          _SavedPatternRow(summary: summary, onLoad: onLoad),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _SavedPatternRow extends StatelessWidget {
  const _SavedPatternRow({required this.summary, required this.onLoad});

  final SavedPatternSummary summary;
  final ValueChanged<String> onLoad;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${summary.label}: ${summary.activeCount} active; '
                'neurons ${summary.neuronIdsLabel}; ${summary.currentLabel}',
                style: theme.textTheme.bodySmall,
              ),
            ),
            IconButton(
              tooltip: 'Load ${summary.label} for editing',
              onPressed: () => onLoad(summary.id),
              icon: const Icon(Icons.edit),
            ),
          ],
        ),
      ),
    );
  }
}
