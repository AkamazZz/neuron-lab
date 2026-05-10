import 'package:ccn_visualization/core/ffi/ccn_repository.dart';
import 'package:ccn_visualization/core/models/metrics.dart';
import 'package:ccn_visualization/core/models/network_visualization.dart';
import 'package:ccn_visualization/core/models/phase.dart';
import 'package:ccn_visualization/core/models/preset_result.dart';
import 'package:ccn_visualization/core/models/snapshots.dart';
import 'package:ccn_visualization/core/models/step_frame.dart';
import 'package:ccn_visualization/features/experiments/presets/preset_catalog.dart';
import 'package:ccn_visualization/features/pattern_editor/controller/pattern_editor_controller.dart';
import 'package:ccn_visualization/features/simulation/controller/rolling_history.dart';
import 'package:ccn_visualization/features/simulation/controller/run_state.dart';
import 'package:ccn_visualization/features/simulation/controller/simulation_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fake_repository.dart';

void main() {
  test('run tick completes and stores bounded history', () async {
    final repository = FakeRepository();
    final controller = SimulationController(
      repository: repository,
      initialExperiment: PresetCatalog.patternRecognition(),
      history: RollingHistory(maxEvents: 1, maxSpikeCounts: 1),
    );

    await controller.loadPreset(PresetCatalog.patternRecognition());
    await controller.run();
    await controller.stepTick();

    expect(controller.state.runState, RunState.completed);
    expect(controller.state.rasterHistory, hasLength(1));
    expect(controller.state.spikeCountHistory, hasLength(1));
    expect(controller.state.result, isNotNull);
  });

  test('errors move controller into failed state', () async {
    final repository = FakeRepository()..nextError = StateError('bad preset');
    final controller = SimulationController(
      repository: repository,
      initialExperiment: PresetCatalog.patternRecognition(),
    );

    await controller.loadPreset(PresetCatalog.memoryEcho());

    expect(controller.state.runState, RunState.failed);
    expect(controller.state.error, contains('bad preset'));
  });

  test('camera and selected-neuron state stay in controller layer', () async {
    final repository = FakeRepository();
    final controller = SimulationController(
      repository: repository,
      initialExperiment: PresetCatalog.patternRecognition(),
    );

    controller.updateCamera(
      const NeuralFieldCamera(pan: Offset(12, -4), zoom: 1.5, rotation: 0.3),
    );
    controller.selectNeuron(3);

    expect(controller.state.camera.zoom, 1.5);
    expect(controller.state.camera.pan, const Offset(12, -4));
    expect(controller.state.selectedNeuronId, 3);

    controller.resetCamera();
    controller.clearSelectedNeuron();

    expect(controller.state.camera.zoom, NeuralFieldCamera.defaults.zoom);
    expect(controller.state.selectedNeuronId, isNull);
  });

  test('running frames preserve selected neuron identity', () async {
    final repository = FakeRepository()
      ..frameResponses.add(
        const StepFrame(
          startStep: 0,
          steps: 1,
          spikes: [
            SpikeEvent(
              stepOffset: 0,
              absoluteStep: 1,
              neuronId: 2,
              membrane: 0.8,
            ),
          ],
        ),
      )
      ..stateResponses.add(NativeExperimentState.running);
    final controller = SimulationController(
      repository: repository,
      initialExperiment: PresetCatalog.patternRecognition(),
    );

    await controller.loadPreset(PresetCatalog.patternRecognition());
    controller.selectNeuron(2);
    await controller.run();
    await controller.stepTick();

    expect(controller.state.selectedNeuronId, 2);
  });

  test('reset and dispose call repository lifecycle', () async {
    final repository = FakeRepository();
    final controller = SimulationController(
      repository: repository,
      initialExperiment: PresetCatalog.patternRecognition(),
    );

    await controller.loadPreset(PresetCatalog.patternRecognition());
    await controller.reset();
    controller.dispose();

    expect(repository.resetCount, 1);
    expect(repository.freeCount, 1);
  });

  test(
    'manual step while paused preserves completed variant snapshots',
    () async {
      final repository = FakeRepository()
        ..progressResponses.addAll([
          const PhaseProgress(
            phaseIndex: 0,
            phaseStep: 20,
            phaseDuration: 20,
            totalStep: 20,
            totalDuration: 60,
            progress: 0.33,
          ),
          const PhaseProgress(
            phaseIndex: 1,
            phaseStep: 1,
            phaseDuration: 20,
            totalStep: 21,
            totalDuration: 60,
            progress: 0.35,
          ),
        ])
        ..activityResponses.addAll([
          const ActivitySnapshot(recentFiringRates: [0.1, 0.2]),
          const ActivitySnapshot(recentFiringRates: [0.4, 0.5]),
        ])
        ..weightResponses.addAll([
          const SparseWeightSnapshot(
            weights: [
              WeightSample(
                source: 0,
                target: 1,
                weight: 0.3,
                inhibitory: false,
              ),
            ],
          ),
          const SparseWeightSnapshot(
            weights: [
              WeightSample(
                source: 0,
                target: 1,
                weight: 0.6,
                inhibitory: false,
              ),
            ],
          ),
        ])
        ..frameResponses.add(
          const StepFrame(
            startStep: 20,
            steps: 1,
            spikes: [
              SpikeEvent(
                stepOffset: 0,
                absoluteStep: 21,
                neuronId: 0,
                membrane: 1,
              ),
            ],
          ),
        )
        ..stateResponses.add(NativeExperimentState.running);
      final controller = SimulationController(
        repository: repository,
        initialExperiment: PresetCatalog.continuousLearningFlow(),
      );

      await controller.loadPreset(PresetCatalog.continuousLearningFlow());
      await controller.stepOnce();

      expect(controller.state.runState, RunState.paused);
      expect(controller.state.variantSnapshots, hasLength(1));
      expect(controller.state.variantSnapshots.single.label, 'Baseline');
      expect(controller.state.latestFrame?.spikes.single.neuronId, 0);

      controller.inspectVariant(0);

      expect(controller.state.inspectedVariant?.label, 'Baseline');
    },
  );

  test('advance stores native frame statistics in visible metrics', () async {
    final repository = FakeRepository()
      ..frameResponses.add(
        const StepFrame(
          startStep: 0,
          steps: 1,
          spikes: [
            SpikeEvent(
              stepOffset: 0,
              absoluteStep: 0,
              neuronId: 4,
              membrane: 0,
            ),
          ],
          statistics: LiveMetrics(
            totalSpikes: 42,
            batchSpikes: 7,
            activeNeuronCount: 3,
            averageWeight: 0.35,
          ),
        ),
      )
      ..stateResponses.add(NativeExperimentState.running);
    final controller = SimulationController(
      repository: repository,
      initialExperiment: PresetCatalog.patternRecognition(),
    );

    await controller.loadPreset(PresetCatalog.patternRecognition());
    await controller.stepOnce();

    expect(controller.state.metrics.totalSpikes, 42);
    expect(controller.state.metrics.batchSpikes, 7);
    expect(controller.state.metrics.activeNeuronCount, 3);
    expect(controller.state.metrics.averageWeight, 0.35);
  });

  test(
    'custom pattern completion exposes pattern-specific result evidence',
    () async {
      final patternController = PatternEditorController()
        ..toggleCell(2)
        ..toggleCell(5)
        ..setStrength(1.6)
        ..setNoise(0.25);
      final definition = patternController.state.toExperimentDefinition();
      final repository = FakeRepository()
        ..activityResponses.addAll([
          const ActivitySnapshot(recentFiringRates: [0, 0, 0, 0, 0, 0]),
          const ActivitySnapshot(recentFiringRates: [0.4, 0, 0.9, 0, 0, 0.8]),
        ])
        ..frameResponses.add(
          const StepFrame(
            startStep: 180,
            steps: 2,
            spikes: [
              SpikeEvent(
                stepOffset: 0,
                absoluteStep: 181,
                neuronId: 2,
                membrane: 1,
              ),
              SpikeEvent(
                stepOffset: 1,
                absoluteStep: 182,
                neuronId: 4,
                membrane: 1,
              ),
            ],
          ),
        )
        ..stateResponses.add(NativeExperimentState.completed);
      final controller = SimulationController(
        repository: repository,
        initialExperiment: definition,
      );

      await controller.loadPreset(definition);
      await controller.run();
      await controller.stepTick();

      final result = controller.state.result;
      expect(result, isA<CustomPatternResult>());
      final customResult = result! as CustomPatternResult;
      expect(customResult.patternLabel, 'Pattern A');
      expect(customResult.neuronIds, <int>[2, 5]);
      expect(customResult.strength, 1.6);
      expect(customResult.dropout, 0.25);
      expect(customResult.targetSpikeCount, 1);
      expect(customResult.offPatternSpikeCount, 1);
      expect(customResult.targetActiveCount, 2);
      expect(customResult.offPatternActiveCount, 1);
      expect(customResult.responseSimilarity, 1.0);
    },
  );
}
