import 'package:flutter/material.dart';
import 'package:ccn_visualization/core/models/metrics.dart';
import 'package:ccn_visualization/core/models/snapshots.dart';

enum VisualNeuronType { excitatory, inhibitory }

class VisualNeuron {
  const VisualNeuron({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.depth,
    required this.activity,
    required this.spiked,
    required this.recentFiringRate,
  });

  final int id;
  final VisualNeuronType type;
  final double x;
  final double y;
  final double depth;
  final double activity;
  final bool spiked;
  final double recentFiringRate;
}

class VisualSynapse {
  const VisualSynapse({
    required this.source,
    required this.target,
    required this.weight,
    required this.inhibitory,
    required this.signalActivity,
    required this.weightChange,
  });

  final int source;
  final int target;
  final double weight;
  final bool inhibitory;
  final double signalActivity;
  final double weightChange;
}

class VisualNetworkFrame {
  const VisualNetworkFrame({
    required this.neurons,
    required this.synapses,
    required this.step,
    required this.phaseLabel,
  });

  final List<VisualNeuron> neurons;
  final List<VisualSynapse> synapses;
  final int step;
  final String phaseLabel;

  bool get isEmpty => neurons.isEmpty;

  VisualNeuron? neuronById(int id) {
    for (final neuron in neurons) {
      if (neuron.id == id) {
        return neuron;
      }
    }
    return null;
  }
}

class VariantSnapshot {
  const VariantSnapshot({
    required this.phaseIndex,
    required this.phaseId,
    required this.label,
    required this.activity,
    required this.weights,
    required this.metrics,
    required this.step,
  });

  final int phaseIndex;
  final String phaseId;
  final String label;
  final ActivitySnapshot activity;
  final SparseWeightSnapshot weights;
  final LiveMetrics metrics;
  final int step;
}

class NeuralFieldCamera {
  const NeuralFieldCamera({
    this.pan = Offset.zero,
    this.zoom = 1.0,
    this.rotation = 0.0,
    this.depthTilt = 0.08,
  });

  final Offset pan;
  final double zoom;
  final double rotation;
  final double depthTilt;

  static const defaults = NeuralFieldCamera();

  NeuralFieldCamera copyWith({
    Offset? pan,
    double? zoom,
    double? rotation,
    double? depthTilt,
  }) {
    return NeuralFieldCamera(
      pan: pan ?? this.pan,
      zoom: (zoom ?? this.zoom).clamp(0.55, 3.2),
      rotation: rotation ?? this.rotation,
      depthTilt: (depthTilt ?? this.depthTilt).clamp(-0.18, 0.18),
    );
  }
}
