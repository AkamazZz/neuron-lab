import 'metrics.dart';

class SpikeEvent {
  const SpikeEvent({
    required this.stepOffset,
    required this.absoluteStep,
    required this.neuronId,
    required this.membrane,
  });

  final int stepOffset;
  final int absoluteStep;
  final int neuronId;
  final double membrane;
}

class StepFrame {
  const StepFrame({
    required this.startStep,
    required this.steps,
    required this.spikes,
    this.statistics = const LiveMetrics(),
  });

  final int startStep;
  final int steps;
  final List<SpikeEvent> spikes;
  final LiveMetrics statistics;

  int get endStep => startStep + steps;
}
