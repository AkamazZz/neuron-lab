sealed class PresetResult {
  const PresetResult();

  factory PresetResult.fromJson(Map<String, Object?> json) {
    return switch (json['type']) {
      'pattern_recognition' => PatternRecognitionResult.fromJson(json),
      'memory_echo' => MemoryEchoResult.fromJson(json),
      _ => GenericResult.fromJson(json),
    };
  }
}

class CustomPatternResult extends PresetResult {
  const CustomPatternResult({
    required this.patternLabel,
    required this.patternId,
    required this.neuronIds,
    required this.strength,
    required this.dropout,
    required this.targetActiveCount,
    required this.targetSpikeCount,
    required this.offPatternActiveCount,
    required this.offPatternSpikeCount,
    required this.responseSimilarity,
    required this.totalSpikes,
    required this.averageWeight,
  });

  final String patternLabel;
  final String patternId;
  final List<int> neuronIds;
  final double strength;
  final double dropout;
  final int targetActiveCount;
  final int targetSpikeCount;
  final int offPatternActiveCount;
  final int offPatternSpikeCount;
  final double responseSimilarity;
  final int totalSpikes;
  final double averageWeight;
}

class GenericResult extends PresetResult {
  const GenericResult({required this.totalSpikes, required this.averageWeight});

  final int totalSpikes;
  final double averageWeight;

  factory GenericResult.fromJson(Map<String, Object?> json) => GenericResult(
    totalSpikes: (json['total_spikes'] as num? ?? 0).toInt(),
    averageWeight: (json['average_weight'] as num? ?? 0).toDouble(),
  );
}

class PatternRecognitionResult extends PresetResult {
  const PatternRecognitionResult({
    required this.aSelectiveCount,
    required this.bSelectiveCount,
    required this.mixedCount,
    required this.silentCount,
    required this.averageSelectivityScore,
    required this.explanationFacts,
  });

  final int aSelectiveCount;
  final int bSelectiveCount;
  final int mixedCount;
  final int silentCount;
  final double averageSelectivityScore;
  final List<String> explanationFacts;

  factory PatternRecognitionResult.fromJson(Map<String, Object?> json) =>
      PatternRecognitionResult(
        aSelectiveCount: (json['a_selective_count'] as num? ?? 0).toInt(),
        bSelectiveCount: (json['b_selective_count'] as num? ?? 0).toInt(),
        mixedCount: (json['mixed_count'] as num? ?? 0).toInt(),
        silentCount: (json['silent_count'] as num? ?? 0).toInt(),
        averageSelectivityScore:
            (json['average_selectivity_score'] as num? ?? 0).toDouble(),
        explanationFacts: _stringList(json['explanation_facts']),
      );
}

class MemoryEchoResult extends PresetResult {
  const MemoryEchoResult({
    required this.echoDurationSteps,
    required this.decayCurve,
    required this.remainingActiveNeuronCount,
    required this.spontaneousSpikeRate,
    required this.explanationFacts,
  });

  final int echoDurationSteps;
  final List<double> decayCurve;
  final int remainingActiveNeuronCount;
  final double spontaneousSpikeRate;
  final List<String> explanationFacts;

  factory MemoryEchoResult.fromJson(Map<String, Object?> json) =>
      MemoryEchoResult(
        echoDurationSteps: (json['echo_duration_steps'] as num? ?? 0).toInt(),
        decayCurve: (json['decay_curve'] as List? ?? const <Object?>[])
            .map((value) => (value as num? ?? 0).toDouble())
            .toList(growable: false),
        remainingActiveNeuronCount:
            (json['remaining_active_neuron_count'] as num? ?? 0).toInt(),
        spontaneousSpikeRate: (json['spontaneous_spike_rate'] as num? ?? 0)
            .toDouble(),
        explanationFacts: _stringList(json['explanation_facts']),
      );
}

List<String> _stringList(Object? value) => (value as List? ?? const <Object?>[])
    .map((item) => item.toString())
    .toList(growable: false);
