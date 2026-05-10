import 'dart:ffi';
import 'dart:io';

import 'package:ccn_visualization/core/ffi/ccn_bindings.dart';

class CcnNative {
  CcnNative._(this.library)
    : abiVersion = library
          .lookupFunction<CcnAbiVersionNative, CcnAbiVersionDart>(
            'ccn_abi_version',
          ),
      validateConfig = library
          .lookupFunction<CcnValidateConfigNative, CcnValidateConfigDart>(
            'ccn_validate_config',
          ),
      createSimulation = library
          .lookupFunction<CcnCreateSimulationNative, CcnCreateSimulationDart>(
            'ccn_create_simulation',
          ),
      freeSimulation = library
          .lookupFunction<CcnFreeSimulationNative, CcnFreeSimulationDart>(
            'ccn_free_simulation',
          ),
      rawReset = library.lookupFunction<CcnRawResetNative, CcnRawResetDart>(
        'ccn_raw_reset',
      ),
      rawStep = library.lookupFunction<CcnRawStepNative, CcnRawStepDart>(
        'ccn_raw_step',
      ),
      validateExperiment = library
          .lookupFunction<
            CcnValidateExperimentNative,
            CcnValidateExperimentDart
          >('ccn_validate_experiment'),
      loadExperiment = library
          .lookupFunction<CcnLoadExperimentNative, CcnLoadExperimentDart>(
            'ccn_load_experiment',
          ),
      clearExperiment = library
          .lookupFunction<CcnClearExperimentNative, CcnClearExperimentDart>(
            'ccn_clear_experiment',
          ),
      stepExperiment = library
          .lookupFunction<CcnStepExperimentNative, CcnStepExperimentDart>(
            'ccn_step_experiment',
          ),
      experimentState = library
          .lookupFunction<CcnExperimentStateNative, CcnExperimentStateDart>(
            'ccn_experiment_state',
          ),
      phaseProgress = library
          .lookupFunction<CcnPhaseProgressNative, CcnPhaseProgressDart>(
            'ccn_phase_progress',
          ),
      experimentResult = library
          .lookupFunction<CcnExperimentResultNative, CcnExperimentResultDart>(
            'ccn_experiment_result',
          ),
      activitySnapshot = library
          .lookupFunction<CcnSnapshotNative, CcnSnapshotDart>(
            'ccn_activity_snapshot',
          ),
      weightSnapshot = library
          .lookupFunction<CcnSnapshotNative, CcnSnapshotDart>(
            'ccn_weight_snapshot',
          ),
      freeStepFrame = library
          .lookupFunction<CcnFreeStepFrameNative, CcnFreeStepFrameDart>(
            'ccn_free_step_frame',
          ),
      freeBuffer = library
          .lookupFunction<CcnFreeBufferNative, CcnFreeBufferDart>(
            'ccn_free_buffer',
          );

  static const expectedAbiVersion = 1;

  final DynamicLibrary library;
  final CcnAbiVersionDart abiVersion;
  final CcnValidateConfigDart validateConfig;
  final CcnCreateSimulationDart createSimulation;
  final CcnFreeSimulationDart freeSimulation;
  final CcnRawResetDart rawReset;
  final CcnRawStepDart rawStep;
  final CcnValidateExperimentDart validateExperiment;
  final CcnLoadExperimentDart loadExperiment;
  final CcnClearExperimentDart clearExperiment;
  final CcnStepExperimentDart stepExperiment;
  final CcnExperimentStateDart experimentState;
  final CcnPhaseProgressDart phaseProgress;
  final CcnExperimentResultDart experimentResult;
  final CcnSnapshotDart activitySnapshot;
  final CcnSnapshotDart weightSnapshot;
  final CcnFreeStepFrameDart freeStepFrame;
  final CcnFreeBufferDart freeBuffer;

  static CcnNative loadAndVerify({DynamicLibrary? library}) {
    final native = CcnNative._(library ?? _openLibrary());
    final version = native.abiVersion();
    if (version != expectedAbiVersion) {
      throw StateError(
        'Unsupported CCN ABI version $version, expected $expectedAbiVersion',
      );
    }
    return native;
  }

  static DynamicLibrary _openLibrary() {
    const nativeAssetName =
        'package:ccn_visualization/core/ffi/ccn_bindings.dart';
    for (final candidate in _localBuildPaths()) {
      if (File(candidate).existsSync()) {
        return DynamicLibrary.open(candidate);
      }
    }
    try {
      return DynamicLibrary.open(nativeAssetName);
    } catch (_) {
      return DynamicLibrary.open(_libraryFileName());
    }
  }

  static Iterable<String> _localBuildPaths() sync* {
    final fileName = _libraryFileName();
    final nativeAssetsDir = Platform.isMacOS
        ? 'macos'
        : Platform.isLinux
        ? 'linux'
        : Platform.isWindows
        ? 'windows'
        : Platform.isAndroid
        ? 'android'
        : Platform.isIOS
        ? 'ios'
        : null;
    for (final root in _candidateRoots()) {
      if (nativeAssetsDir != null) {
        yield '$root/build/native_assets/$nativeAssetsDir/$fileName';
      }
      yield '$root/rust/target/release/$fileName';
      yield '$root/rust/target/debug/$fileName';
      yield '$root/rust/target/release/deps/$fileName';
      yield '$root/rust/target/debug/deps/$fileName';
    }
  }

  static Iterable<String> _candidateRoots() sync* {
    final seen = <String>{};
    for (final start in [
      Directory.current.path,
      File(Platform.resolvedExecutable).parent.path,
    ]) {
      var directory = Directory(start);
      while (true) {
        final path = directory.absolute.path;
        if (seen.add(path)) {
          yield path;
        }
        final parent = directory.parent.absolute.path;
        if (parent == path) {
          break;
        }
        directory = Directory(parent);
      }
    }
  }

  static String _libraryFileName() {
    if (Platform.isMacOS || Platform.isIOS) {
      return 'libccn_simulation_core.dylib';
    }
    if (Platform.isLinux || Platform.isAndroid) {
      return 'libccn_simulation_core.so';
    }
    if (Platform.isWindows) {
      return 'ccn_simulation_core.dll';
    }
    throw UnsupportedError('Unsupported platform for CCN native library');
  }
}
