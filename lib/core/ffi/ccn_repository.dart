import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../models/experiment_definition.dart';
import '../models/metrics.dart';
import '../models/phase.dart';
import '../models/preset_result.dart';
import '../models/simulation_config.dart';
import '../models/snapshots.dart';
import '../models/step_frame.dart';
import 'ccn_bindings.dart';
import 'ccn_native.dart';
import 'ccn_status.dart';
import 'native_buffer.dart';

enum NativeExperimentState { idle, loaded, running, paused, completed, failed }

enum NativeResetMode {
  networkOnly(0),
  networkAndExperiment(1),
  fullRecreateFromSeed(2);

  const NativeResetMode(this.code);

  final int code;
}

abstract class CcnRepository {
  Future<void> validateConfig(SimulationConfig config);
  Future<void> create(SimulationConfig config);
  Future<void> free();
  Future<void> reset(NativeResetMode mode);
  Future<StepFrame> rawStep({
    required int steps,
    required bool learningEnabled,
    List<Map<String, Object?>> input = const <Map<String, Object?>>[],
  });
  Future<void> validateExperiment(ExperimentDefinition definition);
  Future<void> loadExperiment(ExperimentDefinition definition);
  Future<void> clearExperiment();
  Future<StepFrame> stepExperiment(int maxSteps);
  Future<NativeExperimentState> experimentState();
  Future<PhaseProgress> phaseProgress();
  Future<PresetResult> experimentResult();
  Future<ActivitySnapshot> activitySnapshot();
  Future<SparseWeightSnapshot> weightSnapshot();
}

class NativeCcnRepository implements CcnRepository {
  NativeCcnRepository(this._native);

  final CcnNative _native;
  Pointer<CcnSimulationHandle>? _handle;

  @override
  Future<void> validateConfig(SimulationConfig config) async {
    final report = calloc<CcnBuffer>();
    try {
      _withJson(config.toJson(), (pointer, length) {
        final status = _native.validateConfig(pointer, length, report);
        _throwOrFreeStatus(status);
      });
      _native.freeBuffer(report.ref);
    } finally {
      calloc.free(report);
    }
  }

  @override
  Future<void> create(SimulationConfig config) async {
    if (_handle != null) {
      await free();
    }
    final outHandle = calloc<CcnSimulationHandle>();
    try {
      _withJson(config.toJson(), (pointer, length) {
        final status = _native.createSimulation(pointer, length, outHandle);
        _throwOrFreeStatus(status);
      });
      _handle = outHandle;
    } catch (_) {
      calloc.free(outHandle);
      rethrow;
    }
  }

  @override
  Future<void> free() async {
    final handle = _requireHandle();
    final status = _native.freeSimulation(handle);
    _throwOrFreeStatus(status);
    calloc.free(_handle!);
    _handle = null;
  }

  @override
  Future<void> reset(NativeResetMode mode) async {
    final status = _native.rawReset(_requireHandle(), mode.code);
    _throwOrFreeStatus(status);
  }

  @override
  Future<StepFrame> rawStep({
    required int steps,
    required bool learningEnabled,
    List<Map<String, Object?>> input = const <Map<String, Object?>>[],
  }) async {
    final outFrame = calloc<CcnStepFrameStruct>();
    try {
      _withJson(input, (pointer, length) {
        final status = _native.rawStep(
          _requireHandle(),
          pointer,
          length,
          steps,
          learningEnabled,
          outFrame,
        );
        _throwOrFreeStatus(status);
      });
      return _copyFrame(outFrame.ref);
    } finally {
      if (outFrame.ref.events != nullptr) {
        _native.freeStepFrame(outFrame.ref);
      }
      calloc.free(outFrame);
    }
  }

  @override
  Future<void> validateExperiment(ExperimentDefinition definition) async {
    final report = calloc<CcnBuffer>();
    try {
      _withJson(definition.toJson(), (pointer, length) {
        final status = _native.validateExperiment(pointer, length, report);
        _throwOrFreeStatus(status);
      });
      _native.freeBuffer(report.ref);
    } finally {
      calloc.free(report);
    }
  }

  @override
  Future<void> loadExperiment(ExperimentDefinition definition) async {
    await _ensureCreated(definition.network);
    _withJson(definition.toJson(), (pointer, length) {
      final status = _native.loadExperiment(_requireHandle(), pointer, length);
      _throwOrFreeStatus(status);
    });
  }

  @override
  Future<void> clearExperiment() async {
    final status = _native.clearExperiment(_requireHandle());
    _throwOrFreeStatus(status);
  }

