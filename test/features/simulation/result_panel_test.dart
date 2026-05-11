import 'package:ccn_visualization/core/models/preset_result.dart';
import 'package:ccn_visualization/features/simulation/ui/result_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('custom pattern result shows identity and response metrics', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResultPanel(
            result: CustomPatternResult(
              patternLabel: 'Pattern B',
              patternId: 'pattern_b',
              neuronIds: [3, 7],
              strength: 1.5,
              dropout: 0.2,
              targetActiveCount: 1,
              targetSpikeCount: 4,
              offPatternActiveCount: 9,
              offPatternSpikeCount: 12,
              responseSimilarity: 0.5,
              totalSpikes: 30,
              averageWeight: 0.4,
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Custom pattern Pattern B'), findsOneWidget);
    expect(find.textContaining('neurons 3, 7'), findsOneWidget);
    expect(find.textContaining('current 1.50'), findsOneWidget);
    expect(find.textContaining('train dropout 20%'), findsOneWidget);
    expect(find.textContaining('target probe spikes 4'), findsOneWidget);
    expect(find.textContaining('off-pattern probe spikes 12'), findsOneWidget);
    expect(find.textContaining('Response similarity 0.50'), findsOneWidget);
  });
}
