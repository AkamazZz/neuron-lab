import 'metrics.dart';
import 'pattern.dart';
import 'phase.dart';
import 'simulation_config.dart';

enum PresetKind { generic, patternRecognition, memoryEcho }

extension PresetKindJson on PresetKind {
  String get resultJsonName => switch (this) {
    PresetKind.generic => 'generic',
    PresetKind.patternRecognition => 'pattern_recognition',
    PresetKind.memoryEcho => 'memory_echo',
  };
}

class ExperimentDefinition {
  const ExperimentDefinition({
    this.schemaVersion = 1,
    required this.id,
    required this.label,
    required this.description,
    required this.seed,
    required this.network,
    required this.patterns,
    required this.phases,
    required this.metricWindows,
    required this.resultKind,
  });

  final int schemaVersion;
  final String id;
  final String label;
  final String description;
  final int seed;
  final SimulationConfig network;
  final List<PatternDefinition> patterns;
  final List<ExperimentPhase> phases;
  final List<MetricWindowDefinition> metricWindows;
  final PresetKind resultKind;

  Map<String, Object?> toJson() => {
    'schema_version': schemaVersion,
    'preset_id': id,
    'seed': seed,
    'network': network.toJson(),
    'patterns': patterns.map((pattern) => pattern.toJson()).toList(),
    'phases': phases.map((phase) => phase.toJson()).toList(),
    'metric_windows': metricWindows.map((window) => window.toJson()).toList(),
    'result_config': {'kind': resultKind.resultJsonName},
  };
}
