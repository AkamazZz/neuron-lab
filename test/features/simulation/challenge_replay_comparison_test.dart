import 'package:ccn_visualization/core/models/metrics.dart';
import 'package:ccn_visualization/core/models/network_visualization.dart';
import 'package:ccn_visualization/core/models/snapshots.dart';
import 'package:ccn_visualization/features/simulation/domain/challenge_replay_comparison.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const builder = ChallengeReplayComparisonBuilder();

  test('classifies full path reuse from baseline and challenge snapshots', () {
    final comparison = builder.build(
      selectedNeuronId: 0,
      selectedPaths: [_path(0, 1)],
      variants: [
        _snapshot(
          index: 0,
          id: 'baseline',
          label: 'Baseline',
          activity: const [0.1, 0.1],
          spiked: const [false, false],
        ),
        _snapshot(
          index: 2,
          id: 'challenge',
          label: 'Challenge',
          activity: const [0.8, 0.6],
          spiked: const [true, true],
        ),
      ],
    );

    expect(comparison.outcome, ChallengeReplayOutcome.reused);
    expect(comparison.paths.single.reuse, ChallengePathReuse.reused);
    expect(comparison.explanation, contains('reused'));
  });

  test('classifies partial and missing comparison states', () {
    final partial = builder.build(
      selectedNeuronId: 0,
      selectedPaths: [_path(0, 1), _path(1, 2)],
      variants: [
        _snapshot(
          index: 0,
          id: 'baseline',
          label: 'Baseline',
          activity: const [0.1, 0.1, 0.1],
          spiked: const [false, false, false],
        ),
        _snapshot(
          index: 2,
          id: 'challenge',
          label: 'Challenge',
          activity: const [0.5, 0.2, 0.0],
          spiked: const [true, false, false],
        ),
      ],
    );
    final unavailable = builder.build(
      selectedNeuronId: 0,
      selectedPaths: [_path(0, 1)],
      variants: const <VariantSnapshot>[],
    );

    expect(partial.outcome, ChallengeReplayOutcome.partiallyReused);
    expect(partial.paths.where((path) => path.challengeActive), hasLength(1));
    expect(unavailable.outcome, ChallengeReplayOutcome.unavailable);
    expect(unavailable.explanation, contains('available after'));
  });
}

VariantSnapshot _snapshot({
  required int index,
  required String id,
  required String label,
  required List<double> activity,
  required List<bool> spiked,
}) {
  return VariantSnapshot(
    phaseIndex: index,
    phaseId: id,
    label: label,
    activity: ActivitySnapshot(recentFiringRates: activity, spiked: spiked),
    weights: const SparseWeightSnapshot(),
    metrics: const LiveMetrics(),
    step: index * 10,
  );
}

VisualSynapse _path(int source, int target) {
  return VisualSynapse(
    source: source,
    target: target,
    weight: 0.6,
    inhibitory: false,
    signalActivity: 1,
    weightChange: 0.2,
  );
}
