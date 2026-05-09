import 'package:flutter/widgets.dart';

import '../../../core/models/network_visualization.dart';
import 'selected_path_classifier.dart';
import 'visualization_projection.dart';

class ContinuousNetworkRenderData {
  const ContinuousNetworkRenderData({
    required this.frame,
    required this.projection,
    required this.selectedPaths,
  });

  final VisualNetworkFrame frame;
  final VisualProjection projection;
  final SelectedPathClassification selectedPaths;
}

class ContinuousNetworkRenderDataBuilder {
  const ContinuousNetworkRenderDataBuilder({
    this.projector = const VisualNetworkProjector(),
    this.pathClassifier = const SelectedPathClassifier(),
  });

  final VisualNetworkProjector projector;
  final SelectedPathClassifier pathClassifier;

  ContinuousNetworkRenderData build({
    required VisualNetworkFrame frame,
    required Size size,
    required NeuralFieldCamera camera,
    required int? selectedNeuronId,
  }) {
    return ContinuousNetworkRenderData(
      frame: frame,
      projection: projector.projectFrame(
        frame: frame,
        size: size,
        camera: camera,
      ),
      selectedPaths: pathClassifier.classify(
        frame: frame,
        selectedNeuronId: selectedNeuronId,
      ),
    );
  }
}
