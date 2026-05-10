import 'package:ccn_visualization/core/models/network_visualization.dart';
import 'package:ccn_visualization/core/models/step_frame.dart';
import 'package:ccn_visualization/features/simulation/domain/spike_timing_explanation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const builder = SpikeTimingExplanationBuilder();

  test('explains strengthening when source fires before target', () {
    final explanation = builder.build(
      synapse: _synapse(weightChange: 0.2),
      recentSpikes: const [
        SpikeEvent(stepOffset: 0, absoluteStep: 10, neuronId: 0, membrane: 1),
        SpikeEvent(stepOffset: 1, absoluteStep: 13, neuronId: 1, membrane: 1),
      ],
    );

    expect(explanation.kind, SpikeTimingExplanationKind.strengthening);
    expect(explanation.gap, 3);
    expect(explanation.message, contains('fired before target'));
    expect(explanation.message, contains('strengthened'));
  });

  test('explains weakening when target fires before source', () {
    final explanation = builder.build(
      synapse: _synapse(weightChange: -0.2),
      recentSpikes: const [
        SpikeEvent(stepOffset: 0, absoluteStep: 10, neuronId: 1, membrane: 1),
        SpikeEvent(stepOffset: 1, absoluteStep: 14, neuronId: 0, membrane: 1),
      ],
    );

    expect(explanation.kind, SpikeTimingExplanationKind.weakening);
    expect(explanation.gap, 4);
    expect(explanation.message, contains('Target 1 fired before source 0'));
    expect(explanation.message, contains('weakened'));
  });

  test('reports unavailable when timing evidence is missing', () {
    final explanation = builder.build(
      synapse: _synapse(weightChange: 0.2),
      recentSpikes: const [
        SpikeEvent(stepOffset: 0, absoluteStep: 10, neuronId: 0, membrane: 1),
      ],
    );

    expect(explanation.kind, SpikeTimingExplanationKind.unavailable);
    expect(
      explanation.message,
      contains('Detailed timing evidence is unavailable'),
    );
  });
}

VisualSynapse _synapse({required double weightChange}) {
  return VisualSynapse(
    source: 0,
    target: 1,
    weight: 0.6,
    inhibitory: false,
    signalActivity: 1,
    weightChange: weightChange,
  );
}
