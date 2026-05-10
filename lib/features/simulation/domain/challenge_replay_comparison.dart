import 'package:ccn_visualization/core/models/network_visualization.dart';

enum ChallengeReplayOutcome { reused, partiallyReused, notReused, unavailable }

enum ChallengePathReuse { reused, inactive, unavailable }

class ChallengeReplayPathComparison {
  const ChallengeReplayPathComparison({
    required this.source,
    required this.target,
    required this.reuse,
    required this.baselineActive,
    required this.challengeActive,
  });

  final int source;
  final int target;
  final ChallengePathReuse reuse;
  final bool baselineActive;
  final bool challengeActive;

  String get label {
    final state = switch (reuse) {
      ChallengePathReuse.reused => 'reused',
      ChallengePathReuse.inactive => 'inactive',
      ChallengePathReuse.unavailable => 'unavailable',
    };
    return '$source -> $target: $state';
  }
}

class ChallengeReplayComparison {
  const ChallengeReplayComparison({
    required this.outcome,
    required this.baselineLabel,
    required this.challengeLabel,
    required this.baselineActivity,
    required this.challengeActivity,
    required this.paths,
    required this.explanation,
  });

  const ChallengeReplayComparison.unavailable({required this.explanation})
    : outcome = ChallengeReplayOutcome.unavailable,
      baselineLabel = 'Baseline',
      challengeLabel = 'Challenge',
      baselineActivity = 0,
      challengeActivity = 0,
      paths = const <ChallengeReplayPathComparison>[];

  final ChallengeReplayOutcome outcome;
  final String baselineLabel;
  final String challengeLabel;
  final double baselineActivity;
  final double challengeActivity;
  final List<ChallengeReplayPathComparison> paths;
  final String explanation;
}

class ChallengeReplayComparisonBuilder {
  const ChallengeReplayComparisonBuilder({this.pathLimit = 4});

  final int pathLimit;

  ChallengeReplayComparison build({
    required int selectedNeuronId,
    required List<VisualSynapse> selectedPaths,
    required List<VariantSnapshot> variants,
  }) {
    final baseline = _baseline(variants);
    final challenge = _challenge(variants);
    if (baseline == null || challenge == null) {
      return const ChallengeReplayComparison.unavailable(
        explanation:
            'Replay comparison is available after baseline and challenge snapshots are captured.',
      );
    }

    final baselineActivity = _activityFor(baseline, selectedNeuronId);
    final challengeActivity = _activityFor(challenge, selectedNeuronId);
    final pathComparisons = selectedPaths
        .take(pathLimit)
        .map(
          (path) => ChallengeReplayPathComparison(
            source: path.source,
            target: path.target,
            reuse: _pathActive(challenge, path)
                ? ChallengePathReuse.reused
                : ChallengePathReuse.inactive,
            baselineActive: _pathActive(baseline, path),
            challengeActive: _pathActive(challenge, path),
          ),
        )
        .toList(growable: false);
    final activeCount = pathComparisons
        .where((comparison) => comparison.challengeActive)
        .length;
    final outcome = _outcome(
      challengeActivity: challengeActivity,
      pathCount: pathComparisons.length,
      activeCount: activeCount,
    );
    return ChallengeReplayComparison(
      outcome: outcome,
      baselineLabel: baseline.label,
      challengeLabel: challenge.label,
      baselineActivity: baselineActivity,
      challengeActivity: challengeActivity,
      paths: List<ChallengeReplayPathComparison>.unmodifiable(pathComparisons),
      explanation: _explanation(outcome),
    );
  }

  VariantSnapshot? _baseline(List<VariantSnapshot> variants) {
    if (variants.isEmpty) {
      return null;
    }
    return variants.reduce((a, b) => a.phaseIndex <= b.phaseIndex ? a : b);
  }

  VariantSnapshot? _challenge(List<VariantSnapshot> variants) {
    final challenge = variants.where(
      (snapshot) => snapshot.phaseId.toLowerCase().contains('challenge'),
    );
    if (challenge.isNotEmpty) {
      return challenge.last;
    }
    if (variants.length < 2) {
      return null;
    }
    return variants.reduce((a, b) => a.phaseIndex >= b.phaseIndex ? a : b);
  }

  double _activityFor(VariantSnapshot snapshot, int neuronId) {
    if (neuronId >= snapshot.activity.recentFiringRates.length) {
      return 0;
    }
    return snapshot.activity.recentFiringRates[neuronId].clamp(0.0, 1.0);
  }

  bool _pathActive(VariantSnapshot snapshot, VisualSynapse path) {
    final spiked = snapshot.activity.spiked;
    final sourceSpiked = path.source < spiked.length && spiked[path.source];
    final targetSpiked = path.target < spiked.length && spiked[path.target];
    return sourceSpiked || targetSpiked;
  }

  ChallengeReplayOutcome _outcome({
    required double challengeActivity,
    required int pathCount,
    required int activeCount,
  }) {
    if (pathCount == 0) {
      return challengeActivity > 0.05
          ? ChallengeReplayOutcome.partiallyReused
          : ChallengeReplayOutcome.notReused;
    }
    if (activeCount == pathCount) {
      return ChallengeReplayOutcome.reused;
    }
    if (activeCount > 0 || challengeActivity > 0.05) {
      return ChallengeReplayOutcome.partiallyReused;
    }
    return ChallengeReplayOutcome.notReused;
  }

  String _explanation(ChallengeReplayOutcome outcome) {
    return switch (outcome) {
      ChallengeReplayOutcome.reused =>
        'Challenge activity reused the selected model path.',
      ChallengeReplayOutcome.partiallyReused =>
        'Challenge activity partially reused the selected context.',
      ChallengeReplayOutcome.notReused =>
        'Challenge activity did not reactivate the selected context.',
      ChallengeReplayOutcome.unavailable =>
        'Replay comparison is available after the challenge phase runs.',
    };
  }
}
