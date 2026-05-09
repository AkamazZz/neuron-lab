class PatternDefinition {
  const PatternDefinition({
    required this.id,
    required this.label,
    required this.activations,
  });

  final String id;
  final String label;
  final List<PatternActivation> activations;

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'activations': activations
        .map((activation) => activation.toJson())
        .toList(),
  };
}

class PatternActivation {
  const PatternActivation({required this.neuronId, required this.current});

  final int neuronId;
  final double current;

  Map<String, Object?> toJson() => {'neuron_id': neuronId, 'current': current};
}
