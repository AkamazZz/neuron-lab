import 'package:flutter_test/flutter_test.dart';

import 'package:ccn_visualization/core/models/preset_result.dart';

void main() {
  test('decodes custom pattern response result from Rust JSON', () {
    final result = PresetResult.fromJson({
      'type': 'custom_pattern_response',
      'pattern_id': 'pattern_b',
      'pattern_label': 'Pattern B',
      'neuron_ids': [3, 7, 11],
      'strength': 1.5,
      'dropout': 0.2,
      'target_active_count': 2,
      'target_spike_count': 8,
      'off_pattern_active_count': 4,
      'off_pattern_spike_count': 12,
      'response_similarity': 0.67,
      'total_spikes': 30,
      'average_weight': 0.41,
      'explanation_facts': ['computed by Rust'],
    });

    expect(result, isA<CustomPatternResult>());
    final custom = result as CustomPatternResult;
    expect(custom.patternId, 'pattern_b');
    expect(custom.patternLabel, 'Pattern B');
    expect(custom.neuronIds, <int>[3, 7, 11]);
    expect(custom.strength, 1.5);
    expect(custom.dropout, 0.2);
    expect(custom.targetActiveCount, 2);
    expect(custom.targetSpikeCount, 8);
    expect(custom.offPatternActiveCount, 4);
    expect(custom.offPatternSpikeCount, 12);
    expect(custom.responseSimilarity, 0.67);
    expect(custom.totalSpikes, 30);
    expect(custom.averageWeight, 0.41);
    expect(custom.explanationFacts, <String>['computed by Rust']);
  });
}
