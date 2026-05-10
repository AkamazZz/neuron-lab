import 'package:flutter/material.dart';

import 'package:ccn_visualization/core/models/preset_result.dart';

class ResultPanel extends StatelessWidget {
  const ResultPanel({super.key, required this.result});

  final PresetResult? result;

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    if (result == null) {
      return const Text('Run an experiment to produce a result summary.');
    }
    return switch (result) {
      PatternRecognitionResult() => _PatternRecognitionResultView(
        result: result,
      ),
      MemoryEchoResult() => _MemoryEchoResultView(result: result),
      CustomPatternResult() => _CustomPatternResultView(result: result),
      GenericResult() => Text(
        'Total spikes ${result.totalSpikes}, average weight ${result.averageWeight.toStringAsFixed(3)}.',
      ),
    };
  }
}

class _CustomPatternResultView extends StatelessWidget {
  const _CustomPatternResultView({required this.result});

  final CustomPatternResult result;

  @override
  Widget build(BuildContext context) {
    final neurons = result.neuronIds.isEmpty
        ? 'none'
        : result.neuronIds.join(', ');
    return Text(
      'Custom pattern ${result.patternLabel} (${result.patternId}) used '
      'neurons $neurons at current ${result.strength.toStringAsFixed(2)} '
      'with train dropout ${(result.dropout * 100).toStringAsFixed(0)}%. '
      'Probe target activation ${result.targetActiveCount}/${result.neuronIds.length}, '
      'target probe spikes ${result.targetSpikeCount}; off-pattern activation '
      '${result.offPatternActiveCount}, off-pattern probe spikes '
      '${result.offPatternSpikeCount}. Response similarity '
      '${result.responseSimilarity.toStringAsFixed(2)}.',
    );
  }
}

class _PatternRecognitionResultView extends StatelessWidget {
  const _PatternRecognitionResultView({required this.result});

  final PatternRecognitionResult result;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Probe responses separated into A-selective ${result.aSelectiveCount}, '
      'B-selective ${result.bSelectiveCount}, mixed ${result.mixedCount}, and '
      'silent ${result.silentCount}. Average selectivity score: '
      '${result.averageSelectivityScore.toStringAsFixed(3)}.',
    );
  }
}

class _MemoryEchoResultView extends StatelessWidget {
  const _MemoryEchoResultView({required this.result});

  final MemoryEchoResult result;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Post-cue activity persisted for ${result.echoDurationSteps} steps before '
      'decay. Remaining active neurons: ${result.remainingActiveNeuronCount}; '
      'spontaneous spike rate: ${result.spontaneousSpikeRate.toStringAsFixed(3)}.',
    );
  }
}
