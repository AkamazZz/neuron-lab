import 'package:ccn_visualization/core/models/network_visualization.dart';
import 'package:ccn_visualization/core/models/step_frame.dart';
import 'package:ccn_visualization/features/simulation/domain/signal_trace_story.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const builder = SignalTraceStoryBuilder();

  test('builds bounded trace from selected neuron and recent spikes', () {
    final story = builder.build(
      selectedNeuronId: 0,
      frame: _frame(),
      recentSpikes: const [
        SpikeEvent(stepOffset: 0, absoluteStep: 1, neuronId: 0, membrane: 1),
        SpikeEvent(stepOffset: 1, absoluteStep: 2, neuronId: 1, membrane: 1),
        SpikeEvent(stepOffset: 2, absoluteStep: 3, neuronId: 2, membrane: 1),
      ],
    );

    expect(story.isAvailable, isTrue);
    expect(story.outcome, SignalTraceOutcome.reachedLearnedPath);
    expect(story.nodes.map((node) => node.neuronId), [0, 1, 2]);
    expect(story.segments.map((segment) => segment.key), ['0:1', '1:2']);
  });

  test('represents fade out when no continuing active segment is visible', () {
    final story = builder.build(
      selectedNeuronId: 0,
      frame: _frame(),
      recentSpikes: const [
        SpikeEvent(stepOffset: 0, absoluteStep: 1, neuronId: 0, membrane: 1),
        SpikeEvent(stepOffset: 1, absoluteStep: 2, neuronId: 3, membrane: 1),
      ],
    );

    expect(story.outcome, SignalTraceOutcome.fadedOut);
    expect(story.segments, isEmpty);
    expect(story.explanation, contains('no continuing active path'));
  });

  test('represents unavailable trace when selected neuron has no activity', () {
    final story = builder.build(
      selectedNeuronId: 0,
      frame: _frame(),
      recentSpikes: const [
        SpikeEvent(stepOffset: 0, absoluteStep: 1, neuronId: 1, membrane: 1),
      ],
    );

    expect(story.outcome, SignalTraceOutcome.unavailable);
    expect(story.explanation, contains('Not enough recent activity'));
  });
}

VisualNetworkFrame _frame() {
  return const VisualNetworkFrame(
    step: 4,
    phaseLabel: 'Learning',
    neurons: [
      VisualNeuron(
        id: 0,
        type: VisualNeuronType.excitatory,
        x: 0.2,
        y: 0.2,
        depth: 0.1,
        activity: 1,
        spiked: true,
        recentFiringRate: 0.8,
      ),
      VisualNeuron(
        id: 1,
        type: VisualNeuronType.excitatory,
        x: 0.4,
        y: 0.4,
        depth: 0.2,
        activity: 0.8,
        spiked: true,
        recentFiringRate: 0.6,
      ),
      VisualNeuron(
        id: 2,
        type: VisualNeuronType.inhibitory,
        x: 0.6,
        y: 0.6,
        depth: 0.3,
        activity: 0.6,
        spiked: true,
        recentFiringRate: 0.4,
      ),
    ],
    synapses: [
      VisualSynapse(
        source: 0,
        target: 1,
        weight: 0.7,
        inhibitory: false,
        signalActivity: 1,
        weightChange: 0.1,
      ),
      VisualSynapse(
        source: 1,
        target: 2,
        weight: 0.4,
        inhibitory: false,
        signalActivity: 1,
        weightChange: 0,
      ),
    ],
  );
}