  @override
  Future<StepFrame> stepExperiment(int maxSteps) async {
    final outFrame = calloc<CcnStepFrameStruct>();
    try {
      final status = _native.stepExperiment(
        _requireHandle(),
        maxSteps,
        outFrame,
      );
      _throwOrFreeStatus(status);
      return _copyFrame(outFrame.ref);
    } finally {
      if (outFrame.ref.events != nullptr) {
        _native.freeStepFrame(outFrame.ref);
      }
      calloc.free(outFrame);
    }
  }

  @override
  Future<NativeExperimentState> experimentState() async {
    final outState = calloc<Uint32>();
    try {
      final status = _native.experimentState(_requireHandle(), outState);
      _throwOrFreeStatus(status);
      return NativeExperimentState.values[outState.value.clamp(0, 5).toInt()];
    } finally {
      calloc.free(outState);
    }
  }

  @override
  Future<PhaseProgress> phaseProgress() async {
    final outProgress = calloc<CcnPhaseProgressStruct>();
    try {
      final status = _native.phaseProgress(_requireHandle(), outProgress);
      _throwOrFreeStatus(status);
      final value = outProgress.ref;
      return PhaseProgress(
        phaseIndex: value.phaseIndex,
        phaseStep: value.phaseStep,
        phaseDuration: value.phaseDuration,
        totalStep: value.totalStep,
        totalDuration: value.totalDuration,
        progress: value.progress,
      );
    } finally {
      calloc.free(outProgress);
    }
  }

  @override
  Future<PresetResult> experimentResult() async {
    return _decodeBuffer((buffer) {
      final status = _native.experimentResult(_requireHandle(), buffer);
      _throwOrFreeStatus(status);
    }, PresetResult.fromJson);
  }

  @override
  Future<ActivitySnapshot> activitySnapshot() async {
    return _decodeBuffer((buffer) {
      final status = _native.activitySnapshot(_requireHandle(), buffer);
      _throwOrFreeStatus(status);
    }, ActivitySnapshot.fromJson);
  }

  @override
  Future<SparseWeightSnapshot> weightSnapshot() async {
    return _decodeBuffer((buffer) {
      final status = _native.weightSnapshot(_requireHandle(), buffer);
      _throwOrFreeStatus(status);
    }, SparseWeightSnapshot.fromJson);
  }

  Future<void> _ensureCreated(SimulationConfig config) async {
    if (_handle == null) {
      await create(config);
    }
  }

  CcnSimulationHandle _requireHandle() {
    final handle = _handle;
    if (handle == null) {
      throw const CcnNativeException(
        kind: CcnErrorKind.invalidHandle,
        message: 'simulation has not been created',
        code: 1,
      );
    }
    return handle.ref;
  }

  T _decodeBuffer<T>(
    void Function(Pointer<CcnBuffer> buffer) call,
    T Function(Map<String, Object?> json) decode,
  ) {
    final outBuffer = calloc<CcnBuffer>();
    try {
      call(outBuffer);
      return decode(decodeJsonObject(outBuffer.ref));
    } finally {
      if (outBuffer.ref.ptr != nullptr) {
        _native.freeBuffer(outBuffer.ref);
      }
      calloc.free(outBuffer);
    }
  }

  StepFrame _copyFrame(CcnStepFrameStruct frame) {
    final events = <SpikeEvent>[];
    for (var i = 0; i < frame.eventCount; i += 1) {
      final event = (frame.events + i).ref;
      events.add(
        SpikeEvent(
          stepOffset: event.stepOffset,
          absoluteStep: event.absoluteStep,
          neuronId: event.neuronId,
          membrane: event.membrane,
        ),
      );
    }
    return StepFrame(
      startStep: frame.startStep,
      steps: frame.steps,
      spikes: events,
      statistics: LiveMetrics(
        totalSpikes: frame.totalSpikes,
        batchSpikes: frame.batchSpikes,
        activeNeuronCount: frame.activeNeuronCount,
        averageWeight: frame.averageWeight,
      ),
    );
  }

  void _throwOrFreeStatus(CcnStatusStruct status) =>
      throwIfStatusError(status, _native.freeBuffer);

  void _withJson(
    Object? json,
    void Function(Pointer<Uint8> pointer, int length) action,
  ) {
    final bytes = utf8.encode(jsonEncode(json));
    final pointer = calloc<Uint8>(bytes.length);
    try {
      for (var i = 0; i < bytes.length; i += 1) {
        pointer[i] = bytes[i];
      }
      action(pointer, bytes.length);
    } finally {
      calloc.free(pointer);
    }
  }
}
