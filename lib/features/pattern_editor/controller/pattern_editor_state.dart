import 'package:ccn_visualization/core/models/experiment_definition.dart';
import 'package:ccn_visualization/core/models/metrics.dart';
import 'package:ccn_visualization/core/models/pattern.dart';
import 'package:ccn_visualization/core/models/phase.dart';
import 'package:ccn_visualization/core/models/simulation_config.dart';

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

  PatternDefinition get activePattern => PatternDefinition(
    id: activePatternId,
    label: activeName,
    activations: sortedActiveCells
        .map((id) => PatternActivation(neuronId: id, current: strength))
        .toList(growable: false),
  );

  String get activePatternId => _slotId(activeName);

  List<int> get sortedActiveCells {
    final cells = activeCells.toList(growable: false)..sort();
    return cells;
  }

  List<SavedPatternSummary> get savedPatternSummaries {
    final summaries =
        savedPatterns.values
            .map(SavedPatternSummary.fromPattern)
            .toList(growable: false)
          ..sort((a, b) => a.label.compareTo(b.label));
    return summaries;
  }

  PatternExperimentPreview get experimentPreview {
    final pattern = activePattern;
    return PatternExperimentPreview(
      patternId: pattern.id,
      patternLabel: pattern.label,
      neuronIds: sortedActiveCells,
      strength: strength,
      dropout: noise,
    );
  }

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
    final firstPattern = activePattern;
    final patternsById = <String, PatternDefinition>{
      for (final pattern in savedPatterns.values) pattern.id: _sorted(pattern),
      firstPattern.id: firstPattern,
    };
    final patterns = patternsById.values.toList(growable: false)
      ..sort((a, b) {
        if (a.id == firstPattern.id) {
          return -1;
        }
        if (b.id == firstPattern.id) {
          return 1;
        }
        return a.label.compareTo(b.label);
      });
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

  static String _slotId(String label) => label
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  static PatternDefinition _sorted(PatternDefinition pattern) {
    final activations = pattern.activations.toList(growable: false)
      ..sort((a, b) => a.neuronId.compareTo(b.neuronId));
    return PatternDefinition(
      id: pattern.id,
      label: pattern.label,
      activations: activations,
    );
  }
}

class SavedPatternSummary {
  const SavedPatternSummary({
    required this.id,
    required this.label,
    required this.neuronIds,
    required this.activeCount,
    required this.minCurrent,
    required this.maxCurrent,
  });

  final String id;
  final String label;
  final List<int> neuronIds;
  final int activeCount;
  final double minCurrent;
  final double maxCurrent;

  String get neuronIdsLabel =>
      neuronIds.isEmpty ? 'none' : neuronIds.join(', ');

  String get currentLabel {
    if (activeCount == 0) {
      return 'current none';
    }
    if (minCurrent == maxCurrent) {
      return 'current ${minCurrent.toStringAsFixed(2)}';
    }
    return 'current ${minCurrent.toStringAsFixed(2)}-${maxCurrent.toStringAsFixed(2)}';
  }

  factory SavedPatternSummary.fromPattern(PatternDefinition pattern) {
    final activations = pattern.activations.toList(growable: false)
      ..sort((a, b) => a.neuronId.compareTo(b.neuronId));
    final currents = activations.map((activation) => activation.current);
    return SavedPatternSummary(
      id: pattern.id,
      label: pattern.label,
      neuronIds: activations
          .map((activation) => activation.neuronId)
          .toList(growable: false),
      activeCount: activations.length,
      minCurrent: currents.isEmpty
          ? 0
          : currents.reduce((a, b) => a < b ? a : b),
      maxCurrent: currents.isEmpty
          ? 0
          : currents.reduce((a, b) => a > b ? a : b),
    );
  }
}

class PatternExperimentPreview {
  const PatternExperimentPreview({
    required this.patternId,
    required this.patternLabel,
    required this.neuronIds,
    required this.strength,
    required this.dropout,
  });

  final String patternId;
  final String patternLabel;
  final List<int> neuronIds;
  final double strength;
  final double dropout;

  int get activeCount => neuronIds.length;

  String get neuronIdsLabel =>
      neuronIds.isEmpty ? 'none' : neuronIds.join(', ');

  String get dropoutLabel => '${(dropout * 100).toStringAsFixed(0)}%';
}
