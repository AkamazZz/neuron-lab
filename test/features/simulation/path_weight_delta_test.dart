import 'package:ccn_visualization/core/models/network_visualization.dart';
import 'package:ccn_visualization/features/simulation/domain/path_weight_delta.dart';
import 'package:ccn_visualization/features/simulation/domain/selected_path_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calculates and ranks selected path deltas by magnitude', () {
    const frame = VisualNetworkFrame(
      step: 1,
      phaseLabel: 'Learning',
      neurons: [
        VisualNeuron(
          id: 0,
          type: VisualNeuronType.excitatory,
          x: 0,
          y: 0,
          depth: 0,
          activity: 0,
          spiked: false,
          recentFiringRate: 0,
        ),
        VisualNeuron(
          id: 1,
          type: VisualNeuronType.excitatory,
          x: 0,
          y: 0,
          depth: 0,
          activity: 0,
          spiked: false,
          recentFiringRate: 0,
        ),
        VisualNeuron(
          id: 2,
          type: VisualNeuronType.excitatory,
          x: 0,
          y: 0,
          depth: 0,
          activity: 0,
          spiked: false,
          recentFiringRate: 0,
        ),
      ],
      synapses: [
        VisualSynapse(
          source: 0,
          target: 1,
          weight: 0.8,
          inhibitory: false,
          signalActivity: 0,
          weightChange: 0,
        ),
        VisualSynapse(
          source: 2,
          target: 0,
          weight: 0.1,
          inhibitory: false,
          signalActivity: 0,
          weightChange: 0,
        ),
      ],
    );
    const classifier = SelectedPathClassifier();
    const builder = PathWeightDeltaBuilder();

    final deltas = builder.build(
      frame: frame,
      selectedPaths: classifier.classify(frame: frame, selectedNeuronId: 0),
      baselineWeights: const {'0:1': 0.3, '2:0': 0.5},
    );

    expect(deltas.map((delta) => delta.key), ['0:1', '2:0']);
    expect(deltas.first.delta, closeTo(0.5, 0.0001));
    expect(deltas.first.direction, PathWeightDeltaDirection.strengthened);
    expect(deltas.last.direction, PathWeightDeltaDirection.weakened);
    expect(deltas.first.label, '0.30 -> 0.80 (+0.50)');
  });

  test('marks missing baseline explicitly and caps labels', () {
    const frame = VisualNetworkFrame(
      step: 1,
      phaseLabel: 'Learning',
      neurons: [
        VisualNeuron(
          id: 0,
          type: VisualNeuronType.excitatory,
          x: 0,
          y: 0,
          depth: 0,
          activity: 0,
          spiked: false,
          recentFiringRate: 0,
        ),
        VisualNeuron(
          id: 1,
          type: VisualNeuronType.excitatory,
          x: 0,
          y: 0,
          depth: 0,
          activity: 0,
          spiked: false,
          recentFiringRate: 0,
        ),
        VisualNeuron(
          id: 2,
          type: VisualNeuronType.excitatory,
          x: 0,
          y: 0,
          depth: 0,
          activity: 0,
          spiked: false,
          recentFiringRate: 0,
        ),
      ],
      synapses: [
        VisualSynapse(
          source: 0,
          target: 1,
          weight: 0.4,
          inhibitory: false,
          signalActivity: 0,
          weightChange: 0,
        ),
        VisualSynapse(
          source: 0,
          target: 2,
          weight: 0.2,
          inhibitory: false,
          signalActivity: 0,
          weightChange: 0,
        ),
      ],
    );
    const classifier = SelectedPathClassifier();
    const builder = PathWeightDeltaBuilder(labelLimit: 1);

    final deltas = builder.build(
      frame: frame,
      selectedPaths: classifier.classify(frame: frame, selectedNeuronId: 0),
      baselineWeights: const <String, double>{},
    );

    expect(deltas, hasLength(1));
    expect(deltas.single.before, isNull);
    expect(deltas.single.direction, PathWeightDeltaDirection.unknown);
    expect(deltas.single.label, '? -> 0.40');
  });
}
