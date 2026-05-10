import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:ccn_visualization/core/models/experiment_definition.dart';
import 'package:ccn_visualization/core/models/network_visualization.dart';
import 'package:ccn_visualization/core/models/snapshots.dart';
import 'package:ccn_visualization/core/models/step_frame.dart';

class ProjectedNeuron {
  const ProjectedNeuron({
    required this.neuron,
    required this.center,
    required this.depthScale,
    required this.radius,
  });

  final VisualNeuron neuron;
  final Offset center;
  final double depthScale;
  final double radius;
}

class VisualProjection {
  const VisualProjection({required this.neurons});

  final List<ProjectedNeuron> neurons;

  Map<int, Offset> get positions => {
    for (final projected in neurons) projected.neuron.id: projected.center,
  };

  ProjectedNeuron? byId(int id) {
    for (final projected in neurons) {
      if (projected.neuron.id == id) {
        return projected;
      }
    }
    return null;
  }
}

class NeuronHitTestResult {
  const NeuronHitTestResult({required this.neuronId, required this.distance});

  final int neuronId;
  final double distance;
}

class VisualNetworkProjector {
  const VisualNetworkProjector();

  VisualNetworkFrame project({
    required ExperimentDefinition experiment,
    required ActivitySnapshot activity,
    required SparseWeightSnapshot weights,
    required StepFrame? latestFrame,
    required Map<String, double> baselineWeights,
    required int currentStep,
    required String phaseLabel,
  }) {
    final neuronCount = experiment.network.neuronCount;
    if (neuronCount <= 0) {
      return VisualNetworkFrame(
        neurons: const <VisualNeuron>[],
        synapses: const <VisualSynapse>[],
        step: currentStep,
        phaseLabel: phaseLabel,
      );
    }

    final inhibitoryCount =
        (neuronCount * experiment.network.inhibitoryFraction).round();
    final neurons = List<VisualNeuron>.generate(neuronCount, (id) {
      final position = _layout(id, neuronCount, experiment.seed);
      final membrane = id < activity.membranes.length
          ? activity.membranes[id]
          : 0.0;
      final firingRate = id < activity.recentFiringRates.length
          ? activity.recentFiringRates[id]
          : 0.0;
      final spiked = id < activity.spiked.length && activity.spiked[id];
      return VisualNeuron(
        id: id,
        type: id < inhibitoryCount
            ? VisualNeuronType.inhibitory
            : VisualNeuronType.excitatory,
        x: position.x,
        y: position.y,
        depth: position.depth,
        activity: math.max(membrane, firingRate).clamp(0.0, 1.4),
        spiked: spiked,
        recentFiringRate: firingRate.clamp(0.0, 1.0),
      );
    }, growable: false);

    final recentSources = <int>{
      for (final event in latestFrame?.spikes ?? const <SpikeEvent>[])
        event.neuronId,
    };
    final synapses = weights.weights
        .map((sample) {
          final key = '${sample.source}:${sample.target}';
          final baseline = baselineWeights[key] ?? sample.weight;
          return VisualSynapse(
            source: sample.source,
            target: sample.target,
            weight: sample.weight,
            inhibitory: sample.inhibitory,
            signalActivity: recentSources.contains(sample.source) ? 1.0 : 0.0,
            weightChange: sample.weight - baseline,
          );
        })
        .toList(growable: false);

    return VisualNetworkFrame(
      neurons: neurons,
      synapses: synapses,
      step: currentStep,
      phaseLabel: phaseLabel,
    );
  }

  VisualProjection projectFrame({
    required VisualNetworkFrame frame,
    required Size size,
    NeuralFieldCamera camera = NeuralFieldCamera.defaults,
  }) {
    return VisualProjection(
      neurons: frame.neurons
          .map(
            (neuron) => ProjectedNeuron(
              neuron: neuron,
              center: projectNeuron(neuron, size: size, camera: camera),
              depthScale: 0.7 + neuron.depth * 0.8,
              radius:
                  (5.5 + neuron.recentFiringRate.clamp(0.0, 1.0) * 8.0) *
                  (0.7 + neuron.depth * 0.8) *
                  camera.zoom.clamp(0.75, 1.55),
            ),
          )
          .toList(growable: false),
    );
  }

  Offset projectNeuron(
    VisualNeuron neuron, {
    required Size size,
    NeuralFieldCamera camera = NeuralFieldCamera.defaults,
  }) {
    final perspective = 0.78 + neuron.depth * 0.22;
    var x = (neuron.x - 0.5) * perspective;
    var y =
        (neuron.y - 0.5) * perspective -
        (neuron.depth - 0.5) * camera.depthTilt;
    final cosRotation = math.cos(camera.rotation);
    final sinRotation = math.sin(camera.rotation);
    final rotatedX = x * cosRotation - y * sinRotation;
    final rotatedY = x * sinRotation + y * cosRotation;
    x = rotatedX * camera.zoom + 0.5;
    y = rotatedY * camera.zoom + 0.5;
    return Offset(x * size.width, y * size.height) + camera.pan;
  }

  _LayoutPoint _layout(int id, int count, int seed) {
    final golden = math.pi * (3.0 - math.sqrt(5.0));
    final t = count == 1 ? 0.0 : id / (count - 1);
    final seedTurn = (seed % 360) * math.pi / 180.0;
    final angle = id * golden + seedTurn;
    final radius = math.sqrt(t).clamp(0.0, 1.0);
    final depth = (0.5 + 0.5 * math.sin(angle * 0.73 + seed * 0.013)).clamp(
      0.0,
      1.0,
    );
    return _LayoutPoint(
      x: 0.5 + math.cos(angle) * radius * 0.43,
      y: 0.5 + math.sin(angle) * radius * 0.34 - (depth - 0.5) * 0.08,
      depth: depth,
    );
  }
}

class NeuronHitTester {
  const NeuronHitTester({this.projector = const VisualNetworkProjector()});

  final VisualNetworkProjector projector;

  NeuronHitTestResult? hitTest({
    required VisualNetworkFrame frame,
    required Size size,
    required Offset position,
    NeuralFieldCamera camera = NeuralFieldCamera.defaults,
    double baseThreshold = 18,
  }) {
    if (size.isEmpty || frame.neurons.isEmpty) {
      return null;
    }
    final projection = projector.projectFrame(
      frame: frame,
      size: size,
      camera: camera,
    );
    ProjectedNeuron? best;
    var bestScore = double.infinity;
    var bestDistance = double.infinity;
    for (final projected in projection.neurons) {
      final distance = (projected.center - position).distance;
      final threshold = math.max(baseThreshold, projected.radius * 1.45);
      if (distance > threshold) {
        continue;
      }
      final depthBias = (1.0 - projected.neuron.depth) * 4.0;
      final score = distance + depthBias;
      if (score < bestScore) {
        best = projected;
        bestScore = score;
        bestDistance = distance;
      }
    }
    if (best == null) {
      return null;
    }
    return NeuronHitTestResult(
      neuronId: best.neuron.id,
      distance: bestDistance,
    );
  }
}

class _LayoutPoint {
  const _LayoutPoint({required this.x, required this.y, required this.depth});

  final double x;
  final double y;
  final double depth;
}
