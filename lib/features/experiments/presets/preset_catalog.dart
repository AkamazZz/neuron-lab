import '../../../core/models/experiment_definition.dart';
import '../../../core/models/metrics.dart';
import '../../../core/models/pattern.dart';
import '../../../core/models/phase.dart';
import '../../../core/models/simulation_config.dart';

class PresetCatalog {
  static List<ExperimentDefinition> all() => [
    continuousLearningFlow(),
    patternRecognition(),
    memoryEcho(),
  ];

  static ExperimentDefinition continuousLearningFlow({int seed = 144}) {
    final network = SimulationConfig(
      seed: seed,
      neuronCount: 72,
      connectionDensity: 0.15,
      noise: const NoiseConfig(
        inputNoiseProbability: 0.02,
        inputNoiseAmplitude: 0.18,
      ),
    );
    return ExperimentDefinition(
      id: 'continuous_learning_flow',
      label: 'Continuous Learning Flow',
      description:
          'Compare an untrained response, STDP training, then a noisy partial challenge.',
      seed: seed,
      network: network,
      resultKind: PresetKind.patternRecognition,
      patterns: const [
        PatternDefinition(
          id: 'cue_full',
          label: 'Full Cue',
          activations: [
            PatternActivation(neuronId: 8, current: 1.25),
            PatternActivation(neuronId: 12, current: 1.25),
            PatternActivation(neuronId: 16, current: 1.25),
            PatternActivation(neuronId: 20, current: 1.25),
            PatternActivation(neuronId: 24, current: 1.25),
          ],
        ),
        PatternDefinition(
          id: 'cue_partial',
          label: 'Partial Noisy Cue',
          activations: [
            PatternActivation(neuronId: 8, current: 1.2),
            PatternActivation(neuronId: 16, current: 1.2),
            PatternActivation(neuronId: 28, current: 0.65),
          ],
        ),
      ],
      phases: const [
        ExperimentPhase(
          id: 'baseline_untrained',
          phaseType: PhaseKind.probe,
          durationSteps: 110,
          learningEnabled: false,
          schedule: ConstantPatternSchedule(patternId: 'cue_full'),
          phaseSeed: 301,
        ),
        ExperimentPhase(
          id: 'learning_stdp',
          phaseType: PhaseKind.train,
          durationSteps: 260,
          learningEnabled: true,
          schedule: ConstantPatternSchedule(
            patternId: 'cue_full',
            noiseProbability: 0.04,
          ),
          phaseSeed: 302,
        ),
        ExperimentPhase(
          id: 'challenge_partial_noisy',
          phaseType: PhaseKind.probe,
          durationSteps: 120,
          learningEnabled: false,
          schedule: ConstantPatternSchedule(
            patternId: 'cue_partial',
            noiseProbability: 0.14,
          ),
          phaseSeed: 303,
        ),
      ],
      metricWindows: const [
        MetricWindowDefinition(
          id: 'baseline_response',
          phaseId: 'baseline_untrained',
          startStep: 0,
          durationSteps: 110,
        ),
        MetricWindowDefinition(
          id: 'challenge_response',
          phaseId: 'challenge_partial_noisy',
          startStep: 0,
          durationSteps: 120,
        ),
      ],
    );
  }

  static ExperimentDefinition patternRecognition({int seed = 42}) {
    final network = SimulationConfig(seed: seed, neuronCount: 64);
    return ExperimentDefinition(
      id: 'pattern_recognition',
      label: 'Pattern Recognition',
      description:
          'Train alternating A/B inputs, then compare probe responses.',
      seed: seed,
      network: network,
      resultKind: PresetKind.patternRecognition,
      patterns: const [
        PatternDefinition(
          id: 'pattern_a',
          label: 'Pattern A',
          activations: [
            PatternActivation(neuronId: 4, current: 1.25),
            PatternActivation(neuronId: 8, current: 1.25),
            PatternActivation(neuronId: 12, current: 1.25),
            PatternActivation(neuronId: 16, current: 1.25),
          ],
        ),
        PatternDefinition(
          id: 'pattern_b',
          label: 'Pattern B',
          activations: [
            PatternActivation(neuronId: 36, current: 1.25),
            PatternActivation(neuronId: 40, current: 1.25),
            PatternActivation(neuronId: 44, current: 1.25),
            PatternActivation(neuronId: 48, current: 1.25),
          ],
        ),
      ],
      phases: const [
        ExperimentPhase(
          id: 'train_ab',
          phaseType: PhaseKind.train,
          durationSteps: 240,
          learningEnabled: true,
          schedule: SequencePatternSchedule(
            patternIds: ['pattern_a', 'pattern_b'],
            noiseProbability: 0.05,
          ),
          phaseSeed: 101,
        ),
        ExperimentPhase(
          id: 'probe_a',
          phaseType: PhaseKind.probe,
          durationSteps: 90,
          learningEnabled: false,
          schedule: ConstantPatternSchedule(patternId: 'pattern_a'),
          phaseSeed: 102,
        ),
        ExperimentPhase(
          id: 'probe_b',
          phaseType: PhaseKind.probe,
          durationSteps: 90,
          learningEnabled: false,
          schedule: ConstantPatternSchedule(patternId: 'pattern_b'),
          phaseSeed: 103,
        ),
      ],
      metricWindows: const [
        MetricWindowDefinition(
          id: 'probe_a_window',
          phaseId: 'probe_a',
          startStep: 0,
          durationSteps: 90,
        ),
        MetricWindowDefinition(
          id: 'probe_b_window',
          phaseId: 'probe_b',
          startStep: 0,
          durationSteps: 90,
        ),
      ],
    );
  }

  static ExperimentDefinition memoryEcho({int seed = 77}) {
    final network = SimulationConfig(
      seed: seed,
      neuronCount: 72,
      connectionDensity: 0.16,
      noise: const NoiseConfig(
        inputNoiseProbability: 0.02,
        inputNoiseAmplitude: 0.2,
      ),
    );
    return ExperimentDefinition(
      id: 'memory_echo',
      label: 'Memory Echo',
      description:
          'Stimulate one pattern, then observe persistence during silence.',
      seed: seed,
      network: network,
      resultKind: PresetKind.memoryEcho,
      patterns: const [
        PatternDefinition(
          id: 'cue',
          label: 'Cue Pattern',
          activations: [
            PatternActivation(neuronId: 10, current: 1.3),
            PatternActivation(neuronId: 14, current: 1.3),
            PatternActivation(neuronId: 18, current: 1.3),
            PatternActivation(neuronId: 22, current: 1.3),
            PatternActivation(neuronId: 26, current: 1.3),
          ],
        ),
      ],
      phases: const [
        ExperimentPhase(
          id: 'train_cue',
          phaseType: PhaseKind.train,
          durationSteps: 180,
          learningEnabled: true,
          schedule: ConstantPatternSchedule(
            patternId: 'cue',
            noiseProbability: 0.04,
          ),
          phaseSeed: 201,
        ),
        ExperimentPhase(
          id: 'echo_silence',
          phaseType: PhaseKind.probe,
          durationSteps: 220,
          learningEnabled: false,
          schedule: SilencePatternSchedule(),
          phaseSeed: 202,
        ),
      ],
      metricWindows: const [
        MetricWindowDefinition(
          id: 'echo_decay',
          phaseId: 'echo_silence',
          startStep: 0,
          durationSteps: 220,
        ),
      ],
    );
  }
}
