import 'package:ccn_visualization/core/ffi/ccn_repository.dart';
import 'package:ccn_visualization/core/models/experiment_definition.dart';
import 'package:ccn_visualization/core/models/metrics.dart';
import 'package:ccn_visualization/core/models/network_visualization.dart';
import 'package:ccn_visualization/core/models/snapshots.dart';
import 'package:ccn_visualization/core/models/step_frame.dart';
import 'package:ccn_visualization/features/simulation/controller/rolling_history.dart';
import 'package:ccn_visualization/features/simulation/controller/run_state.dart';
import 'package:ccn_visualization/features/simulation/controller/simulation_state.dart';
import 'package:ccn_visualization/features/simulation/domain/custom_pattern_result_builder.dart';
import 'package:ccn_visualization/features/simulation/domain/signal_trace_story.dart';
import 'package:ccn_visualization/features/simulation/domain/variant_snapshot_tracker.dart';

class SimulationRunLifecycle {
  SimulationRunLifecycle({
    required CcnRepository repository,
    RollingHistory? history,
    VariantSnapshotTracker? variantSnapshotTracker,
    CustomPatternResultBuilder? customPatternResultBuilder,
  }) : _repository = repository,
       _history = history ?? RollingHistory(),
       _variantSnapshotTracker =
           variantSnapshotTracker ?? const VariantSnapshotTracker(),
       _customPatternResultBuilder =
           customPatternResultBuilder ?? const CustomPatternResultBuilder();

  final CcnRepository _repository;
  final RollingHistory _history;
  final VariantSnapshotTracker _variantSnapshotTracker;
  final CustomPatternResultBuilder _customPatternResultBuilder;

  Future<SimulationState> loadPreset(
    SimulationState state,
    ExperimentDefinition definition,
  ) async {
    _history.clear();
    await _repository.loadExperiment(definition);
    final snapshots = await _refreshSnapshots();
    final progress = await _repository.phaseProgress();
    final baselineWeights = _weightMap(snapshots.weights);
    return state.copyWith(
      selectedExperiment: definition,
      runState: RunState.loaded,
      currentStep: 0,
      phaseProgress: progress,
      rasterHistory: const <SpikeEvent>[],
      spikeCountHistory: const <int>[],
      latestFrame: null,
      clearLatestFrame: true,
      activitySnapshot: snapshots.activity,
      weightSnapshot: snapshots.weights,
      baselineWeights: baselineWeights,
      variantSnapshots: const <VariantSnapshot>[],
      clearInspectedVariant: true,
      camera: NeuralFieldCamera.defaults,
      clearSelectedNeuron: true,
      tracePlayback: const SignalTracePlayback(),
      showWeightDeltaOverlay: false,
      showChallengeReplayComparison: false,
      metrics: const LiveMetrics(),
      result: null,
      clearResult: true,
      clearError: true,
    );
  }

  Future<SimulationState> run(SimulationState state) async {
    if (state.runState == RunState.idle) {
      await _repository.loadExperiment(state.selectedExperiment);
    }
    return state.copyWith(runState: RunState.running, clearError: true);
  }

  Future<SimulationState> reset(SimulationState state) async {
    _history.clear();
    await _repository.reset(NativeResetMode.networkAndExperiment);
    await _repository.clearExperiment();
    await _repository.loadExperiment(state.selectedExperiment);
    final snapshots = await _refreshSnapshots();
    final progress = await _repository.phaseProgress();
    return state.copyWith(
      runState: RunState.loaded,
      currentStep: 0,
      phaseProgress: progress,
      rasterHistory: const <SpikeEvent>[],
      spikeCountHistory: const <int>[],
      latestFrame: null,
      clearLatestFrame: true,
      activitySnapshot: snapshots.activity,
      weightSnapshot: snapshots.weights,
      baselineWeights: _weightMap(snapshots.weights),
      variantSnapshots: const <VariantSnapshot>[],
      clearInspectedVariant: true,
      camera: NeuralFieldCamera.defaults,
      clearSelectedNeuron: true,
      tracePlayback: const SignalTracePlayback(),
      showWeightDeltaOverlay: false,
      showChallengeReplayComparison: false,
      metrics: const LiveMetrics(),
      result: null,
      clearResult: true,
      clearError: true,
    );
  }

