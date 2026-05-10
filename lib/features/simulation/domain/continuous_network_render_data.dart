import 'package:flutter/widgets.dart';

import '../../../core/models/network_visualization.dart';
import 'path_weight_delta.dart';
import 'selected_path_classifier.dart';
import 'signal_trace_story.dart';
import 'visualization_projection.dart';

class ContinuousNetworkRenderData {
  const ContinuousNetworkRenderData({
    required this.frame,
    required this.projection,
    required this.selectedPaths,
    required this.activeTraceSegment,
    required this.weightDeltas,
  });

  final VisualNetworkFrame frame;
  final VisualProjection projection;
  final SelectedPathClassification selectedPaths;
  final SignalTraceSegment? activeTraceSegment;
  final List<PathWeightDelta> weightDeltas;
}

class ContinuousNetworkRenderDataBuilder {
  const ContinuousNetworkRenderDataBuilder({
    this.projector = const VisualNetworkProjector(),
    this.pathClassifier = const SelectedPathClassifier(),
    this.deltaBuilder = const PathWeightDeltaBuilder(),
  });

  final VisualNetworkProjector projector;
  final SelectedPathClassifier pathClassifier;
  final PathWeightDeltaBuilder deltaBuilder;

  ContinuousNetworkRenderData build({
    required VisualNetworkFrame frame,
    required Size size,
    required NeuralFieldCamera camera,
    required int? selectedNeuronId,
    SignalTraceSegment? activeTraceSegment,
    bool showWeightDeltaOverlay = false,
    Map<String, double> baselineWeights = const <String, double>{},
  }) {
    final selectedPaths = pathClassifier.classify(
      frame: frame,
      selectedNeuronId: selectedNeuronId,
    );
    return ContinuousNetworkRenderData(
      frame: frame,
      projection: projector.projectFrame(
        frame: frame,
        size: size,
        camera: camera,
      ),
      selectedPaths: selectedPaths,
      activeTraceSegment: activeTraceSegment,
      weightDeltas: showWeightDeltaOverlay
          ? deltaBuilder.build(
              frame: frame,
              selectedPaths: selectedPaths,
              baselineWeights: baselineWeights,
            )
          : const <PathWeightDelta>[],
    );
  }
}
