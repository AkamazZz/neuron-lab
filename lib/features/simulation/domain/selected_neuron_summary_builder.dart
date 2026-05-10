import 'package:ccn_visualization/core/models/experiment_definition.dart';
import 'package:ccn_visualization/core/models/network_visualization.dart';
import 'package:ccn_visualization/core/models/step_frame.dart';
import 'package:ccn_visualization/features/simulation/domain/challenge_replay_comparison.dart';
import 'package:ccn_visualization/features/simulation/domain/experiment_phase_interpreter.dart';
import 'package:ccn_visualization/features/simulation/domain/spike_timing_explanation.dart';

class SelectedNeuronSummary {
  const SelectedNeuronSummary({
    required this.neuron,
    required this.incoming,
    required this.outgoing,
    required this.activePaths,
    required this.changedPaths,
    required this.phaseExplanation,
    required this.timingExplanations,
    required this.challengeReplayComparison,
    required this.variantComparisons,
  });

  final VisualNeuron neuron;
  final List<VisualSynapse> incoming;
  final List<VisualSynapse> outgoing;
  final List<VisualSynapse> activePaths;
  final List<VisualSynapse> changedPaths;
  final String phaseExplanation;
  final List<SpikeTimingExplanation> timingExplanations;
  final ChallengeReplayComparison challengeReplayComparison;
  final List<SelectedNeuronVariantComparison> variantComparisons;
}

class SelectedNeuronVariantComparison {
  const SelectedNeuronVariantComparison({
    required this.label,
    required this.available,
    required this.activity,
    required this.spiked,
    required this.notableChangedPaths,
  });

  const SelectedNeuronVariantComparison.unavailable({required this.label})
    : available = false,
      activity = 0,
      spiked = false,
      notableChangedPaths = const <VisualSynapse>[];

  final String label;
  final bool available;
  final double activity;
  final bool spiked;
  final List<VisualSynapse> notableChangedPaths;
}

class SelectedNeuronSummaryBuilder {
  const SelectedNeuronSummaryBuilder({
    this.phaseInterpreter = const ExperimentPhaseInterpreter(),
    this.timingExplanationBuilder = const SpikeTimingExplanationBuilder(),
    this.challengeReplayComparisonBuilder =
        const ChallengeReplayComparisonBuilder(),
  });

  final ExperimentPhaseInterpreter phaseInterpreter;
  final SpikeTimingExplanationBuilder timingExplanationBuilder;
  final ChallengeReplayComparisonBuilder challengeReplayComparisonBuilder;

  SelectedNeuronSummary? build({
    required int? selectedNeuronId,
    required VisualNetworkFrame frame,
    required ExperimentDefinition experiment,
    required List<VariantSnapshot> variants,
    required Map<String, double> baselineWeights,
    List<SpikeEvent> recentSpikes = const <SpikeEvent>[],
  }) {
    if (selectedNeuronId == null) {
      return null;
    }
    final neuron = frame.neuronById(selectedNeuronId);
    if (neuron == null) {
      return null;
    }
    final incoming = _rank(
      frame.synapses.where((synapse) => synapse.target == selectedNeuronId),
    );
    final outgoing = _rank(
      frame.synapses.where((synapse) => synapse.source == selectedNeuronId),
    );
    final active = _rank(
      frame.synapses.where(
        (synapse) =>
            (synapse.source == selectedNeuronId ||
                synapse.target == selectedNeuronId) &&
            synapse.signalActivity > 0,
      ),
    );
    final changed = _rank(
      frame.synapses.where(
        (synapse) =>
            (synapse.source == selectedNeuronId ||
                synapse.target == selectedNeuronId) &&
            synapse.weightChange.abs() >= 0.05,
      ),
    );
    return SelectedNeuronSummary(
      neuron: neuron,
      incoming: incoming,
      outgoing: outgoing,
      activePaths: active,
      changedPaths: changed,
      phaseExplanation: phaseInterpreter.selectedNeuronExplanation(
        phaseLabel: frame.phaseLabel,
        neuron: neuron,
        changedPaths: changed,
        activePaths: active,
      ),
      timingExplanations: _timingExplanations(
        changedPaths: changed,
        activePaths: active,
        recentSpikes: recentSpikes,
      ),
      challengeReplayComparison: challengeReplayComparisonBuilder.build(
        selectedNeuronId: selectedNeuronId,
        selectedPaths: changed.isNotEmpty ? changed : outgoing,
        variants: variants,
      ),
      variantComparisons: _variantComparisons(
        selectedNeuronId: selectedNeuronId,
        experiment: experiment,
        variants: variants,
        baselineWeights: baselineWeights,
      ),
    );
  }

