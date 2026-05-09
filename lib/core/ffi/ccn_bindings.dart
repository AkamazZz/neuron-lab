import 'dart:ffi';

final class CcnSimulationHandle extends Struct {
  @Uint64()
  external int id;
}

final class CcnBuffer extends Struct {
  external Pointer<Uint8> ptr;

  @Size()
  external int len;

  @Size()
  external int cap;
}

final class CcnStatusStruct extends Struct {
  @Uint32()
  external int code;

  @Uint32()
  external int errorKind;

  external CcnBuffer message;
}

final class CcnSpikeEventStruct extends Struct {
  @Uint32()
  external int stepOffset;

  @Uint64()
  external int absoluteStep;

  @Uint32()
  external int neuronId;

  @Float()
  external double membrane;
}

final class CcnStepFrameStruct extends Struct {
  @Uint64()
  external int startStep;

  @Uint32()
  external int steps;

  @Size()
  external int eventCount;

  external Pointer<CcnSpikeEventStruct> events;

  @Uint64()
  external int totalSpikes;

  @Uint32()
  external int batchSpikes;

  @Uint32()
  external int activeNeuronCount;

  @Float()
  external double averageWeight;
}

final class CcnPhaseProgressStruct extends Struct {
  @Uint32()
  external int phaseIndex;

  @Uint32()
  external int phaseStep;

  @Uint32()
  external int phaseDuration;

  @Uint32()
  external int totalStep;

  @Uint32()
  external int totalDuration;

  @Float()
  external double progress;
}

typedef CcnAbiVersionNative = Uint32 Function();
typedef CcnAbiVersionDart = int Function();

typedef CcnValidateConfigNative =
    CcnStatusStruct Function(Pointer<Uint8>, Size, Pointer<CcnBuffer>);
typedef CcnValidateConfigDart =
    CcnStatusStruct Function(Pointer<Uint8>, int, Pointer<CcnBuffer>);

typedef CcnCreateSimulationNative =
    CcnStatusStruct Function(
      Pointer<Uint8>,
      Size,
      Pointer<CcnSimulationHandle>,
    );
typedef CcnCreateSimulationDart =
    CcnStatusStruct Function(Pointer<Uint8>, int, Pointer<CcnSimulationHandle>);

typedef CcnFreeSimulationNative = CcnStatusStruct Function(CcnSimulationHandle);
typedef CcnFreeSimulationDart = CcnStatusStruct Function(CcnSimulationHandle);

typedef CcnRawResetNative =
    CcnStatusStruct Function(CcnSimulationHandle, Uint32);
typedef CcnRawResetDart = CcnStatusStruct Function(CcnSimulationHandle, int);

typedef CcnRawStepNative =
    CcnStatusStruct Function(
      CcnSimulationHandle,
      Pointer<Uint8>,
      Size,
      Uint32,
      Bool,
      Pointer<CcnStepFrameStruct>,
    );
typedef CcnRawStepDart =
    CcnStatusStruct Function(
      CcnSimulationHandle,
      Pointer<Uint8>,
      int,
      int,
      bool,
      Pointer<CcnStepFrameStruct>,
    );

typedef CcnValidateExperimentNative =
    CcnStatusStruct Function(Pointer<Uint8>, Size, Pointer<CcnBuffer>);
typedef CcnValidateExperimentDart =
    CcnStatusStruct Function(Pointer<Uint8>, int, Pointer<CcnBuffer>);

typedef CcnLoadExperimentNative =
    CcnStatusStruct Function(CcnSimulationHandle, Pointer<Uint8>, Size);
typedef CcnLoadExperimentDart =
    CcnStatusStruct Function(CcnSimulationHandle, Pointer<Uint8>, int);

typedef CcnClearExperimentNative =
    CcnStatusStruct Function(CcnSimulationHandle);
typedef CcnClearExperimentDart = CcnStatusStruct Function(CcnSimulationHandle);

typedef CcnStepExperimentNative =
    CcnStatusStruct Function(
      CcnSimulationHandle,
      Uint32,
      Pointer<CcnStepFrameStruct>,
    );
typedef CcnStepExperimentDart =
    CcnStatusStruct Function(
      CcnSimulationHandle,
      int,
      Pointer<CcnStepFrameStruct>,
    );

typedef CcnExperimentStateNative =
    CcnStatusStruct Function(CcnSimulationHandle, Pointer<Uint32>);
typedef CcnExperimentStateDart =
    CcnStatusStruct Function(CcnSimulationHandle, Pointer<Uint32>);

typedef CcnPhaseProgressNative =
    CcnStatusStruct Function(
      CcnSimulationHandle,
      Pointer<CcnPhaseProgressStruct>,
    );
typedef CcnPhaseProgressDart =
    CcnStatusStruct Function(
      CcnSimulationHandle,
      Pointer<CcnPhaseProgressStruct>,
    );

typedef CcnExperimentResultNative =
    CcnStatusStruct Function(CcnSimulationHandle, Pointer<CcnBuffer>);
typedef CcnExperimentResultDart =
    CcnStatusStruct Function(CcnSimulationHandle, Pointer<CcnBuffer>);

typedef CcnSnapshotNative =
    CcnStatusStruct Function(CcnSimulationHandle, Pointer<CcnBuffer>);
typedef CcnSnapshotDart =
    CcnStatusStruct Function(CcnSimulationHandle, Pointer<CcnBuffer>);

typedef CcnFreeStepFrameNative = Void Function(CcnStepFrameStruct);
typedef CcnFreeStepFrameDart = void Function(CcnStepFrameStruct);

typedef CcnFreeBufferNative = Void Function(CcnBuffer);
typedef CcnFreeBufferDart = void Function(CcnBuffer);
