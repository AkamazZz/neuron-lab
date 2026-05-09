import 'package:flutter/material.dart';

import '../../../core/models/preset_result.dart';

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
      GenericResult() => Text(
        'Total spikes ${result.totalSpikes}, average weight ${result.averageWeight.toStringAsFixed(3)}.',
      ),
    };
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
