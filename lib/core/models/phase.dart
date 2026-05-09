enum PhaseKind { train, probe, silence }

extension PhaseKindJson on PhaseKind {
  String get jsonName => switch (this) {
    PhaseKind.train => 'train',
    PhaseKind.probe => 'probe',
    PhaseKind.silence => 'silence',
  };
}

class ExperimentPhase {
  const ExperimentPhase({
    required this.id,
    required this.phaseType,
    required this.durationSteps,
    required this.learningEnabled,
    required this.schedule,
    this.phaseSeed,
    this.stopCondition,
  });

  final String id;
  final PhaseKind phaseType;
  final int durationSteps;
  final bool learningEnabled;
  final PatternSchedule schedule;
  final int? phaseSeed;
  final StopCondition? stopCondition;

  Map<String, Object?> toJson() => {
    'id': id,
    'phase_type': phaseType.jsonName,
    'duration_steps': durationSteps,
    'learning_enabled': learningEnabled,
    'schedule': schedule.toJson(),
    'phase_seed': phaseSeed,
    'stop_condition': stopCondition?.toJson(),
  };
}

sealed class PatternSchedule {
  const PatternSchedule();

  Map<String, Object?> toJson();
}

class ConstantPatternSchedule extends PatternSchedule {
  const ConstantPatternSchedule({
    required this.patternId,
    this.noiseProbability = 0,
  });

  final String patternId;
  final double noiseProbability;

  @override
  Map<String, Object?> toJson() => {
    'type': 'constant',
    'pattern_id': patternId,
    'noise_probability': noiseProbability,
  };
}

class SequencePatternSchedule extends PatternSchedule {
  const SequencePatternSchedule({
    required this.patternIds,
    this.noiseProbability = 0,
  });

  final List<String> patternIds;
  final double noiseProbability;

  @override
  Map<String, Object?> toJson() => {
    'type': 'sequence',
    'pattern_ids': patternIds,
    'noise_probability': noiseProbability,
  };
}

class SilencePatternSchedule extends PatternSchedule {
  const SilencePatternSchedule();

  @override
  Map<String, Object?> toJson() => {'type': 'silence'};
}

class StopCondition {
  const StopCondition({this.maxSpikes});

  final int? maxSpikes;

  Map<String, Object?> toJson() => {'max_spikes': maxSpikes};
}

class PhaseProgress {
  const PhaseProgress({
    this.phaseIndex = 0,
    this.phaseStep = 0,
    this.phaseDuration = 0,
    this.totalStep = 0,
    this.totalDuration = 0,
    this.progress = 0,
  });

  final int phaseIndex;
  final int phaseStep;
  final int phaseDuration;
  final int totalStep;
  final int totalDuration;
  final double progress;

  String get label => totalDuration == 0
      ? 'No phase loaded'
      : 'Phase ${phaseIndex + 1} - $phaseStep/$phaseDuration';
}
