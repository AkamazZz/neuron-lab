import 'package:ccn_visualization/core/models/experiment_definition.dart';
import 'package:ccn_visualization/core/models/phase.dart';
import 'package:ccn_visualization/core/models/preset_result.dart';
import 'package:ccn_visualization/core/models/snapshots.dart';
import 'package:ccn_visualization/core/models/step_frame.dart';

class CustomPatternResultBuilder {
  const CustomPatternResultBuilder();

  PresetResult build({
    required ExperimentDefinition experiment,
    required PresetResult nativeResult,
    required List<SpikeEvent> rasterHistory,
    required ActivitySnapshot activity,
  }) {
    if (nativeResult is CustomPatternResult) {
      return nativeResult;
    }
    if (experiment.id != 'custom_pattern_lab' ||
        experiment.patterns.isEmpty ||
        nativeResult is! GenericResult) {
      return nativeResult;
    }

    final pattern = experiment.patterns.first;
    final activations = pattern.activations.toList(growable: false)
      ..sort((a, b) => a.neuronId.compareTo(b.neuronId));
    final neuronIds = activations
        .map((activation) => activation.neuronId)
        .toList(growable: false);
    final neuronSet = neuronIds.toSet();
    final probeStart = experiment.phases
        .takeWhile((phase) => phase.id != 'custom_probe')
        .fold<int>(0, (sum, phase) => sum + phase.durationSteps);
    final probeSpikes = rasterHistory
        .where((event) => event.absoluteStep >= probeStart)
        .toList(growable: false);
    final targetSpikeCount = probeSpikes
        .where((event) => neuronSet.contains(event.neuronId))
        .length;
    final offPatternSpikeCount = probeSpikes.length - targetSpikeCount;
    final targetActiveCount = neuronIds
        .where(
          (id) =>
              id < activity.recentFiringRates.length &&
              activity.recentFiringRates[id] > 0,
        )
        .length;
    final offPatternActiveCount = activity.recentFiringRates
        .asMap()
        .entries
        .where((entry) => !neuronSet.contains(entry.key) && entry.value > 0)
        .length;
    final responseSimilarity = neuronIds.isEmpty
        ? 0.0
        : targetActiveCount / neuronIds.length;
    final trainPhase = experiment.phases.firstWhere(
      (phase) => phase.id == 'custom_train',
      orElse: () => experiment.phases.first,
    );
    final schedule = trainPhase.schedule;
    final dropout = switch (schedule) {
      ConstantPatternSchedule(:final noiseProbability) => noiseProbability,
      SequencePatternSchedule(:final noiseProbability) => noiseProbability,
      SilencePatternSchedule() => 0.0,
    };
    final strength = activations.isEmpty ? 0.0 : activations.first.current;

    return CustomPatternResult(
      patternLabel: pattern.label,
      patternId: pattern.id,
      neuronIds: neuronIds,
      strength: strength,
      dropout: dropout,
      targetActiveCount: targetActiveCount,
      targetSpikeCount: targetSpikeCount,
      offPatternActiveCount: offPatternActiveCount,
      offPatternSpikeCount: offPatternSpikeCount,
      responseSimilarity: responseSimilarity,
      totalSpikes: nativeResult.totalSpikes,
      averageWeight: nativeResult.averageWeight,
      explanationFacts: const <String>[
        'Fallback result derived in Flutter because Rust returned a generic result.',
      ],
    );
  }
}
