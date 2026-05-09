import '../../../core/models/network_visualization.dart';
import '../../../core/models/phase.dart';

class ExperimentPhaseInterpreter {
  const ExperimentPhaseInterpreter();

  String labelForProgress(
    PhaseProgress progress,
    List<ExperimentPhase> phases,
  ) {
    if (phases.isEmpty) {
      return 'No phase';
    }
    final index = progress.phaseIndex.clamp(0, phases.length - 1);
    return labelForPhaseId(phases[index].id, index);
  }

  String labelForPhaseId(String phaseId, int index) {
    final normalized = phaseId.toLowerCase();
    if (normalized.contains('baseline')) {
      return 'Baseline';
    }
    if (normalized.contains('learn') || normalized.contains('train')) {
      return 'Learning';
    }
    if (normalized.contains('challenge')) {
      return 'Challenge';
    }
    return 'Phase ${index + 1}';
  }

  String selectedNeuronExplanation({
    required String phaseLabel,
    required VisualNeuron neuron,
    required List<VisualSynapse> changedPaths,
    required List<VisualSynapse> activePaths,
  }) {
    final normalized = phaseLabel.toLowerCase();
    if (normalized.contains('learn')) {
      if (changedPaths.isEmpty) {
        return 'Training telemetry shows no notable weight change attached to this neuron yet.';
      }
      return 'Training telemetry shows attached paths changing while the model runs STDP-style updates.';
    }
    if (normalized.contains('challenge')) {
      if (activePaths.isEmpty && !neuron.spiked) {
        return 'Challenge telemetry shows this neuron is not currently part of the active response.';
      }
      return 'Challenge telemetry shows this neuron participating in the current response pattern.';
    }
    return 'Baseline telemetry describes this neuron before training-phase path changes are compared.';
  }
}
