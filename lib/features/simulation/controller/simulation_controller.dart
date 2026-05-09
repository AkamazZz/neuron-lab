import 'package:flutter/foundation.dart';

import '../../../core/ffi/ccn_repository.dart';
import '../../../core/models/experiment_definition.dart';
import '../../../core/models/network_visualization.dart';
import 'rolling_history.dart';
import 'run_state.dart';
import 'simulation_state.dart';
import '../domain/simulation_run_lifecycle.dart';

class SimulationController extends ChangeNotifier {
  SimulationController({
    required CcnRepository repository,
    required ExperimentDefinition initialExperiment,
    RollingHistory? history,
    SimulationRunLifecycle? runLifecycle,
  }) : _runLifecycle =
           runLifecycle ??
           SimulationRunLifecycle(repository: repository, history: history),
       _state = SimulationState(selectedExperiment: initialExperiment);

  final SimulationRunLifecycle _runLifecycle;
  SimulationState _state;
  bool _disposed = false;

  SimulationState get state => _state;

  Future<void> loadPreset(ExperimentDefinition definition) async {
    await _guard(() async {
      _setState(await _runLifecycle.loadPreset(_state, definition));
    });
  }

  Future<void> run() async {
    if (_state.runState == RunState.running) {
      return;
    }
    await _guard(() async {
      _setState(await _runLifecycle.run(_state));
    });
  }

  void pause() {
    final nextState = _runLifecycle.pause(_state);
    if (!identical(nextState, _state)) {
      _setState(nextState);
    }
  }

  void setStepsPerTick(int steps) {
    _setState(_state.copyWith(stepsPerTick: steps.clamp(1, 24)));
  }

  void inspectVariant(int? index) {
    if (index == null) {
      _setState(_state.copyWith(clearInspectedVariant: true));
      return;
    }
    if (index >= 0 && index < _state.variantSnapshots.length) {
      _setState(_state.copyWith(inspectedVariantIndex: index));
    }
  }

  void updateCamera(NeuralFieldCamera camera) {
    _setState(_state.copyWith(camera: camera));
  }

  void resetCamera() {
    _setState(_state.copyWith(camera: NeuralFieldCamera.defaults));
  }

  void selectNeuron(int neuronId) {
    if (neuronId < 0 ||
        neuronId >= _state.selectedExperiment.network.neuronCount) {
      return;
    }
    _setState(_state.copyWith(selectedNeuronId: neuronId));
  }

  void clearSelectedNeuron() {
    _setState(_state.copyWith(clearSelectedNeuron: true));
  }

  Future<void> reset() async {
    await _guard(() async {
      _setState(await _runLifecycle.reset(_state));
    });
  }

  Future<void> rerunSameSeed() async {
    await _guard(() async {
      _setState(await _runLifecycle.rerunSameSeed(_state));
    });
  }

  Future<void> stepTick({int maxSteps = 8}) async {
    if (_state.runState != RunState.running) {
      return;
    }
    await _advance(maxSteps: maxSteps, keepPaused: false);
  }

  Future<void> stepOnce() async {
    if (_state.runState == RunState.running ||
        _state.runState == RunState.failed) {
      return;
    }
    await _advance(maxSteps: _state.stepsPerTick, keepPaused: true);
  }

  Future<void> _advance({
    required int maxSteps,
    required bool keepPaused,
  }) async {
    await _guard(() async {
      _setState(
        await _runLifecycle.advance(
          _state,
          maxSteps: maxSteps,
          keepPaused: keepPaused,
        ),
      );
    });
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      _setState(_runLifecycle.setFailure(_state, error));
    }
  }

  void _setState(SimulationState state) {
    _state = state;
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _runLifecycle.dispose();
    super.dispose();
  }
}
