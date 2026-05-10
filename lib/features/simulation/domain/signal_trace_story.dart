import 'package:ccn_visualization/core/models/network_visualization.dart';
import 'package:ccn_visualization/core/models/step_frame.dart';

enum SignalTraceOutcome { reachedLearnedPath, fadedOut, unavailable }

class SignalTraceNode {
  const SignalTraceNode({required this.neuronId, required this.step});

  final int neuronId;
  final int step;
}

class SignalTraceSegment {
  const SignalTraceSegment({
    required this.source,
    required this.target,
    required this.startStep,
    required this.endStep,
    required this.weight,
    required this.weightChange,
  });

  final int source;
  final int target;
  final int startStep;
  final int endStep;
  final double weight;
  final double weightChange;

  String get key => '$source:$target';
}

class SignalTraceStory {
  const SignalTraceStory({
    required this.selectedNeuronId,
    required this.nodes,
    required this.segments,
    required this.outcome,
    required this.explanation,
  });

  const SignalTraceStory.unavailable({
    required this.selectedNeuronId,
    required this.explanation,
  }) : nodes = const <SignalTraceNode>[],
       segments = const <SignalTraceSegment>[],
       outcome = SignalTraceOutcome.unavailable;

  final int selectedNeuronId;
  final List<SignalTraceNode> nodes;
  final List<SignalTraceSegment> segments;
  final SignalTraceOutcome outcome;
  final String explanation;

  bool get isAvailable => outcome != SignalTraceOutcome.unavailable;
  int get playbackLength => nodes.length + segments.length;
}

class SignalTracePlayback {
  const SignalTracePlayback({
    this.active = false,
    this.playing = false,
    this.cursor = 0,
    this.speed = 1.0,
    this.story,
  });

  final bool active;
  final bool playing;
  final int cursor;
  final double speed;
  final SignalTraceStory? story;

  SignalTraceSegment? get activeSegment {
    final current = story;
    if (!active || current == null || current.segments.isEmpty) {
      return null;
    }
    final segmentIndex = (cursor - 1) ~/ 2;
    if (segmentIndex < 0 || segmentIndex >= current.segments.length) {
      return null;
    }
    return current.segments[segmentIndex];
  }

  SignalTracePlayback copyWith({
    bool? active,
    bool? playing,
    int? cursor,
    double? speed,
    SignalTraceStory? story,
    bool clearStory = false,
  }) {
    return SignalTracePlayback(
      active: active ?? this.active,
      playing: playing ?? this.playing,
      cursor: cursor ?? this.cursor,
      speed: (speed ?? this.speed).clamp(0.25, 3.0),
      story: clearStory ? null : story ?? this.story,
    );
  }
}

class SignalTraceStoryBuilder {
  const SignalTraceStoryBuilder({this.maxEvents = 18, this.maxSegments = 6});

  final int maxEvents;
  final int maxSegments;

  SignalTraceStory build({
    required int selectedNeuronId,
    required VisualNetworkFrame frame,
    required List<SpikeEvent> recentSpikes,
  }) {
    if (frame.neuronById(selectedNeuronId) == null) {
      return SignalTraceStory.unavailable(
        selectedNeuronId: selectedNeuronId,
        explanation:
            'Trace unavailable because the selected neuron is not in the current network frame.',
      );
    }

    final attached = frame.synapses
        .where(
          (synapse) =>
              synapse.source == selectedNeuronId ||
              synapse.target == selectedNeuronId,
        )
        .toList(growable: false);
    if (attached.isEmpty) {
      return SignalTraceStory.unavailable(
        selectedNeuronId: selectedNeuronId,
        explanation:
            'Trace unavailable because this neuron has no attached telemetry paths.',
      );
    }

    final frameNeuronIds = frame.neurons.map((neuron) => neuron.id).toSet();
    final orderedEvents =
        recentSpikes
            .where((event) => frameNeuronIds.contains(event.neuronId))
            .toList(growable: false)
          ..sort((a, b) => a.absoluteStep.compareTo(b.absoluteStep));
    final startIndex = orderedEvents.indexWhere(
      (event) => event.neuronId == selectedNeuronId,
    );
    if (startIndex == -1) {
      return SignalTraceStory.unavailable(
        selectedNeuronId: selectedNeuronId,
        explanation:
            'Not enough recent activity to replay a trace from this neuron.',
      );
    }

    final events = orderedEvents.skip(startIndex).take(maxEvents).toList();
    if (events.isEmpty) {
      return SignalTraceStory.unavailable(
        selectedNeuronId: selectedNeuronId,
        explanation:
            'Not enough recent activity to replay a trace from this neuron.',
      );
    }

    final nodes = <SignalTraceNode>[
      for (final event in events)
        SignalTraceNode(neuronId: event.neuronId, step: event.absoluteStep),
    ];
    final synapsesByKey = {
      for (final synapse in frame.synapses)
        _key(synapse.source, synapse.target): synapse,
    };
    final segments = <SignalTraceSegment>[];
    for (var i = 0; i < events.length - 1; i += 1) {
      if (segments.length >= maxSegments) {
        break;
      }
      final source = events[i].neuronId;
      final target = events[i + 1].neuronId;
      if (source == target) {
        continue;
      }
      final synapse = synapsesByKey[_key(source, target)];
      if (synapse == null) {
        continue;
      }
      segments.add(
        SignalTraceSegment(
          source: source,
          target: target,
          startStep: events[i].absoluteStep,
          endStep: events[i + 1].absoluteStep,
          weight: synapse.weight,
          weightChange: synapse.weightChange,
        ),
      );
    }

    if (segments.isEmpty) {
      return SignalTraceStory(
        selectedNeuronId: selectedNeuronId,
        nodes: List<SignalTraceNode>.unmodifiable(nodes.take(maxEvents)),
        segments: const <SignalTraceSegment>[],
        outcome: SignalTraceOutcome.fadedOut,
        explanation:
            'Recent activity touched this neuron, then no continuing active path was visible in the captured telemetry.',
      );
    }

    final reachedLearnedPath = segments.any(
      (segment) =>
          segment.weight.abs() >= 0.55 || segment.weightChange.abs() >= 0.05,
    );
    return SignalTraceStory(
      selectedNeuronId: selectedNeuronId,
      nodes: List<SignalTraceNode>.unmodifiable(nodes.take(maxEvents)),
      segments: List<SignalTraceSegment>.unmodifiable(segments),
      outcome: reachedLearnedPath
          ? SignalTraceOutcome.reachedLearnedPath
          : SignalTraceOutcome.fadedOut,
      explanation: reachedLearnedPath
          ? 'The replay follows a recently active path with strengthened or high-weight connections.'
          : 'The replay shows recent activity, but it fades before a strong learned path is visible.',
    );
  }

  String _key(int source, int target) => '$source:$target';
}