  Future<SimulationState> rerunSameSeed(SimulationState state) async {
    _history.clear();
    await _repository.reset(NativeResetMode.fullRecreateFromSeed);
    await _repository.loadExperiment(state.selectedExperiment);
    final snapshots = await _refreshSnapshots();
    final progress = await _repository.phaseProgress();
    return state.copyWith(
      runState: RunState.running,
      currentStep: 0,
      phaseProgress: progress,
      rasterHistory: const <SpikeEvent>[],
      spikeCountHistory: const <int>[],
      latestFrame: null,
      clearLatestFrame: true,
      activitySnapshot: snapshots.activity,
      weightSnapshot: snapshots.weights,
      baselineWeights: _weightMap(snapshots.weights),
      variantSnapshots: const <VariantSnapshot>[],
      clearInspectedVariant: true,
      camera: NeuralFieldCamera.defaults,
      clearSelectedNeuron: true,
      tracePlayback: const SignalTracePlayback(),
      showWeightDeltaOverlay: false,
      showChallengeReplayComparison: false,
      metrics: const LiveMetrics(),
      result: null,
      clearResult: true,
      clearError: true,
    );
  }

  Future<SimulationState> advance(
    SimulationState state, {
    required int maxSteps,
    required bool keepPaused,
  }) async {
    final frame = await _repository.stepExperiment(maxSteps);
    _history.addFrame(frame);
    final previousProgress = state.phaseProgress;
    final progress = await _repository.phaseProgress();
    final snapshots = await _refreshSnapshots();
    var nextRunState = RunState.running;
    final nativeState = await _repository.experimentState();
    if (nativeState == NativeExperimentState.completed) {
      nextRunState = RunState.completed;
    } else if (nativeState == NativeExperimentState.failed) {
      nextRunState = RunState.failed;
    }

    final variantSnapshots = _variantSnapshotTracker.capture(
      phases: state.selectedExperiment.phases,
      existing: state.variantSnapshots,
      previous: previousProgress,
      next: progress,
      completed: nextRunState == RunState.completed,
      activity: snapshots.activity,
      weights: snapshots.weights,
      metrics: frame.statistics,
    );

    var nextState = state.copyWith(
      runState: keepPaused && nextRunState == RunState.running
          ? RunState.paused
          : nextRunState,
      currentStep: progress.totalStep,
      phaseProgress: progress,
      rasterHistory: List<SpikeEvent>.unmodifiable(_history.raster),
      spikeCountHistory: List<int>.unmodifiable(_history.spikeCounts),
      latestFrame: frame,
      activitySnapshot: snapshots.activity,
      weightSnapshot: snapshots.weights,
      variantSnapshots: variantSnapshots,
      clearInspectedVariant: false,
      metrics: frame.statistics,
      clearError: true,
    );

    if (nextRunState == RunState.completed) {
      final nativeResult = await _repository.experimentResult();
      final result = _customPatternResultBuilder.build(
        experiment: state.selectedExperiment,
        nativeResult: nativeResult,
        rasterHistory: nextState.rasterHistory,
        activity: snapshots.activity,
      );
      nextState = nextState.copyWith(result: result);
    }
    return nextState;
  }

  SimulationState pause(SimulationState state) {
    if (state.runState != RunState.running) {
      return state;
    }
    return state.copyWith(runState: RunState.paused);
  }

  SimulationState setFailure(SimulationState state, Object error) {
    return state.copyWith(runState: RunState.failed, error: error.toString());
  }

  Future<void> dispose() => _repository.free().catchError((_) {});

  Future<_SimulationSnapshotBundle> _refreshSnapshots() async {
    final activity = await _repository.activitySnapshot().catchError(
      (_) => const ActivitySnapshot(),
    );
    final weights = await _repository.weightSnapshot().catchError(
      (_) => const SparseWeightSnapshot(),
    );
    return _SimulationSnapshotBundle(activity: activity, weights: weights);
  }

  Map<String, double> _weightMap(SparseWeightSnapshot snapshot) {
    return {
      for (final sample in snapshot.weights)
        '${sample.source}:${sample.target}': sample.weight,
    };
  }
}

class _SimulationSnapshotBundle {
  const _SimulationSnapshotBundle({
    required this.activity,
    required this.weights,
  });

  final ActivitySnapshot activity;
  final SparseWeightSnapshot weights;
}
