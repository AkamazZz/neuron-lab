import 'package:flutter/widgets.dart';

import '../../../core/models/network_visualization.dart';
import 'selected_path_classifier.dart';
import 'visualization_projection.dart';

class CameraGestureAnchor {
  const CameraGestureAnchor({required this.camera, required this.focalPoint});

  final NeuralFieldCamera camera;
  final Offset focalPoint;
}

class SimulationInteractionController {
  const SimulationInteractionController({
    this.hitTester = const NeuronHitTester(),
    this.pathClassifier = const SelectedPathClassifier(),
  });

  final NeuronHitTester hitTester;
  final SelectedPathClassifier pathClassifier;

  CameraGestureAnchor beginGesture({
    required NeuralFieldCamera camera,
    required Offset focalPoint,
  }) {
    return CameraGestureAnchor(camera: camera, focalPoint: focalPoint);
  }

  NeuralFieldCamera updateGesture({
    required CameraGestureAnchor anchor,
    required Offset focalPoint,
    required double scale,
    required double rotation,
  }) {
    return anchor.camera.copyWith(
      pan: anchor.camera.pan + focalPoint - anchor.focalPoint,
      zoom: anchor.camera.zoom * scale,
      rotation: anchor.camera.rotation + rotation * 0.55,
    );
  }

  int? selectedNeuronAt({
    required VisualNetworkFrame frame,
    required Size size,
    required Offset position,
    required NeuralFieldCamera camera,
  }) {
    return hitTester
        .hitTest(frame: frame, size: size, position: position, camera: camera)
        ?.neuronId;
  }

  NeuralFieldCamera rotateLeft(NeuralFieldCamera camera) =>
      camera.copyWith(rotation: camera.rotation - 0.16);

  NeuralFieldCamera zoomOut(NeuralFieldCamera camera) =>
      camera.copyWith(zoom: camera.zoom / 1.18);

  NeuralFieldCamera zoomIn(NeuralFieldCamera camera) =>
      camera.copyWith(zoom: camera.zoom * 1.18);

  SelectedPathClassification classifyPaths({
    required VisualNetworkFrame frame,
    required int? selectedNeuronId,
  }) {
    return pathClassifier.classify(
      frame: frame,
      selectedNeuronId: selectedNeuronId,
    );
  }
}
