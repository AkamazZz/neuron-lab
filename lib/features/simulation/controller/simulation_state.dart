import '../../../core/models/experiment_definition.dart';
import '../../../core/models/metrics.dart';
import '../../../core/models/network_visualization.dart';
import '../../../core/models/phase.dart';
import '../../../core/models/preset_result.dart';
import '../../../core/models/snapshots.dart';
import '../../../core/models/step_frame.dart';
import 'run_state.dart';

class SimulationState {
  const SimulationState({
    required this.selectedExperiment,
    this.runState = RunState.idle,
    this.currentStep = 0,
    this.phaseProgress = const PhaseProgress(),
    this.rasterHistory = const <SpikeEvent>[],
    this.spikeCountHistory = const <int>[],
    this.activitySnapshot = const ActivitySnapshot(),
    this.weightSnapshot = const SparseWeightSnapshot(),
    this.latestFrame,
    this.baselineWeights = const <String, double>{},
    this.variantSnapshots = const <VariantSnapshot>[],
    this.inspectedVariantIndex,
    this.camera = NeuralFieldCamera.defaults,
    this.selectedNeuronId,
    this.stepsPerTick = 6,
    this.metrics = const LiveMetrics(),
    this.result,
    this.error,
  });

  final ExperimentDefinition selectedExperiment;
  final RunState runState;
  final int currentStep;
  final PhaseProgress phaseProgress;
  final List<SpikeEvent> rasterHistory;
  final List<int> spikeCountHistory;
  final ActivitySnapshot activitySnapshot;
  final SparseWeightSnapshot weightSnapshot;
  final StepFrame? latestFrame;
  final Map<String, double> baselineWeights;
  final List<VariantSnapshot> variantSnapshots;
  final int? inspectedVariantIndex;
  final NeuralFieldCamera camera;
  final int? selectedNeuronId;
  final int stepsPerTick;
  final LiveMetrics metrics;
  final PresetResult? result;
  final String? error;

  VariantSnapshot? get inspectedVariant {
    final index = inspectedVariantIndex;
    if (index == null || index < 0 || index >= variantSnapshots.length) {
      return null;
    }
    return variantSnapshots[index];
  }

  SimulationState copyWith({
    ExperimentDefinition? selectedExperiment,
    RunState? runState,
    int? currentStep,
    PhaseProgress? phaseProgress,
    List<SpikeEvent>? rasterHistory,
    List<int>? spikeCountHistory,
    ActivitySnapshot? activitySnapshot,
    SparseWeightSnapshot? weightSnapshot,
    StepFrame? latestFrame,
    bool clearLatestFrame = false,
    Map<String, double>? baselineWeights,
    List<VariantSnapshot>? variantSnapshots,
    int? inspectedVariantIndex,
    bool clearInspectedVariant = false,
    NeuralFieldCamera? camera,
    int? selectedNeuronId,
    bool clearSelectedNeuron = false,
    int? stepsPerTick,
    LiveMetrics? metrics,
    PresetResult? result,
    bool clearResult = false,
    String? error,
    bool clearError = false,
  }) {
    return SimulationState(
      selectedExperiment: selectedExperiment ?? this.selectedExperiment,
      runState: runState ?? this.runState,
      currentStep: currentStep ?? this.currentStep,
      phaseProgress: phaseProgress ?? this.phaseProgress,
      rasterHistory: rasterHistory ?? this.rasterHistory,
      spikeCountHistory: spikeCountHistory ?? this.spikeCountHistory,
      activitySnapshot: activitySnapshot ?? this.activitySnapshot,
      weightSnapshot: weightSnapshot ?? this.weightSnapshot,
      latestFrame: clearLatestFrame ? null : latestFrame ?? this.latestFrame,
      baselineWeights: baselineWeights ?? this.baselineWeights,
      variantSnapshots: variantSnapshots ?? this.variantSnapshots,
      inspectedVariantIndex: clearInspectedVariant
          ? null
          : inspectedVariantIndex ?? this.inspectedVariantIndex,
      camera: camera ?? this.camera,
      selectedNeuronId: clearSelectedNeuron
          ? null
          : selectedNeuronId ?? this.selectedNeuronId,
      stepsPerTick: stepsPerTick ?? this.stepsPerTick,
      metrics: metrics ?? this.metrics,
      result: clearResult ? null : result ?? this.result,
      error: clearError ? null : error ?? this.error,
    );
  }
}
