class SimulationConfig {
  const SimulationConfig({
    this.schemaVersion = 1,
    required this.seed,
    this.neuronCount = 64,
    this.inhibitoryFraction = 0.2,
    this.connectionDensity = 0.12,
    this.threshold = 1.0,
    this.resetPotential = 0.0,
    this.membraneDecay = 0.9,
    this.recoveryDecay = 0.95,
    this.adaptationIncrement = 0.05,
    this.minExcitatoryWeight = 0.05,
    this.maxExcitatoryWeight = 0.8,
    this.maxInhibitoryWeight = 0.8,
    this.learning = const LearningConfig(),
    this.noise = const NoiseConfig(),
  });

  final int schemaVersion;
  final int seed;
  final int neuronCount;
  final double inhibitoryFraction;
  final double connectionDensity;
  final double threshold;
  final double resetPotential;
  final double membraneDecay;
  final double recoveryDecay;
  final double adaptationIncrement;
  final double minExcitatoryWeight;
  final double maxExcitatoryWeight;
  final double maxInhibitoryWeight;
  final LearningConfig learning;
  final NoiseConfig noise;

  Map<String, Object?> toJson() => {
    'schema_version': schemaVersion,
    'seed': seed,
    'neuron_count': neuronCount,
    'inhibitory_fraction': inhibitoryFraction,
    'connection_density': connectionDensity,
    'threshold': threshold,
    'reset_potential': resetPotential,
    'membrane_decay': membraneDecay,
    'recovery_decay': recoveryDecay,
    'adaptation_increment': adaptationIncrement,
    'min_excitatory_weight': minExcitatoryWeight,
    'max_excitatory_weight': maxExcitatoryWeight,
    'max_inhibitory_weight': maxInhibitoryWeight,
    'learning': learning.toJson(),
    'noise': noise.toJson(),
  };
}

class LearningConfig {
  const LearningConfig({
    this.enabled = true,
    this.potentiationRate = 0.04,
    this.depressionRate = 0.025,
    this.positiveWindowSteps = 6,
    this.negativeWindowSteps = 6,
    this.traceDecay = 0.9,
  });

  final bool enabled;
  final double potentiationRate;
  final double depressionRate;
  final int positiveWindowSteps;
  final int negativeWindowSteps;
  final double traceDecay;

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'potentiation_rate': potentiationRate,
    'depression_rate': depressionRate,
    'positive_window_steps': positiveWindowSteps,
    'negative_window_steps': negativeWindowSteps,
    'trace_decay': traceDecay,
  };
}

class NoiseConfig {
  const NoiseConfig({
    this.inputNoiseProbability = 0,
    this.inputNoiseAmplitude = 0,
  });

  final double inputNoiseProbability;
  final double inputNoiseAmplitude;

  Map<String, Object?> toJson() => {
    'input_noise_probability': inputNoiseProbability,
    'input_noise_amplitude': inputNoiseAmplitude,
  };
}
