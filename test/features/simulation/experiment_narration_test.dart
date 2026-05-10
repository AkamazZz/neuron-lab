import 'package:ccn_visualization/core/models/metrics.dart';
import 'package:ccn_visualization/core/models/network_visualization.dart';
import 'package:ccn_visualization/features/simulation/domain/challenge_replay_comparison.dart';
import 'package:ccn_visualization/features/simulation/domain/experiment_narration.dart';
import 'package:ccn_visualization/features/simulation/domain/selected_neuron_summary_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const builder = ExperimentNarrationBuilder();

  test('selects baseline and metric checkpoints deterministically', () {
    final baseline = builder.build(
      phaseLabel: 'Baseline',
      metrics: const LiveMetrics(),
    );
    final spikes = builder.build(
      phaseLabel: 'Learning',
      metrics: const LiveMetrics(batchSpikes: 5),
    );

    expect(baseline.type, NarrationCheckpointType.baseline);
    expect(baseline.message, contains('before learning changes'));
    expect(spikes.type, NarrationCheckpointType.learningChange);
    expect(spikes.message, contains('5 spikes'));
  });

  test('uses selected context with neutral wording', () {
    final summary = SelectedNeuronSummary(
      neuron: const VisualNeuron(
        id: 3,
        type: VisualNeuronType.excitatory,
        x: 0,
        y: 0,
        depth: 0,
        activity: 0.6,
        spiked: true,
        recentFiringRate: 0.4,
      ),
      incoming: const <VisualSynapse>[],
      outgoing: const <VisualSynapse>[],
      activePaths: const <VisualSynapse>[],
      changedPaths: const <VisualSynapse>[],
      phaseExplanation: 'Selected context.',
      timingExplanations: const [],
      challengeReplayComparison: const ChallengeReplayComparison.unavailable(
        explanation: 'missing',
      ),
      variantComparisons: const <SelectedNeuronVariantComparison>[],
    );

    final checkpoint = builder.build(
      phaseLabel: 'Learning',
      metrics: const LiveMetrics(),
      selectedSummary: summary,
    );

    expect(checkpoint.type, NarrationCheckpointType.selectedContext);
    expect(checkpoint.message, contains('Selected neuron 3'));
    expect(checkpoint.message.toLowerCase(), isNot(contains('understand')));
    expect(checkpoint.message.toLowerCase(), isNot(contains('memory')));
  });
}
