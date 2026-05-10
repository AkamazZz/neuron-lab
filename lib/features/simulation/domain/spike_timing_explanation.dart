import '../../../core/models/network_visualization.dart';
import '../../../core/models/step_frame.dart';

enum SpikeTimingExplanationKind { strengthening, weakening, unavailable }

class SpikeTimingExplanation {
  const SpikeTimingExplanation({
    required this.source,
    required this.target,
    required this.kind,
    required this.message,
    this.sourceStep,
    this.targetStep,
    this.gap,
  });

  final int source;
  final int target;
  final SpikeTimingExplanationKind kind;
  final String message;
  final int? sourceStep;
  final int? targetStep;
  final int? gap;

  String get key => '$source:$target';
}

class SpikeTimingExplanationBuilder {
  const SpikeTimingExplanationBuilder({this.learningWindow = 12});

  final int learningWindow;

  SpikeTimingExplanation build({
    required VisualSynapse synapse,
    required List<SpikeEvent> recentSpikes,
  }) {
    final sourceStep = _latestStepFor(synapse.source, recentSpikes);
    final targetStep = _latestStepFor(synapse.target, recentSpikes);
    if (sourceStep == null || targetStep == null) {
      return _unavailable(
        synapse,
        'Detailed timing evidence is unavailable for ${synapse.source} -> ${synapse.target}.',
      );
    }
    final gap = targetStep - sourceStep;
    if (gap.abs() > learningWindow) {
      return _unavailable(
        synapse,
        'Recent spikes for ${synapse.source} -> ${synapse.target} were outside the model timing window.',
        sourceStep: sourceStep,
        targetStep: targetStep,
        gap: gap,
      );
    }
    if (synapse.weightChange > 0.001 && gap > 0) {
      return SpikeTimingExplanation(
        source: synapse.source,
        target: synapse.target,
        kind: SpikeTimingExplanationKind.strengthening,
        sourceStep: sourceStep,
        targetStep: targetStep,
        gap: gap,
        message:
            'Source ${synapse.source} fired before target ${synapse.target} by $gap steps; this model marks the selected connection as strengthened.',
      );
    }
    if (synapse.weightChange < -0.001 && gap < 0) {
      return SpikeTimingExplanation(
        source: synapse.source,
        target: synapse.target,
        kind: SpikeTimingExplanationKind.weakening,
        sourceStep: sourceStep,
        targetStep: targetStep,
        gap: gap.abs(),
        message:
            'Target ${synapse.target} fired before source ${synapse.source} by ${gap.abs()} steps; this model marks the selected connection as weakened.',
      );
    }
    return _unavailable(
      synapse,
      'Timing evidence for ${synapse.source} -> ${synapse.target} does not explain the displayed weight direction.',
      sourceStep: sourceStep,
      targetStep: targetStep,
      gap: gap,
    );
  }

  int? _latestStepFor(int neuronId, List<SpikeEvent> recentSpikes) {
    int? latest;
    for (final spike in recentSpikes) {
      if (spike.neuronId == neuronId &&
          (latest == null || spike.absoluteStep > latest)) {
        latest = spike.absoluteStep;
      }
    }
    return latest;
  }

  SpikeTimingExplanation _unavailable(
    VisualSynapse synapse,
    String message, {
    int? sourceStep,
    int? targetStep,
    int? gap,
  }) {
    return SpikeTimingExplanation(
      source: synapse.source,
      target: synapse.target,
      kind: SpikeTimingExplanationKind.unavailable,
      sourceStep: sourceStep,
      targetStep: targetStep,
      gap: gap,
      message: message,
    );
  }
}
