import '../../../core/models/metrics.dart';
import '../../../core/models/network_visualization.dart';
import '../../../core/models/phase.dart';
import '../../../core/models/snapshots.dart';
import 'experiment_phase_interpreter.dart';

class VariantSnapshotTracker {
  const VariantSnapshotTracker({
    this.phaseInterpreter = const ExperimentPhaseInterpreter(),
  });

  final ExperimentPhaseInterpreter phaseInterpreter;

  List<VariantSnapshot> capture({
    required List<ExperimentPhase> phases,
    required List<VariantSnapshot> existing,
    required PhaseProgress previous,
    required PhaseProgress next,
    required bool completed,
    required ActivitySnapshot activity,
    required SparseWeightSnapshot weights,
    required LiveMetrics metrics,
  }) {
    if (phases.isEmpty || previous.totalDuration == 0) {
      return existing;
    }
    final shouldCapturePrevious =
        next.phaseIndex != previous.phaseIndex || completed;
    if (!shouldCapturePrevious) {
      return existing;
    }
    final phaseIndex = previous.phaseIndex.clamp(0, phases.length - 1);
    final phase = phases[phaseIndex];
    final snapshots = existing
        .where((snapshot) => snapshot.phaseIndex != phaseIndex)
        .toList(growable: true);
    snapshots.add(
      VariantSnapshot(
        phaseIndex: phaseIndex,
        phaseId: phase.id,
        label: phaseInterpreter.labelForPhaseId(phase.id, phaseIndex),
        activity: activity,
        weights: weights,
        metrics: metrics,
        step: previous.totalStep,
      ),
    );
    snapshots.sort((a, b) => a.phaseIndex.compareTo(b.phaseIndex));
    return List<VariantSnapshot>.unmodifiable(snapshots);
  }
}
