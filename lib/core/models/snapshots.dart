class ActivitySnapshot {
  const ActivitySnapshot({
    this.step = 0,
    this.membranes = const <double>[],
    this.recentFiringRates = const <double>[],
    this.spiked = const <bool>[],
  });

  final int step;
  final List<double> membranes;
  final List<double> recentFiringRates;
  final List<bool> spiked;

  factory ActivitySnapshot.fromJson(Map<String, Object?> json) =>
      ActivitySnapshot(
        step: (json['step'] as num? ?? 0).toInt(),
        membranes: _doubleList(json['membranes']),
        recentFiringRates: _doubleList(json['recent_firing_rates']),
        spiked: (json['spiked'] as List? ?? const <Object?>[])
            .map((value) => value == true)
            .toList(growable: false),
      );
}

class SparseWeightSnapshot {
  const SparseWeightSnapshot({
    this.step = 0,
    this.weights = const <WeightSample>[],
    this.averageWeight = 0,
  });

  final int step;
  final List<WeightSample> weights;
  final double averageWeight;

  factory SparseWeightSnapshot.fromJson(Map<String, Object?> json) =>
      SparseWeightSnapshot(
        step: (json['step'] as num? ?? 0).toInt(),
        averageWeight: (json['average_weight'] as num? ?? 0).toDouble(),
        weights: (json['weights'] as List? ?? const <Object?>[])
            .whereType<Map>()
            .map(
              (value) => WeightSample.fromJson(value.cast<String, Object?>()),
            )
            .toList(growable: false),
      );
}

class WeightSample {
  const WeightSample({
    required this.source,
    required this.target,
    required this.weight,
    required this.inhibitory,
  });

  final int source;
  final int target;
  final double weight;
  final bool inhibitory;

  factory WeightSample.fromJson(Map<String, Object?> json) => WeightSample(
    source: (json['source'] as num? ?? 0).toInt(),
    target: (json['target'] as num? ?? 0).toInt(),
    weight: (json['weight'] as num? ?? 0).toDouble(),
    inhibitory: json['inhibitory'] == true,
  );
}

List<double> _doubleList(Object? value) => (value as List? ?? const <Object?>[])
    .map((item) => (item as num? ?? 0).toDouble())
    .toList(growable: false);
