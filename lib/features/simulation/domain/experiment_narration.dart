import 'package:ccn_visualization/core/models/metrics.dart';
import 'package:ccn_visualization/features/simulation/domain/challenge_replay_comparison.dart';
import 'package:ccn_visualization/features/simulation/domain/selected_neuron_summary_builder.dart';

enum NarrationCheckpointType {
  baseline,
  learningChange,
  challengeOutcome,
  selectedContext,
  unavailable,
}

class NarrationCheckpoint {
  const NarrationCheckpoint({required this.type, required this.message});

  final NarrationCheckpointType type;
  final String message;
}

class ExperimentNarrationBuilder {
  const ExperimentNarrationBuilder();

  NarrationCheckpoint build({
    required String phaseLabel,
    required LiveMetrics metrics,
    SelectedNeuronSummary? selectedSummary,
  }) {
    final phase = phaseLabel.toLowerCase();
    final comparison = selectedSummary?.challengeReplayComparison;
    if (comparison != null &&
        comparison.outcome != ChallengeReplayOutcome.unavailable &&
        phase.contains('challenge')) {
      return NarrationCheckpoint(
        type: NarrationCheckpointType.challengeOutcome,
        message: _challengeCopy(comparison.outcome),
      );
    }
    if (selectedSummary != null && selectedSummary.changedPaths.isNotEmpty) {
      final path = selectedSummary.changedPaths.first;
      return NarrationCheckpoint(
        type: NarrationCheckpointType.learningChange,
        message:
            'Selected neuron ${selectedSummary.neuron.id} has a changed model path ${path.source} -> ${path.target}; compare weight deltas before reading this as route evidence.',
      );
    }
    if (selectedSummary != null) {
      return NarrationCheckpoint(
        type: NarrationCheckpointType.selectedContext,
        message:
            'Selected neuron ${selectedSummary.neuron.id} is shown with current activity ${selectedSummary.neuron.activity.toStringAsFixed(2)} and nearby telemetry paths.',
      );
    }
    if (phase.contains('baseline')) {
      return NarrationCheckpoint(
        type: NarrationCheckpointType.baseline,
        message:
            'Baseline shows the model response before learning changes are compared.',
      );
    }
    if (metrics.batchSpikes > 0) {
      return NarrationCheckpoint(
        type: NarrationCheckpointType.learningChange,
        message:
            'Recent steps produced ${metrics.batchSpikes} spikes; watch for path changes backed by the weight snapshots.',
      );
    }
    return const NarrationCheckpoint(
      type: NarrationCheckpointType.unavailable,
      message:
          'Narration will add checkpoints when phase, spike, or comparison telemetry is available.',
    );
  }

  String _challengeCopy(ChallengeReplayOutcome outcome) {
    return switch (outcome) {
      ChallengeReplayOutcome.reused =>
        'Challenge replay reused the selected route in this toy model.',
      ChallengeReplayOutcome.partiallyReused =>
        'Challenge replay partially reused the selected route in this toy model.',
      ChallengeReplayOutcome.notReused =>
        'Challenge replay did not reactivate the selected route in this run.',
      ChallengeReplayOutcome.unavailable =>
        'Challenge replay comparison is available after challenge telemetry is captured.',
    };
  }
}
