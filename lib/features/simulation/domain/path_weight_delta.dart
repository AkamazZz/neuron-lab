import '../../../core/models/network_visualization.dart';
import 'selected_path_classifier.dart';

enum PathWeightDeltaDirection { strengthened, weakened, unchanged, unknown }

class PathWeightDelta {
  const PathWeightDelta({
    required this.source,
    required this.target,
    required this.before,
    required this.after,
    required this.delta,
    required this.direction,
    required this.label,
  });

  final int source;
  final int target;
  final double? before;
  final double after;
  final double? delta;
  final PathWeightDeltaDirection direction;
  final String label;

  String get key => '$source:$target';
}

class PathWeightDeltaBuilder {
  const PathWeightDeltaBuilder({this.labelLimit = 4});

  final int labelLimit;

  List<PathWeightDelta> build({
    required VisualNetworkFrame frame,
    required SelectedPathClassification selectedPaths,
    required Map<String, double> baselineWeights,
  }) {
    if (selectedPaths.selectedNeuronId == null) {
      return const <PathWeightDelta>[];
    }
    final deltas = <PathWeightDelta>[];
    for (final synapse in frame.synapses) {
      if (!selectedPaths.highlightsSynapse(synapse)) {
        continue;
      }
      final key = '${synapse.source}:${synapse.target}';
      final before = baselineWeights[key];
      final delta = before == null ? null : synapse.weight - before;
      deltas.add(
        PathWeightDelta(
          source: synapse.source,
          target: synapse.target,
          before: before,
          after: synapse.weight,
          delta: delta,
          direction: _direction(delta),
          label: _label(before: before, after: synapse.weight, delta: delta),
        ),
      );
    }
    deltas.sort((a, b) {
      final aMagnitude = a.delta?.abs() ?? -1;
      final bMagnitude = b.delta?.abs() ?? -1;
      final magnitude = bMagnitude.compareTo(aMagnitude);
      if (magnitude != 0) {
        return magnitude;
      }
      return b.after.abs().compareTo(a.after.abs());
    });
    return List<PathWeightDelta>.unmodifiable(deltas.take(labelLimit));
  }

  PathWeightDeltaDirection _direction(double? delta) {
    if (delta == null) {
      return PathWeightDeltaDirection.unknown;
    }
    if (delta > 0.001) {
      return PathWeightDeltaDirection.strengthened;
    }
    if (delta < -0.001) {
      return PathWeightDeltaDirection.weakened;
    }
    return PathWeightDeltaDirection.unchanged;
  }

  String _label({
    required double? before,
    required double after,
    required double? delta,
  }) {
    if (before == null || delta == null) {
      return '? -> ${after.toStringAsFixed(2)}';
    }
    final sign = delta >= 0 ? '+' : '';
    return '${before.toStringAsFixed(2)} -> ${after.toStringAsFixed(2)} ($sign${delta.toStringAsFixed(2)})';
  }
}
