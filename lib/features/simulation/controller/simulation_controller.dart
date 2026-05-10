import 'package:flutter/foundation.dart';

import '../../../core/ffi/ccn_repository.dart';
import '../../../core/models/experiment_definition.dart';
import '../../../core/models/network_visualization.dart';
import '../domain/experiment_phase_interpreter.dart';
import '../domain/signal_trace_story.dart';
import '../domain/visualization_projection.dart';
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
  final SignalTraceStoryBuilder _traceBuilder = const SignalTraceStoryBuilder();
  final VisualNetworkProjector _projector = const VisualNetworkProjector();
  final ExperimentPhaseInterpreter _phaseInterpreter =
      const ExperimentPhaseInterpreter();
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
    _setState(
      _state.copyWith(
        selectedNeuronId: neuronId,
        tracePlayback: const SignalTracePlayback(),
      ),
    );
  }

  void clearSelectedNeuron() {
    _setState(
      _state.copyWith(
        clearSelectedNeuron: true,
        tracePlayback: const SignalTracePlayback(),
      ),
    );
  }

  void activateTraceMode() {
    final selectedNeuronId = _state.selectedNeuronId;
    if (selectedNeuronId == null) {
      return;
    }
    final story = _traceBuilder.build(
      selectedNeuronId: selectedNeuronId,
      frame: _currentFrame(),
      recentSpikes: _state.rasterHistory,
    );
    _setState(
      _state.copyWith(
        tracePlayback: SignalTracePlayback(active: true, story: story),
      ),
    );
  }

  void pauseTrace() {
    _setState(
      _state.copyWith(
        tracePlayback: _state.tracePlayback.copyWith(playing: false),
      ),
    );
  }

  void playTrace() {
    final playback = _state.tracePlayback;
    if (!playback.active || playback.story == null) {
      return;
    }
    _setState(_state.copyWith(tracePlayback: playback.copyWith(playing: true)));
  }

  void resetTrace() {
    final playback = _state.tracePlayback;
    if (!playback.active) {
      return;
    }
    _setState(
      _state.copyWith(
        tracePlayback: playback.copyWith(cursor: 0, playing: false),
      ),
    );
  }

  void stepTraceForward() {
    final playback = _state.tracePlayback;
    final story = playback.story;
    if (!playback.active || story == null || story.playbackLength == 0) {
      return;
    }
    final nextCursor = playback.cursor + 1;
    _setState(
      _state.copyWith(
        tracePlayback: playback.copyWith(
          cursor: nextCursor.clamp(0, story.playbackLength - 1),
          playing: nextCursor < story.playbackLength - 1 && playback.playing,
        ),
      ),
    );
  }

  void setTraceSpeed(double speed) {
    _setState(
      _state.copyWith(
        tracePlayback: _state.tracePlayback.copyWith(speed: speed),
      ),
    );
  }

  void setWeightDeltaOverlayVisible(bool visible) {
    _setState(_state.copyWith(showWeightDeltaOverlay: visible));
  }

  void setChallengeReplayComparisonVisible(bool visible) {
    _setState(_state.copyWith(showChallengeReplayComparison: visible));
  }

  void setNarrationEnabled(bool enabled) {
    _setState(
      _state.copyWith(narrationEnabled: enabled, narrationDismissed: false),
    );
  }

  void dismissNarration() {
    _setState(_state.copyWith(narrationDismissed: true));
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

  VisualNetworkFrame _currentFrame() {
    final inspected = _state.inspectedVariant;
    final activity = inspected?.activity ?? _state.activitySnapshot;
    final weights = inspected?.weights ?? _state.weightSnapshot;
    return _projector.project(
      experiment: _state.selectedExperiment,
      activity: activity,
      weights: weights,
      latestFrame: inspected == null ? _state.latestFrame : null,
      baselineWeights: _state.baselineWeights,
      currentStep: inspected?.step ?? _state.currentStep,
      phaseLabel: inspected?.label ?? _phaseLabel(),
    );
  }

  String _phaseLabel() {
    return _phaseInterpreter.labelForProgress(
      _state.phaseProgress,
      _state.selectedExperiment.phases,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _runLifecycle.dispose();
    super.dispose();
  }
}