  List<SpikeTimingExplanation> _timingExplanations({
    required List<VisualSynapse> changedPaths,
    required List<VisualSynapse> activePaths,
    required List<SpikeEvent> recentSpikes,
  }) {
    final candidates = <String, VisualSynapse>{};
    for (final synapse in changedPaths.followedBy(activePaths)) {
      candidates['${synapse.source}:${synapse.target}'] = synapse;
    }
    return List<SpikeTimingExplanation>.unmodifiable(
      candidates.values
          .take(4)
          .map(
            (synapse) => timingExplanationBuilder.build(
              synapse: synapse,
              recentSpikes: recentSpikes,
            ),
          ),
    );
  }

  List<SelectedNeuronVariantComparison> _variantComparisons({
    required int selectedNeuronId,
    required ExperimentDefinition experiment,
    required List<VariantSnapshot> variants,
    required Map<String, double> baselineWeights,
  }) {
    return List<SelectedNeuronVariantComparison>.unmodifiable(
      experiment.phases.asMap().entries.map((entry) {
        final phase = entry.value;
        final label = phaseInterpreter.labelForPhaseId(phase.id, entry.key);
        VariantSnapshot? snapshot;
        for (final candidate in variants) {
          if (candidate.phaseIndex == entry.key) {
            snapshot = candidate;
            break;
          }
        }
        if (snapshot == null) {
          return SelectedNeuronVariantComparison.unavailable(label: label);
        }
        final activity =
            selectedNeuronId < snapshot.activity.recentFiringRates.length
            ? snapshot.activity.recentFiringRates[selectedNeuronId]
            : 0.0;
        final spiked =
            selectedNeuronId < snapshot.activity.spiked.length &&
            snapshot.activity.spiked[selectedNeuronId];
        final changed = snapshot.weights.weights
            .where(
              (sample) =>
                  sample.source == selectedNeuronId ||
                  sample.target == selectedNeuronId,
            )
            .map((sample) {
              final key = '${sample.source}:${sample.target}';
              final baseline = baselineWeights[key] ?? sample.weight;
              return VisualSynapse(
                source: sample.source,
                target: sample.target,
                weight: sample.weight,
                inhibitory: sample.inhibitory,
                signalActivity: 0,
                weightChange: sample.weight - baseline,
              );
            })
            .where((synapse) => synapse.weightChange.abs() >= 0.05);
        return SelectedNeuronVariantComparison(
          label: label,
          available: true,
          activity: activity.clamp(0.0, 1.0),
          spiked: spiked,
          notableChangedPaths: _rank(changed),
        );
      }),
    );
  }

  static List<VisualSynapse> _rank(Iterable<VisualSynapse> synapses) {
    final ranked = synapses.toList(growable: false)
      ..sort((a, b) {
        final aScore =
            a.signalActivity * 2 + a.weightChange.abs() + a.weight.abs();
        final bScore =
            b.signalActivity * 2 + b.weightChange.abs() + b.weight.abs();
        return bScore.compareTo(aScore);
      });
    return List<VisualSynapse>.unmodifiable(ranked.take(6));
  }
}
