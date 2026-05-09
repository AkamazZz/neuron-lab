import 'package:ccn_visualization/core/ffi/ccn_repository.dart';
import 'package:ccn_visualization/core/models/experiment_definition.dart';
import 'package:ccn_visualization/core/models/phase.dart';
import 'package:ccn_visualization/core/models/preset_result.dart';
import 'package:ccn_visualization/core/models/simulation_config.dart';
import 'package:ccn_visualization/core/models/snapshots.dart';
import 'package:ccn_visualization/core/models/step_frame.dart';

class FakeRepository implements CcnRepository {
  NativeExperimentState nativeState = NativeExperimentState.loaded;
  int freeCount = 0;
  int resetCount = 0;
  ExperimentDefinition? loaded;
  Object? nextError;
  final List<ActivitySnapshot> activityResponses = <ActivitySnapshot>[];
  final List<SparseWeightSnapshot> weightResponses = <SparseWeightSnapshot>[];
  final List<StepFrame> frameResponses = <StepFrame>[];
  final List<PhaseProgress> progressResponses = <PhaseProgress>[];
  final List<NativeExperimentState> stateResponses = <NativeExperimentState>[];

  @override
  Future<ActivitySnapshot> activitySnapshot() async {
    if (activityResponses.isNotEmpty) {
      return activityResponses.removeAt(0);
    }
    return const ActivitySnapshot(
      step: 0,
      recentFiringRates: [0.2, 0.4, 0.1, 0.7],
    );
  }

  @override
  Future<void> clearExperiment() async {}

  @override
  Future<void> create(SimulationConfig config) async {}

  @override
  Future<NativeExperimentState> experimentState() async {
    if (stateResponses.isNotEmpty) {
      nativeState = stateResponses.removeAt(0);
    }
    return nativeState;
  }

  @override
  Future<PresetResult> experimentResult() async =>
      const GenericResult(totalSpikes: 12, averageWeight: 0.3);

  @override
  Future<void> free() async {
    freeCount += 1;
  }

  @override
  Future<void> loadExperiment(ExperimentDefinition definition) async {
    if (nextError != null) {
      throw nextError!;
    }
    loaded = definition;
    nativeState = NativeExperimentState.loaded;
  }

  @override
  Future<PhaseProgress> phaseProgress() async {
    if (progressResponses.isNotEmpty) {
      return progressResponses.removeAt(0);
    }
    return const PhaseProgress(
      phaseIndex: 0,
      phaseStep: 5,
      phaseDuration: 20,
      totalStep: 5,
      totalDuration: 20,
      progress: 0.25,
    );
  }

  @override
  Future<StepFrame> rawStep({
    required int steps,
    required bool learningEnabled,
    List<Map<String, Object?>> input = const <Map<String, Object?>>[],
  }) async => const StepFrame(startStep: 0, steps: 1, spikes: []);

  @override
  Future<void> reset(NativeResetMode mode) async {
    resetCount += 1;
  }

  @override
  Future<StepFrame> stepExperiment(int maxSteps) async {
    if (frameResponses.isNotEmpty) {
      return frameResponses.removeAt(0);
    }
    nativeState = NativeExperimentState.completed;
    return const StepFrame(
      startStep: 0,
      steps: 1,
      spikes: [
        SpikeEvent(stepOffset: 0, absoluteStep: 1, neuronId: 2, membrane: 0.8),
      ],
    );
  }

  @override
  Future<void> validateConfig(SimulationConfig config) async {}

  @override
  Future<void> validateExperiment(ExperimentDefinition definition) async {}

  @override
  Future<SparseWeightSnapshot> weightSnapshot() async {
    if (weightResponses.isNotEmpty) {
      return weightResponses.removeAt(0);
    }
    return const SparseWeightSnapshot(
      weights: [
        WeightSample(source: 0, target: 1, weight: 0.4, inhibitory: false),
      ],
    );
  }
}
