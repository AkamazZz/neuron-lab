import '../../../core/models/experiment_definition.dart';
import '../../../core/models/metrics.dart';
import '../../../core/models/pattern.dart';
import '../../../core/models/phase.dart';
import '../../../core/models/simulation_config.dart';

class PatternEditorState {
  const PatternEditorState({
    this.activeCells = const <int>{},
    this.strength = 1.2,
    this.noise = 0.05,
    this.activeName = 'Pattern A',
    this.savedPatterns = const <String, PatternDefinition>{},
  });

  final Set<int> activeCells;
  final double strength;
  final double noise;
  final String activeName;
  final Map<String, PatternDefinition> savedPatterns;

  PatternEditorState copyWith({
    Set<int>? activeCells,
    double? strength,
    double? noise,
    String? activeName,
    Map<String, PatternDefinition>? savedPatterns,
  }) {
    return PatternEditorState(
      activeCells: activeCells ?? this.activeCells,
      strength: strength ?? this.strength,
      noise: noise ?? this.noise,
      activeName: activeName ?? this.activeName,
      savedPatterns: savedPatterns ?? this.savedPatterns,
    );
  }

  ExperimentDefinition toExperimentDefinition({int seed = 909}) {
    final patterns = savedPatterns.values.toList(growable: false);
    final firstPattern = patterns.isEmpty
        ? PatternDefinition(
            id: 'custom_a',
            label: 'Custom A',
            activations: activeCells
                .map((id) => PatternActivation(neuronId: id, current: strength))
                .toList(growable: false),
          )
        : patterns.first;
    return ExperimentDefinition(
      id: 'custom_pattern_lab',
      label: 'Custom Pattern Lab',
      description:
          'User-defined pattern probe using Rust validation and stepping.',
      seed: seed,
      network: SimulationConfig(seed: seed, neuronCount: 64),
      patterns: patterns.isEmpty ? [firstPattern] : patterns,
      resultKind: PresetKind.generic,
      phases: [
        ExperimentPhase(
          id: 'custom_train',
          phaseType: PhaseKind.train,
          durationSteps: 180,
          learningEnabled: true,
          schedule: ConstantPatternSchedule(
            patternId: firstPattern.id,
            noiseProbability: noise,
          ),
          phaseSeed: 301,
        ),
        ExperimentPhase(
          id: 'custom_probe',
          phaseType: PhaseKind.probe,
          durationSteps: 100,
          learningEnabled: false,
          schedule: ConstantPatternSchedule(patternId: firstPattern.id),
          phaseSeed: 302,
        ),
      ],
      metricWindows: const [
        MetricWindowDefinition(
          id: 'custom_probe_window',
          phaseId: 'custom_probe',
          startStep: 0,
          durationSteps: 100,
        ),
      ],
    );
  }
}
