class MetricWindowDefinition {
  const MetricWindowDefinition({
    required this.id,
    required this.phaseId,
    required this.startStep,
    required this.durationSteps,
  });

  final String id;
  final String phaseId;
  final int startStep;
  final int durationSteps;

  Map<String, Object?> toJson() => {
    'id': id,
    'phase_id': phaseId,
    'start_step': startStep,
    'duration_steps': durationSteps,
  };
}

class LiveMetrics {
  const LiveMetrics({
    this.totalSpikes = 0,
    this.batchSpikes = 0,
    this.activeNeuronCount = 0,
    this.averageWeight = 0,
  });

  final int totalSpikes;
  final int batchSpikes;
  final int activeNeuronCount;
  final double averageWeight;
}
